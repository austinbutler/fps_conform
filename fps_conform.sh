#!/bin/bash

#Current directory script is being executed from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Folder parameter
FOLDER="$1"

#FPS parameter
FPS="$2"

USAGE="USAGE: bash fps_conform.sh [folder] [framerate]\n  [folder] = location of video files to be converted\n  [framerate] = framerate to conform to (23.976, 24, 25)"

if [[ $# == 0 ]]; then
  echo -e "$USAGE"
  exit 1
fi

#Checking for valid first parameter
if [[ ! -d "$FOLDER" ]]; then
  echo "[ERROR] Please provide a valid folder!"
  echo -e "$USAGE"
  exit 1
fi

#Checking for valid second parameter
if [[ "$FPS" != "23.976" && "$FPS" != "24" && "$FPS" != "25" ]]; then
  echo -e "[ERROR] Please provide the framerate to conform to!\n        Valid options: 23.976, 24, 25"
  echo -e "$USAGE"
  exit 1
fi

#Setting output directory based on FPS
OUTPUT_VID="$DIR/temp/vid_$FPS"
OUTPUT_AUD="$DIR/temp/aud_$FPS"
OUTPUT_SUB="$DIR/temp/sub_$FPS"

#Making output directories
mkdir -p "$OUTPUT_VID"
mkdir -p "$OUTPUT_AUD"
mkdir -p "$OUTPUT_SUB"

#Folder for finished conversion
CONVERTED="$DIR/converted"
mkdir -p "$CONVERTED"

MSG_ERROR=" ➥ [ERROR ]"
MSG_NOTICE=" ➥ [NOTICE]"

#Convert video to desired FPS using mkvmerge
function CONVERT_VID () {
  echo "$MSG_NOTICE Starting video conversion"

  #Get index of video track
  VID_INDEX=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=index "$1")

  mkvmerge -q -o "$OUTPUT_VID/$OUTPUT_FILE" --default-duration "$VID_INDEX:$FPS_OUT" -d "$VID_INDEX" -A -S -T "$1"
}

#Convert audio to desired length, compensating pitch
function CONVERT_AUD () {
  echo "$MSG_NOTICE Starting audio conversion"

  ffmpeg -y -v error -i "$1" -c:a libopus -b:a 128k -filter:a "atempo=$TEMPO" -vn "$OUTPUT_AUD/$OUTPUT_FILE"
}

#Convert subtitles to desired length
function CONVERT_SUB () {
  echo "$MSG_NOTICE Starting subtitle conversion"

  #Get subtitle language
  SUBTITLE_LANG=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:0 -show_entries stream_tags=language "$1")

  #Extract subtitle file if necessary, perform FPS change
  if [[ ! -s "$SUBTITLE_EXT" ]]; then
    echo "$MSG_NOTICE Using embedded subtitles"
    ffmpeg -y -v error -i "$1" -map 0:s:0 "$OUTPUT_SUB/${OUTPUT_FILE}_original.srt"
    perl "$DIR/srt/srtshift.pl" "${FPS_IN}-${FPS}" "${OUTPUT_SUB}/${OUTPUT_FILE}_original.srt" "${OUTPUT_SUB}/$OUTPUT_FILE" > "$DIR"/temp/perl.log 2>&1
  else
    echo "$MSG_NOTICE Using external subtitles"
    perl "$DIR/srt/srtshift.pl" "${FPS_IN}-${FPS}" "$SUBTITLE_EXT" "${OUTPUT_SUB}/${OUTPUT_FILE}" > "$DIR"/temp/perl.log 2>&1
  fi

}

