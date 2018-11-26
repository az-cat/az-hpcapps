#!/bin/sh

WORKING_DIR=$(pwd)

source /opt/intel/impi/*/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT
export PATH=/opt/NWChem-6.8/bin:$PATH

ln -s /opt/NWChem-6.8/data/default.nwchemrc $HOME/.nwchemrc 

cd $SHARED_DIR

echo "Downloading from: $STORAGE_ENDPOINT/nwchem-6.8-x/h2o_freq.tar?$SAS_KEY"
wget -q "$STORAGE_ENDPOINT/nwchem-6.8-x/h2o_freq.tar?$SAS_KEY" -O - | tar x

mpirun \
    -genv I_MPI_FABRICS shm:dapl \
    -genv I_MPI_DAPL_PROVIDER ofa-v2-ib0 \
    -genv I_MPI_DYNAMIC_CONNECTION 0 \
    -genv I_MPI_DAPL_TRANSLATION_CACHE 0 \
    -np $CORES \
    -ppn $PPN \
    -hostfile $MPI_HOSTFILE \
     nwchem \
    ./h2o_freq.nw \
    > $OUTPUT_DIR/h2o_freq.out

fname=$OUTPUT_DIR/h2o_freq.out
cpu_str=$(grep "Total times" $fname | awk '{print $4}')
cpu_str_s=${cpu_str::-1}
cpu_time=$(bc <<< "$cpu_str_s * $CORES")
wall_str=$(grep "Total times" $fname | awk '{print $6}')
wall_time=${wall_str::-1}
memory_heap_MB=$(grep "maximum total M-bytes" $fname | awk '{print $4}')
memory_stack_MB=$(grep "maximum total M-bytes" $fname | awk '{print $5}')
memory_MB=$(bc <<< "$memory_heap_MB + $memory_stack_MB")

cd $WORKING_DIR

cat <<EOF >$APPLICATION.json
{
"model": "h2o_freq",
"cpu_time": "$cpu_time",
"clock_time": "$wall_time",
"memory": "$memory_MB"
}
EOF
