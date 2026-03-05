local comms = {}

local PROTOCOL   = "mining_turtles"
local state      = nil

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

local function resetPairing()
    print("Session mismatch, re-registering...")
    state.miner_id      = nil
    state.miner_status  = "Unknown"
    state.miner_fuel    = nil
    state.miner_pos     = nil
    state.controller_id = nil
    state.session_id    = nil
end

local function findController()
    print("Searching for controller...")
    local x, y, z     = gps.locate()
    local closest_id   = nil
    local closest_dist = math.huge
    local timer        = os.startTimer(5)

    rednet.broadcast({
        type = "DOCK_LOOKING",
        pos  = { x = x, y = y, z = z },
        id   = os.getComputerID()
    }, PROTOCOL)

    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "rednet_message" and p3 == PROTOCOL then
            if p2.type == "CONTROLLER_AVAILABLE" then
                local cp   = p2.pos
                local dist = math.sqrt((cp.x-x)^2 + (cp.y-y)^2 + (cp.z-z)^2)
                if dist < closest_dist then
                    closest_dist        = dist
                    closest_id          = p1
                    state.session_id    = p2.session_id
                end
            end
        elseif ev == "timer" and p1 == timer then
            break
        end
    end

    if closest_id then
        state.controller_id = closest_id
        print("Found controller #" .. closest_id .. " session: " .. tostring(state.session_id))
        return true
    end

    print("No controller found.")
    return false
end

local function handleMessage(sender, msg)
    -- Session check
    if msg.session_id and state.session_id and msg.session_id ~= state.session_id then
        resetPairing()
        findController()
        return
    end

    if msg.type == "PAIR_MINER" then
        state.miner_id     = msg.miner_id
        state.miner_status = "Idle"
        print("Paired with miner #" .. msg.miner_id)
        local x, y, z = gps.locate()
        send(msg.miner_id, {
            type       = "PAIR_DOCK",
            dock_id    = os.getComputerID(),
            dock_pos   = { x = x, y = y, z = z },
            facing     = state.facing,
            session_id = state.session_id
        })

    elseif msg.type == "PONG" then
        state.miner_status = msg.status
        state.miner_fuel   = msg.fuel
        state.miner_pos    = msg.pos

    elseif msg.type == "ASSIGN_JOB" then
        table.insert(state.job_queue, msg.job)
        print("Job added to queue. Queue length: " .. #state.job_queue)

    elseif msg.type == "CONTROLLER_AVAILABLE" then
        if not state.controller_id then
            state.controller_id = sender
            state.session_id    = msg.session_id
            print("Found controller #" .. sender)
        end
    end
end

function comms.findController()
    return findController()
end

function comms.pingMiner()
    if state.miner_id then
        send(state.miner_id, {
            type       = "PING",
            id         = os.getComputerID(),
            session_id = state.session_id
        })
    end
end

function comms.pingController()
    if state.controller_id then
        send(state.controller_id, {
            type         = "DOCK_REPORT",
            id           = os.getComputerID(),
            miner_id     = state.miner_id,
            miner_type   = state.miner_type,
            miner_status = state.miner_status,
            queue_length = #state.job_queue,
            curr_job_id  = state.curr_job_id,
            session_id   = state.session_id
        })
    end
end

function comms.init(s)
    state = s
    if not openModem() then return false end
    findController()
    return true
end

function comms.handleMessage(sender, msg)
    handleMessage(sender, msg)
end

return comms