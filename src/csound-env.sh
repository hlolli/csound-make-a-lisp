# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Launchers set root before sourcing this file, while still in the caller's
# directory. An explicit CSOUND takes precedence over the local build.
if [ -z "${CSOUND:-}" ]; then
  if [ -e "$root/.csound-build" ] || [ -L "$root/.csound-build" ]; then
    CSOUND=$root/.csound-build/csound
    if [ ! -x "$CSOUND" ]; then
      echo "No Csound executable in $root/.csound-build; update the build link." >&2
      exit 1
    fi
    OPCODE7DIR64=${OPCODE7DIR64:-$root/.csound-build}
    export OPCODE7DIR64
  else
    CSOUND=csound
  fi
fi

case "$CSOUND" in
  /*) ;;
  */*) CSOUND=$PWD/$CSOUND ;;
esac
export CSOUND
