#!/bin/bash
# score.sh N TEAM [POLICY] -> "wins/N  avgKO  TEAM"
cd "$(dirname "$0")"; out=""
for s in $(seq 1 $1); do out+=$(TEAM="$2" POLICY=${3:-helper} SEED=$s RH=${RH:-$PWD/../rh_test/RH65.rb} timeout 60 ruby boot.rb ../../.. withrh.rb 2>/dev/null | grep RESULT)$'\n'; done
w=$(echo "$out" | grep -c "decision=1 "); ko=$(echo "$out" | grep RESULT | sed 's/.*foe_left=//' | awk '{s+=6-$1}END{printf "%.2f", s/NR}')
echo "$w/$1 KO=$ko $2"
