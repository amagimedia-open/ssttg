#!/bin/bash

set -u
#set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(dirname $(readlink -e $0))
MODNAME=$(basename $0)

#----[sources]---------------------------------------------------------------


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

echo "executing $0" | boxes -d stone >&2

export PATH=$PATH:$SSTTG_DEV_ROOT
#echo $PATH >&2

ssttg.sh \
    -x \
    -O gencfg \
    -o /data/in/01/cfg.ini \
    -d /data/in/01/dbg.txt

