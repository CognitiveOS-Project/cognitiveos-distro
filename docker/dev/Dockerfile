ARG CGO_ENABLED=0
FROM golang:1.25-alpine AS builder
ARG CGO_ENABLED
ENV CGO_ENABLED=${CGO_ENABLED}
RUN sed -i 's/#http/http/g' /etc/apk/repositories && apk update
RUN apk add --no-cache git ca-certificates cmake build-base make
WORKDIR /src
COPY . .
RUN make docker.build

FROM alpine:edge
COPY scripts/bootstrap-docker-release.sh /usr/local/bin/
COPY scripts/docker-init.sh /usr/local/bin/
COPY packages.standard-x86_64 /tmp/packages
RUN bootstrap-docker-release.sh /tmp/packages
RUN chmod +x /usr/local/bin/docker-init.sh
COPY --from=builder /src/build/out/ /
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/docker-init.sh"]
