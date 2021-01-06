#!/bin/bash

set -u
#set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(readlink -e $(dirname $0))
MODNAME=$(basename $0)

G_MAPPED_ROOT_PATH=/data
G_NAMED_PIPE_PATH=/tmp/ssttg_pack_pcm_fifo
G_DEF_CONFIG_FILEPATH="${DIRNAME}/ssttg_def_cfg.ini"

#----[sources]---------------------------------------------------------------

source $DIRNAME/common_bash_functions.sh

#----[options]---------------------------------------------------------------

OPT_OP="transcribe"
OPT_INPUT_FILEPATH=""
OPT_OUTPUT_FILEPATH=""
OPT_DEBUG_FILEPATH="$G_MAPPED_ROOT_PATH/err_dbg.txt"
OPT_AUTH_FILEPATH=""
OPT_CONFIG_FILEPATH="$G_DEF_CONFIG_FILEPATH"
OPT_DURATION=""
OPT_VERBOSE=0
OPT_VERBOSE_ON_TTY=0
OPT_ADD_SILENCE_SEC=0
OPT_BASH_DEBUG=0

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

    This script performs streaming speech to text transcription using 
    the google api (https://cloud.google.com/speech-to-text/docs/streaming-recognize)

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
        * transcribepcm
          here pcm data in the pcm_s16le format is pumped via stdin. this
          is then packetized with timestamps and transcribed to text

        this is optional. default is $OPT_OP.

        +---------------+---------------------------------------------------------+
        | operation     |  options ([] => optional)                               |
        +---------------+---------------------------------------------------------+
        | gencfg        |  none                                                   |
        | pcm           |  -i, [-o], [-d], [-x], [-D]                             |
        | packpcm       |  -i, [-o], [-d], [-x], [-D], [-v], [-s]                 |
        | transcribe    |  -i, [-o], [-d], [-x], [-D], [-v], [-s], -a, [-c], [-t] |
        | transcribepcm |  -i, [-o], [-d], [-x],       [-v],       -a, [-c]       |
        +---------------+---------------------------------------------------------+

    -i  $G_MAPPED_ROOT_PATH/.../input_media_file_path
        A .mp4 or .ts file or any other format recognized by ffmpeg.
        This is mandatory for all operations except 'gencfg'.

    -o  $G_MAPPED_ROOT_PATH/.../output_file_path
        The format is dependent in the operation specified (see -O option).
        This is optional. defaults are as follows:
        +---------------+-------------------+
        | operation     | output_file_name  |
        +---------------+-------------------+
        | gencfg        | ssttg_def_cfg.ini |
        | pcm           | out.s16le.pcm     |
        | packpcm       | out.s16le.packpcm |
        | transcribe    | out.srt           |
        | transcribepcm | out.srt           |
        +---------------+-------------------+

    -d  $G_MAPPED_ROOT_PATH/.../err_dbg_file_path
        Debug and error messages are stored here.
        This is optional. Default $G_MAPPED_ROOT_PATH/err_dbg.txt

    -a  $G_MAPPED_ROOT_PATH/.../gcp_auth_filepath.json
        Google security credentials file.
        This is mandatory if the operation is 'transcribe' or 'transcribepcm'
        and ignored otherwise.

    -c  $G_MAPPED_ROOT_PATH/.../transcribe_config_file_path.ini
        The configuration file used for control of the transcription
        algorithm. 
        This is optional. (i.e. there is a default configuration 'coded' 
        internally).

    -x
        Enables 'set -x' for this script.
        This is optional. If enabled it is preferable to specify this as
        the first option.

    -D  HH:MM:SS
        Restrics audio from input_media_file_path to the first #secs.
        This is optional.

    -v
        enable verbosity. 
        this is optional.

    -t
        dump verbose messages also on tty. 
        this is optional.

    -s  #secs
        add silence of #secs to the input.
        this is optional.

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

export PATH=$PATH:$DIRNAME

TEMP=`getopt -o "O:i:o:d:a:c:D:s:xvth" -n "$0" -- "$@"`
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
        -D) OPT_DURATION="$2"; shift 2;;
        -s) OPT_ADD_SILENCE_SEC=$2; shift 2;;
        -x) set -x; OPT_BASH_DEBUG=1; shift 1;;
        -v) OPT_VERBOSE=1; shift 1;;
        -t) OPT_VERBOSE_ON_TTY=1; shift 1;;
        -h) usage; exit 0;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

case $OPT_OP in
    gencfg|pcm|packpcm|transcribe|transcribepcm)
        ;;
    *)
        error_message "invalid value for -O option"
        exit 1
esac

case $OPT_OP in
    gencfg|transcribepcm)
        ;;
    *)
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
        ;;
esac

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
        transcribe|transcribepcm)
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

case $OPT_OP in
    transcribe|transcribepcm)
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
        ;;
esac

if [[ -n $OPT_DURATION ]]
then
    if [[ ! $OPT_DURATION =~ ^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$ ]]
    then
        error_message "value for -D option not in the form HH:MM:SS"
        exit 1
    fi
    OPT_DURATION="-to $OPT_DURATION"
fi

if ((OPT_VERBOSE==0))
then
   OPT_VERBOSE_ON_TTY=0
fi

#-----------------------------------------------------------

if [[ ! -p $G_NAMED_PIPE_PATH ]]
then
    if ! mkfifo $G_NAMED_PIPE_PATH
    then
        error_message "creation of $G_NAMED_PIPE_PATH failed"
        exit 2
    fi

    info_message "creation of $G_NAMED_PIPE_PATH succeeded"
fi

