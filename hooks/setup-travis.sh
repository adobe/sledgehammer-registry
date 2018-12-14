#!/usr/bin/env bash

set -o errexit

main() {
  install_sledgehammer

  echo "INFO:
  Done! Finished setting up Travis-CI machine.
  "
}

# Installs Sledgehammer to have access to build tools
install_sledgehammer() {
  echo "
  INFO: Installing Sledgehammer...
"
  mkdir -p $(pwd)/bin
  docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/bin:/data adobe/slh
}

main