#!/bin/bash

set -u
#set -x

(
cat <<EOD
$SSTTG_DEV_ROOT/test/in/01/run.sh
EOD
) |\
while read test_script_path
do
    [[ $test_script_path =~ ^# ]] && { continue; }
    $test_script_path
done

