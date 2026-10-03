# Csound interop

MAL can build typed Csound graphs, compile them into instruments, and schedule
notes. The opcode functions build graphs during MAL evaluation. Csound runs
the resulting instruments during performance.

## Build and run

Install Csound 7.

For `./play`, `./run`, and `./run-selfhost`, link the build directory once from
the repository root:

```sh
ln -s /path/to/csound/build .csound-build
./play demo/xanadu.mal
```

The launchers use that directory's `csound` executable and opcode modules.
Git ignores the link, so each checkout can select its own build. An explicit
`CSOUND` environment variable takes precedence; `OPCODE7DIR64` can override
the module directory. Without `CSOUND` or the link, the launchers use `csound`
from `PATH`.

To select a build for direct Csound commands and the test suite:

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

The [demos](demo/README.md) transcribe Xanadu, Trapped in Convert, and the
CsoundQt reconstruction of Stria. Each keeps the source instruments and score.

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
name must be a Csound identifier. Its body must be a Csound statement with no
outputs, such as `outs`, `chnmix`, or a `csound/do` sequence.

`csound` is a namespace. You can alias it with
`(ns music.voice (:require [csound :as c]))` and call `c/definst` or `c/oscili`.
Instruments defined outside `user` receive a host name that includes a
namespace identifier, so `music.voice/Tone` and `music.bass/Tone` can coexist.
Pass the instrument value to `csound/event`; its host name is an internal
detail. Instruments in `user` keep their original Csound names.

Use `csound/source` to inspect orchestra text without defining an instrument:

```clojure
(def signal (csound/poscil 0.02 440))
(def graph (csound/outs signal signal))
(println (csound/source 'Preview [] graph))
```

A graph node keeps its identity when reused. The renderer emits each shared
node once per instrument, so both channels above use the same oscillator.
Rendering another instrument starts a new cache.

Use `csound/do` to keep several statements in the graph. Plain MAL `do`
evaluates its forms and returns only the last graph node. For example, a
reverb instrument can read a shared audio channel, output the wet signal,
then clear the channel for the next control period:

```clojure
(def audio-bus (csound/at-rate :a csound/chnget))
(csound/definst Send [frequency 440]
  (csound/chnmix (csound/oscil 0.02 frequency) "reverb-send"))
(csound/definst Return []
  (let* [wet (csound/reverb (audio-bus "reverb-send") 2)]
    (csound/do
      (csound/outs wet wet)
      (csound/chnclear "reverb-send"))))
```

Define senders before receivers so Csound runs them in that order each block.
`chnmix` adds audio to a named channel; `chnclear` accepts one or more channel
names. `csound/do` accepts only statements with no outputs, may nest, and
preserves their order. An empty `csound/do` defines a silent body. Shared nodes,
including statements, still render once; use separate mix calls for two sends.

## Threading macros

Use the [core helpers](CORE.md) to compose functions, process collections,
and update nested score data.

MAL includes Clojure's seven [threading macros](https://clojure.org/guides/threading_macros):

| Macro | Behavior |
| --- | --- |
| `->` | Pass each result as the first argument of the next form. |
| `->>` | Pass each result as the last argument. |
| `as->` | Bind each result to a name used in the next form. |
| `some->` | Thread first; stop when a result is `nil`. |
| `some->>` | Thread last; stop when a result is `nil`. |
| `cond->` | Thread first through forms whose paired tests are true. |
| `cond->>` | Thread last through forms whose paired tests are true. |

Use them with ordinary MAL values or Csound graphs:

```clojure
(-> (csound/poscil 0.02 440)
    (csound/butterlp 4000)
    (csound/butterlp 4000))

(->> [1 2 3]
     (map (fn* (x) (* x 2)))
     first)

(as-> 5 x
  (- 20 x)
  (* x 2))
```

`some->` and `some->>` continue through `false`. `cond->` and `cond->>`
evaluate every test in order, skipping forms whose tests are false or `nil`.
A chain with no forms returns its initial value.

