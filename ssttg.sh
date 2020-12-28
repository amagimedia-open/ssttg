#!/bin/bash

set -u
#set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(dirname $(readlink -e $0))
MODNAME=$(basename $0)

G_MAPPED_ROOT_PATH=/data
G_NAMED_PIPE_PATH=/tmp/ssttg_pack_pcm_fifo
G_DEF_CONFIG_FILEPATH="${DIRNAME}/ssttg_def_cfg.ini"

#----[sources]---------------------------------------------------------------

source $DIRNAME/common_bash_functions.sh

#----[prefix-checks]---------------------------------------------------------

if [[ ! -d $SSTTG_D_WORK_AREA ]]
then
    error_message "environment variable SSTTG_D_WORK_AREA not defined"
    exit 1
fi

#----[options]---------------------------------------------------------------

OPT_OP="transcribe"
OPT_INPUT_FILEPATH=""
OPT_OUTPUT_FILEPATH=""
OPT_DEBUG_FILEPATH="$G_MAPPED_ROOT_PATH/err_dbg.txt"
OPT_AUTH_FILEPATH=""
OPT_CONFIG_FILEPATH="$G_DEF_CONFIG_FILEPATH"

#----[temp files and termination]--------------------------------------------

function fnxOnEnd
{
    rm $TMP1 $TMP2
}

TMP1=`mktemp`
TMP2=`mktemp`

trap 'fnxOnEnd;' 0 1 2 3 6 9 11

#----[helper functions]------------------------------------------------------

function usage
{
    cat <<EOD
NAME

    $MODNAME - performs streaming speech to text transcription
                   

SYNOPSIS

    $MODNAME [-O operation]
             [-i $G_MAPPED_ROOT_PATH/.../input_media_file_path] 
             [-o $G_MAPPED_ROOT_PATH/.../output_file_path]
             [-d $G_MAPPED_ROOT_PATH/.../output_debug_file_path]
             [-a $G_MAPPED_ROOT_PATH/.../auth_file_path.json] 
             [-c $G_MAPPED_ROOT_PATH/.../config_file_path.ini] 
             [-x]
             [-h]

DESCRIPTION

    This script performs speech to text transcription using the 
    google api.

    The filepaths specified for the -i, -o, -d, -a, and -c options 
    must have a common ancestor and this must be mapped to 
    '$G_MAPPED_ROOT_PATH' using the -v option of the docker run 
    command.

OPTIONS

    -O  operation
        this must be one of
        * gencfg
          default configuration file dumped to output_file_path
        * pcm
          here pcm data in the pcm_s16le format is extracted from the 
          input_media_file_path
        * packpcm
          here pcm data in the pcm_s16le format is extracted from the 
          input_media_file_path and it is packetized with timestamps
        * transcribe
          here pcm data in the pcm_s16le format is extracted from the 
          input_media_file_path, packetized with timestamps and transcribed
          to text
        this is optional. default is $OPT_OP.

    -i  $G_MAPPED_ROOT_PATH/.../input_media_file_path
        A .mp4 or .ts file or any other format recognized by ffmpeg.
        This is mandatory.

    -o  $G_MAPPED_ROOT_PATH/.../output_file_path
        The format is dependent in the operation specified (see -O option).
        This is optional. defaults are as follows:
        +------------+-------------------+
        | operation  | name              |
        +------------+-------------------+
        | gencfg     | ssttg_def_cfg.ini |
        | pcm        | out.s16le.pcm     |
        | packpcm    | out.s16le.packpcm |
        | transcribe | out.srt           |
        +------------+-------------------+

    -d  $G_MAPPED_ROOT_PATH/.../err_dbg_file_path
        Debug and error messages are stored here.
        This is optional. Default $G_MAPPED_ROOT_PATH/err_dbg.txt

    -a  $G_MAPPED_ROOT_PATH/.../gcp_auth_filepath.json
        Google security credentials file.
        This is mandatory if the operation is 'transcribe' and ignored 
        otherwise.

    -c  $G_MAPPED_ROOT_PATH/.../transcribe_config_file_path.ini
        The configuration file used for control of the transcription
        algorithm.
        This is mandatory if the operation is 'transcribe' and ignored 
        otherwise.

    -x
        Enables 'set -x' for this script.
        This is optional. If enabled it is preferable to specify this as
        the first option.

    -h
        Displays this help and quits.
        This is optional.

EXAMPLES

    TODO

EOD
}

#----------------------------------------------------------------------------
# MAIN
#----------------------------------------------------------------------------

export PYTHONPATH=$DIRNAME

TEMP=`getopt -o "O:i:o:d:a:c:xh" -n "$0" -- "$@"`
eval set -- "$TEMP"

