#!/bin/bash

#Current directory script is being executed from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#FPS parameter
FPS="$1"

#Setting FPS for mkvmerge
if [[ "$FPS" != "23.976" && "$FPS" != "24" && "$FPS" != "25" ]]; then
  echo "[ERROR] Please provide the framerate to convert to! Valid options: 23.976, 24, 25"
  exit 1
fi

#Setting output directory based on FPS
OUTPUT_VID="$DIR/temp/video_$FPS"
OUTPUT_AUD="$DIR/temp/audio_$FPS"

#Making output directories
mkdir -p "$OUTPUT_VID"
mkdir -p "$OUTPUT_AUD"

#Converting video to desired FPS using mkvmerge
function CONVERT_VID () {
  mkvmerge -o "$OUTPUT_VID/$1" --default-duration "0:$2" -d "0" -A -S -T "$1" --track-order "0:0"
}

function CONVERT_AUD () {
  ffmpeg -i "$1" -c:a libopus -b:a 128k -filter:a "atempo=$2" -vn "$OUTPUT_AUD/$1"
}

function MUX () {
  ffmpeg -i "$OUTPUT_VID/$1" -i "$OUTPUT_AUD/$1" -c copy -map 0:v:0 -map 1:a:0 "$DIR/converted_$1"
}

#Loop to convert all files with mkv extension in current directory
for INPUT_FILE in *.mkv; do
  #Get framerate of input file to make calculate conversion
  FPS_IN=$(ffprobe "$INPUT_FILE" -v 0 -select_streams v -print_format flat -show_entries stream=r_frame_rate | cut -d"=" -f2 | tr -d '"')

  #Error for same input and output FPS
  ERR_NO_ACTION="[NOTICE] Taking no action on $INPUT_FILE, FPS would be unchanged or is unsupported"

  #Error for unsupported framerate
  ERR_UNSUPPORTED="[ERROR] Framerate not supported: $FPS_IN\nFile: $INPUT_FILE"

  #By default take action
  PASS="false"

  #Determine action, tempo
  if [[ "$FPS_IN" == "24000/1001" ]]; then
    FPS_IN="23.976"
    if [[ "$FPS" == "25" ]]; then
      FPS_OUT="25p"
      TEMPO="1.042709376"
    else
      echo "$ERR_NO_ACTION"
      PASS="true"
    fi
  elif [[ "$FPS_IN" == "24/1" ]]; then
    FPS_IN="24"
    if [[ "$FPS" == "25" ]]; then
      FPS_OUT="25p"
      TEMPO="1.041666667"
    else
      echo "$ERR_NO_ACTION"
      PASS="true"
    fi
  elif [[ "$FPS_IN" == "25/1" ]]; then
    FPS_IN="25"
    if [[ "$FPS" == "24" ]]; then
      FPS_OUT="24p"
      TEMPO="0.96"
    elif [[ "$FPS" == "23.976" ]]; then
      FPS_OUT="24000/1001p"
      TEMPO="0.95904"
    else
      echo "$ERR_NO_ACTION"
      PASS="true"
    fi
  else
    echo -e "$ERR_UNSUPPORTED"
    PASS="true"
  fi

  #Do conversion for files not set to pass
  if [[ "$PASS" != "true" ]]; then
    CONVERT_VID "$INPUT_FILE" "$FPS_OUT"
    CONVERT_AUD "$INPUT_FILE" "$TEMPO"
    MUX "$INPUT_FILE"
    rm -f "$OUTPUT_VID/$INPUT_FILE"
    rm -f "$OUTPUT_AUD/$INPUT_FILE"
  fi
done

rm -rf "$OUTPUT_VID"
rm -rf "$OUTPUT_AUD"
