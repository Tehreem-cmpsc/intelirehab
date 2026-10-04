"""Cuts a recording of elbow angle into single reps and turns each into the model's input.

A rep runs from the arm last at rest, up to its peak, and back to rest. That is the same shape the
app's ElbowRepChecker scores: the angle resampled to 100 points, plus the rep's duration.

The thresholds are plain parameters. They only decide where one rep ends and the next begins in a
RECORDING; they do not change how the app counts reps live. Check the result by eye (plot a few reps)
before training on it.
"""
import csv
import glob
import os

import numpy as np

STEPS = 100  # points per rep; must equal the model's `steps`


def effective_rate(t_rx):
    """Samples per second over the whole recording. Notifications arrive in bursts, so the time each one
    was received is jittery; the average rate is not."""
    t_rx = np.asarray(t_rx, dtype=float)
    if len(t_rx) < 2 or t_rx[-1] <= t_rx[0]:
        raise ValueError("need at least two samples spread over some time")
    return (len(t_rx) - 1) / (t_rx[-1] - t_rx[0])


def smooth_time(n, rate):
    """Evenly spaced times for n samples at [rate] Hz."""
    return np.arange(n) / rate


def resample(t, angle, n=STEPS):
    """The angle spread evenly over the rep's time to exactly n points (linear interpolation)."""
    t = np.asarray(t, dtype=float)
    angle = np.asarray(angle, dtype=float)
    return np.interp(np.linspace(t[0], t[-1], n), t, angle)


def find_reps(t, angle, rest_deg=None, rest_band=4.0, start_deg=10.0, min_peak_deg=20.0,
              min_duration=0.4, max_duration=12.0):
    """Returns one dict per rep: start/end index, duration_s, peak_deg, returned.

    rest_deg      the angle the arm rests at; default is the 10th percentile of the recording.
    rest_band     within this many degrees of rest counts as "at rest".
    start_deg     a rep starts when the angle rises this far above rest.
    min_peak_deg  reps whose peak is less than this above rest are ignored as twitches.
    returned      False when the arm did not come back to rest before the next lift began.
    """
    t = np.asarray(t, dtype=float)
    a = np.asarray(angle, dtype=float)
    if rest_deg is None:
        rest_deg = float(np.percentile(a, 10))
    at_rest = rest_deg + rest_band
    reps = []
    i, n = 0, len(a)
    while i < n:
        if a[i] <= rest_deg + start_deg:
            i += 1
            continue
        # The rep began at the last sample still at rest before this rise.
        s = i
        while s > 0 and a[s - 1] > at_rest:
            s -= 1
        s = max(s - 1, 0)
        peak_i = i
        valley_i = None  # lowest point after the peak, while the arm has not reached rest
        end, returned = None, False
        j = i
        while j < n:
            if a[j] > a[peak_i] and valley_i is None:
                peak_i = j
            elif a[j] < a[peak_i] or valley_i is not None:
                if a[j] <= at_rest:
                    end, returned = j, True
                    break
                if valley_i is None or a[j] < a[valley_i]:
                    valley_i = j
                # lifted again before reaching rest: the first rep never came back down
                if a[j] - a[valley_i] >= start_deg:
                    end, returned = valley_i, False
                    break
            j += 1
        if end is None:  # the recording ended mid-rep: drop the unfinished rep
            break
        duration = t[end] - t[s]
        peak_deg = float(a[peak_i])
        if peak_deg - rest_deg >= min_peak_deg and min_duration <= duration <= max_duration:
            reps.append({"start": s, "end": end, "duration_s": float(duration), "peak_deg": peak_deg,
                         "returned": returned})
        i = end + 1 if returned else max(end, peak_i + 1)
    return reps


def read_block(path):
    """Reads one recorded block (see record_reps.py) -> (t, angle)."""
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    return (np.array([float(r["t_s"]) for r in rows]), np.array([float(r["elbow_deg"]) for r in rows]))


def block_info(path):
    """subject and label come from the file name: <subject>__<label>__<timestamp>.csv"""
    parts = os.path.basename(path)[:-4].split("__")
    if len(parts) < 3:
        raise ValueError(f"{path}: expected <subject>__<label>__<time>.csv")
    return parts[0], parts[1]


def build_dataset(raw_dir, out_csv, **find_kwargs):
    """Every rep in every recorded block -> one CSV, one row per rep: subject, label, duration, peak,
    returned, then the 100 resampled angles a000..a099. Returns the number of reps."""
    header = ["subject", "label", "block", "rep", "duration_s", "peak_deg", "returned"] + [
        f"a{k:03d}" for k in range(STEPS)]
    count = 0
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        for path in sorted(glob.glob(os.path.join(raw_dir, "*.csv"))):
            subject, label = block_info(path)
            t, a = read_block(path)
            for k, r in enumerate(find_reps(t, a, **find_kwargs)):
                seg = slice(r["start"], r["end"] + 1)
                curve = resample(t[seg], a[seg])
                w.writerow([subject, label, os.path.basename(path), k, f"{r['duration_s']:.3f}",
                            f"{r['peak_deg']:.1f}", int(r["returned"])] + [f"{v:.2f}" for v in curve])
                count += 1
    return count


if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="Turn recorded blocks into a table of reps.")
    p.add_argument("--raw", default=os.path.join("Data", "raw"))
    p.add_argument("--out", default=os.path.join("Data", "reps.csv"))
    args = p.parse_args()
    print(f"{build_dataset(args.raw, args.out)} reps written to {args.out}")
