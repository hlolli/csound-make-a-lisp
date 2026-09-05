#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Check MAL interop results and render the generated instruments to audio."""
import argparse
import array
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csound', default=os.environ.get('CSOUND', 'csound'))
    args = parser.parse_args()
    binary = shutil.which(args.csound)
    if binary is None:
        parser.error(f'Csound executable not found: {args.csound}')
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix='mal-interop-') as temporary:
        output = Path(temporary) / 'interop.wav'
        command = [binary, '-d', '-m128', '-W', '-s', '-o', str(output),
                   '--orc', str(ROOT / 'src/play.orc'), '--',
                   str(ROOT / 'tests/csound-interop.mal')]
        try:
            run = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, timeout=45)
        except subprocess.TimeoutExpired:
            print('FAIL: interop render exceeded 45 seconds', file=sys.stderr)
            return 1
        if (run.returncode != 0 or 'CSOUND-INTEROP-PASS' not in run.stdout.splitlines()
                or any(error in run.stdout for error in
                       ('INIT ERROR', 'PERF ERROR', 'AddressSanitizer', 'Uncaught exception:'))):
            print(run.stdout, file=sys.stderr)
            return 1
        if not output.is_file():
            print('FAIL: Csound produced no audio file', file=sys.stderr)
            return 1
        with wave.open(str(output), 'rb') as audio:
            if audio.getnchannels() != 2 or audio.getsampwidth() != 2:
                raise RuntimeError('expected stereo 16-bit PCM')
            frames = audio.getnframes()
            rate = audio.getframerate()
            samples = array.array('h', audio.readframes(frames))
        if sys.byteorder != 'little':
            samples.byteswap()
        if not 0.15 <= frames / rate <= 0.18:
            raise RuntimeError(f'unexpected render duration: {frames / rate}')
        for start, end in ((0, 0.05), (0.05, 0.10), (0.10, 0.15)):
            for channel in (0, 1):
                section = samples[int(start * rate) * 2 + channel:int(end * rate) * 2:2]
                peak = max(abs(sample) for sample in section)
                if not 100 < peak < 32767:
                    raise RuntimeError(f'bad audio in {start}s section, channel {channel}: {peak}')
        checks = sum(line.startswith('PASS ') for line in run.stdout.splitlines())
        print(f'PASS: {checks} interop checks and three stereo instrument renders')
    return 0


if __name__ == '__main__':
    sys.exit(main())