FFMPEG_ADD_SILENCE_OPTS=""
if ((OPT_ADD_SILENCE_SEC > 0))
then
    #https://superuser.com/a/579110
    FFMPEG_ADD_SILENCE_OPTS="
        -f lavfi 
        -t $OPT_ADD_SILENCE_SEC 
        -i anullsrc=r=16000 
        -filter_complex [0:a][1:a]concat=n=2:v=0:a=1"
fi

case $OPT_OP in

    gencfg)

        cp $G_DEF_CONFIG_FILEPATH $OPT_OUTPUT_FILEPATH
        ;;

    pcm)

        #+-----------------------+
        #| check only pcm output |
        #+-----------------------+

        ffmpeg \
            -i $OPT_INPUT_FILEPATH \
            $FFMPEG_ADD_SILENCE_OPTS \
            -vn \
            -acodec pcm_s16le -ac 1 -ar 16k \
            -f s16le \
            -y \
            $OPT_OUTPUT_FILEPATH \
            2>$OPT_DEBUG_FILEPATH
        ;;

    packpcm)

        #+---------------------+
        #| dump packetized pcm |
        #+---------------------+

        DEPACK_VERBOSITY=""
        ((OPT_VERBOSE)) && { DEPACK_VERBOSITY="-vv"; }

        ((OPT_VERBOSE)) && \
            { echo "starting ffmpeg|pack|depack ..." > /dev/tty; }

        ffmpeg \
            -loglevel quiet \
            -re \
            -i $OPT_INPUT_FILEPATH \
            $FFMPEG_ADD_SILENCE_OPTS \
            $OPT_DURATION \
            -vn \
            -acodec pcm_s16le -ac 1 -ar 16k \
            -f s16le \
            pipe:1 |\
        audio_packetizer \
            -z |\
        audio_depacketizer \
            $DEPACK_VERBOSITY \
            -z \
            -f \
            1>$OPT_OUTPUT_FILEPATH 2>$OPT_DEBUG_FILEPATH

        stty sane
        ;;


    transcribe)

        #+-----------------------+
        #| perform transcription |
        #+-----------------------+

        DEPACK_VERBOSITY=""
        TRANSCRIBE_VERBOSITY=""

        ((OPT_VERBOSE)) && { DEPACK_VERBOSITY="-vv"; }
        ((OPT_VERBOSE)) && { TRANSCRIBE_VERBOSITY="-v"; }

        (
            ((OPT_BASH_DEBUG)) && { set -x; }

            ((OPT_VERBOSE_ON_TTY)) && \
                { echo "starting transcriber ..." > /dev/tty; }

            python3 $DIRNAME/ssttg.py \
                $TRANSCRIBE_VERBOSITY \
                -i $G_NAMED_PIPE_PATH \
                -o $OPT_OUTPUT_FILEPATH \
                -c $OPT_CONFIG_FILEPATH \
                -a $OPT_AUTH_FILEPATH \
                -f &
            BG_PID=$!

            if ((OPT_VERBOSE_ON_TTY))
            then
                echo "starting tail ..." > /dev/tty
                sleep 2
                stdbuf -o 0 tail --pid=$BG_PID -f $OPT_DEBUG_FILEPATH 1>/dev/tty & 
            fi

            ((OPT_VERBOSE_ON_TTY)) && \
                { echo "starting ffmpeg|pack|depack ..." > /dev/tty; }
            sleep 2

            ffmpeg \
                -loglevel quiet \
                -re \
                -i $OPT_INPUT_FILEPATH \
                $FFMPEG_ADD_SILENCE_OPTS \
                $OPT_DURATION \
                -vn \
                -acodec pcm_s16le -ac 1 -ar 16k \
                -f s16le \
                pipe:1 |\
            audio_packetizer \
                -z |\
            audio_depacketizer \
                $DEPACK_VERBOSITY \
                -z \
                -f \
                1> $G_NAMED_PIPE_PATH

            stty sane

            ((OPT_VERBOSE_ON_TTY)) && \
                { echo "end of input" > /dev/tty; \
                  echo "sleeping for 2 seconds ..." > /dev/tty; }
            sleep 2     # TODO: make it event based

            kill_pid $BG_PID

        ) 2>$OPT_DEBUG_FILEPATH

        ;;


    transcribepcm)

        #+-----------------------+
        #| perform transcription |
        #+-----------------------+

        DEPACK_VERBOSITY=""
        TRANSCRIBE_VERBOSITY=""

        ((OPT_VERBOSE)) && { DEPACK_VERBOSITY="-vv"; }
        ((OPT_VERBOSE)) && { TRANSCRIBE_VERBOSITY="-v"; }

        (
            ((OPT_BASH_DEBUG)) && { set -x; }

            python3 $DIRNAME/ssttg.py \
                $TRANSCRIBE_VERBOSITY \
                -i $G_NAMED_PIPE_PATH \
                -o $OPT_OUTPUT_FILEPATH \
                -c $OPT_CONFIG_FILEPATH \
                -a $OPT_AUTH_FILEPATH \
                -f &
            BG_PID=$!

            sleep 2

            # pcm is supplied to audio_packetizer via stdin

            stdbuf -o 0 cat |\
            audio_packetizer \
                -z |\
            audio_depacketizer \
                $DEPACK_VERBOSITY \
                -z \
                -f \
                1> $G_NAMED_PIPE_PATH

            sleep 2     # TODO: make it event based

            kill_pid $BG_PID

        ) 2>$OPT_DEBUG_FILEPATH

        ;;
esac

RET=$?

#stty sane

exit $RET

