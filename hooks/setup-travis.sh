#!/usr/bin/env bash

set -o errexit

main() {
  update_docker
  install_sledgehammer

  echo "INFO:
  Done! Finished setting up Travis-CI machine.
  "
}

# Updated docker to the latest version
update_docker() {
  echo "
  INFO:  Updating docker...
"

  sudo apt update -y
  sudo apt install --only-upgrade docker-ce -y

  docker info
}

# Installs Sledgehammer to have access to build tools
install_sledgehammer() {
  echo "
  INFO: Installing Sledgehammer...
"

  docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/bin:/data adobe/slh
}

main