Default registry of Sledgehammer [![Build Status](https://travis-ci.com/adobe/sledgehammer-registry.svg)](https://travis-ci.com/adobe/sledgehammer-registry)
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
slh create registry git https://github.com/adobe/sledgehammer-registry.git --name default
```

##### Configuration

### Build & Run

To build this project, you need the following tools:
* Docker
* Make
* Bash
* git (*)
* modify-repository (*)
* shellcheck (*)
* alpine-version (*)

Sledgehammer offers the tools mentioned with `(*)` aboved in a development kit called `slh-dev`:

    slh install slh-dev --kit

Checkout a new branch, make you changes, commit them and to verify your changes just call

    make

### Contributing

Contributions are welcomed! Read the [Contributing Guide](CONTRIBUTING.md) for more information.

### Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.