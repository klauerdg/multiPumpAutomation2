/*
 * RAMPS 1.4 Pump Controller for QML/Python backend
 *
 * Commands (newline-terminated JSON at 115200 baud), matching backend.py:
 *
 *   {"prime": N}
 *   {"pump": N, "flow": F}          // µL/min, N = 1..5 on each board
 *   {"stop": N}
 *   {"stop_all": true}
 *
 *   {"wave": {
 *       "pump":      N,
 *       "shape":     "Square" | "Sinusoidal" | "off",
 *       "period":    T_seconds,
 *       "duty":      D_percent,      // 0..100, only used for Square
 *       "min_flow":  Fmin_ul_per_min,
 *       "max_flow":  Fmax_ul_per_min
 *   }}
 *
 * - For shape "off", we disable pulsatile mode for that pump and set a
 *   constant flow equal to max_flow (or 0 if not provided).
 */

#include <AccelStepper.h>

// ---------- RAMPS 1.4 pins ----------
#define X_EN   38
#define X_DIR   A1
#define X_STP   A0

#define Y_EN    A2
#define Y_DIR   A7
#define Y_STP   A6

#define Z_EN    A8
#define Z_DIR  48
#define Z_STP  46

#define E0_EN  24
#define E0_DIR 28
#define E0_STP 26

#define E1_EN  30
#define E1_DIR 34
#define E1_STP 36

// ---------- Config ----------
#define BAUD 115200

// Map local pump number 1..5 -> which driver to use.
// You can choose any ordering; this one matches your original sketch.
enum DriverId {DRV_E1=0, DRV_E0, DRV_X, DRV_Y, DRV_Z, DRV_COUNT};
const DriverId PUMP_MAP[DRV_COUNT] = {DRV_E1, DRV_E0, DRV_X, DRV_Y, DRV_Z};

// Prime / flow mapping
const float PRIME_SPS            = 250.0f;  // priming speed (steps/s)
const float FLOW_UL_PER_MIN_MAX  = 60.0f;   // "60 µL/min" -> MAX_SPS
const float MAX_SPS              = 720.0f;  // steps/s at that max (tune if needed)

// ---------- Objects ----------
AccelStepper steppers[DRV_COUNT] = {
  AccelStepper(AccelStepper::DRIVER, E1_STP, E1_DIR),  // DRV_E1
  AccelStepper(AccelStepper::DRIVER, E0_STP, E0_DIR),  // DRV_E0
  AccelStepper(AccelStepper::DRIVER, X_STP,  X_DIR ),  // DRV_X
  AccelStepper(AccelStepper::DRIVER, Y_STP,  Y_DIR ),  // DRV_Y
  AccelStepper(AccelStepper::DRIVER, Z_STP,  Z_DIR )   // DRV_Z
};

const uint8_t EN_PINS[DRV_COUNT] = { E1_EN, E0_EN, X_EN, Y_EN, Z_EN };

// State
float    targetSps[DRV_COUNT] = {0,0,0,0,0};
String   line;

enum WaveShape { WAVE_NONE=0, WAVE_SINE, WAVE_SQUARE };

struct WaveCfg {
  bool     active     = false;
  WaveShape shape     = WAVE_NONE;
  uint32_t startMs    = 0;
  uint32_t periodMs   = 1000;   // ms
  float    duty       = 0.5f;   // 0..1 (for square)
  float    minUl      = 0.0f;   // µL/min
  float    maxUl      = 0.0f;   // µL/min
};

WaveCfg waves[DRV_COUNT];
bool debugEnabled = false;
uint32_t lastDebugMs[DRV_COUNT] = {0,0,0,0,0};

// ---------- Helpers ----------
void enableDriver(DriverId d, bool en) {
  // RAMPS enable is active LOW
  digitalWrite(EN_PINS[d], en ? LOW : HIGH);
}

void setSpeedSps(DriverId d, float sps) {
  if (sps < 0) sps = -sps;
  targetSps[d] = sps;

  if (sps > 0.0f) {
    enableDriver(d, true);
    steppers[d].setMaxSpeed(sps);
    steppers[d].setSpeed(sps);  // constant speed; runSpeed() in loop
  } else {
    steppers[d].setSpeed(0);
    enableDriver(d, false);
  }
}

void setSpeedForFlow(DriverId d, float flowUlPerMin) {
  float sps = 0.0f;
  if (flowUlPerMin > 0.0f) {
    sps = (flowUlPerMin / FLOW_UL_PER_MIN_MAX) * MAX_SPS;
    if (sps < 0.0f)   sps = 0.0f;
    if (sps > MAX_SPS) sps = MAX_SPS;
  }
  setSpeedSps(d, sps);
}

