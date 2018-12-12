FROM alpine
LABEL maintainer="plaschke@adobe.com"

COPY ./assets/linux-amd64-alpine-json /usr/local/bin/alpine-json

RUN apk add ca-certificates --no-cache

ENTRYPOINT ["/usr/local/bin/alpine-json"]