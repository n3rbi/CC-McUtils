local comms = require("comms")

local PROTOCOL = "mining_turtles"
local RETRY_DELAY = 10
local MAX_RETRIES = 5

local state = {
    id            = os.getComputerID(),
    status        = "Idle",
    dock_id       = nil,
    dock_pos      = nil,
    controller_id = nil,
}

print("Miner #" .. state.id .. " booting...")

local ok = false
for i = 1, MAX_RETRIES do
    print("Attempt " .. i .. " of " .. MAX_RETRIES .. "...")
    ok = comms.init(state)
    if ok then break end
    if i < MAX_RETRIES then
        print("Retrying in " .. RETRY_DELAY .. " seconds...")
        sleep(RETRY_DELAY)
    end
end

if not ok then
    printError("Failed to initialise after " .. MAX_RETRIES .. " attempts.")
    return
end

print("Registered. Waiting for pairing...")

while true do
    local ev, p1, p2, p3 = os.pullEvent("rednet_message")
    if p3 == PROTOCOL then
        comms.handleMessage(p1, p2)
    end
end