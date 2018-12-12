#!/usr/bin/env bash
VERSION=$(sed -e 's;-[^-]*$;;' < ./VERSION)

echo "Using version ${VERSION}"

ASSET_URL="https://github.com/Chumper/alpine-json/releases/download/${VERSION}/alpine-json_${VERSION}_Linux_x86_64"

mkdir -p ./assets

curl -sL -H "Accept: application/octet-stream" \
         -o assets/linux-amd64-alpine-json \
         "${ASSET_URL}"
chmod +x assets/linux-amd64-alpine-json

