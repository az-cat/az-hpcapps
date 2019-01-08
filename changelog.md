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