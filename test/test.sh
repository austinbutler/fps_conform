#!/usr/bin/env bash

set -eu

TEST_FILE="test/sprite.mkv"
CONFORMED_FILE="conformed/sprite-conformed.mkv"

FPS_IN=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=r_frame_rate "$TEST_FILE")
AUDIO_CHANNELS_IN=$(ffprobe -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0 "$TEST_FILE")

if (("$FPS_IN" != 24)); then
	echo "[ERROR] Expected 24fps input"
	exit 1
fi

if (("$AUDIO_CHANNELS_IN" != 2)); then
	echo "[ERROR] Expected 2 audio channels in input file"
	exit 1
fi

./fps_conform.sh test 25

FPS_OUT=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=r_frame_rate "$CONFORMED_FILE")

if (("$FPS_OUT" != 25)); then
	echo "[ERROR] Expected 25fps output"
	exit 1
fi

SUBTITLE_TYPE=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:0 -show_entries stream=codec_name "$CONFORMED_FILE")

if [[ $SUBTITLE_TYPE != "subrip" ]]; then
	echo "[ERROR] Expected SRT subtitles in converted file"
	exit 1
fi

AUDIO_CHANNELS_OUT=$(ffprobe -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0 "$CONFORMED_FILE")

if (("$AUDIO_CHANNELS_OUT" != 2)); then
	echo "[ERROR] Expected 2 audio channels in converted file"
	exit 1
fi
