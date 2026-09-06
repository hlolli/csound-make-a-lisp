# Demos

Use the Csound build described in [INTEROP.md](../INTEROP.md), with `CSOUND`
and `OPCODE7DIR64` set to that build. Run commands from the repository root.

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
with the source CSD's 48 kHz and 128 samples per control period:

```sh
"$CSOUND" -d -m0 -W -f -o /tmp/xanadu.wav \
  --sample-rate=48000 --ksmps=128 \
  --orc src/play.orc -- demo/xanadu.mal
```

MAL submits notes during playback startup, so event times follow Csound's
live-event rounding to control periods. This can shift onsets by a control
period compared with a CSD score loaded before playback.
