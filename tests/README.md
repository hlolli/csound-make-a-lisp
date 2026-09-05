# Tests

The runnable Csound learning harnesses live here. Each file can include the
implementation modules from `src/` and schedule its own `instr TEST`.

Run the current checks with:

```sh
just test
```

Run a single checkpoint with:

```sh
just smoke
just reader
```

The Csound interop checks cover signature matching, rate selection, multiple
outputs, typed arrays, and instrument scheduling. They also render three
instruments and check that each produces stereo audio without clipping:

```sh
just --set csound "$CSOUND" csound-interop
```

`just test` includes this render check and the interactive interop harness.
The render check needs no reference MAL checkout or audio device. See
[INTEROP.md](../INTEROP.md) for the API and required Csound build.

Run the reference MAL interpreters inside Csound MAL with:

```sh
just --set csound "$CSOUND" selfhost
```

These checks cover reference Steps 1–4, 6–9, and A. They check printed results,
closures, collections, atoms, tail calls, script arguments, and quote, macros,
exceptions, and metadata where supported. The runner stops Csound on a timeout
or memory limit. It fails if any required result is missing. See
[SELF_HOSTING.md](../SELF_HOSTING.md)
for setup and commands for a single script.
