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

local function broadcast(msg)
    rednet.broadcast(msg, PROTOCOL)
end

local function send(id, msg)
    rednet.send(id, msg, PROTOCOL)
end

function comms.init(s)
    state = s
    if not openModem() then return false end
    local x, y, z = gps.locate()
    broadcast({
        type = "CONTROLLER_AVAILABLE",
        id   = os.getComputerID(),
        pos  = { x = x, y = y, z = z }
    })
    print("Controller broadcast sent.")
    return true
end

function comms.handleMessage(sender, msg, s, connections)
    state = s

    if msg.type == "DOCK_LOOKING" then
        local x, y, z = gps.locate()
        send(sender, {
            type = "CONTROLLER_AVAILABLE",
            id   = os.getComputerID(),
            pos  = { x = x, y = y, z = z }
        })
        state.docks[sender] = state.docks[sender] or {
            id           = sender,
            pos          = msg.pos,
            miner_id     = nil,
            miner_type   = nil,
            miner_status = "Waiting",
            queue_length = 0,
            curr_job_id  = nil,
        }
        print("Dock #" .. sender .. " registered.")
        connections.tryPair(state, send)

    elseif msg.type == "MINER_REGISTER" then
        state.miners[sender] = state.miners[sender] or {
            id      = sender,
            pos     = msg.pos,
            dock_id = nil,
            status  = "Idle",
            fuel    = msg.fuel,
        }
        print("Miner #" .. sender .. " registered.")
        connections.tryPair(state, send)

    elseif msg.type == "DOCK_REPORT" then
        local dock = state.docks[sender]
        if dock then
            dock.miner_type   = msg.miner_type
            dock.miner_status = msg.miner_status
            dock.queue_length = msg.queue_length
            dock.curr_job_id  = msg.curr_job_id
            dock.miner_id     = msg.miner_id
            if msg.miner_id and state.miners[msg.miner_id] then
                state.miners[msg.miner_id].dock_id = sender
            end
        end

    elseif msg.type == "DOCK_OFFLINE" then
        local dock = state.docks[sender]
        if dock and dock.miner_id then
            send(dock.miner_id, {
                type    = "DOCK_LOST",
                dock_id = sender
            })
            if state.miners[dock.miner_id] then
                state.miners[dock.miner_id].dock_id = nil
            end
        end
        state.docks[sender] = nil
        print("Dock #" .. sender .. " went offline.")

    elseif msg.type == "MINER_LOST_DOCK" then
        local miner = state.miners[sender]
        if miner then
            miner.dock_id = nil
            print("Miner #" .. sender .. " lost its dock, re-pairing...")
            connections.tryPair(state, send)
        end
    end
end

function comms.broadcastJob(s, from, to)
    state = s
    local job = {
        id     = os.epoch("utc"),
        from   = from,
        to     = to,
        status = "pending"
    }
    for id, dock in pairs(state.docks) do
        rednet.send(id, {
            type = "ASSIGN_JOB",
            job  = job
        }, PROTOCOL)
    end
end

return comms