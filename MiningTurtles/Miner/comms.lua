local comms = {}

local PROTOCOL = "mining_turtles"
local state    = nil

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

local function findController()
    print("Searching for controller...")
    local x, y, z     = gps.locate()
    local closest_id   = nil
    local closest_dist = math.huge
    local timer        = os.startTimer(5)

    rednet.broadcast({
        type = "MINER_REGISTER",
        id   = os.getComputerID(),
        pos  = { x = x, y = y, z = z },
        fuel = turtle.getFuelLevel()
    }, PROTOCOL)

    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "rednet_message" and p3 == PROTOCOL then
            if p2.type == "CONTROLLER_AVAILABLE" then
                local cp   = p2.pos
                local dist = math.sqrt((cp.x-x)^2 + (cp.y-y)^2 + (cp.z-z)^2)
                if dist < closest_dist then
                    closest_dist = dist
                    closest_id   = p1
                    state.controller_id = p1
                end
            end
        elseif ev == "timer" and p1 == timer then
            break
        end
    end

    return closest_id ~= nil
end

local function handleMessage(sender, msg)
    if msg.type == "PAIR_DOCK" then
        local offsets = {
            north = { x = -1, z = 0  },
            south = { x = 1,  z = 0  },
            east  = { x = 0,  z = 1  },
            west  = { x = 0,  z = -1 },
        }
        local off = offsets[msg.facing] or { x = 0, z = 0 }
        state.dock_id  = msg.dock_id
        state.dock_pos = {
            x = msg.dock_pos.x + off.x,
            y = msg.dock_pos.y,
            z = msg.dock_pos.z + off.z
        }
        print("Paired with dock #" .. msg.dock_id)

    elseif msg.type == "DOCK_LOST" then
        print("Dock #" .. msg.dock_id .. " went offline, notifying controller...")
        state.dock_id  = nil
        state.dock_pos = nil
        if state.controller_id then
            send(state.controller_id, {
                type = "MINER_LOST_DOCK",
                id   = os.getComputerID()
            })
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

function comms.findController()
    return findController()
end

function comms.handleMessage(sender, msg)
    handleMessage(sender, msg)
end

return comms