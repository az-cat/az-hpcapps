#! /bin/sh

ENV_FILE=$SGE_JOB_SPOOL_DIR/environment
touch $ENV_FILE
if [ ! -f $ENV_FILE -o ! -w $ENV_FILE ]
then
  exit 1
fi

# Set the environment.

MPI_MACHINEFILE=$SGE_JOB_SPOOL_DIR/azure_machine_file
PE_HOST_FILE=$SGE_JOB_SPOOL_DIR/pe_hostfile
awk -v PPN="$PPN" 'BEGIN{FS="."}{ print $1":"PPN}' $PE_HOST_FILE > $MPI_MACHINEFILE 

MPI_HOSTLIST=$(awk 'BEGIN{FS="."}{ print $1}' $PE_HOST_FILE | tr '\n' ',' | sed 's/,$/\n/')


echo CORES=$NSLOTS >> $ENV_FILE
echo MPI_HOSTFILE=$TMPDIR/machines >> $ENV_FILE
echo MPI_HOSTLIST=$MPI_HOSTLIST >> $ENV_FILE
echo MPI_MACHINEFILE=$MPI_MACHINEFILE >> $ENV_FILE

echo ""
echo "ENVFILE: $ENV_FILE"
cat $ENV_FILE
echo ""

exit 0