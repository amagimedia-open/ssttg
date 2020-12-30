#!/bin/bash

set -u
set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(dirname $(readlink -e $0))
MODNAME=$(basename $0)

docker run \
        -it \
        --rm \
        --privileged \
        --network host \
        --name ssttg_dev_c \
        -v $DIRNAME:/ssttg \
        -v $DIRNAME/testdata:/data \
        -e SSTTG_DEV_ROOT=/ssttg \
        -w /ssttg \
        ssttg_dev \
        /ssttg/ssttg.sh -h

