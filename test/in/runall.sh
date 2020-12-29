#!/bin/bash

set -u
#set -x

(
cat <<EOD
$SSTTG_DEV_ROOT/test/in/01/run.sh
$SSTTG_DEV_ROOT/test/in/02/run.sh
EOD
) |\
while read test_script_path
do
    [[ $test_script_path =~ ^# ]] && { continue; }
    echo "executing $test_script_path" | boxes -d stone >&2
    $test_script_path
    echo
done

