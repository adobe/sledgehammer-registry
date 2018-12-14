FROM alpine
LABEL maintainer="plaschke@adobe.com"

ARG VERSION

RUN apk add ca-certificates git~=${VERSION} --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/main

ENTRYPOINT ["git"]