while true 
do
	case "$1" in
        -O) OPT_OP="$2"; shift 2;;
        -i) OPT_INPUT_FILEPATH="$2"; shift 2;;
        -o) OPT_OUTPUT_FILEPATH="$2"; shift 2;;
        -d) OPT_DEBUG_FILEPATH="$2"; shift 2;;
        -a) OPT_AUTH_FILEPATH="$2"; shift 2;;
        -c) OPT_CONFIG_FILEPATH="$2"; shift 2;;
        -x) set -x; shift 1;;
        -h) usage; exit 0;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

case $OPT_OP in
    gencfg|pcm|packpcm|transcribe)
        ;;
    *)
        error_message "invalid value for -O option"
        exit 1
esac

if [[ -n $OPT_INPUT_FILEPATH ]]
then
    if [[ ! -f $OPT_INPUT_FILEPATH ]]
    then
        error_message "file $OPT_INPUT_FILEPATH not present"
        exit 1
    fi
else
    error_message "-i option not specified"
    exit 1
fi

if [[ -z $OPT_OUTPUT_FILEPATH ]]
then
    case $OPT_OP in
        gencfg)
            OPT_OUTPUT_FILEPATH="$G_MAPPED_ROOT_PATH/ssttg_def_cfg.ini"
            ;;
        pcm)
            OPT_OUTPUT_FILEPATH="$G_MAPPED_ROOT_PATH/out.s16le.pcm"
            ;;
        packpcm)
            OPT_OUTPUT_FILEPATH="$G_MAPPED_ROOT_PATH/out.s16le.packpcm"
            ;;
        transcribe)
            OPT_OUTPUT_FILEPATH="$G_MAPPED_ROOT_PATH/out.srt"
            ;;
    esac
fi
if ! create_file $OPT_OUTPUT_FILEPATH
then
    error_message "$OPT_OUTPUT_FILEPATH not present or cannot be created"
    exit 1
fi

if ! create_file $OPT_DEBUG_FILEPATH
then
    error_message "cannot create $OPT_DEBUG_FILEPATH"
    exit 1
fi

if [[ $OPT_OP = "transcribe" ]]
then
    if [[ -n $OPT_AUTH_FILEPATH ]]
    then
        if [[ ! -f $OPT_AUTH_FILEPATH ]]
        then
            error_message "file $OPT_AUTH_FILEPATH not present"
            exit 1
        fi
    else
        error_message "-a option not specified"
        exit 1
    fi

    if [[ ! -f $OPT_CONFIG_FILEPATH ]]
    then
        error_message "file $OPT_CONFIG_FILEPATH not present"
        exit 1
    fi
fi


#-----------------------------------------------------------

case $OPT_OP in

    gencfg)

        cp $G_DEF_CONFIG_FILEPATH $OPT_OUTPUT_FILEPATH
        ;;

    pcm)

        #+-----------------------+
        #| check only pcm output |
        #+-----------------------+

        ffmpeg \
            -re \
            -i $OPT_INPUT_FILEPATH \
            -vn \
            -acodec pcm_s16le -ac 1 -ar 16k \
            -f s16le \
            $OPT_OUTPUT_FILEPATH \
            2>$OPT_DEBUG_FILEPATH
        ;;


    packpcm)

        #+---------------------+
        #| dump packetized pcm |
        #+---------------------+

        ffmpeg \
            -loglevel quiet \
            -re \
            -i $OPT_INPUT_FILEPATH \
            -vn \
            -acodec pcm_s16le -ac 1 -ar 16k \
            -f s16le \
            pipe:1 |\
        audio_packetizer \
            -z |\
        audio_depacketizer \
            -v \
            -z \
            1>$OPT_OUTPUT_FILEPATH \
            2>$OPT_DEBUG_FILEPATH
        ;;


    transcribe)

        #+-----------------------+
        #| perform transcription |
        #+-----------------------+

        python3 ssttg.py \
               -i $G_NAMED_PIPE_PATH \
               -o $OPT_OUTPUT_FILEPATH \
               -c $OPT_CONFIG_FILEPATH \
               -a $OPT_AUTH_FILEPATH \
               -f \
               -v \
               2>$OPT_DEBUG_FILEPATH &
        TRANSCRIBE_PID=$!

        ffmpeg \
            -loglevel quiet \
            -re \
            -i $OPT_INPUT_FILEPATH \
            -vn \
            -acodec pcm_s16le -ac 1 -ar 16k \
            -f s16le \
            pipe:1 |\
        audio_packetizer \
            -z |\
        audio_depacketizer \
            -z \
            -f > $G_NAMED_PIPE_PATH

        sleep 5     # TODO: make it event based
        kill_pid $TRANSCRIBE_PID
        ;;
esac

RET=$?

stty sane

exit $RET