function MUX () {
  echo "$MSG_NOTICE Starting muxing"
  if [[ "$SUBTITLE_TYPE" == "srt" && ! -z "$SUBTITLE_LANG" ]]; then
    ffmpeg -y -v error -i "$OUTPUT_VID/$OUTPUT_FILE" -i "$OUTPUT_AUD/$OUTPUT_FILE" -i "$OUTPUT_SUB/$OUTPUT_FILE" -c copy -map 0:v:0 -map 1:a:0 -map 2:s:0 -metadata:s:2 language="$SUBTITLE_LANG" "$CONVERTED/$OUTPUT_FILE"
  elif [[ "$SUBTITLE_TYPE" == "srt" ]]; then
    ffmpeg -y -v error -i "$OUTPUT_VID/$OUTPUT_FILE" -i "$OUTPUT_AUD/$OUTPUT_FILE" -i "$OUTPUT_SUB/$OUTPUT_FILE" -c copy -map 0:v:0 -map 1:a:0 -map 2:s:0 "$CONVERTED/$OUTPUT_FILE"
  elif [[ -s "$SUBTITLE_EXT" ]]; then
    ffmpeg -y -v error -i "$OUTPUT_VID/$OUTPUT_FILE" -i "$OUTPUT_AUD/$OUTPUT_FILE" -i "$OUTPUT_SUB/$OUTPUT_FILE" -c copy -map 0:v:0 -map 1:a:0 -map 2:s:0 "$CONVERTED/$OUTPUT_FILE"
  else
    ffmpeg -y -v error -i "$OUTPUT_VID/$OUTPUT_FILE" -i "$OUTPUT_AUD/$OUTPUT_FILE" -c copy -map 0:v:0 -map 1:a:0 "$CONVERTED/$OUTPUT_FILE"
  fi
}

#Loop to convert all files with mkv extension in current directory
for INPUT_FILE in "$FOLDER"/*.mkv; do
  echo "FILE: $INPUT_FILE"

  #Get basename of file
  OUTPUT_FILE=$(basename "$INPUT_FILE")

  #Get framerate of input file to make calculate conversion
  FPS_IN=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=r_frame_rate "$INPUT_FILE")

  #Check if there are subtitles embedded and if so what type
  SUBTITLE_TYPE=$(ffprobe -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:0 -show_entries stream=codec_name "$INPUT_FILE")

  #Check for external subtitles if there are none embedded
  if [[ -z "$SUBTITLE_TYPE" ]]; then
    SUBTITLE_EXT=$(printf '%s' "$(dirname "$INPUT_FILE")" && printf '/' && printf '%s' "$(basename "$INPUT_FILE" .mkv)" && printf .srt)
  fi

  #Error for same input and output FPS
  ERR_NO_ACTION="$MSG_NOTICE Taking no action, FPS would be unchanged or is unsupported"

  #Error for unsupported framerate
  ERR_UNSUPPORTED="$MSG_ERROR Framerate not supported: $FPS_IN"

  #By default take action
  PASS="false"

  #Determine action, tempo
  if [[ "$FPS_IN" == "24000/1001" ]]; then
    FPS_IN="23.976"
    if [[ "$FPS" == "25" ]]; then
      FPS_OUT="25p"
      TEMPO="1.042709376"
      echo "$MSG_NOTICE Converting from ${FPS_IN}fps to ${FPS}fps"
    else
      echo -e "$ERR_NO_ACTION"
      PASS="true"
    fi
  elif [[ "$FPS_IN" == "24/1" ]]; then
    FPS_IN="24"
    if [[ "$FPS" == "25" ]]; then
      FPS_OUT="25p"
      TEMPO="1.041666667"
      echo "$MSG_NOTICE Converting from ${FPS_IN}fps to ${FPS}fps"
    else
      echo -e "$ERR_NO_ACTION"
      PASS="true"
    fi
  elif [[ "$FPS_IN" == "25/1" ]]; then
    FPS_IN="25"
    if [[ "$FPS" == "24" ]]; then
      FPS_OUT="24p"
      TEMPO="0.96"
      echo "$MSG_NOTICE Converting from ${FPS_IN}fps to ${FPS}fps"
    elif [[ "$FPS" == "23.976" ]]; then
      FPS_OUT="24000/1001p"
      TEMPO="0.95904"
      echo "$MSG_NOTICE Converting from ${FPS_IN}fps to ${FPS}fps"
    else
      echo -e "$ERR_NO_ACTION"
      PASS="true"
    fi
  else
    echo "$ERR_UNSUPPORTED"
    PASS="true"
  fi

  #Do conversion for files not set to pass
  if [[ "$PASS" != "true" ]]; then
    CONVERT_VID "$INPUT_FILE"
    CONVERT_AUD "$INPUT_FILE"
    if [[ "$SUBTITLE_TYPE" == "srt" || -s "$SUBTITLE_EXT" ]]; then
      CONVERT_SUB "$INPUT_FILE"
    else
      echo "$MSG_NOTICE No SRT subtitles found"
    fi
    MUX "$INPUT_FILE"

    #Delete intermediary files to save space
    rm -f "$OUTPUT_VID/$INPUT_FILE"
    rm -f "$OUTPUT_AUD/$INPUT_FILE"
  fi
done

#Clean up
rm -rf "$DIR/temp"
