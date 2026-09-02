--- Lists available nim versions from nim-lang/Nim tags
--- TODO(upstream): requires BackendResolveLockInfo hook in mise vfox crate
--- so locked installs reproduce MISE_NIM_COMPILE build-method marks.
--- Workaround: read MISE_NIM_COMPILE env directly; build method is NOT
--- recorded in lockfile (plugin has no PlatformInfo access).
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions
--- @param ctx {tool: string} Context
--- @return {versions: string[]}
function PLUGIN:BackendListVersions(ctx)
    local cmd = require("cmd")
    -- Fast path: git ls-remote --tags --refs nim-lang/Nim v*
    local result = cmd.exec(
        "git ls-remote --tags --refs " ..
        "https://github.com/nim-lang/Nim v*"
    )
    if not result or result == "" then
        error("Failed to list nim versions from nim-lang/Nim")
    end

    local versions = {}
    for line in result:gmatch("(.-)\n") do
        -- Extract tag like refs/tags/v2.2.0
        local tag_ref = line:match("^refs/tags/v(.+)")
        if tag_ref then
            -- Strip any trailing ^{} annotation
            local clean = tag_ref:gsub("%^{.*}$", "")
            -- Filter semver: ^[0-9]+\.[0-9]+\.[0-9]+$; exclude pre-releases
            if clean:match("^[0-9]+%.[0-9]+%.[0-9]+$") then
                table.insert(versions, clean)
            end
        end
    end

    -- Deduplicate and sort
    local seen = {}
    local unique = {}
    for _, v in ipairs(versions) do
        if not seen[v] then
            seen[v] = true
            table.insert(unique, v)
        end
    end
    table.sort(unique)

    if #unique == 0 then
        error("No valid nim versions found")
    end

    return { versions = unique }
end
