#!/bin/bash

WORKING_DIR=$(pwd)
set -x
set -e

source /opt/intel/impi/*/bin64/mpivars.sh

export PATH=/opt/q-e-qe-6.2.0/bin:$PATH

cd $SHARED_DIR
wget -q $STORAGE_ENDPOINT/qe/6.2/qe-6.2.0-benchmarks.tar.gz?$SAS_KEY -O - | tar zx

cd $SHARED_DIR/q-e-qe-6.2.0/examples/atomic/examples/pseudo-gen

start_time=$SECONDS

work=./results
reference=./reference
. ./environment_variables
PATH=/opt/q-e-qe-6.2.0/bin:$PATH

mkdir -p $work # does not fail if $work exist
rm -f $work/*

ld1_command="$PARA_PREFIX ld1.x $PARA_POSTFIX"

echo "ld1_command =" $ld1_command

if test -e difference ; then /bin/rm difference > /dev/null ; fi
touch difference

for atom in o al as pt si_nc ; do
    $ld1_command < $atom.in > $work/$atom.out
    echo "diff -wib ./results/$atom.out ./reference/$atom.out" >> difference
    diff -wib $work/$atom.out $reference/ >> difference
done

/bin/rm ld1.wfc


for file in OPBE.RRKJ3 Al.rrkj3 Asrel.RRKJ3.UPF Ptrel.RRKJ3.UPF SiPBE_nc  ; do
    echo "-------------------------------------------------" >> difference
    echo "diff -wib ./results/$file ./reference/$file" >> difference
    echo "Note that results and reference data may differ for numerical reasons" >> difference
    mv $file $work
    diff $work/$file $reference/ >> difference
done

end_time=$SECONDS

clock_time=$(($end_time - $start_time))

cd $WORKING_DIR

cat <<EOF >$APPLICATION.json
{
"model": "psuedo-gen",
"clock_time": "$clock_time"
}
EOF
