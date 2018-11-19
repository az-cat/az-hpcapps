#!/bin/bash

WORKING_DIR=$(pwd)

source /opt/intel/impi/*/bin64/mpivars.sh

wget -q "$STORAGE_ENDPOINT/namd-2-10/namd_stmv_benchmark.tgz?$SAS_KEY" -O - | tar zx

mpirun \
    -genv I_MPI_FABRICS shm:dapl \
    -genv I_MPI_DAPL_PROVIDER ofa-v2-ib0 \
    -genv I_MPI_DYNAMIC_CONNECTION 0 \
    -genv I_MPI_DAPL_TRANSLATION_CACHE 0 \
    -genv I_MPI_STATS ipm \
    -np $CORES \
    -ppn $PPN \
    -hostfile $MPI_HOSTFILE \
    /opt/namd2.10/namd2 ${WORKING_DIR}/namd_stmv_benchmark/stmv.namd \
    > $OUTPUT_DIR/stmv.log

cp -f ${WORKING_DIR}/namd_stmv_benchmark/stats.ipm .

# grepping for line like:
#    "WallClock: 95.590508 CPUTime: 95.590508 Memory: 1037.929688 MB"
line=$(grep "WallClock:" $OUTPUT_DIR/stmv.log)
wall_clock=$(cut -d' ' -f 2 <<< $line)
cpu_time=$(cut -d' ' -f 4 <<< $line)
memory=$(cut -d' ' -f 6 <<< $line)

cat <<EOF >$APPLICATION.json
{
"model": "stmv",
"clock_time": "$wall_clock",
"cpu_time": "$cpu_time",
"memory": "$memory"
}
EOF
