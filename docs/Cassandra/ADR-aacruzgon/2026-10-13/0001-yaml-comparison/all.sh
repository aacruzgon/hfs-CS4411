cd "$(dirname "$0")"
for x in "S P1 C" "L P1 C" "S P2 B" "L P2 B"; do bash bench.sh $x > raw/log-${x// /-}.txt 2>&1; done
echo ALLDONE > raw/ALLDONE
