# cognitiveos-distro

CognitiveOS distribution image builder — produces bootable Alpine Linux based OS images for x86_64 and ARM64 (Raspberry Pi). Handles custom Alpine Linux ISO generation, Go binary compilation (cpm, cognitiveosd, cli, inference, core-mcp-bridges), overlay assembly, and image signing.

## Prerequisites

- Alpine Linux / Linux host with `apk` and `alpine-conf` (for `mkimage`)
- Docker (for cross-architecture builds)
- Go 1.23+ (at `/tmp/go/bin/go`)
- Git

## Quick start

```sh
# Install mkimage
apk add alpine-conf

# Build x86_64 ISO
make iso

# Build Raspberry Pi image
make rpi
```

## Build structure

```
├── overlay/              # Files baked into root filesystem
│   └── etc/
│       ├── inittab       # Boot into cognitiveos-cli
│       ├── hostname
│       └── cognitiveos/  # Config files (config.toml, registries.toml)
├── packages.*            # Alpine package lists per architecture
├── scripts/
│   ├── build-binaries.sh # Compile all Go projects
│   ├── build-overlay.sh  # Assemble overlay from built binaries
│   ├── build-iso.sh      # Run mkimage for x86_64
│   ├── build-rpi.sh      # Run mkimage for aarch64
│   └── sign.sh           # Checksums and GPG signatures
├── docker/
│   └── Dockerfile.build  # Multi-stage Docker build environment
└── Makefile              # Top-level automation
```

## Development mode

```sh
# Build all Go binaries from local repos and prepare overlay
make install-local
```

Output from `make iso` / `make rpi` goes to `output/`. Run `make clean` to remove build artifacts.