`gensym` creates fresh symbols for macro bindings. It accepts an optional
string prefix: `(gensym "value-")`.

## Rates and signatures

Opcode names live under `csound/`. The catalog has 54 entries:

| Family | Opcodes | Output selection |
| --- | --- | --- |
| Math and conversion | `abs`, `sqrt`, `sin`, `cos`, `tanh`, `exp`, `ampdb`, `cpsoct`, `int`, `frac`, `dbamp`, `cpsmidinn`, `cpspch`, `octpch` | Infer from the input; the last four accept init or control only |
| Oscillators | `poscil`, `oscil`, `oscili`, `phasor`, `vco2`, `pluck`, `buzz`, `gbuzz`, `foscil` | Default to audio; the first four also offer control outputs |
| Noise | `rand`, `randh`, `randi` | Default to audio; control outputs available |
| Envelopes | `line`, `linseg`, `expseg`, `expon`, `adsr`, `linen` | Default to audio; control outputs available |
| Filters and smoothing | `tone`, `butterlp`, `butterhp`, `reson`, `dcblock2`, `portk` | Audio, except `portk` which returns control |
| Effects and output | `delay`, `vdelay`, `reverb`, `reverbsc`, `comb`, `alpass`, `balance`, `pan2`, `outs` | Audio effects, stereo reverb, stereo or array panning, and an output statement |
| Channels | `chnget`, `chnmix`, `chnclear` | Reads default to control; init, audio, and string reads available; mix and clear return statements |
| Function-table lookup | `table`, `tablei` | Infer init, control, or audio from the index |
| Array queries | `sumarray`, `lenarray` | Sum uses the array's numeric rate; length defaults to init with a control option |

`csound/type` reports `:i`, `:k`, `:a`, or `:S` for a scalar, a vector of type
keywords for multiple outputs, and `nil` for a statement with no outputs.
Numbers have init rate; strings have type `:S`.

```clojure
(def kosc (csound/at-rate :k csound/poscil))
(def modulation (kosc 1 2))
(csound/type modulation)                    ; :k
(csound/type (+ modulation 440))            ; :k
(csound/type (csound/poscil 0.02 440))       ; :a
```

Arithmetic with a graph operand runs in Csound. Plain MAL division truncates,
so use decimal constants for fractions outside a graph. Generated Csound
source and event fields retain full double precision.

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

The classic `buzz`, `gbuzz`, and `foscil` entries accept control inputs for
amplitude and modulation, with init table and phase options. Noise entries
also accept audio amplitude, but their frequency inputs remain control rate.
`comb` and `alpass` take a control decay time and an init loop time in seconds.
The catalog exposes these signatures; it does not yet cover every Csound
overload of these opcodes.

Scalar outputs use typed function calls in the generated source. This supports
math functions such as `sin` and preserves the selected output rate even when
an input can promote from init to control.

## Function tables

Numeric `f` events create tables with Csound's GEN routines. Schedule them
before notes that read the tables:

```clojure
(csound/event "f" 1 0 65536 10 1)     ; sine
(csound/event "f" 2 0 65536 11 1)     ; cosine
(csound/event "f" 3 0 65536 -12 20)   ; unscaled log of I0(x)
(csound/oscili 0.02 440 1)
(csound/tablei (csound/phasor 440) 2 1)
```

The fields are table number, time, size, GEN number, then GEN arguments.
A negative GEN number skips normalization. The bridge checks numeric field
types; Csound checks each GEN routine's arguments. String arguments and
abbreviated `f0` events are not supported yet. `tablei` accepts optional index
mode, offset, and wrap arguments after the index and table number.

## Multiple outputs and arrays

