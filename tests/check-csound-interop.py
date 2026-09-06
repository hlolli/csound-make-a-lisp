#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Check MAL interop results and render the generated instruments to audio."""
import argparse
import array
from dataclasses import dataclass
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class RenderFixture:
    name: str
    duration: float
    regions: tuple

    @property
    def script(self):
        return ROOT / "tests" / f"csound-{self.name}.mal"

    @property
    def marker(self):
        return f"CSOUND-{self.name.upper()}-PASS"


FIXTURES = (
    RenderFixture("interop", 0.16, (
        ("array outputs", 0, 0.05),
        ("tuple outputs", 0.05, 0.10),
        ("typed arrays", 0.10, 0.15),
    )),
    RenderFixture("catalog", 1.11, (
        ("oscillators", 0.01, 0.09),
        ("array reductions", 0.11, 0.19),
        ("envelopes", 0.22, 0.28),
        ("filters", 0.31, 0.39),
        ("math", 0.41, 0.49),
        ("delay", 0.525, 0.595),
        ("reverb", 0.70, 0.99),
        ("tables and precision", 1.01, 1.09),
    )),
    RenderFixture("classic", 1.01, (
        ("ordered bus sends", 0.01, 0.09),
        ("classic synthesis", 0.21, 0.39),
        ("classic reverb tail", 0.44, 0.50),
    )),
)


def render(binary, fixture, output):
    command = [binary, "-d", "-m128", "-W", "-s", "-o", str(output),
               "--orc", str(ROOT / "src/play.orc"), "--", str(fixture.script)]
    try:
        run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, timeout=45)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"{fixture.name}: render exceeded 45 seconds") from None
    errors = ("INIT ERROR", "PERF ERROR", "AddressSanitizer", "Uncaught exception:")
    if (run.returncode != 0 or fixture.marker not in run.stdout.splitlines()
            or any(error in run.stdout for error in errors)):
        raise RuntimeError(f"{fixture.name}: Csound render failed\n{run.stdout}")
    return sum(line.startswith("PASS ") for line in run.stdout.splitlines())


def read_audio(output, fixture):
    with wave.open(str(output), "rb") as audio:
        if audio.getnchannels() != 2 or audio.getsampwidth() != 2:
            raise RuntimeError(f"{fixture.name}: expected stereo 16-bit PCM")
        frames = audio.getnframes()
        rate = audio.getframerate()
        samples = array.array("h", audio.readframes(frames))
    if sys.byteorder != "little":
        samples.byteswap()
    if abs(frames / rate - fixture.duration) > 0.02:
        raise RuntimeError(f"{fixture.name}: unexpected duration {frames / rate:.4f}s")
    channels = (samples[0::2], samples[1::2])
    for channel in channels:
        if max(abs(sample) for sample in channel) >= 32767:
            raise RuntimeError(f"{fixture.name}: audio clipped")
    return rate, channels


def section(channel, rate, start, end):
    return channel[round(start * rate):round(end * rate)]


def rms(samples):
    return math.sqrt(sum(sample * sample for sample in samples) / len(samples))


def check_regions(fixture, rate, channels):
    for label, start, end in fixture.regions:
        for index, channel in enumerate(channels):
            samples = section(channel, rate, start, end)
            if max(abs(sample) for sample in samples) <= 100:
                raise RuntimeError(f"{fixture.name}: {label}, channel {index} is silent")


def check_catalog_audio(rate, channels):
    left, right = channels

    # sumarray doubles the left signal; lenarray sets the gain on both sides.
    array_left = rms(section(left, rate, 0.11, 0.19))
    array_right = rms(section(right, rate, 0.11, 0.19))
    if not 1.8 < array_left / array_right < 2.2:
        raise RuntimeError("catalog: array reduction produced the wrong channel gain")

    # The linen attack and release must reach the running audio signal.
    middle = rms(section(left, rate, 0.225, 0.275))
    for start, end in ((0.2, 0.204), (0.297, 0.3)):
        if rms(section(left, rate, start, end)) >= middle * 0.3:
            raise RuntimeError("catalog: envelope attack or release is missing")

    # sqrt(abs(-1)) and ampdb(dbamp(0.02)) set a cosine's amplitude to 0.02.
    math_level = rms(section(right, rate, 0.405, 0.495)) / 32768
    if not 0.013 < math_level < 0.015:
        raise RuntimeError(f"catalog: math produced the wrong audio level {math_level}")

    # delay uses seconds; vdelay uses milliseconds. Both delay by 20 ms.
    for channel in channels:
        if max(abs(sample) for sample in section(channel, rate, 0.501, 0.518)) > 2:
            raise RuntimeError("catalog: delayed signal started before 20 ms")

    # Only the wet signal reaches the output. The input ends at 0.64 seconds.
    for channel in channels:
        if max(abs(sample) for sample in section(channel, rate, 0.85, 0.98)) <= 20:
            raise RuntimeError("catalog: reverb tail is missing")
    wet_left = section(left, rate, 0.70, 0.99)
    wet_right = section(right, rate, 0.70, 0.99)
    if max(abs(a - b) for a, b in zip(wet_left, wet_right)) <= 10:
        raise RuntimeError("catalog: reverb outputs lost their stereo separation")

    for channel in channels:
        table_level = rms(section(channel, rate, 1.01, 1.09)) / 32768
        if not 0.013 < table_level < 0.015:
            raise RuntimeError("catalog: table lookup or numeric precision changed the gain")


def check_classic_audio(rate, channels):
    for channel in channels:
        # Direct output is 0.02; two bus sends add 0.04. Missing statements,
        # duplicate oscillators, or clearing before the read changes this sum.
        level = rms(section(channel, rate, 0.01, 0.09)) / 32768
        if not 0.041 < level < 0.044:
            raise RuntimeError(f"classic: bus sum has the wrong level {level}")
        # A missing per-block clear accumulates old samples or leaves a tail.
        if max(abs(sample) for sample in section(channel, rate, 0.11, 0.19)) > 1:
            raise RuntimeError("classic: bus did not clear after the sender ended")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csound", default=os.environ.get("CSOUND", "csound"))
    parser.add_argument("--fixture", choices=[fixture.name for fixture in FIXTURES])
    args = parser.parse_args()
    binary = shutil.which(args.csound)
    if binary is None:
        parser.error(f"Csound executable not found: {args.csound}")
    binary = str(Path(binary).resolve())
    checks = 0
    instruments = 0
    try:
        with tempfile.TemporaryDirectory(prefix="mal-interop-") as temporary:
            for fixture in FIXTURES:
                if args.fixture is not None and args.fixture != fixture.name:
                    continue
                output = Path(temporary) / f"{fixture.name}.wav"
                checks += render(binary, fixture, output)
                rate, channels = read_audio(output, fixture)
                check_regions(fixture, rate, channels)
                if fixture.name == "catalog":
                    check_catalog_audio(rate, channels)
                elif fixture.name == "classic":
                    check_classic_audio(rate, channels)
                instruments += len(fixture.regions)
    except (RuntimeError, OSError, wave.Error) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: {checks} interop checks and {instruments} stereo instrument renders")
    return 0


if __name__ == "__main__":
    sys.exit(main())
