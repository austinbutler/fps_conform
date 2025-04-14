# FPS Conform

:warning: Works for me but not tested much! I've used this on Arch Linux with
files that have stereo and 5.1 audio.

Bash script to conform between NTSC and PAL.

## What's conforming?

Conforming is either speeding up or slowing down the duration to match the
desired output frame rate. This is generally how films and TV shows are
converted between standards.

The alternative is repeating or dropping frames to change the frame rate, and
that's bad.

## Any change in quality?

### Video

No. For the video this is done losslessly without re-encoding. The duration
will be longer moving from PAL to NTSC and vice versa.

### Audio

Yes. For the audio it is changing the tempo. This means the pitch is adjusted
accordingly to match the new speed. In other words, there should be little
perceptible difference in pitch between the original and the conformed one.
This is a lossy process.

The audio is re-encoded with [Opus](https://opus-codec.org) at 48000Hz/128K.
This is actually very good quality for an Opus file.

## Running

Provide the folder where your MKV videos to be converted are followed by the
frame rate to conform to. Valid frame rates are `23.976`, `24`, and `25`.

It _should_ not overwrite your originals, however it may be safest to _make a
backup copy_!

The first embedded subtitle will be used, otherwise if there's an SRT subtitle
of the same name next to the video file it will use that.

It will output the finished files in a `converted` folder in the current
working directory.

### Nix

If you have Nix installed with [Flakes enabled](https://wiki.nixos.org/wiki/Flakes)
you can run the script like this:

```shell
nix run github:austinbutler/fps_conform [folder] [frame rate]
```

This is nice because you don't need to worry about installing any requirements.

### Standalone

You can also just clone this repo and run the script directly if you have
all the necessary requirements installed (see below).

```shell
./fps_conform.sh [folder] [frame rate]
```

## Requirements

### Not Included

The following is only relevant if not running with Nix.

#### `mkvmerge`

Part of the [`mkvtoolnix`](https://mkvtoolnix.download/) package usually. Used
to change the video frame rate.

#### `ffmpeg` and `ffprobe`

Both usually come with [`ffmpeg`](https://ffmpeg.org). Uses `ffprobe` to get
the frame rate of the input file and `ffmpeg` to convert the audio while
maintaining pitch.

### Included

#### `srtshift`

Part of [`mplayer-tools`](http://mplayer-tools.sourceforge.net). I couldn't
even find a package for this in Arch! So since it's a simple Perl script it's
just included. Used to convert the frame rate for SRT subtitles.

## Test

There's a rudimentary sanity-check test that can be run.

```shell
just test
```

The test clip is from [Sprite Fright](https://studio.blender.org/projects/sprite-fright).