void stopAll() {
  for (int i = 0; i < DRV_COUNT; ++i) {
    targetSps[i]    = 0;
    steppers[i].setSpeed(0);
    enableDriver((DriverId)i, false);
    waves[i].active = false;
  }
}

static int readIntAfter(const String& s, const String& key, int deflt=-1) {
  int k = s.indexOf(key);
  if (k < 0) return deflt;
  k = s.indexOf(':', k);
  if (k < 0) return deflt;
  int j = k + 1;
  while (j < (int)s.length() && s[j] == ' ') j++;
  return s.substring(j).toInt();
}

static float readFloatAfter(const String& s, const String& key, float deflt=0.0f) {
  int k = s.indexOf(key);
  if (k < 0) return deflt;
  k = s.indexOf(':', k);
  if (k < 0) return deflt;
  int j = k + 1;
  while (j < (int)s.length() && s[j] == ' ') j++;
  return s.substring(j).toFloat();
}

static String readStringAfter(const String& s, const String& key, const String& deflt="") {
  int k = s.indexOf(key);
  if (k < 0) return deflt;
  k = s.indexOf(':', k);
  if (k < 0) return deflt;
  int j = k + 1;
  while (j < (int)s.length() && s[j] == ' ') j++;
  if (j >= (int)s.length()) return deflt;
  if (s[j] == '"') {
    int m = s.indexOf('"', j+1);
    if (m < 0) return deflt;
    return s.substring(j+1, m);
  }
  int m = j;
  while (m < (int)s.length() && s[m] != ',' && s[m] != '}' && s[m] != ']') m++;
  return s.substring(j, m);
}

static bool readBoolAfter(const String& s, const String& key, bool deflt=false) {
  int k = s.indexOf(key);
  if (k < 0) return deflt;
  k = s.indexOf(':', k);
  if (k < 0) return deflt;
  int j = k + 1;
  while (j < (int)s.length() && s[j] == ' ') j++;
  int m = j;
  while (m < (int)s.length() && s[m] != ',' && s[m] != '}' && s[m] != ']') m++;
  String tok = s.substring(j, m);
  tok.toLowerCase();
  if (tok.startsWith("t") || tok.startsWith("1")) return true;
  return false;
}

// Map local pump number (1..5) to driver
bool uiPumpToDriver(int pump, DriverId &outDrv) {
  if (pump < 1 || pump > 5) return false;
  outDrv = PUMP_MAP[(pump - 1) % DRV_COUNT];
  return true;
}

