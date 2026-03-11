# backend.py
import os
import sys
import json
import time
import threading
from typing import Optional, Dict, List

import serial
from serial.tools import list_ports

from PySide6.QtCore import QObject, Slot, Signal

# -------- Serial defaults (TWO ARDUINOS) --------
DEFAULT_PORT_A = "COM4" if sys.platform.startswith("win") else "/dev/ttyACM0"
DEFAULT_PORT_B = "COM6" if sys.platform.startswith("win") else "/dev/ttyACM1"

SERIAL_PORT_A = os.environ.get("PUMP_SERIAL_PORT_A", DEFAULT_PORT_A)
SERIAL_PORT_B = os.environ.get("PUMP_SERIAL_PORT_B", DEFAULT_PORT_B)
SERIAL_PORT   = SERIAL_PORT_A

BAUD            = 115200
OPEN_RETRY_SEC  = 2.0


class PumpLink:
    """
    Low-level serial link to a single Arduino running the RAMPS pump firmware.
    """

    def __init__(self, port: str = SERIAL_PORT, baud: int = BAUD):
        self.port = port
        self.baud = baud
        self.ser: Optional[serial.Serial] = None
        self._stop = False
        self._rx_thread: Optional[threading.Thread] = None
        self._tx_lock = threading.Lock()

    # ---------- Port management ----------

    def open(self) -> bool:
        if self.ser and self.ser.is_open:
            return True
        while not self._stop:
            try:
                print(f"[PumpLink] Opening {self.port} @ {self.baud}…")
                self.ser = serial.Serial(self.port, self.baud, timeout=0.1)
                if not self._rx_thread or not self._rx_thread.is_alive():
                    self._rx_thread = threading.Thread(
                        target=self._rx_loop, daemon=True
                    )
                    self._rx_thread.start()
                print("[PumpLink] Port open ✓")
                return True
            except Exception as e:
                print(f"[PumpLink] open failed on {self.port}: {e}; retrying in {OPEN_RETRY_SEC}s")
                time.sleep(OPEN_RETRY_SEC)
        return False

    def close(self):
        self._stop = True
        try:
            if self.ser and self.ser.is_open:
                self.ser.close()
                print(f"[PumpLink] Port {self.port} closed")
        except Exception as e:
            print(f"[PumpLink] close error on {self.port}: {e}")

    # ---------- TX helper ----------

    def _send(self, obj: dict):
        data = (json.dumps(obj) + "\n").encode("utf-8")
        with self._tx_lock:
            try:
                if not self.ser or not self.ser.is_open:
                    if not self.open():
                        print(f"[PumpLink] write skipped (port {self.port} not open)")
                        return
                print(f"[PumpLink] TX({self.port}): {data!r}")
                self.ser.write(data)
                self.ser.flush()
            except Exception as e:
                print(f"[PumpLink] write error on {self.port}: {e}")

    # ---------- Public API ----------

    def set_flow(self, pump: int, ul_per_min: float):
        self._send({"pump": int(pump), "flow": float(ul_per_min)})

    def prime(self, pump: int):
        self._send({"prime": int(pump)})

    def stop(self, pump: int):
        self._send({"stop": int(pump)})

    def stop_all(self):
        self._send({"stop_all": True})

    def start_wave(
        self,
        pump: int,
        shape: str,
        period_sec: float,
        duty_fraction: float,
        min_flow_ul_min: Optional[float] = None,
        max_flow_ul_min: Optional[float] = None,
        base_flow_ul_min: Optional[float] = None,
    ):
        pump       = int(pump)
        shape      = str(shape)
        period_sec = float(period_sec) if period_sec > 0 else 1.0

        duty_fraction = float(duty_fraction)
        if duty_fraction <= 0:  duty_fraction = 0.5
        if duty_fraction >= 1:  duty_fraction = 0.99
        duty_percent = duty_fraction * 100.0

        if min_flow_ul_min is None and max_flow_ul_min is None and base_flow_ul_min is not None:
            min_flow_ul_min = 0.0
            max_flow_ul_min = float(base_flow_ul_min)

        if min_flow_ul_min is None: min_flow_ul_min = 0.0
        if max_flow_ul_min is None: max_flow_ul_min = min_flow_ul_min

        min_flow_ul_min = max(0.0, float(min_flow_ul_min))
        max_flow_ul_min = max(0.0, float(max_flow_ul_min))
        if max_flow_ul_min < min_flow_ul_min:
            min_flow_ul_min, max_flow_ul_min = max_flow_ul_min, min_flow_ul_min

        self._send({
            "wave": {
                "pump":     pump,
                "shape":    shape,
                "period":   period_sec,
                "duty":     duty_percent,
                "min_flow": min_flow_ul_min,
                "max_flow": max_flow_ul_min,
            }
        })

    def wave_off(self, pump: int, fallback_flow: float = 0.0):
        self.start_wave(
            pump=pump, shape="off", period_sec=1.0, duty_fraction=0.5,
            min_flow_ul_min=0.0, max_flow_ul_min=float(fallback_flow),
        )

    # ---------- RX loop ----------

    def _rx_loop(self):
        buf = b""
        while not self._stop:
            try:
                chunk = self.ser.read(256) if self.ser else b""
                if not chunk:
                    time.sleep(0.01)
                    continue
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        print(f"[PumpLink] RX({self.port}, raw): {line.decode('utf-8', 'ignore')}")
                    except Exception:
                        print(f"[PumpLink] RX({self.port}, bytes): {line!r}")
            except Exception as e:
                print(f"[PumpLink] rx error on {self.port}: {e}")
                time.sleep(0.25)


