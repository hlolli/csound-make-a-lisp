# Self-hosting

Run the reference MAL interpreter inside Csound MAL.

## Run

Clone the reference MAL implementation:

```sh
git clone https://github.com/kanaka/mal.git mal
```

Select your Csound 7 build and run the self-hosted interpreter:

```sh
export CSOUND=/path/to/csound/build/csound
export OPCODE7DIR64="${CSOUND%/*}"
./run-selfhost tests/selfhost/boot.mal
```

The script prints `42`, `host=Csound7-mal`, and both completion markers. To check
more features and argument handling:

```sh
./run-selfhost tests/selfhost/stepA.mal first "two words" --gain=0.5 ""
just --set csound "$CSOUND" selfhost
```

The launcher resolves the target path before switching to `mal/impls/mal`.
The reference interpreter needs that working directory for `env.mal` and
`core.mal`. Relative paths inside the target script also use that directory.

The test runner covers reference Steps 1–4, 6–9, and A. The reference checkout
has no separate Step 5 implementation. Each process has a 180-second timeout
and a 1,536 MiB sampled RSS limit. Override these when needed:

```sh
python3 tests/selfhost/check.py --csound "$CSOUND" --steps A --timeout 240 --max-mb 1536
```
