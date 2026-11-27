#!/bin/bash
# chunk 1 of the step list (story var 339 = 0..6): every step, from where you'd really be
run() { echo "=== V339=$1 SS=$2 START=$3"; V339=$1 SS="$2" START=$3 UPD=${UPD:-updates53.txt} timeout 170 ruby harness.rb ../../.. ${RH:-RH53a.rb} guidewalk.rb 2>&1 | grep -E "STEP|PASS|FAIL|no exit|on [0-9]"; }
run 0 "" 519,35,47
run 1 "" 38,15,10
run 1 "" 525,21,23
run 2 "527,66" 527,35,24
run 2 "552,35" 552,10,22
run 3 "527,66;526,57" 526,52,21
run 3 "527,66;526,57" 525,21,23
run 3 "526,57;552,35" 552,10,22
run 4 "527,66;526,57;552,35" 552,10,22
run 4 "527,66;526,57;552,35" 519,35,47
run 5 "527,66;526,57;552,35" 38,15,10
run 6 "527,66;526,57;552,35" 229,6,10
