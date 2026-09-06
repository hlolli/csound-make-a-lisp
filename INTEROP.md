# Csound interop

MAL can build typed Csound graphs, compile them into instruments, and schedule
notes. The opcode functions build graphs during MAL evaluation. Csound runs
the resulting instruments during performance.

## Build and run

Install Csound 7.

Select your Csound build and its opcode modules:

```sh
export CSOUND=/path/to/csound/build/csound
export OPCODE7DIR64="${CSOUND%/*}"
just --set csound "$CSOUND" csound-interop
./play examples/row-row-row.mal
```

The test command checks graph construction and renders short WAV files in a
temporary directory. The play command uses an audio device.
Use `./run script.mal` for scripts that only evaluate MAL or inspect graphs.

[subtractive.mal](examples/subtractive.mal) uses a sawtooth oscillator, filter
envelope, and stereo reverb:

```sh
./play examples/subtractive.mal
```

## Instruments

```clojure
(csound/definst Tone [frequency 440 amplitude 0.02 pan 0.5]
  (csound/outs
    (csound/pan2
      (csound/poscil amplitude frequency)
      pan)))

(csound/event "i" Tone 0 0.5 660)
(csound/event "e" 0.6 0)
```

Parameter pairs supply names and numeric defaults. Parameters map to Csound
fields `p4` onward; `p2` and `p3` are available as the note's start and duration.
An event may omit trailing parameters to use their defaults. The instrument
name must be a Csound identifier. Its body must end in an output statement.

Use `csound/source` to inspect orchestra text without defining an instrument:

```clojure
(def! signal (csound/poscil 0.02 440))
(def! graph (csound/outs signal signal))
(println (csound/source 'Preview [] graph))
```

A graph node keeps its identity when reused. The renderer emits each shared
node once per instrument, so both channels above use the same oscillator.
Rendering another instrument starts a new cache.

## Rates and signatures

Opcode names live under `csound/`. The catalog has 30 entries:

| Family | Opcodes | Output selection |
| --- | --- | --- |
| Math and conversion | `abs`, `sqrt`, `sin`, `cos`, `tanh`, `ampdb`, `dbamp`, `cpsmidinn` | Infer from the input; `dbamp` and `cpsmidinn` accept init or control only |
| Oscillators | `poscil`, `oscili`, `phasor`, `vco2`, `pluck` | Default to audio; the first three also offer control outputs |
| Envelopes | `linseg`, `expseg`, `adsr`, `linen` | Default to audio; control outputs available |
| Filters and smoothing | `tone`, `butterlp`, `butterhp`, `reson`, `dcblock2`, `portk` | Audio, except `portk` which returns control |
| Effects and output | `delay`, `vdelay`, `reverbsc`, `pan2`, `outs` | Audio delays, stereo reverb, stereo or array panning, and an output statement |
| Array queries | `sumarray`, `lenarray` | Sum uses the array's numeric rate; length defaults to init with a control option |

`csound/type` reports `:i`, `:k`, `:a`, or `:S` for a scalar, a vector of type
keywords for multiple outputs, and `nil` for a statement with no outputs.
Numbers have init rate; strings have type `:S`.

```clojure
(def! kosc (csound/at-rate :k csound/poscil))
(def! modulation (kosc 1 2))
(csound/type modulation)                    ; :k
(csound/type (+ modulation 440))            ; :k
(csound/type (csound/poscil 0.02 440))       ; :a
```

`csound/at-rate` selects an opcode's output signature. Calls match the input
types and prefer exact matches over init-to-control promotion. They reject
unsupported rates, missing or extra arguments in the declared signature, and
incompatible types before compiling an instrument. Optional arguments remain
absent from the emitted call so Csound supplies its defaults. `linseg` and
`expseg` accept a start value followed by one or more duration/value pairs.

Csound still checks value-dependent rules, such as the extra parameters needed
for some [vco2 modes](https://csound.com/docs/manual/vco2.html). The bridge keeps
Csound's argument units: `delay` uses seconds, while
[vdelay](https://csound.com/docs/manual/vdelay.html) uses milliseconds for both
its current and maximum delay. `oscili` currently accepts a numeric table ID;
omitting it selects Csound's default sine table.

Scalar outputs use typed function calls in the generated source. This supports
math functions such as `sin` and preserves the selected output rate even when
an input can promote from init to control.

## Multiple outputs and arrays

```clojure
(def! stereo (csound/pan2 signal 0.5))
(csound/type stereo)                         ; [:a :a]
(def! channels (csound/outputs stereo))
(csound/type (nth channels 0))               ; :a
(csound/outs stereo)

(def! frequencies (csound/array :i [440 660]))
(csound/type frequencies)                    ; :i-array
(csound/type (csound/aget frequencies 0))     ; :i
(csound/type (csound/sumarray frequencies))  ; :i
(csound/type (csound/lenarray frequencies))  ; :i

(def! pair-array
  ((csound/at-rate :a-array csound/pan2) signal 0.5))
(csound/outs (csound/aget pair-array 0) (csound/aget pair-array 1))
```

Opcode calls expand multiple outputs into separate arguments. An array stays
one argument. `csound/outputs` returns a MAL vector of output projections;
an opcode that returns one array therefore has one output.

`csound/array` accepts `:i`, `:k`, `:a`, or `:S` and a MAL vector. It checks
each element's type. Plain MAL vectors do not become Csound arrays implicitly.
Array signatures match exactly. `csound/aget` currently accepts only an
init-rate index into a one-dimensional array. Literal indices must be whole
and nonnegative, and must fit when the graph supplies a known array length.

## Adding an opcode

The family installers in `src/csound-opcodes.orc` contain the catalog. A fixed
signature lists its outputs, inputs, and required input count, followed by an
empty repeated group and a zero group count. For example, `delay` has one
optional init argument:

```csound
MalCsoundSignature("a", "a,i,i", 2, "", 0)
```

Use concrete types for each overload. The shared matcher handles promotion,
output selection, optional arguments, and repeated groups. The catalog shares
builders for unary functions and table oscillators, and groups other entries
by family. A new opcode should only need a signature definition and tests.

Add type and argument checks to `tests/csound-catalog.mal`, then exercise the
opcode in a rendered instrument. The Python runner checks signal levels,
envelope shape, delay onset, and reverb tails. Run just the catalog fixture with:

```sh
python3 tests/check-csound-interop.py --csound "$CSOUND" --fixture catalog
```

## Scope

This is a curated opcode set with concrete signatures. It does not yet import
the full opcode registry or support arbitrary UDOs, multidimensional arrays,
or control-rate array indices. `outs` currently accepts two audio channels.
The earlier `csound-eval` and `definst` names remain aliases for `csound/eval`
and `csound/definst`.

The implementation separates graph types and signature matching
(`src/csound.orc`), opcode signatures (`src/csound-opcodes.orc`), source
generation (`src/csound-render.orc`), instrument parameters
(`src/csound-instruments.orc`), and event scheduling (`src/csound-events.orc`).
