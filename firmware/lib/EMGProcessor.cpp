#include "EMGProcessor.h"
#include <math.h>

EMGProcessor::EMGProcessor(uint8_t adcPin)
    : _pin(adcPin), _lastRaw(0), _baseline(0), _envelope(0), _mvcMax(1.0f),
      _mvcCalActive(false), _mvcCalEnd(0) {}

void EMGProcessor::begin() {
    pinMode(_pin, INPUT);
    analogSetPinAttenuation(_pin, ADC_11db); // full 0-3.3V input range
    _lastRaw = analogRead(_pin);
    _baseline = _lastRaw; // seed so baseline doesn't ramp up from zero on boot
}

void EMGProcessor::update() {
    _lastRaw = analogRead(_pin);

    _baseline += BASELINE_ALPHA * (_lastRaw - _baseline);

    float rectified = fabsf((float)_lastRaw - _baseline);
    _envelope += ENVELOPE_ALPHA * (rectified - _envelope);

    if (_mvcCalActive) {
        if (_envelope > _mvcMax) _mvcMax = _envelope;
        if ((int32_t)(millis() - _mvcCalEnd) >= 0) _mvcCalActive = false;
    }
}

float EMGProcessor::getPercentMVC() const {
    if (_mvcMax <= 1.0f) return 0.0f;
    float pct = (_envelope / _mvcMax) * 100.0f;
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    return pct;
}

void EMGProcessor::startMVCCalibration(uint32_t durationMs) {
    _mvcMax = 1.0f;
    _mvcCalActive = true;
    _mvcCalEnd = millis() + durationMs;
}