void handleLine(const String& s) {
  // {"prime": N}
  if (s.indexOf("\"prime\"") >= 0) {
    int p = readIntAfter(s, "\"prime\"");
    if (p >= 1) {
      DriverId d;
      if (!uiPumpToDriver(p, d)) return;
      setSpeedSps(d, PRIME_SPS);
      Serial.println(F("{\"ack\":\"prime_on\"}"));
      return;
    }
  }

  // {"pump": N, "flow": F}
  if (s.indexOf("\"pump\"") >= 0 && s.indexOf("\"flow\"") >= 0) {
    int p = readIntAfter(s, "\"pump\"");
    float flow = readFloatAfter(s, "\"flow\"");
    if (p >= 1) {
      DriverId d;
      if (!uiPumpToDriver(p, d)) return;
      setSpeedForFlow(d, flow);
      Serial.println(F("{\"ack\":\"set_flow\"}"));
      return;
    }
  }

  // {"stop_all": true}
  if (s.indexOf("\"stop_all\"") >= 0) {
    stopAll();
    Serial.println(F("{\"ack\":\"stop_all\"}"));
    return;
  }

  // {"stop": N}
  if (s.indexOf("\"stop\"") >= 0 && s.indexOf("\"stop_all\"") < 0) {
    int p = readIntAfter(s, "\"stop\"");
    if (p >= 1) {
      DriverId d;
      if (!uiPumpToDriver(p, d)) return;
      setSpeedSps(d, 0.0f);
      waves[d].active = false;
      Serial.println(F("{\"ack\":\"stop\"}"));
      return;
    }
  }

  // {"wave": { ... }}
  if (s.indexOf("\"wave\"") >= 0) {
    int p = readIntAfter(s, "\"pump\"");
    if (p >= 1) {
      DriverId d;
      if (!uiPumpToDriver(p, d)) return;

      String shapeStr = readStringAfter(s, "\"shape\"");
      shapeStr.trim();
      String shapeLower = shapeStr;
      shapeLower.toLowerCase();

      float periodSec   = readFloatAfter(s, "\"period\"", 1.0f);
      float dutyPercent = readFloatAfter(s, "\"duty\"", 50.0f);
      float minFlowUl   = readFloatAfter(s, "\"min_flow\"", 0.0f);
      float maxFlowUl   = readFloatAfter(s, "\"max_flow\"", 0.0f);

      if (shapeLower == "off") {
        // Turn off pulsatile, optionally set constant flow = max_flow
        waves[d].active = false;
        setSpeedForFlow(d, maxFlowUl);
        Serial.println(F("{\"ack\":\"wave_off\"}"));
        return;
      }

      WaveShape shape = WAVE_SINE;
      if (shapeLower.indexOf("square") >= 0) shape = WAVE_SQUARE;
      else if (shapeLower.indexOf("sin") >= 0) shape = WAVE_SINE;

      if (periodSec <= 0.0f) periodSec = 1.0f;

      // Configure wave
      waves[d].active   = true;
      waves[d].shape    = shape;
      waves[d].startMs  = millis();
      waves[d].periodMs = (uint32_t)(periodSec * 1000.0f);
      float dutyFrac    = dutyPercent / 100.0f;
      if (dutyFrac < 0.0f) dutyFrac = 0.0f;
      if (dutyFrac > 1.0f) dutyFrac = 1.0f;
      waves[d].duty     = dutyFrac;
      waves[d].minUl    = minFlowUl;
      waves[d].maxUl    = maxFlowUl;

      if (debugEnabled) {
        Serial.print("{\"dbg\":\"wave_cfg\",\"pump\":");
        Serial.print(p);
        Serial.print(",\"shape\":\"");
        Serial.print(shapeStr);
        Serial.print("\",\"period_s\":");
        Serial.print(periodSec);
        Serial.print(",\"duty\":");
        Serial.print(waves[d].duty);
        Serial.print(",\"min_ul\":");
        Serial.print(waves[d].minUl);
        Serial.print(",\"max_ul\":");
        Serial.print(waves[d].maxUl);
        Serial.println("}");
      }

      Serial.println(F("{\"ack\":\"wave\"}"));
      return;
    }
  }

  // {"debug": true} or {"debug": false}
  if (s.indexOf("\"debug\"") >= 0) {
    bool val = readBoolAfter(s, "\"debug\"", false);
    debugEnabled = val;
    if (debugEnabled) Serial.println(F("{\"ack\":\"debug_on\"}"));
    else Serial.println(F("{\"ack\":\"debug_off\"}"));
    return;
  }
}

void setup() {
  Serial.begin(BAUD);

  for (int i = 0; i < DRV_COUNT; ++i) {
    pinMode(EN_PINS[i], OUTPUT);
    enableDriver((DriverId)i, false);  // disabled at boot
    steppers[i].setAcceleration(2000);
    steppers[i].setMaxSpeed(1500);
    steppers[i].setSpeed(0);
  }

  Serial.println(F("{\"status\":\"ready\"}"));
}

void loop() {
  // ----- read serial line -----
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (line.length()) {
        handleLine(line);
        line = "";
      }
    } else {
      line += c;
      if (line.length() > 300) line = ""; // safety reset
    }
  }

  // ----- run motors (with optional waveform override) -----
  uint32_t now = millis();
  for (int i = 0; i < DRV_COUNT; ++i) {
    if (waves[i].active) {
      uint32_t dt = now - waves[i].startMs;
      if (waves[i].periodMs == 0) waves[i].periodMs = 1000;
      uint32_t t   = dt % waves[i].periodMs;
      float frac   = (float)t / (float)waves[i].periodMs; // 0..1
      float value  = 0.0f; // normalized 0..1

      switch (waves[i].shape) {
        case WAVE_SINE:
          value = 0.5f * (1.0f + sinf(2.0f * 3.14159265f * frac));
          break;
        case WAVE_SQUARE:
          value = (frac < waves[i].duty) ? 1.0f : 0.0f;
          break;
        default:
          value = 0.0f;
          break;
      }

      float flow_ul = waves[i].minUl + (waves[i].maxUl - waves[i].minUl) * value;
      setSpeedForFlow((DriverId)i, flow_ul);

      if (debugEnabled) {
        const uint32_t DBG_INTERVAL = 500; // ms
        if (now - lastDebugMs[i] >= DBG_INTERVAL) {
          lastDebugMs[i] = now;
          Serial.print("{\"dbg_pump\":");
          Serial.print(i+1);
          Serial.print(",\"flow_ul\":");
          Serial.print(flow_ul);
          Serial.print(",\"value\":");
          Serial.print(value);
          Serial.println("}");
        }
      }

      steppers[i].runSpeed();
    } else {
      steppers[i].runSpeed();   // just keep running at current speed
    }
  }
}
