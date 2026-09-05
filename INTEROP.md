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

The first command checks graph construction and renders a short WAV in a
temporary directory. The second plays the example through an audio device.
Use `./run script.mal` for scripts that only evaluate MAL or inspect graphs.

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

Opcode names live under `csound/`. The current set is `cpsmidinn`, `poscil`,
`pluck`, `linseg`, `tone`, `pan2`, and `outs`.

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
unsupported rates, missing or extra arguments, and incompatible types before
compiling an instrument. Optional arguments remain absent from the emitted
call so Csound supplies its defaults. `linseg` accepts a start value followed
by one or more duration/value pairs.

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
