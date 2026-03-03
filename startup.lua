local TYPE = "Miner"

local GITHUB_USER = "n3rbi"
local GITHUB_REPO = "CC-McUtils"
local GITHUB_BRANCH = "main"
local FOLDER = "MiningTurtles/" .. TYPE

local API_URL = "https://api.github.com/repos/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/contents/" .. FOLDER .. "?ref=" .. GITHUB_BRANCH
local RAW_BASE = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH .. "/" .. FOLDER .. "/"

local MAX_RETRIES = 5
local RETRY_DELAY = 30

local function downloadFiles()
    print("Fetching file list from GitHub...")
    local response = http.get(API_URL, { ["User-Agent"] = "CC-Tweaked" })
    if not response then
        return false, "Failed to reach GitHub API"
    end

    local raw = response.readAll()
    response.close()

    local files = {}
    for name in raw:gmatch('"name"%s*:%s*"([^"]+)"') do
        if name:sub(-4) == ".lua" then
            table.insert(files, name)
        end
    end

    if #files == 0 then
        return false, "No lua files found in " .. FOLDER
    end

    print("Found " .. #files .. " file(s). Downloading...")

    for _, filename in ipairs(files) do
        local url = RAW_BASE .. filename
        print("Downloading " .. filename .. "...")
        local response = http.get(url)
        if not response then
            return false, "Failed to download " .. filename
        end
        local content = response.readAll()
        response.close()

        local new_file = fs.open(filename, "w")
        if not new_file then
            return false, "Could not open file for writing: " .. filename
        end
        new_file.write(content)
        new_file.close()
    end

    return true
end

local success, err
for attempt = 1, MAX_RETRIES do
    print("Attempt " .. attempt .. " of " .. MAX_RETRIES .. "...")
    success, err = downloadFiles()
    if success then
        print("Download complete! Starting " .. TYPE .. "...")
        break
    end
    print("Error: " .. (err or "unknown"))
    if attempt < MAX_RETRIES then
        print("Retrying in " .. RETRY_DELAY .. " seconds...")
        sleep(RETRY_DELAY)
    end
end

if not success then
    printError("----------------------------------")
    printError("FAILED after " .. MAX_RETRIES .. " attempts.")
    printError("Last error: " .. (err or "unknown"))
    printError("Check your connection or GitHub repo.")
    printError("----------------------------------")
    return
end

shell.run("main.lua")