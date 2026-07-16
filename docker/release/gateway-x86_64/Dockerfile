ARG CGO_ENABLED=1
FROM golang:1.26-alpine AS builder
ARG CGO_ENABLED
ENV CGO_ENABLED=${CGO_ENABLED}
ENV DOWNLOAD_MODELS=1
RUN sed -i 's/#http/http/g' /etc/apk/repositories && apk update
RUN apk add --no-cache git ca-certificates cmake build-base make
WORKDIR /src
COPY . .
RUN make docker.build

FROM alpine:edge
COPY scripts/bootstrap-docker-release.sh /usr/local/bin/
COPY packages.gateway-x86_64 /tmp/packages
RUN bootstrap-docker-release.sh /tmp/packages
COPY --from=builder /src/build/out/ /
ENTRYPOINT ["/usr/local/bin/coginit"]
