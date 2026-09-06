# Demos

Link the Csound build described in [INTEROP.md](../INTEROP.md) as
`.csound-build` once. The launchers then select the executable and its opcode
modules. Run commands from the repository root.

## Xanadu

[xanadu.mal](xanadu.mal) transcribes **Xanadu (short version)** by Joseph T.
Kung, dated 12 December 1988, from Csound's `examples/xanadu.csd`.

```sh
./play demo/xanadu.mal
```

The piece lasts 60 seconds. It keeps all three instruments, the three function
tables, and all 84 notes across seven chord sections. The score keeps the
original octave.pitch-class values, including repeated pitches and wide
octave spacing.

The host uses `0dbfs = 1`, so the gains scale the original amplitudes by
1/32768. The plucked voices have no delay feedback; separate `delay` and
`vdelay` calls reproduce the original fixed and interpolated taps. The FM
voice keeps the original equations and table lookup.

The usual player uses 44.1 kHz and 32 samples per control period. To render
with the source CSD's 48 kHz and 128 samples per control period using that build:

```sh
env OPCODE7DIR64="$PWD/.csound-build" ./.csound-build/csound \
  -d -m0 -W -f -o /tmp/xanadu.wav \
  --sample-rate=48000 --ksmps=128 \
  --orc src/play.orc -- demo/xanadu.mal
```

MAL submits notes during playback startup, so event times follow Csound's
live-event rounding to control periods. This can shift onsets by a control
period compared with a CSD score loaded before playback.

## Trapped in Convert

[trapped.mal](trapped.mal) transcribes Richard Boulanger's
[Trapped in Convert](https://github.com/csound/csound/blob/develop/examples/trapped.csd).
Boulanger wrote the piece in 1979 and revised it for Csound in 1986 and
SHARCsound in 1996.

```sh
./play demo/trapped.mal
```

It keeps the 13 voices, the delay and reverb instruments, all 22 tables, and
198 sound and effect events. The four sections retain their score fields and
pitches. The final section uses the original tempo map: Csound interpolates
seconds per beat between tempo marks. Its 100 beats take 107.1715 seconds,
so the full piece lasts about **4 minutes 50 seconds**. The source's comment
says 283 seconds, which sums the section lengths before the tempo changes.

Named audio channels carry the shared delay and reverb sends. `csound/do`
keeps the output, sends, and channel clearing in order. The original amplitude
scale stays inside the instruments; only the stereo output divides by 32768.
This keeps the noise levels, modulation, and filter balance intact.

For the source's 44.1 kHz and 100 samples per control period:

```sh
env OPCODE7DIR64="$PWD/.csound-build" ./.csound-build/csound \
  -d -m0 -W -f -o /tmp/trapped.wav \
  --sample-rate=44100 --ksmps=100 \
  --orc src/play.orc -- demo/trapped.mal
```

## Stria

[stria.mal](stria.mal) transcribes John Chowning's **Stria**, using
[Kevin Dahan's 2007–2010 Csound reconstruction from CsoundQt](https://github.com/CsoundQt/CsoundQt/blob/master/src/Examples/CsoundQt/Music/Chowning-Stria.csd).

```sh
./play demo/stria.mal
```

The full score lasts **15 minutes 58 seconds**. It keeps all 383 FM notes,
six reverb events, nine tables, and the final filter and amplitude stage.
The four internal channels retain the source's stereo mix: front-right plus
rear-right on the left output, front-left plus rear-left on the right output.
The CsoundQt spectrogram and GUI setup have no role in this player.

The six score sections live in [demo/stria](stria/), starting with
[t0.mal](stria/t0.mal). Each note is a map with named fields, including
`:start`, `:duration`, `:amplitude`, and `:carrier`. `play-note` puts those
fields in Csound's order and fills the unused fields with zero. Reverb events
also use names. All source values retain their original precision.

`stria.mal` loads the sections in order. Smaller files keep the interpreter
from holding the whole score while it evaluates each form. Loading the full
named score can take a couple of minutes in the current MAL interpreter.

The root `cljfmt.edn` teaches [cljfmt](https://github.com/weavejester/cljfmt)
how to indent MAL's special forms. Format or check Stria from the repository
root with:

```sh
cljfmt fix --file-pattern '\.mal$' demo/stria.mal demo/stria
cljfmt check --file-pattern '\.mal$' demo/stria.mal demo/stria
```

For the source's 48 kHz and 16 samples per control period:

```sh
env OPCODE7DIR64="$PWD/.csound-build" ./.csound-build/csound \
  -d -m0 -W -f -o /tmp/stria.wav \
  --sample-rate=48000 --ksmps=16 \
  --orc src/play.orc -- demo/stria.mal
```

These larger scripts take time to load and compile before the sound starts.
The control-period rounding described above applies to all three demos.
With the generated instruments placed in the original CSD scores at the
source sample and control rates, Trapped's float WAV matches sample for sample;
Stria's largest sample difference is below 3 × 10⁻¹⁰. The normal MAL player
schedules the same notes through live events, so its waveform may differ.
