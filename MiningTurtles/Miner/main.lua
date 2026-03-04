local comms = require("comms")
local nav   = require("nav")

local PROTOCOL        = "mining_turtles"
local RETRY_DELAY     = 10
local MAX_RETRIES     = 5
local CONTROLLER_PING = 30

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

local controller_timer = os.startTimer(CONTROLLER_PING)

while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "rednet_message" and p3 == PROTOCOL then
        comms.handleMessage(p1, p2)

        if state.dock_pos and state.status == "Idle" then
            print("Navigating to dock...")
            state.status = "Navigating to Dock"
            local success = nav.goto(state.dock_pos.x, state.dock_pos.y, state.dock_pos.z)
            if success then
                print("Docked successfully.")
                state.status = "Docked"
            else
                printError("Failed to reach dock.")
            end
        end

    elseif ev == "timer" and p1 == controller_timer then
        if not state.controller_id then
            print("No controller found, searching...")
            local found = false
            while not found do
                found = comms.findController()
                if not found then
                    print("Retrying in " .. RETRY_DELAY .. " seconds...")
                    sleep(RETRY_DELAY)
                end
            end
            print("Controller found, resuming.")
        else
            controller_timer = os.startTimer(CONTROLLER_PING)
        end
    end
end