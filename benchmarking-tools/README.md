# Benchmarking Tools
This directory contains scripts to help automate the process of executing Cachelib benchmarks using cachebench.
The scripts have been developed based upon common use-cases of running workloads using cachebench and then collecting metrics from the workload runs. 
Currently, it contains the following scripts:
1. measure-dev: This script is used to monitor the NVMe device and collect WAF related statistics based on nvme-cli smart log.
It also collects memory usage and flexalloc-related data.
The script was originally developed because cachebench related device amplification statistics have not been enough.

2. run-cachelib.sh: This script was written to generalize the command(s) used to set up the NVMe device for experimentation, build and run cachebench workloads.
This script uses a set of configuration parameters which can be specified directly in the script or via a configuration file.
A configuration file for the [Docker container configuration](../dockerfiles/Dockerfile-cachelib-ubuntu-jammy) is available [here](../configs/run-cachelib-default-docker-config).
The NVME_DEVICE variable in the configuration file needs to be updated according to the NVMe device on the host machine or specified when the script is used using a flag.
Please look at the configuration file and change parameters to pertain to the specific hardware on your machine.

## Using run-cachelib.sh with the supplied configuration file in the Docker container
You can pass the NVMe device using either the configuration file or the flag -i.
**It is recommended to update the configuration file rather than using the -i switch each time if you are dealing with a single NVMe device in the container.**

### Delete the /dev/nvme0n1 namespace
```
./run-cachelib.sh -f ../configs/run-cachelib-default-docker-config -i /dev/nvme0n1 -d
```

### Create a namespace /dev/nvme0n1 with 50% of the size of the device
```
./run-cachelib.sh -f ../configs/run-cachelib-default-docker-config -i /dev/nvme0n1 -a 50
```
**Note that the -i option is not required if the configuration file is updated for the NVMe device.**
*The order of -f and -i is also important due to the simplified nature of handling of arguments in the script using getopts.
The flag -f must always precede -i if combined.*

### Disable FDP functionality
```
./run-cachelib.sh -f ../configs/run-cachelib-default-docker-config -o
```
The above command assumes that the NVMe device is specified in the configuration file else the -i switch must be used.
You can only run this command successfully if you don't have any active namespace on the NVMe controller.

### Enable FDP functionality
```
./run-cachelib.sh -f ../configs/run-cachelib-default-docker-config -e
```

### Build Cachelib
```
./run-cachelib.sh -f ../configs/run-cachelib-default-docker-config -b
```
You can specify a branch name to the -b flag else it defaults to main.
The branch name can also be configured in the configuration file.

### Run cachebench workload
```
./run-cachelib.sh -f ../configs/run-cachelib-default-docker-config -r
```
The cachebench workload that is executed is specified in *../configs/run-cachelib-default-docker-config* in the variable CACHEBENCH_RUN_CONFIG by listing the path to the cachebench workload configuration.
You can also specify the log directory in which the workload specific logs are produced as an argument to the -r flag or by specifying it in *../configs/run-cachelib-default-docker-config*.

### Miscellaneous
The scripts support other usage scenarios, please look at the help for more details.
Any argument that can be provided to a flag in *run-cachelib.sh* can also be specified using the configuration file provided to it as input.
*It is not required to use the scripts within the Docker container built using the Dockerfile provided in this repository.
You can use your own environment with the scripts if you configure the configuration file to point to your specific hardware and software configuration i.e., paths to nvme-cli, NVMe device, path to Cachelib, FDP specific information.*