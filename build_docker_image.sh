#!/bin/bash

set -e
set -u
set -x

docker build -t ssttg -f dockerfile.txt .
