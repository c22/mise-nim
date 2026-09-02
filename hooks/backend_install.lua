--- Installs a specific nim version (prebuilt binary or source)
--- TODO(upstream): requires BackendResolveLockInfo hook in mise vfox crate
--- so locked installs reproduce MISE_NIM_COMPILE build-method marks.
--- Workaround: read MISE_NIM_COMPILE env directly; build method is NOT
--- recorded in lockfile (plugin has no PlatformInfo access).
--- TODO(upstream): requires setting-registration hook or plugin-declared
--- settings so nim.compile appears in settings.toml / schema/mise.json.
--- Workaround: use MISE_NIM_COMPILE env only.
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall
--- @param ctx {tool: string, version: string, install_path: string} Context
--- @return table
function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end

    local cmd = require("cmd")
    local http = require("http")
    local file = require("file")

    -- Ensure parent directory exists
    local parent = file.dirname(install_path)
    cmd.exec("mkdir -p \"" .. parent .. "\"")

    -- Decide: source build if MISE_NIM_COMPILE=true, else try prebuilt
    local compile = os.getenv("MISE_NIM_COMPILE")
    local force_source = compile == "true" or compile == "1"

    if force_source then
        install_from_source(ctx, cmd, http, file, install_path, version)
    else
        local ok, err = install_prebuilt(ctx, cmd, http, file, install_path, version)
        if not ok then
            install_from_source(ctx, cmd, http, file, install_path, version)
        end
    end

    -- Verify both binaries
    local nim_bin = file.join_path(install_path, "bin", "nim")
    local nimble_bin = file.join_path(install_path, "bin", "nimble")
    if RUNTIME.osType == "Windows" then
        nim_bin = nim_bin .. ".exe"
        nimble_bin = nimble_bin .. ".exe"
    end

    local nim_ver = cmd.exec("\"" .. nim_bin .. "\" --version")
    if not nim_ver or nim_ver == "" then
        error("nim --version failed after install")
    end
    local nimble_ver = cmd.exec("\"" .. nimble_bin .. "\" --version")
    if not nimble_ver or nimble_ver == "" then
        error("nimble --version failed after install")
    end

    return {}
end

--- Installs nim from official prebuilt binary (nim-lang.org).
--- Returns (true) on success, or (false, errmsg) if no prebuilt exists for this platform.
local function install_prebuilt(ctx, cmd, http, file, install_path, version)
    local os_type = RUNTIME.osType
    local arch = RUNTIME.archType

    local url = prebuilt_url(version, os_type, arch)
    if not url then
        return false, "no prebuilt for this platform"
    end

    local filename = url:match("([^/]+)$")
    if not filename then
        return false, "could not parse filename from URL"
    end

    -- Download tarball
    local download_path = install_path .. "/" .. filename
    local download_dir = file.dirname(download_path)
    cmd.exec("mkdir -p \"" .. download_dir .. "\"")

    http.download({ url = url, output = download_path })

    -- Fetch checksum from .sha256 sidecar
    local checksum_url = url .. ".sha256"
    local checksum_resp = http.get({ url = checksum_url })
    if not checksum_resp or checksum_resp.status_code ~= 200 then
        error("Failed to fetch checksum: " .. (checksum_resp and checksum_resp.status_code or "nil"))
    end
    local checksum = checksum_resp.body:match("^[a-fA-F0-9]+")
    if not checksum then
        error("Could not parse sha256 from: " .. checksum_resp.body)
    end
    checksum = checksum:lower()

    -- Verify checksum
    local calc = file.sha256(download_path)
    if calc ~= checksum then
        error("Checksum mismatch for " .. filename .. ": expected " .. checksum .. ", got " .. calc)
    end

    -- Extract
    local tmp_dir = download_dir .. "/_tmp_nim"
    cmd.exec("mkdir -p \"" .. tmp_dir .. "\"")

    if os_type == "Windows" then
        cmd.exec("tar -xJf \"" .. download_path .. "\" -C \"" .. tmp_dir .. "\"")
    else
        -- tar.xz on Unix; fallback to tar with auto detection
        cmd.exec("tar -xf \"" .. download_path .. "\" -C \"" .. tmp_dir .. "\"")
    end

    -- Rename top-level nim-<version> (or nim-<version>-linux_x64) dir to install_path
    local entries = file.list_dir(tmp_dir)
    local top_dir = nil
    for _, entry in ipairs(entries) do
        if entry:match("^nim%-[^/]+$") or entry:match("^nim%-[^/]+%-linux_[^/]+$") then
            top_dir = entry
            break
        end
    end
    if not top_dir then
        error("Could not find top-level nim directory in archive")
    end

    -- Copy bin contents to install_path
    local install_bin = install_path .. "/bin"
    local src_bin = tmp_dir .. "/" .. top_dir .. "/bin"
    cmd.exec("cp -r \"" .. src_bin .. "/.\" \"" .. install_bin .. "/\"")

    -- Make executable on Unix
    if os_type ~= "Windows" then
        cmd.exec("chmod +x \"" .. install_bin .. "/nim\"")
        cmd.exec("chmod +x \"" .. install_bin .. "/nimble\"")
    end

    -- Clean up
    cmd.exec("rm -rf \"" .. tmp_dir .. "\"")
    cmd.exec("rm -f \"" .. download_path .. "\"")

    return true