# ===========================================================
#                    QML-facing backend
# ===========================================================

class QBackend(QObject):
    """
    QObject wrapper exported to QML as 'backend'.

    Arduino A: pumps 1, 4, 5, 7, 8
    Arduino B: pumps 2, 3, 6, 9

    Calibration factors are set from QML via setCalibrationFactors().
    Every flow value sent to the Arduino is multiplied by the matching
    per-pump calibration factor before transmission.
    """

    connectionChanged = Signal(bool)
    lastErrorChanged  = Signal(str)

    PUMP_MAP_A: Dict[int, int] = {1: 1, 4: 2, 5: 3, 7: 4, 8: 5}
    PUMP_MAP_B: Dict[int, int] = {2: 1, 3: 2, 6: 3, 9: 4}

    def __init__(self, parent=None):
        super().__init__(parent)
        self.linkA = PumpLink(port=SERIAL_PORT_A, baud=BAUD)
        self.linkB = PumpLink(port=SERIAL_PORT_B, baud=BAUD)

        self.last_flows:   Dict[int, float] = {}
        self.paused_flows: Dict[int, float] = {}
        self._last_error = ""

        # 9 calibration factors indexed by global pump id (1-based)
        # default 1.0 = no scaling until QML provides real values
        self._cal_factors: Dict[int, float] = {i: 1.0 for i in range(1, 10)}

    # ---------- Calibration ----------

    @Slot("QVariantList")
    def setCalibrationFactors(self, factors):
        """
        Receive a list of 9 calibration factors from QML (index 0 = pump 1).
        Each factor converts µL/min → the unit the Arduino expects
        (i.e. actual_flow_sent = requested_flow * factor).
        """
        for i, f in enumerate(factors):
            pump_id = i + 1
            try:
                val = float(f)
                self._cal_factors[pump_id] = val if val > 0 else 1.0
            except (TypeError, ValueError):
                self._cal_factors[pump_id] = 1.0
        print(f"[QBackend] calibration factors updated: {self._cal_factors}")

    def _cal(self, global_pump_id: int) -> float:
        """Return calibration factor for a global pump id."""
        return self._cal_factors.get(int(global_pump_id), 1.0)

    # ---------- Internal helpers ----------

    def _set_error(self, msg: str):
        if msg != self._last_error:
            self._last_error = msg
            print(f"[QBackend] ERROR: {msg}")
            self.lastErrorChanged.emit(msg)

    def _route_pump(self, pump: int):
        p = int(pump)
        if p in self.PUMP_MAP_A:
            return self.linkA, self.PUMP_MAP_A[p]
        if p in self.PUMP_MAP_B:
            return self.linkB, self.PUMP_MAP_B[p]
        self._set_error(f"Invalid pump id {p}")
        return None, None

    def _all_links(self):
        return [self.linkA, self.linkB]

    # ---------- Lifecycle ----------

    @Slot(result=bool)
    def open(self) -> bool:
        okA = self.linkA.open()
        okB = self.linkB.open()
        ok  = okA and okB
        self.connectionChanged.emit(ok)
        if not ok:
            self._set_error("Failed to open one or both serial ports")
        else:
            self._set_error("")
        return ok

    @Slot()
    def close(self):
        for link in self._all_links():
            link.close()
        self.connectionChanged.emit(False)

    @Slot()
    def refreshPorts(self):
        ports = list_ports.comports()
        print("[QBackend] Available serial ports:")
        for p in ports:
            print("  ", p.device)

    # ---------- Basic pump commands ----------

    @Slot("QVariant")
    @Slot(int)
    @Slot(float)
    def prime(self, pump):
        p = int(pump)
        link, local = self._route_pump(p)
        if not link:
            return
        print(f"[QBackend] prime(global={p} -> local={local})")
        link.prime(local)

    @Slot("QVariant")
    @Slot(int)
    @Slot(float)
    def stop(self, pump):
        p = int(pump)
        link, local = self._route_pump(p)
        if not link:
            return
        print(f"[QBackend] stop(global={p} -> local={local})")
        link.stop(local)
        link.wave_off(local, 0.0)

    @Slot()
    def stopAll(self):
        print("[QBackend] stopAll()")
        for link in self._all_links():
            link.stop_all()

    @Slot()
    def stop_all(self):
        self.stopAll()

    @Slot("QVariant", "QVariant")
    @Slot(int, float)
    @Slot(int, int)
    def set_flow(self, pump, ul_per_min):
        """
        Send a constant flow. The requested flow is multiplied by the
        pump's calibration factor before being sent to the Arduino.
        """
        p   = int(pump)
        f   = float(ul_per_min)
        cal = self._cal(p)
        f_cal = f * cal

        link, local = self._route_pump(p)
        if not link:
            return
        print(f"[QBackend] set_flow(global={p} -> local={local}, "
              f"requested={f} µL/min, cal={cal}, sending={f_cal} µL/min)")
        self.last_flows[p] = f          # store uncalibrated for resume/display
        link.set_flow(local, f_cal)

    # ---------- Pause / resume ----------

    @Slot()
    def pauseAll(self):
        print("[QBackend] pauseAll()")
        self.paused_flows = dict(self.last_flows)
        for link in self._all_links():
            link.stop_all()

    @Slot()
    def pause_all(self):
        self.pauseAll()

    @Slot("QVariantList")
    def pausePumps(self, pumpIds):
        ids: List[int] = [int(p) for p in pumpIds]
        print(f"[QBackend] pausePumps(global={ids})")
        for p in ids:
            if p in self.last_flows:
                self.paused_flows[p] = self.last_flows[p]
            link, local = self._route_pump(p)
            if link:
                link.stop(local)

    @Slot("QVariantList")
    def resumePumps(self, pumpIds):
        ids: List[int] = [int(p) for p in pumpIds]
        print(f"[QBackend] resumePumps(global={ids})")
        for p in ids:
            flow = self.paused_flows.get(p, self.last_flows.get(p, 0.0))
            if flow > 0:
                self.set_flow(p, flow)   # goes through calibration
            else:
                print(f"[QBackend]  -> no saved flow for pump {p}, leaving off")
        for p in ids:
            self.paused_flows.pop(p, None)

    # ---------- Automation ----------

    @Slot("QVariantList", "QVariantList", "QVariantList", "QVariantList",
          "QVariantList", "QVariantList", "QVariantList", "QVariantList")
    def startAutomation(self, pumpIds, modes, shapes, minutes,
                        periods, dutyFractions, minFlows, maxFlows):
        """
        Dispatch each pump to the correct command based on its mode:
          - Constant  → set_flow  (calibrated)
          - Pulsatile → startWaveForPump  (calibrated inside that method)
        """
        for i, pumpId in enumerate(pumpIds):
            mode = str(modes[i])
            if mode == "Constant":
                # maxFlows[i] holds the base/target flow for constant mode
                self.set_flow(int(pumpId), float(maxFlows[i]))
            else:
                self.startWaveForPump(
                    pumpId, shapes[i],
                    periods[i], dutyFractions[i],
                    minFlows[i], maxFlows[i]
                )

    # ---------- Per-pump pulsatile ----------

    @Slot(int, str, float, float, float, float)
    def startWaveForPump(
        self,
        pump: int,
        shape: str,
        period_sec: float,
        dutyFraction: float,
        minFlow: float,
        maxFlow: float,
    ):
        """
        Send a pulsatile wave command. Both min and max flow values are
        multiplied by the pump's calibration factor before sending.
        """
        p            = int(pump)
        shape        = str(shape)
        period_sec   = float(period_sec)
        dutyFraction = float(dutyFraction)
        minFlow      = float(minFlow)
        maxFlow      = float(maxFlow)
        cal          = self._cal(p)

        minFlow_cal = minFlow * cal
        maxFlow_cal = maxFlow * cal

        link, local = self._route_pump(p)
        if not link:
            return

        print(
            f"[QBackend] startWaveForPump(global={p} -> local={local}, shape={shape}, "
            f"period={period_sec}s, dutyFraction={dutyFraction}, "
            f"min={minFlow}->{minFlow_cal} µL/min, max={maxFlow}->{maxFlow_cal} µL/min)"
        )

        if maxFlow > 0:
            self.last_flows[p] = maxFlow

        link.start_wave(
            pump=local,
            shape=shape,
            period_sec=period_sec,
            duty_fraction=dutyFraction,
            min_flow_ul_min=minFlow_cal,
            max_flow_ul_min=maxFlow_cal,
        )

    # ---------- Calibration stub (kept for QML compatibility) ----------

    @Slot("QVariant", "QVariant")
    @Slot(int, float)
    @Slot(int, int)
    def set_calibration(self, pump, ul_per_rev):
        p = int(pump)
        link, local = self._route_pump(p)
        if not link:
            return
        print(f"[QBackend] set_calibration(global={p} -> local={local}, "
              f"ul_per_rev={float(ul_per_rev)})  (no-op)")
