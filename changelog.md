### Version 1.7
- Added Centos76 support for HC/HB
- Removed Centos75 support for HC/HB
- Force packer 1.3.2 as 1.3.4 has a bug not using Premium_LRS for captured image
- Added QE 6.3
- Resolved: Use HTTPS instead of HTTP when accessing DATA storage
- Resolved: Improve ERROR parsing from the output of image craeation 
- Allow packer to use private IP only
- Force waagent to version 2.2.36 which fix the IB0 not being set for HC/HB


### Version 1.6
- Support HC44rs VM Type
- Added builder application to build OSS applications
- Added -u option for run_app to specify a Batch autoUser/scope/elevation value or a specific username
- disable GSS proxy in the base image script for CentOS
- Moved build_openmpi from empty to builder
- Added build_hplamd, build_stream (for HB/HC) script to builder
- Added the VMSIZE, HPC_APPS_STORAGE_ENDPOINT, HPC_APPS_SASKEY, UCX_IB_PKEY, IB_PKEY environment variables available when executing run scripts
- Surround SCRIPT_FLAGS with " in task-template.json to allow passing SAS_KEY in params of scripts
- Updated empty/run_single_hpl_epyc to use hpl built from build_hplamd and stored into blobs
- Added run_stream script to empty that support HB and HC
- Update WAAGENT when building the image
- Upgrade LIS to version 4.2.8
- disable cpupower and firewalld for all SKUs
- use version 1.3.2 for packer as 1.3.3 has a bug for managed image


### Version 1.5
- Use Key Vault to store secrets instead of clear values in configuration files
- Support HB60rs VM Type
  - Setup Mellanox drivers
  - Setup IB
  - Setup Intel MPI 2018
- Use managed disks for OS disks with Packer and Batch for VM type that support it
- Upgraded to Fluent 19.2
- Added new test cases in the empty image (allreduce, ring_pingpong, all_pingpong, stream, single_hpl_epyc)
- new -u option for create_cluster to update a pool if it exists
- new -r option for run_app to repeat task n times
- New -q option for run_app to use a specific queue (pool), this allow running diagnostics tests on existing application pools

### Version 1.4
- Added nwchem
- Update documentation to use setup.sh to configure config file
- Update documentation for app binaries and data upload location

### Version 1.3
- Added OpenFOAM 4.x
- Added Abaqus 2017
- Added NAMD 2.10
- Fix broken links in documentation

### Version 1.0
Initial release