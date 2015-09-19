# FPS Conform

:warning: Works for me but not tested much! I've used this only on stereo MKV files so far. And only on Arch Linux.

Bash script to conform between NTSC and PAL.

## What's conforming?

Conforming being defined as either speeding up or slowing down the duration to match the desired output framerate. This is generally how films and TV shows are converted between standards.

The alternative is repeating or dropping frames to change the frame rate, and that's bad.

## Any change in quality?

### Video

No. For the video this is done losslessly without re-encoding. The duration will be longer moving from PAL to NTSC and vice-versa.

### Audio

Yes. For the audio it is changing the tempo. This means the pitch is adjusted accordingly to match the new speed. In other words, there should be little perceptible difference in pitch between the original and the conformed one. This is a lossy process.

The audio is re-encoded with Opus at 48000Hz/128K. This is actually very good quality for an Opus file.

## Requirements

### mkvmerge

Part of the `mkvtoolnix` package usually. Used to change the video framerate.

### ffmpeg and ffprobe

Both usually come with `ffmpeg`. Uses `ffprobe` to get the framerate of the input file and `ffmpeg` to convert the audio while maintaining pitch.
