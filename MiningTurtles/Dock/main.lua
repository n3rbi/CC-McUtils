local comms   = require("comms")

local FACING        = "north"
local PING_INTERVAL = 15
local PROTOCOL      = "mining_turtles"

local state = {
    block_id      = os.getComputerID(),
    facing        = FACING,
    miner_id      = nil,
    miner_type    = nil,
    miner_status  = "Unknown",
    miner_fuel    = nil,
    curr_job_id   = nil,
    job_queue     = {},
    controller_id = nil,
    controller_pos= nil,
}

local monitor = peripheral.find("monitor")

local function drawMonitor()
    if not monitor then return end
    monitor.setTextScale(1)
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    local w, h = monitor.getSize()

    local function writeLine(row, text, col)
        monitor.setCursorPos(1, row)
        monitor.setTextColor(col or colors.white)
        monitor.write(text:sub(1, w))
    end

    writeLine(1, "Dock #" .. state.block_id, colors.yellow)
    writeLine(2, string.rep("-", w), colors.gray)
    writeLine(3, "Facing:  " .. state.facing, colors.white)
    writeLine(4, "Miner:   " .. (state.miner_id and "#" .. state.miner_id or "None"), colors.white)
    writeLine(5, "Type:    " .. (state.miner_type or "Unknown"), colors.white)
    writeLine(6, "Status:  " .. (state.miner_status or "Unknown"), colors.lime)
    writeLine(7, "Fuel:    " .. (state.miner_fuel and tostring(state.miner_fuel) or "?"), colors.white)
    writeLine(8, "Job:     " .. (state.curr_job_id and tostring(state.curr_job_id) or "None"), colors.white)
    writeLine(9, "Queue:   " .. #state.job_queue, colors.white)
    writeLine(10, string.rep("-", w), colors.gray)
    writeLine(11, "Ctrl:    " .. (state.controller_id and "#" .. state.controller_id or "None"), colors.gray)
end

print("Dock #" .. state.block_id .. " booting...")
drawMonitor()

local connected = comms.init(state)
if not connected then
    print("Warning: No miner found on boot. Listening...")
end

drawMonitor()

local miner_timer      = os.startTimer(PING_INTERVAL)
local controller_timer = os.startTimer(PING_INTERVAL + 5)

while true do
    drawMonitor()

    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "rednet_message" and p3 == PROTOCOL then
        comms.handleMessage(p1, p2)

    elseif ev == "timer" then
        if p1 == miner_timer then
            comms.pingMiner()
            miner_timer = os.startTimer(PING_INTERVAL)
        elseif p1 == controller_timer then
            comms.pingController()
            controller_timer = os.startTimer(PING_INTERVAL + 5)
        end
    end
end