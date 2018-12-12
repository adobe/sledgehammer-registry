#!/usr/bin/env bash

ASSET_URL="https://github.com/Chumper/alpine-json/releases/download/${VERSION}/alpine-json_${VERSION}_Linux_x86_64"

curl -sL -H "Accept: application/octet-stream" \
         -o assets/linux-amd64-alpine-json \
         "${ASSET_URL}"
chmod +x assets/linux-amd64-alpine-json

