# Dockerfile Documentation.
This folder contains Dockerfiles used to set up container images with Cachelib, this repository, and any necessary dependency.
The goal of the Dockerfile is to generate a self-contained container image where Cachelib can be successfully built and experimented with. 

## Dockerfile-cachelib-ubuntu-jammy
This Dockerfile generates an Ubuntu 22.04 image with nvme-cli, this repository, and Samsung's private Cachelib fork (https://github.sec.samsung.net/DS8-MemoryOpenSource/Cachelib).
**All repositories are cloned under the /**.

### Building the image
1. To build the image, you need to make sure Docker Buildkit is used using:
```
export DOCKER_BUILDKIT=1
```

2. You need to have an ssh-agent running with the appropriate ssh keys loaded to access Samsung's github using:
```
eval `ssh-agent -s` && ssh-add
```
Note that the above command would load ~/.ssh/id_rsa, ~/.ssh/id_dsa, and ~/.ssh/identity files. You can provide an argument for the private key to use to ssh-add.

3. Now you can go ahead and build the image from the directory containing this README using:
```
docker build --ssh default -t cachelib -f Dockerfile-cachelib-ubuntu-jammy .
```
The above commands builds an image called **cachelib** with all the repositories and their dependencies cloned under the root file system.
During the image building step, nvme-cli is built and installed in the root system path. Cachelib and its submodules are cloned and all system level packages necessary to build it are installed.
You will have to build Cachelib yourself, see the Cachelib README file for how to do it.

### Running the image
You can run the image container now in privileged mode which gives you the same capabilities in the container as on the host using:
```
docker run -it --privileged cachelib
```
The above command runs a container from the image that was created and runs a shell on it interactively.
Note that while running the container you can use other docker run specific options.
