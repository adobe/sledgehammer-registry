#!/usr/bin/env bash

# Copyright 2018 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe.

echo "Using version ${VERSION}"

ASSET_URL="https://github.com/Chumper/alpine-json/releases/download/${VERSION}/alpine-json_${VERSION}_Linux_x86_64"

mkdir -p ./assets

curl -sL -H "Accept: application/octet-stream" \
         -o assets/linux-amd64-alpine-json \
         "${ASSET_URL}"
chmod +x assets/linux-amd64-alpine-json

