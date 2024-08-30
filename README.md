# cachelib-devops
This repository contains various helper tools written to ease development, experimentation, and reproducibility with Cachelib.
Although the contents of this repository can live within Cachelib, it has been created as a separate repository for the purpose of bootstrapping and ease of evolution. 
The repository is organized under three heads currently:
- benchmarking-tools: Contains helper scripts for executing worloads via cachebench and collect statistics. See the [documentation](benchmarking-tools/README.md) for more details.
- configs: Contains configuration files that can be provided as input to the scripts in benchmarking-tools.
- dockerfiles: Contains Docker build scripts to generate images containing Cachelib, this repository and any necessary dependency. See the [documentation](dockerfiles/README.md) for more details.

Please consider contributing to this repository if you have ideas for feature requests, issues, and patches.

