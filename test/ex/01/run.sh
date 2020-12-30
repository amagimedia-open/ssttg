#!/bin/bash

set -u
#set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(dirname $(readlink -e $0))
MODNAME=$(basename $0)

mkdir -p $DIRNAME/testdata

docker run \
        -it \
        --rm \
        --privileged \
        --network host \
        --name ssttg_rel_c \
        -v $DIRNAME/testdata:/data \
        ssttg_rel \
        /ssttg/ssttg.sh -h

