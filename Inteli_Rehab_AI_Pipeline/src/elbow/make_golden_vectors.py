"""Writes test vectors computed by the real PyTorch model, for the app's Dart copy.

    python src/elbow/make_golden_vectors.py

Writes Inteli_Rehab_Mobile_App/test/fixtures/elbow_golden.json: a set of reps with the
score and rebuilt curve PyTorch produces. test/elbow_model_test.dart checks that the
Dart network gives the same numbers, so the app cannot silently drift from the model.
The reps are synthetic (no patient data): healthy-looking curves plus deliberately
odd ones, so scores range from well under to far over the threshold.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from elbow_model import N_STEPS, load_checkpoint, score_reps  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PIPELINE = os.path.dirname(os.path.dirname(HERE))
CHECKPOINT = os.path.join(PIPELINE, "models", "elbow_final.pt")
OUT = os.path.join(os.path.dirname(PIPELINE), "Inteli_Rehab_Mobile_App", "test", "fixtures", "elbow_golden.json")


def cases():
    t = np.linspace(0, 1, N_STEPS)
    rng = np.random.default_rng(7)
    bell = lambda peak, p=1.0: peak * np.sin(np.pi * t) ** p
    out = [
        ("healthy-like, 120 deg, 2.0 s", bell(120), 2.0),
        ("healthy-like, 145 deg, 1.6 s", bell(145), 1.6),
        ("healthy-like, 100 deg, 2.6 s", bell(100, 1.2), 2.6),
        ("shallow, 55 deg", bell(55), 2.0),
        ("very shallow, 25 deg", bell(25), 2.0),
        ("flat at rest", np.zeros(N_STEPS), 2.0),
        ("never comes back down", 125 * np.sin(np.pi * np.minimum(t * 0.5, 0.5)), 2.5),
        ("plateau at the top", np.clip(190 * np.sin(np.pi * t), 0, 130), 3.0),
        ("jerky", bell(120) + 14 * np.sin(24 * np.pi * t), 2.2),
        ("noisy healthy-like", bell(125) + rng.normal(0, 3.0, N_STEPS), 1.9),
        ("very slow, 5 s", bell(120), 5.0),
        ("very fast, 0.6 s", bell(120), 0.6),
        ("over-bent, 175 deg", bell(175), 2.0),
        ("two humps", 70 * np.sin(2 * np.pi * t) ** 2 + 20 * np.sin(np.pi * t), 2.8),
    ]
    return out


def main():
    ck = load_checkpoint(CHECKPOINT)
    items = cases()
    angle = np.array([c[1] for c in items], dtype=np.float32)
    duration = np.array([c[2] for c in items], dtype=float)
    score, rebuilt = score_reps(ck, angle, duration)
    doc = {
        "note": "Computed by PyTorch from models/elbow_final.pt - see src/elbow/make_golden_vectors.py",
        "threshold_gentle": float(ck["threshold_gentle"]),
        "cases": [
            {
                "name": items[i][0],
                "angle": [round(float(v), 6) for v in angle[i]],
                "duration_s": float(duration[i]),
                "score": float(score[i]),
                "rebuilt_deg": [round(float(v), 6) for v in rebuilt[i]],
            }
            for i in range(len(items))
        ],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, separators=(",", ":"))
    print(f"wrote {OUT}")
    thr = ck["threshold_gentle"]
    for c in doc["cases"]:
        print(f"  {c['score']:8.4f} {'WARN' if c['score'] > thr else 'ok  '}  {c['name']}")


if __name__ == "__main__":
    main()
