#!/bin/bash

set -u
set -x

#----[globals]------------------------------------------------------------------------

DIRNAME=$(dirname $(readlink -e $0))
MODNAME=$(basename $0)

mkdir -p $DIRNAME/testdata

docker run \
        -it \
        --rm \
        --privileged \
        --network host \
        --name ssttg_c \
        -v $DIRNAME:/ssttg \
        -v $DIRNAME/testdata:/data \
        -e SSTTG_DEV_ROOT=/ssttg \
        -e TEST_SOURCE_FILE_PATH=/ssttg/sstt_testclip_20_sec.mp4 \
        -w /ssttg \
        ssttg \
        bash

