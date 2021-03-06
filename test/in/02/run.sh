#!/bin/bash

set -u
#set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(dirname $(readlink -e $0))
MODNAME=$(basename $0)

#----[sources]---------------------------------------------------------------

source $SSTTG_DEV_ROOT/common_bash_functions.sh

#----[options]---------------------------------------------------------------

#----[temp files and termination]--------------------------------------------

function fnxOnEnd
{
    rm $TMP1 $TMP2
}

TMP1=`mktemp`
TMP2=`mktemp`

trap 'fnxOnEnd;' 0 1 2 3 6 9 11

#----[main]------------------------------------------------------------------

export PATH=$PATH:$SSTTG_DEV_ROOT

if [[ ${1-""} = "clean" ]]
then
    info_message "cleaning up ..."
    rm_other_than $TMP1 $DIRNAME run.sh
    exit 0
fi

if [[ ! -f $TEST_SOURCE_FILE_PATH ]]
then
    error_message "$TEST_SOURCE_FILE_PATH not present"
    exit 2
fi

info_message "output can be verified IN HOST through"
info_message "ffplay -autoexit -ar 16k -f s16le $DIRNAME/out.pcm"

set -x

# -x \
ssttg.sh \
    -O pcm \
    -s 5 \
    -i $TEST_SOURCE_FILE_PATH \
    -o $DIRNAME/out.pcm \
    -d $DIRNAME/out_dbg.txt

set +x

