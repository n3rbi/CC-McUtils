local comms = {}

local PROTOCOL = "mining_turtles"
local state = nil

local function openModem()
    local modem = peripheral.find("modem")
    if not modem then
        print("Error: No modem found.")
        return false
    end
    rednet.open(peripheral.getName(modem))
    return true
end

local function send(id, msg)
    rednet.send(id, msg, PROTOCOL)
end

local function register()
    local x, y, z = gps.locate()
    rednet.broadcast({
        type = "MINER_REGISTER",
        id   = os.getComputerID(),
        pos  = { x = x, y = y, z = z },
        fuel = turtle.getFuelLevel()
    }, PROTOCOL)
    print("Broadcast MINER_REGISTER.")
end

local function handleMessage(sender, msg)
    if msg.type == "PAIR_DOCK" then
        state.dock_id  = msg.dock_id
        state.dock_pos = msg.dock_pos
        print("Paired with dock #" .. msg.dock_id)

    elseif msg.type == "DOCK_LOST" then
        print("Dock #" .. msg.dock_id .. " went offline, notifying controller...")
        state.dock_id  = nil
        state.dock_pos = nil
        if state.controller_id then
            send(state.controller_id, {
                type = "MINER_LOST_DOCK",
                id   = os.getComputerID()
            }, PROTOCOL)
        end

    elseif msg.type == "PING" then
        local x, y, z = gps.locate()
        send(sender, {
            type   = "PONG",
            id     = os.getComputerID(),
            status = state.status,
            pos    = { x = x, y = y, z = z },
            fuel   = turtle.getFuelLevel()
        })

    elseif msg.type == "DOCK" then
        print("Received DOCK command from dock #" .. sender)

    elseif msg.type == "CONTROLLER_AVAILABLE" then
        if not state.controller_id then
            state.controller_id = sender
            print("Found controller #" .. sender)
        end
    end
end

function comms.init(s)
    state = s
    if not openModem() then return false end
    register()
    return true
end

function comms.handleMessage(sender, msg)
    handleMessage(sender, msg)
end

return comms