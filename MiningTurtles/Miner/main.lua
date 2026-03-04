local comms = require("comms")

print("Miner #" .. os.getComputerID() .. " booting...")

local connected = false
local RETRY_DELAY = 10
local MAX_RETRIES = 5

for i = 1, MAX_RETRIES do
    print("Attempt " .. i .. " of " .. MAX_RETRIES .. "...")
    connected = comms.init()
    if connected then break end
    if i < MAX_RETRIES then
        print("Retrying in " .. RETRY_DELAY .. " seconds...")
        sleep(RETRY_DELAY)
    end
end

if not connected then
    printError("Could not find a dock after " .. MAX_RETRIES .. " attempts.")
    return
end

print("Connected to dock #" .. comms.getDockId() .. ". Status: Idle.")

while true do
    comms.listen()
end