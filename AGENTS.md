# CognitiveOS Distribution

Build scripts and configurations for producing a bootable CognitiveOS image based on Alpine Linux.

## Build Output

- Bootable ISO image for x86_64 and arm64
- Raspberry Pi image (arm64)
- QEMU test image

## Structure

- `alpine/` — Alpine Linux mkimage config and overlays
- `overlay/` — files baked into the root filesystem:
  - `/etc/inittab` — modified to boot directly into `cognitiveos-cli`
  - `/cognitiveos/` — base OS directory tree
  - `/etc/apk/` — package repositories
- `scripts/` — build automation
- `Dockerfile` — cross-compilation environment

## Build Dependencies

- alpine-conf (mkimage)
- Docker for cross-architecture builds
- All other CognitiveOS binaries pre-compiled and injected into overlay
