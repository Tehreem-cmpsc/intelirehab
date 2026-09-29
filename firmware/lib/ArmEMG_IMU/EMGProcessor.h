#ifndef EMG_PROCESSOR_H
#define EMG_PROCESSOR_H

#include <Arduino.h>

// Turns one raw analog EMG channel into a smoothed "activation level":
// tracks a slow baseline (rest/DC level), rectifies around it, then
// low-passes the rectified signal into an envelope. Optionally normalises
// the envelope to %MVC (max voluntary contraction) once calibrated.
//
// This assumes your EMG module already does the analog front-end job
// (differential amplification + band-pass filtering) and hands you a
// clean-ish analog voltage per channel. If you're feeding truly raw,
// unfiltered EMG into the ADC, expect to see 50/60 Hz mains hum riding on
// top of this — see the accompanying guide for options if that happens.
class EMGProcessor {
public:
    explicit EMGProcessor(uint8_t adcPin);

    void begin();

    // Call once per loop iteration.
    void update();

    float getEnvelope() const { return _envelope; }  // smoothed activation level, ADC counts
    int   getRaw() const { return _lastRaw; }         // last raw ADC reading (0-4095)
    float getPercentMVC() const;                      // 0-100%, meaningful after calibration completes

    // Starts an MVC calibration window: contract the muscle as hard as
    // possible for `durationMs`; the peak envelope seen becomes the 100% reference.
    void startMVCCalibration(uint32_t durationMs = 5000);
    bool isCalibratingMVC() const { return _mvcCalActive; }

private:
    uint8_t _pin;
    int _lastRaw;
    float _baseline;
    float _envelope;
    float _mvcMax;

    bool _mvcCalActive;
    uint32_t _mvcCalEnd;

    static constexpr float BASELINE_ALPHA = 0.0005f; // slow: tracks DC drift over seconds
    static constexpr float ENVELOPE_ALPHA = 0.05f;   // faster: ~100 ms time constant at 500 Hz update
};

#endif
