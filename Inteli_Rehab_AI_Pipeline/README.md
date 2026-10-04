# AI pipeline: elbow rep checker

A small autoencoder that tells whether one elbow-flexion rep looks like a healthy rep. It is trained only on
correct reps; a rep that is too shallow, does not come back down, and so on rebuilds badly, and the rebuild error
is the score. Training is in `notebooks/train_elbow_model.ipynb`, which saves `models/elbow_final.pt`.

## How it reaches the app

The app runs the network itself in plain Dart (`lib/features/exercises/processing/elbow_autoencoder.dart`), so it
needs no ML library and works offline.

| Step | File |
|---|---|
| Train, save the checkpoint | `notebooks/train_elbow_model.ipynb` -> `models/elbow_final.pt` |
| The model as PyTorch code (for checking) | `src/elbow/elbow_model.py` |
| Export weights, thresholds and tolerance to the app | `src/elbow/export_to_app.py` -> `Inteli_Rehab_Mobile_App/assets/ai/elbow_autoencoder.json` |
| Test vectors from the real model | `src/elbow/make_golden_vectors.py` -> `Inteli_Rehab_Mobile_App/test/fixtures/elbow_golden.json` |
| Proof the Dart copy matches PyTorch | `Inteli_Rehab_Mobile_App/test/elbow_model_test.dart` |

After retraining or recalibrating, run both scripts, then `flutter test`:

    pip install -r requirements.txt
    python src/elbow/export_to_app.py
    python src/elbow/make_golden_vectors.py

## What a rep is

The elbow angle in degrees for one rep (from the arm last at rest to at rest again), resampled to 100 steps, plus
log(duration in seconds) repeated on every step. Both are normalised with the `mean` and `std` in the checkpoint.
The score is the mean squared rebuild error over both channels.

## Three states in a live session

| State | What decides it | When |
|---|---|---|
| Green | the rep is fine | |
| Amber, "needs correction" | this model: score above the threshold | about half a second after the arm comes back down |
| Red, "stop" | `SafetyMonitor`: angle or speed above a limit, held for a short window | live, on every sample |

The model only says a rep looked unusual; it cannot stop a movement in progress. Over-bending and jerky reps
can still score as healthy (try them in `make_golden_vectors.py`), which is why red is a separate rule check.

- **Default threshold: gentle** (0.0575). On the 7 test patients it warned on 40 of 110 reps (60% right) with 6 of 35
  correct wheelchair reps flagged; `balanced` (0.0383) warned on 59 (47% right) and flagged 18 of 35. `balanced` is
  kept as a clinician-only setting (`RepCheckMode.balanced`), not offered to patients.
- **Slow reps** (over the healthy 0.76 to 4.19 s range's upper end) get a hint, not a failure. Patients' correct reps
  are slower than healthy ones, and slowness can mean weakness, not bad form.
- **Fast reps** do not separate correct from incorrect; they belong to the red speed rule.

## Recording armband data (to recalibrate or retrain)

The model was trained on Kinect reps, so it has not seen the armband's signal. These tools record elbow-angle data
from the real band, cut it into reps and write a table in the model's own input shape. They need no firmware change:
the band already sends the elbow angle about 31 times a second, and that angle is all this model reads.

    pip install bleak
    python -m src.record.record_reps --subject S01 --label good --seconds 90 --zero
    python -m src.record.segment_reps            # Data/raw/*.csv  ->  Data/reps.csv
    python -m unittest discover -s tests         # the tools' own tests

Close the phone app first (the band talks to one phone at a time). `--zero` re-zeroes the band: hold the arm still,
hanging relaxed.

**A block** is one person doing one kind of rep for 60 to 90 seconds, with a rest between reps. The person and the
label go in the file name (`S01__good__<time>.csv`), so a block cannot be mixed up later.

| Label | What to do | Used for |
|---|---|---|
| `good` | Slow, full, controlled bends, back to rest each time | The healthy reference; the threshold and tolerance band |
| `shallow` | Stop well short of the full bend | Checking the model flags it |
| `no_return` | Bend, come only part way down, bend again | Checking the model flags it |
| `fast` | Quick reps | Looking at speed (the red rule, not this model) |
| `jerky` | Uneven, stop-start reps | Checking the model flags it |

Suggested minimum: 10 or more people, 2 blocks of `good` and 1 of each other label each. Keep whole people out of the
training set and test on them (as the notebook's unseen-subject test does). Use anonymous ids like `S01`; get consent;
the recordings are personal data, so `Data/raw/` and `Data/reps.csv` are git-ignored.

`reps.csv` has one row per rep: `subject, label, block, rep, duration_s, peak_deg, returned`, then `a000` to `a099`,
the angle resampled to 100 points (the model adds log(duration) itself). Where a rep starts and ends is set by the
parameters of `find_reps` in `src/record/segment_reps.py`; plot a few reps by eye before training on them.

Next, with real recordings: run the notebook's section 8 (`recalibrate`) on 15 to 20 `good` reps, or retrain on them,
then `export_to_app.py`, `make_golden_vectors.py` and `flutter test`.

## Open items

- **Red limits are placeholders** (`SafetyLimits` in `safety_monitor.dart`: angle = full range + 10 degrees, speed
  300 deg/s, held 100 ms). They are not from this data (healthy peaks about 150 degrees and about 750 deg/s; Kinect
  noise spikes reach 175 degrees and 2,379 deg/s). A physiotherapist should set them, probably per patient.
- **The thresholds and the tolerance band come from Kinect reps.** Not yet tested on armband recordings. The notebook's
  section 8 (`recalibrate`) resets the gentle threshold and the band from 15 to 20 reps known to be correct, recorded
  with the band. Do that before relying on it, then re-export.
- **EMG is not used** by this model (the training data has none).
- Warning messages are rules on top of the rebuilt curve, not clinical advice.