```clojure
(def stereo (csound/pan2 signal 0.5))
(csound/type stereo)                         ; [:a :a]
(def channels (csound/outputs stereo))
(csound/type (nth channels 0))               ; :a
(csound/outs stereo)

(def frequencies (csound/array :i [440 660]))
(csound/type frequencies)                    ; :i-array
(csound/type (csound/aget frequencies 0))     ; :i
(csound/type (csound/sumarray frequencies))  ; :i
(csound/type (csound/lenarray frequencies))  ; :i

(def pair-array
  ((csound/at-rate :a-array csound/pan2) signal 0.5))
(csound/outs (csound/aget pair-array 0) (csound/aget pair-array 1))
```

Opcode calls expand multiple outputs into separate arguments. An array stays
one argument. `csound/outputs` returns a MAL vector of output projections;
an opcode that returns one array therefore has one output.

`csound/array` accepts `:i`, `:k`, `:a`, or `:S` and a MAL vector. It checks
each element's type. Plain MAL vectors do not become Csound arrays implicitly.
Array signatures match exactly. `csound/aget`, `nth`, and `get` accept init-
or control-rate indices into a one-dimensional array. A control-rate index
into an init-rate array produces a control-rate value. Literal indices must
be whole and nonnegative, and must fit when the graph supplies a known length.

### Collection operators on Csound arrays

Use the usual collection functions on a Csound array:

```clojure
(def frequencies (csound/array :i [440 660]))
(nth frequencies 0)              ; init-rate Csound value
(get frequencies 1)              ; init-rate Csound value
(count frequencies)              ; init-rate lenarray call

(csound/definst ArrayTone []
  (let [changed (update frequencies 0 + 220)
        signal (csound/oscili 0.02 (first changed))]
    (csound/outs signal signal)))
```

| Operators | Csound array behavior |
| --- | --- |
| `nth`, `get`, `first`, `second`, `last` | Read an element at the array/index rate. |
| `count` | Produce an init-rate `lenarray` call, including for opcode outputs. |
| `assoc`, `update` | Write into the native array and return a graph for that same array. |
| `get-in`, `assoc-in`, `update-in` | Follow paths through MAL maps/vectors and Csound arrays. |
| `seq`, `vec`, `map`, `mapv`, `reduce`, and sequence helpers | Work on element graphs when the array length is known while building the instrument. |
| `empty?`, `contains?` | Return MAL booleans when the length and index are known while building the instrument. |

These calls build Csound code. Reads return graph values. Updates run when
their result is used in the instrument, or when they appear in `csound/do`:

```clojure
(csound/definst ArrayWrite []
  (let [values (csound/array :k [440 660])
        alias values]
    (csound/do
      (assoc values 0 220)
      (csound/outs (csound/oscili 0.02 (nth alias 0))
                   (csound/oscili 0.02 (nth alias 1))))))
```

The write reaches aliases of the same native array within that instrument.
Each instrument instance owns its array. Reusing an update graph emits its
write once; calling `assoc` again creates another write. MAL `do` alone does
not sequence graph operations.

Array updates keep the element type and length. `assoc` replaces existing
slots; `conj` does not grow native arrays. Init-rate arrays require init-rate
indices and values for writes. Control and audio arrays run their writes
during performance. `get` uses the same checked access as `nth`, including
an error for a missing element. Csound checks indices computed at runtime.

Sequence helpers build a MAL sequence of element graphs, so they need a
known length. They do not copy running audio into MAL. Arrays returned by
opcodes can still use indexed reads, writes, and `count`; sequence helpers
and MAL boolean queries report an error when they would need runtime data.

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
the full opcode registry or support arbitrary UDOs or multidimensional arrays.
`outs` currently accepts two audio channels.
The earlier `csound-eval` and `definst` names remain aliases for `csound/eval`
and `csound/definst`.

The implementation separates graph types and signature matching
(`src/csound.orc`), opcode signatures (`src/csound-opcodes.orc`), source
generation (`src/csound-render.orc`), instrument parameters
(`src/csound-instruments.orc`), and event scheduling (`src/csound-events.orc`).
