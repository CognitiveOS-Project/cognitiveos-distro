# CognitiveOS Distribution

Build scripts and configurations for producing a bootable CognitiveOS image based on Alpine Linux.

## Build Output

- Bootable ISO image for x86_64
- Raspberry Pi image (aarch64)
- Bootable ARM image (armv7)

## Structure

- `overlay/` — files baked into the root filesystem:
  - `/etc/inittab` — boots directly into `cognitiveos-cli`
  - `/etc/cognitiveos/` — config.toml, registries.toml
- `packages.*` — Alpine package lists per architecture
- `scripts/` — build automation (binaries, overlay, ISO, RPi, signing)
- `docker/Dockerfile.build` — multi-stage cross-compilation
- `Makefile` — targets: all, iso, rpi, clean, distclean, docker, shell, checksums, sign, install-local, deps

## Build Dependencies

- alpine-conf (mkimage)
- Docker for cross-architecture builds
- Go 1.23+ at /tmp/go/bin/go
- CognitiveOS Go repos (cpm, cognitiveosd, cli, inference, core-mcp-bridges)

## Targets

- `make iso` — build x86_64 ISO
- `make rpi` — build aarch64 RPi image
- `make install-local` — compile Go binaries + assemble overlay locally
- `make docker` — build Docker builder image
- `make sign` — generate checksums + GPG signature
