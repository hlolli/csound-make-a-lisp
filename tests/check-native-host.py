#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Check the fixture that intentionally triggers one Csound init error."""

import subprocess
import sys


def main():
    command = sys.argv[1:]
    if not command:
        raise SystemExit("Usage: check-native-host.py csound -n -d -m128 --orc tests/native.orc")

    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=120)
    print(result.stdout, end="")
    if result.returncode != 1 or "PASS: native functions" not in result.stdout:
        raise SystemExit("Expected one Csound init error and a completed native host test")


if __name__ == "__main__":
    main()