end

--- Builds nim from source (recursive git clone + build_all.sh/.bat).
--- Requires git and a C compiler on PATH.
local function install_from_source(ctx, cmd, http, file, install_path, version)
    local os_type = RUNTIME.osType

    -- Clone into a temp directory
    local tmp_base = file.dirname(install_path) .. "/_nim_src"
    cmd.exec("mkdir -p \"" .. tmp_base .. "\"")
    local src_dir = tmp_base .. "/Nim-" .. version

    -- Remove existing if present
    cmd.exec("rm -rf \"" .. src_dir .. "\"")

    -- Recursive clone: GitHub tarball excludes nimble submodule, so git clone is required
    cmd.exec("git clone --depth 1 --branch v" .. version .. " --recursive https://github.com/nim-lang/Nim \"" .. src_dir .. "\"")

    -- Build
    if os_type == "Windows" then
        cmd.exec("\"" .. src_dir .. "\\build_all.bat\"", { cwd = src_dir })
    else
        cmd.exec("bash \"" .. src_dir .. "/build_all.sh\"", { cwd = src_dir })
    end

    -- After build, the Nim source dir itself IS the install (build_all.sh moves things around)
    -- Copy bin to install_path
    local install_bin = install_path .. "/bin"
    cmd.exec("mkdir -p \"" .. install_bin .. "\"")
    cmd.exec("mkdir -p \"" .. install_path .. "/lib\"")
    cmd.exec("mkdir -p \"" .. install_path .. "/config\"")
    cmd.exec("cp -r \"" .. src_dir .. "/bin/.\" \"" .. install_bin .. "/\"")
    cmd.exec("cp -r \"" .. src_dir .. "/lib/.\" \"" .. install_path .. "/lib/\"")
    cmd.exec("cp -r \"" .. src_dir .. "/config/.\" \"" .. install_path .. "/config/\"")

    -- Make executable on Unix
    if os_type ~= "Windows" then
        cmd.exec("chmod +x \"" .. install_bin .. "/nim\"")
        cmd.exec("chmod +x \"" .. install_bin .. "/nimble\"")
    end

    -- Clean up source
    cmd.exec("rm -rf \"" .. src_dir .. "\"")
end

--- Returns the prebuilt download URL for a platform, or nil if no prebuilt exists.
--- Mirrors nim.rs prebuilt_url(): Windows/Linux x86/x64 only.
local function prebuilt_url(version, os_type, arch)
    local arch_key
    if arch == "x64" then
        arch_key = "x64"
    elseif arch == "x32" or arch == "i686" or arch == "i386" then
        arch_key = "x32"
    else
        return nil
    end

    if os_type == "Linux" then
        return "https://nim-lang.org/download/nim-" .. version .. "-linux_" .. arch_key .. ".tar.xz"
    elseif os_type == "Windows" then
        return "https://nim-lang.org/download/nim-" .. version .. "_" .. arch_key .. ".zip"
    else
        return nil
    end
end