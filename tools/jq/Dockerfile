FROM alpine
LABEL maintainer="plaschke@adobe.com"

ARG VERSION

RUN apk add jq~=${VERSION} --no-cache

ENTRYPOINT ["jq"]