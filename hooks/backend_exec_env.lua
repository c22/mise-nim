--- Sets up environment for nim + nimble
--- Adds install_path/bin to PATH so both `nim` and `nimble` are available.
--- On macOS ARM, sets DYLD_LIBRARY_PATH if needed (mirrors mise-nim exec-env).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv
--- @param ctx {install_path: string, tool: string, version: string} Context
--- @return {env_vars: table[]}
function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path
    local file = require("file")
    local bin_path = file.join_path(install_path, "bin")

    local env_vars = {
        { key = "PATH", value = bin_path },
    }

    -- macOS ARM64: set library path so Nim can find system libs at runtime
    if RUNTIME.osType == "Darwin" and RUNTIME.archType == "aarch64" then
        table.insert(env_vars, { key = "DYLD_LIBRARY_PATH", value = bin_path })
    end

    return { env_vars = env_vars }
end
