#!/bin/bash
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPCAPPS_SASKEY="#HPC_APPS_SASKEY#"
LICENSE_SERVER="#LICSERVER#"

LICIP=27000@${LICENSE_SERVER}
echo $LICIP

#echo "----- patch OS -----"
yum install -y ksh 
yum install -y lsb 

mkdir -p /opt/abaqus/applications
mkdir -p /mnt/abaqus/INSTALLERS
mkdir -p /opt/abaqus/benchmark
chmod -R 777 /opt/abaqus
chmod -R 777 /mnt/abaqus

#Get Abaqus bits
echo "----- get Abaqus install bits -----"
cd /mnt/abaqus/INSTALLERS
wget "${HPC_APPS_STORAGE_ENDPOINT}/abaqus-2017/2017.AM_SIM_Abaqus_Extend.AllOS.1-6.tar?${HPCAPPS_SASKEY}" -O -| tar -x 
wget "${HPC_APPS_STORAGE_ENDPOINT}/abaqus-2017/2017.AM_SIM_Abaqus_Extend.AllOS.2-6.tar?${HPCAPPS_SASKEY}" -O -| tar -x 
wget "${HPC_APPS_STORAGE_ENDPOINT}/abaqus-2017/2017.AM_SIM_Abaqus_Extend.AllOS.3-6.tar?${HPCAPPS_SASKEY}" -O -| tar -x 
wget "${HPC_APPS_STORAGE_ENDPOINT}/abaqus-2017/2017.AM_SIM_Abaqus_Extend.AllOS.4-6.tar?${HPCAPPS_SASKEY}" -O -| tar -x 
wget "${HPC_APPS_STORAGE_ENDPOINT}/abaqus-2017/2017.AM_SIM_Abaqus_Extend.AllOS.5-6.tar?${HPCAPPS_SASKEY}" -O -| tar -x 
wget "${HPC_APPS_STORAGE_ENDPOINT}/abaqus-2017/2017.AM_SIM_Abaqus_Extend.AllOS.6-6.tar?${HPCAPPS_SASKEY}" -O -| tar -x 

echo "----- install Abaqus solvers -----"
cat << EOF |  ksh /mnt/abaqus/INSTALLERS/AM_SIM_Abaqus_Extend.AllOS/2/SIMULIA_AbaqusServices/Linux64/1/StartTUI.sh

/opt/abaqus/applications/DassaultSystemes/SimulationServices/V6R2017x









EOF

rm -rf /opt/abaqus/applications/SIMULIA/CAE/2017/linux_a64

# do not check the license during installation.
export NOLICENSECHECK=true
echo "----- install Abaqus services -----"
cat << EOF |  ksh /mnt/abaqus/INSTALLERS/AM_SIM_Abaqus_Extend.AllOS/2/SIMULIA_Abaqus_CAE/Linux64/1/StartTUI.sh

/opt/abaqus/applications/SIMULIA/CAE/2017
/opt/abaqus/applications/DassaultSystemes/SimulationServices/V6R2017x
/opt/abaqus/applications/DassaultSystemes/SIMULIA/Commands
/opt/abaqus/applications/DassaultSystemes/SIMULIA/CAE/plugins/2017

$LICIP







EOF

ENV_PATH="/opt/abaqus/applications/DassaultSystemes/SimulationServices/V6R2017x/linux_a64/SMA/site"

echo abaquslm_license_file="'$LICIP'" >> $ENV_PATH/custom_v6.env
echo license_server_type=FLEXNET  >> $ENV_PATH/custom_v6.env

# Need to path the impi.env file to use the right intel mpi path
cat <<EOF >$ENV_PATH/impi.env

#-*- mode: python -*-

import driverUtils, os

impipath = driverUtils.locateFile(os.environ.get('I_MPI_ROOT', ''), 'bin64', 'mpirun')
mp_mpirun_path = {IMPI: impipath}
mp_rsh_command = 'ssh -n -l %U %H %C'

# bump up the socket buffer size to 132K
os.environ.setdefault('MPI_SOCKBUFSIZE', '131072')

#if not self.mpiEnv.get('MPI_RDMA_MSGSIZE', None):
#    os.environ['MPI_RDMA_MSGSIZE'] = '16384,1048576,4194304'

del impipath
# 

EOF

# Need to specify we are using Intel MPI in mpi_config.env
replace="s,mp_mpi_implementation = PMPI,#mp_mpi_implementation = PMPI,g"
replace+=";s,#mp_mpi_implementation = IMPI,mp_mpi_implementation = IMPI,g"
cp $ENV_PATH/mpi_config.env $ENV_PATH/mpi_config.env.bak
sed "$replace" $ENV_PATH/mpi_config.env.bak > $ENV_PATH/mpi_config.env

cat $ENV_PATH/mpi_config.env

