"""Exports models/elbow_final.pt to the mobile app as one small JSON asset.

    python src/elbow/export_to_app.py [path/to/checkpoint.pt]

Writes Inteli_Rehab_Mobile_App/assets/ai/elbow_autoencoder.json. The app runs the
network itself in plain Dart (no ML runtime), reading the weights from this file.
Re-run it after retraining or after recalibrating the thresholds for the armband
(see "Recalibrate for the armband" in the notebook), then run
src/elbow/make_golden_vectors.py to refresh the test that proves the app and
PyTorch agree.
"""
import base64
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from elbow_model import N_STEPS, load_checkpoint  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PIPELINE = os.path.dirname(os.path.dirname(HERE))
DEFAULT_CHECKPOINT = os.path.join(PIPELINE, "models", "elbow_final.pt")
OUT = os.path.join(os.path.dirname(PIPELINE), "Inteli_Rehab_Mobile_App", "assets", "ai", "elbow_autoencoder.json")


def tensor(t):
    a = t.detach().cpu().numpy().astype("<f4")
    return {"shape": list(a.shape), "data": base64.b64encode(a.tobytes()).decode("ascii")}


def main(path):
    ck = load_checkpoint(path)
    state = ck["model"].state_dict()
    doc = {
        "format": 1,
        "source": os.path.basename(path),
        "steps": N_STEPS,
        "with_duration": bool(ck["with_duration"]),
        "latent": int(ck["latent"]),
        # per-channel normalisation: channel 0 = elbow angle (deg), channel 1 = log(duration in s)
        "mean": [float(v) for v in np.asarray(ck["mean"]).reshape(-1)],
        "std": [float(v) for v in np.asarray(ck["std"]).reshape(-1)],
        # reconstruction-error thresholds (normalised units); gentle is the default
        "threshold_gentle": float(ck["threshold_gentle"]),
        "threshold_balanced": float(ck["threshold_balanced"]),
        # per-step allowed deviation from the rebuilt curve, degrees
        "tolerance": [float(v) for v in np.asarray(ck["tolerance"]).reshape(-1)],
        "healthy_duration_range": [float(v) for v in ck["healthy_duration_range"]],
        "tensors": {name: tensor(t) for name, t in state.items()},
    }
    assert len(doc["tolerance"]) == N_STEPS
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, separators=(",", ":"))
    print(f"wrote {OUT}  ({os.path.getsize(OUT) // 1024} KB, {sum(int(np.prod(t.shape)) for t in state.values())} weights)")
    print(f"gentle {doc['threshold_gentle']:.4f}  balanced {doc['threshold_balanced']:.4f}  "
          f"healthy rep length {doc['healthy_duration_range'][0]:.2f}-{doc['healthy_duration_range'][1]:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CHECKPOINT)
