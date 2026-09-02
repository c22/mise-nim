-- metadata.lua
-- Backend plugin metadata and configuration
-- Author: c22

PLUGIN = { -- luacheck: ignore
    name = "nim",
    version = "1.0.0",
    description = "Nim toolchain plugin (nim + nimble) with checksum, source build, and MISE_NIM_COMPILE",
    author = "c22",
    homepage = "https://github.com/c22/mise-nim",
    license = "MIT",
    notes = {
        "Supports both nim and nimble binaries",
        "Use MISE_NIM_COMPILE=true to force source build (any platform)",
        "Checksum verification via .sha256 sidecar from nim-lang.org",
        "Lockfile build-method recording is NOT available in plugin API (see TODO upstream)",
        "Settings schema (nim.compile) is NOT available in plugin API; use env only",
    },
}
