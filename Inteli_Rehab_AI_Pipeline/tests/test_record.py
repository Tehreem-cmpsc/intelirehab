"""Tests for the recording tools. Run from Inteli_Rehab_AI_Pipeline/:  python -m unittest discover -s tests

The curves here are made up on purpose: they check the CODE (where reps are cut, how they are resampled),
not the model. Real recordings are what the model must be trained on.
"""
import csv
import os
import struct
import sys
import tempfile
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.record.protocol import parse_packet  # noqa: E402
from src.record.segment_reps import (STEPS, build_dataset, effective_rate, find_reps, resample,  # noqa: E402
                                     smooth_time)

RATE = 31.25


def lift(peak, up=1.0, down=1.0, hold=0.2, rest=5.0, end=None, start=None):
    """One smooth rep as angles at RATE Hz: `start` (default rest) -> peak -> `end` (default rest)."""
    start = rest if start is None else start
    end = rest if end is None else end
    n_up, n_hold, n_down = int(up * RATE), int(hold * RATE), int(down * RATE)
    rise = start + (peak - start) * (1 - np.cos(np.linspace(0, np.pi, n_up))) / 2
    fall = end + (peak - end) * (1 + np.cos(np.linspace(0, np.pi, n_down))) / 2
    return np.concatenate([rise, np.full(n_hold, peak), fall])


def rest_for(seconds, rest=5.0):
    return np.full(int(seconds * RATE), rest)


def recording(*parts):
    a = np.concatenate(parts)
    return smooth_time(len(a), RATE), a


class PacketTest(unittest.TestCase):
    def test_valid_packet(self):
        self.assertEqual(parse_packet(struct.pack("<ff", 42.5, 17.0)), (42.5, 17.0))

    def test_bad_length_and_nan_are_refused(self):
        self.assertIsNone(parse_packet(b"\x00" * 7))
        self.assertIsNone(parse_packet(struct.pack("<ff", float("nan"), 1.0)))

    def test_sixteen_byte_packet_reads_the_first_eight(self):
        self.assertEqual(parse_packet(struct.pack("<ffff", 10.0, 20.0, 99.0, 99.0)), (10.0, 20.0))


class TimingTest(unittest.TestCase):
    def test_rate_ignores_bursty_arrival_times(self):
        # 200 samples that arrived in bursts of 5 over 6.4 s
        t_rx = np.repeat(np.arange(40) * 0.16, 5)
        self.assertAlmostEqual(effective_rate(t_rx), 199 / (39 * 0.16), places=6)

    def test_needs_time_spread(self):
        with self.assertRaises(ValueError):
            effective_rate([1.0, 1.0])


class SegmentTest(unittest.TestCase):
    def test_finds_each_rep_with_its_duration_and_peak(self):
        t, a = recording(rest_for(1), lift(100), rest_for(1), lift(100, up=1.5, down=1.5), rest_for(1))
        reps = find_reps(t, a)
        self.assertEqual(len(reps), 2)
        self.assertTrue(all(r["returned"] for r in reps))
        self.assertAlmostEqual(reps[0]["peak_deg"], 100, delta=0.5)
        self.assertGreater(reps[1]["duration_s"], reps[0]["duration_s"])
        self.assertAlmostEqual(reps[0]["duration_s"], 2.2, delta=0.4)

    def test_a_twitch_is_not_a_rep(self):
        t, a = recording(rest_for(1), lift(18), rest_for(1))  # only 13 degrees above rest
        self.assertEqual(find_reps(t, a), [])

    def test_a_shallow_rep_is_kept(self):
        t, a = recording(rest_for(1), lift(45), rest_for(1))
        reps = find_reps(t, a)
        self.assertEqual(len(reps), 1)
        self.assertAlmostEqual(reps[0]["peak_deg"], 45, delta=0.5)

    def test_a_rep_that_does_not_come_back_is_flagged(self):
        # up to 100, down only to 60, then up again and all the way down
        t, a = recording(rest_for(1), lift(100, end=60), lift(100, start=60), rest_for(1))
        reps = find_reps(t, a)
        self.assertEqual(len(reps), 2)
        self.assertFalse(reps[0]["returned"])
        self.assertTrue(reps[1]["returned"])

    def test_an_unfinished_rep_at_the_end_is_dropped(self):
        t, a = recording(rest_for(1), lift(100), rest_for(1), lift(100)[:40])
        self.assertEqual(len(find_reps(t, a)), 1)


class ResampleTest(unittest.TestCase):
    def test_always_100_points_with_the_same_ends(self):
        t = np.linspace(0, 2.3, 71)
        a = np.sin(t) * 50
        out = resample(t, a)
        self.assertEqual(len(out), STEPS)
        self.assertAlmostEqual(out[0], a[0])
        self.assertAlmostEqual(out[-1], a[-1])


class DatasetTest(unittest.TestCase):
    def test_blocks_become_one_row_per_rep_with_subject_and_label(self):
        with tempfile.TemporaryDirectory() as raw, tempfile.TemporaryDirectory() as out:
            for name, parts in (
                ("S01__good__20260101-000000.csv", (rest_for(1), lift(100), rest_for(1), lift(100), rest_for(1))),
                ("S02__shallow__20260101-000001.csv", (rest_for(1), lift(45), rest_for(1))),
            ):
                t, a = recording(*parts)
                with open(os.path.join(raw, name), "w", newline="") as f:
                    w = csv.writer(f)
                    w.writerow(["t_s", "elbow_deg", "emg_pct", "t_rx_s"])
                    for ti, ai in zip(t, a):
                        w.writerow([f"{ti:.4f}", f"{ai:.2f}", "0", f"{ti:.4f}"])
            dest = os.path.join(out, "reps.csv")
            self.assertEqual(build_dataset(raw, dest), 3)
            with open(dest, newline="") as f:
                rows = list(csv.DictReader(f))
            self.assertEqual([(r["subject"], r["label"]) for r in rows],
                             [("S01", "good"), ("S01", "good"), ("S02", "shallow")])
            self.assertIn("a000", rows[0])
            self.assertIn("a099", rows[0])
            self.assertEqual(rows[0]["returned"], "1")


if __name__ == "__main__":
    unittest.main()
