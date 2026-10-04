"""Records elbow-angle data from the real armband over Bluetooth, for training the rep checker.

One run = one "block": one person doing one kind of rep for a set time. The label and the person
go in the file name, so a block can never be mixed up later:

    python -m src.record.record_reps --subject S01 --label good --seconds 90 --zero

Writes Data/raw/<subject>__<label>__<time>.csv with columns t_s, elbow_deg, emg_pct, t_rx_s.
  t_s      evenly spaced times at the recording's average rate (use this one)
  t_rx_s   when each notification actually arrived (jittery; kept for checking)

Close the phone app first: the band talks to one phone at a time. Needs `pip install bleak`.
"""
import argparse
import asyncio
import csv
import os
import time

from .protocol import (CMD_RECALIBRATE_GYRO, CMD_SET_ZERO_POSE, CMD_UUID, DATA_UUID, DEVICE_NAME,
                       parse_packet)
from .segment_reps import effective_rate, smooth_time

# The agreed label names (see the README's protocol). Any name without "__" works.
LABELS = ("good", "shallow", "fast", "no_return", "jerky")


async def record(subject, label, seconds, out_dir, address=None, zero=False):
    from bleak import BleakClient, BleakScanner  # imported here so the rest of the package needs no Bluetooth

    print(f"Looking for {address or DEVICE_NAME} ...")
    if address:
        device = await BleakScanner.find_device_by_address(address, timeout=15)
    else:
        device = await BleakScanner.find_device_by_name(DEVICE_NAME, timeout=15)
    if device is None:
        raise SystemExit("Band not found. Is it on, close by, and disconnected from the phone app?")

    samples = []  # (seconds since start, elbow_deg, emg_pct)
    t0 = time.monotonic()

    def on_data(_, data):
        parsed = parse_packet(data)
        if parsed:
            samples.append((time.monotonic() - t0, parsed[0], parsed[1]))

    async with BleakClient(device) as client:
        if zero:
            print("Hold the arm still, hanging relaxed ...")
            await client.write_gatt_char(CMD_UUID, CMD_RECALIBRATE_GYRO, response=True)
            await asyncio.sleep(4)
            await client.write_gatt_char(CMD_UUID, CMD_SET_ZERO_POSE, response=True)
            await asyncio.sleep(1)
        await client.start_notify(DATA_UUID, on_data)
        print(f"Recording {label!r} for {subject} - go! ({seconds} s)")
        t0 = time.monotonic()
        samples.clear()
        end = t0 + seconds
        while time.monotonic() < end:
            await asyncio.sleep(1)
            if samples:
                print(f"  {int(time.monotonic() - t0):3d} s   elbow {samples[-1][1]:6.1f} deg   {len(samples)} samples")
        await client.stop_notify(DATA_UUID)

    if len(samples) < 20:
        raise SystemExit("Almost no data arrived. Check the connection and try again.")
    t_rx = [s[0] for s in samples]
    rate = effective_rate(t_rx)
    t = smooth_time(len(samples), rate)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{subject}__{label}__{time.strftime('%Y%m%d-%H%M%S')}.csv")
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["t_s", "elbow_deg", "emg_pct", "t_rx_s"])
        for ti, (tr, ang, emg) in zip(t, samples):
            w.writerow([f"{ti:.4f}", f"{ang:.2f}", f"{emg:.1f}", f"{tr:.4f}"])
    print(f"Saved {len(samples)} samples ({rate:.1f} Hz) to {path}")
    return path


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--subject", required=True, help="person id, e.g. S01 (no personal names)")
    p.add_argument("--label", required=True, help="kind of rep in this block, e.g. " + ", ".join(LABELS))
    p.add_argument("--seconds", type=int, default=90)
    p.add_argument("--out", default=os.path.join("Data", "raw"))
    p.add_argument("--address", help="the band's Bluetooth address, if finding it by name fails")
    p.add_argument("--zero", action="store_true", help="re-zero the band first (arm hanging still)")
    a = p.parse_args()
    if "__" in a.subject or "__" in a.label:
        raise SystemExit("subject and label must not contain '__'")
    asyncio.run(record(a.subject, a.label, a.seconds, a.out, a.address, a.zero))


if __name__ == "__main__":
    main()
