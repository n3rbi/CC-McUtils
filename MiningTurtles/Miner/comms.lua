local comms = {}

local PROTOCOL = "mining_turtles"
local STATUS = "Idle"
local dock_id = nil
local dock_pos = nil

local function openModem()
    local modem = peripheral.find("modem")
    if not modem then
        print("Error: No modem found.")
        return false
    end
    rednet.open(peripheral.getName(modem))
    return true
end

local function findDock()
    print("Broadcasting for free dock...")
    local x, y, z = gps.locate()
    rednet.broadcast({
        type = "MINER_LOOKING",
        pos  = { x = x, y = y, z = z },
        id   = os.getComputerID()
    }, PROTOCOL)

    local closest_id = nil
    local closest_dist = math.huge
    local closest_pos = nil
    local timer = os.startTimer(5)

    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "rednet_message" and p3 == PROTOCOL then
            local msg = p2
            if msg.type == "DOCK_AVAILABLE" and msg.miner_id == nil then
                local dp = msg.pos
                print(dp)
                local dist = math.sqrt((dp.x-x)^2 + (dp.y-y)^2 + (dp.z-z)^2)
                if dist < closest_dist then
                    closest_dist = dist
                    closest_id = p1
                    closest_pos = dp
                end
            end
        elseif ev == "timer" and p1 == timer then
            break
        end
    end

    if closest_id then
        dock_id = closest_id
        dock_pos = closest_pos
        print("Found dock #" .. dock_id .. " at distance " .. math.floor(closest_dist))
        rednet.send(dock_id, {
            type   = "MINER_CLAIM",
            id     = os.getComputerID(),
            status = STATUS
        }, PROTOCOL)
        return true
    end

    print("No free dock found.")
    return false
end

local function handleMessage(sender, msg)
    if msg.type == "PING" then
        rednet.send(sender, {
            type   = "PONG",
            id     = os.getComputerID(),
            status = STATUS,
            pos    = { x = gps.locate() },
            fuel   = turtle.getFuelLevel()
        }, PROTOCOL)
    end
end

function comms.setStatus(s)
    STATUS = s
end

function comms.getDockPos()
    return dock_pos
end

function comms.getDockId()
    return dock_id
end

function comms.init()
    if not openModem() then return false end
    return findDock()
end

function comms.listen()
    local ev, p1, p2, p3 = os.pullEvent("rednet_message")
    if p3 == PROTOCOL then
        handleMessage(p1, p2)
    end
end

return comms