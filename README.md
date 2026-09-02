# mise-nim

A [mise](https://mise.jdx.dev) backend plugin for the Nim toolchain.

Installs **both** `nim` and `nimble` binaries. Supports prebuilt official binaries
(Windows/Linux x86/x64) and source builds (all platforms via `MISE_NIM_COMPILE=true`).

---

## Motivation

A `nim` core plugin was proposed in
[jdx/mise#12622](https://github.com/jdx/mise/pull/12622) (`feat/nim-core`).
Not merged into core; this plugin carries the same capabilities (checksums, both
binaries, source build, pre-release filtering) to the community plugin path.

Plan: submit to [`mise-plugins/`](https://github.com/mise-plugins/) once the
plugin is stable and the few remaining backend API gaps are addressed upstream.

---

## Features

- **Prebuilt binary downloads** for Windows and Linux x86/x64 from
  [nim-lang.org](https://nim-lang.org/download)
- **Source build** on any platform via `MISE_NIM_COMPILE=true`
- **SHA-256 checksum verification** via `.sha256` sidecar
- **Both binaries verified** post-install (`nim --version` + `nimble --version`)
- **Pre-release filter**: only stable semver (`2.2.0`) accepted; `2.2.0-rc1`
  and `devel` are excluded
- **macOS ARM64 / Windows ARM64** via source build

---

## Usage

```bash
mise plugin add c22/mise-nim https://github.com/c22/mise-nim.git
mise install nim@2.2.0
mise use nim@2.2.0
```

Verify both binaries:

```bash
nim --version
nimble --version
```

### Force source build

Any platform, or when no prebuilt exists for your architecture:

```bash
MISE_NIM_COMPILE=true mise install nim@2.2.0
```

---

## Comparison

| Feature | `mise-nim` (this) | [`mise-nim` (mise-plugins)](https://github.com/mise-plugins/mise-nim) |
| :--- | :--- | :--- |
| Checksum verification | ✅ | ❌ |
| Source build option (`MISE_NIM_COMPILE`) | ✅ | ❌ |
| Both binaries (`nim` + `nimble`) verified | ✅ | ❌ |
| Pre-release exclusion (no `-rc1`) | ✅ | ❌ (no documented filter) |
| Prebuilt + source 3-tier download | ✅ | ✅ (official → nightly → git) |
| `mise plugin link` / modern backend | ✅ | ✅ (bash plugin) |
| Lockfile build-method recording | ❌ (plugin gap) | ❌ |

---

## Plugin API gaps

The mise backend plugin API does not yet expose `BackendResolveLockInfo`,
settings registration, or `SecurityFeature`. This plugin documents those gaps with
`TODO(upstream)` markers in the source and works around them via env vars.
