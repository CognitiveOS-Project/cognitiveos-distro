# cognitiveos-alpine-distro

CognitiveOS distribution image builder — produces bootable Alpine Linux based OS images for x86_64 and ARM64 (Raspberry Pi). Handles custom Alpine Linux ISO generation, Go binary compilation (cpm, cognitiveosd, cli, inference, core-mcp-bridges), overlay assembly, and image signing.

## Prerequisites

- Alpine Linux / Linux host with `apk` and `alpine-conf` (for `mkimage`)
- Docker (for cross-architecture builds)
- Go 1.24+
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
│   ├── build-binaries.sh # Orchestrate per-repo builds (make build)
│   ├── build-overlay.sh  # Assemble overlay from built binaries
│   ├── build-image.sh    # Run mkimage for any profile (--profile x86_64|aarch64)
│   └── sign.sh           # Checksums and GPG signatures
├── docker/
│   ├── Dockerfile.build  # Multi-stage Docker build environment
│   └── Dockerfile.release # Minimal runtime image
└── Makefile              # Top-level automation
```

## Development mode

```sh
# Build all Go binaries from sibling repos and prepare overlay
make install-local
```

Output from `make iso` / `make rpi` goes to `output/`. Run `make clean` to remove build artifacts.

Each Go component builds independently via its own Makefile:
- `cpm` — `make build` to `build/bin/cpm`
- `cognitiveosd` — `make build` to `build/bin/cognitiveosd`
- `cli` — `make build` to `build/bin/cognitiveos-cli`
- `inference` — `make build` to `build/bin/cognitiveos-inference` and `build/bin/cograw`
- `core-mcp-bridges` — `make build` to `build/bin/` (audio, display, gpio, network, serial, package)

## Related

- [CognitiveOS](https://github.com/CognitiveOS-Project/cognitiveos) — main project repository
- [cognitive-os.org](https://cognitive-os.org) — project website
- [cognitiveosd](https://github.com/CognitiveOS-Project/cognitiveosd) — system daemon included in the distro
- [cli](https://github.com/CognitiveOS-Project/cli) — TUI included in the distro
- [inference](https://github.com/CognitiveOS-Project/inference) — inference engine included in the distro
- [core-mcp-bridges](https://github.com/CognitiveOS-Project/core-mcp-bridges) — MCP bridges included in the distro
- [coginit](https://github.com/CognitiveOS-Project/coginit) — boot manager included in the distro
- [Product Specs](https://github.com/CognitiveOS-Project/product-specs) — distro build specification
- [CognitiveOS Project](https://github.com/CognitiveOS-Project) — GitHub organization

## Contributing

1. Branch from `main`
2. Use topic branches: `feature/<name>`, `fix/<name>`
3. Open a PR to `main` with a clear title and description
4. Merge after review

See the [SDLC repo](https://github.com/CognitiveOS-Project/sdlc) for the full contribution guide, code review standards, and testing strategy.

## Author

**Jean Machuca** — [GitHub](https://github.com/jeanmachuca) · [Sponsor](https://github.com/sponsors/jeanmachuca)
