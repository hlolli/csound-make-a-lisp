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

`just bundle-check` builds the versioned include file in a temporary directory
and checks it without the library source tree. It covers nested includes,
embedded strings, repeatable builds, repeated inclusion, Step A, core helpers,
file loading, and the audio interop checks. To choose a Csound build, run
`just --set csound /path/to/csound bundle-check`.

`just release-check` runs the packaging checks without Csound. It checks version
names, the bundle header and filename, release-note links, and the fallback
when Llama is missing, fails, or returns a bad reply. The release workflow runs
these checks before publishing.

`just harness-threading` checks the seven threading macros, argument order,
lexical scope, skipped forms, and the order and number of evaluations.

`just core-helpers` checks collection operations, function composition,
nested updates, conditional bindings, and early return from reductions.

`just csound-interop` also checks collection operators on native arrays.
The arrays fixture renders indexed reads, writes through aliases, control-rate
indices, opcode-produced arrays, and string arrays. Signal levels check that
writes happen in order and reach the same native storage.

`just clojure-forms` checks `def`, `defn`, `defmacro`, `fn`, and `let`,
including global definitions, local scope, closures, macros, and tail calls.
It also checks immutable collection updates, saved atom values, shared atom
references, failed swaps, and compatibility with the original MAL forms.
`just test` and the standalone bundle check both run it.

`just namespaces` checks qualified names, aliases, referred definitions,
closures, macros, shared atoms, separate interpreter sessions, host bindings,
and instruments with the same local name. It also checks real library files,
nested imports, load-once behavior, cycles, failed imports, retry, and caller
namespace restoration. The standalone bundle check runs these tests too.

`just eval-forms` checks multi-form regions, persistent atoms and namespaces,
reader errors, and recovery after an evaluation error. The bundle check also
runs it without the source tree.

To test the Web-IDE example against its browser engine, build `dist/mal.inc`
and pass the installed browser package to the Node check:

```sh
python3 tools/bundle.py --output dist/mal.inc
node tests/check-web-ide.mjs /path/to/web-ide/node_modules/@csound/browser/dist/csound.js
```

This uses the real WebAssembly engine without an audio device. It checks the
`LispEval` hook, persistent state, errors, source strings, and the example
instrument. Test the WebMCP tools in the IDE itself as described in the
[Web-IDE example](../examples/web-ide/README.md).

`just file-loading` checks repeated reads from one call site, empty files,
long lines, filenames with spaces and Unicode, and nested `load-file` calls.
It runs without the reference MAL checkout and forms part of `just test`.

The Csound interop checks cover signature matching, rate selection, multiple
outputs, typed arrays, function tables, and instrument scheduling. They render
fourteen audio regions, check stereo output without clipping, and measure
array gains, envelope shape, delay onset, reverb tails, and numeric precision.
The shared-channel check adds two sends, reads before clearing, and checks
that the channel falls silent when its sender stops:

```sh
just --set csound "$CSOUND" csound-interop
```

`just launchers` checks local build selection, environment overrides, and
argument handling without starting Csound or opening an audio device.

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
