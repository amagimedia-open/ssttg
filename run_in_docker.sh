#!/bin/bash

set -u
set -x

docker run \
        -it \
        --rm \
        --privileged \
        --network host \
        --name ssttg_c \
        ssttg \
        "$@"


