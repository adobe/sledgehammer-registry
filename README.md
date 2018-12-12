Default registry of Sledgehammer [![Build Status](https://travis-ci.com/adobe/sledgehammer-registry.svg?token=7fDSSWxNwGMMnLrqaxnB&branch=master)](https://travis-ci.com/adobe/sledgehammer-registry)
======

### Introduction

`sledgehammer-registry` is the default registry that accompanies the [Sledgehammer](https://github.com/adobe/sledgehammer) executable.
All tools that are contained in the default registries are defined in the [index.json](index.json).
Additional all tools that do not provide a docker container by default are defined in the [tools](tools) folder.

#### Using with Sledgehammer

<aside class="notice">
The default registry already ships with Sledgehammer. So you only need to install it if you removed it.
</aside>

To register the default registry with Sledgehammer you can execute
```
slh create registry url https://raw.githubusercontent.com/adobe/sledgehammer-registry/master/index.json --name default
```

##### Configuration

### Build & Run

To build this project, you need Docker and Make as well as Sledgehammer and the `slh-dev` toolkit installed:

    slh install slh-dev --kit

This will install all needed tools (shellcheck) so that you can use it during the build

To verify your changes just call

    make

### Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

### Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.