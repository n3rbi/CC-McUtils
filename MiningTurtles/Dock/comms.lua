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

local function findController()
    print("Looking for controller...")
    local x, y, z = gps.locate()
    rednet.broadcast({
        type = "DOCK_LOOKING",
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
            if msg.type == "CONTROLLER_AVAILABLE" then
                local cp = msg.pos
                local dist = math.sqrt((cp.x-x)^2 + (cp.y-y)^2 + (cp.z-z)^2)
                if dist < closest_dist then
                    closest_dist = dist
                    closest_id = p1
                    closest_pos = cp
                end
            end
        elseif ev == "timer" and p1 == timer then
            break
        end
    end

    if closest_id then
        state.controller_id = closest_id
        state.controller_pos = closest_pos
        print("Found controller #" .. closest_id)
        return true
    end

    print("No controller found.")
    return false
end

local function findMiner()
    print("Broadcasting for free miner...")
    local x, y, z = gps.locate()
    rednet.broadcast({
        type     = "DOCK_AVAILABLE",
        pos      = { x = x, y = y, z = z },
        miner_id = nil,
        id       = os.getComputerID()
    }, PROTOCOL)

    local timer = os.startTimer(10)

    while true do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "rednet_message" and p3 == PROTOCOL then
            local msg = p2
            if msg.type == "MINER_CLAIM" then
                state.miner_id = p1
                state.miner_status = "Idle"
                print("Miner #" .. p1 .. " claimed this dock.")
                rednet.send(p1, {
                    type = "DOCK",
                    id   = os.getComputerID()
                }, PROTOCOL)
                return true
            end
        elseif ev == "timer" and p1 == timer then
            break
        end
    end

    print("No miner found.")
    return false
end

local function pingMiner()
    if state.miner_id then
        rednet.send(state.miner_id, {
            type = "PING",
            id   = os.getComputerID()
        }, PROTOCOL)
    end
end

local function pingController()
    if state.controller_id then
        rednet.send(state.controller_id, {
            type        = "DOCK_REPORT",
            id          = os.getComputerID(),
            miner_id    = state.miner_id,
            miner_type  = state.miner_type,
            miner_status= state.miner_status,
            queue_length= #state.job_queue,
            curr_job_id = state.curr_job_id
        }, PROTOCOL)
    end
end

local function handleMessage(sender, msg)
    if msg.type == "PONG" then
        state.miner_status = msg.status
        state.miner_fuel   = msg.fuel

    elseif msg.type == "MINER_LOOKING" then
        if state.miner_id == nil then
            local x, y, z = gps.locate()
            rednet.send(sender, {
                type     = "DOCK_AVAILABLE",
                pos      = { x = x, y = y, z = z },
                miner_id = nil,
                id       = os.getComputerID()
            }, PROTOCOL)
        end

    elseif msg.type == "ASSIGN_JOB" then
        table.insert(state.job_queue, msg.job)
        print("Job added to queue. Queue length: " .. #state.job_queue)

    elseif msg.type == "CONTROLLER_AVAILABLE" then
        if not state.controller_id then
            state.controller_id = sender
        end
    end
end

function comms.handleMessage(sender, msg)
    handleMessage(sender, msg)
end

function comms.init(s)
    state = s
    if not openModem() then return false end
    findController()
    return findMiner()
end

function comms.pingMiner()
    pingMiner()
end

function comms.pingController()
    pingController()
end

function comms.listen()
    local ev, p1, p2, p3 = os.pullEvent("rednet_message")
    if p3 == PROTOCOL then
        handleMessage(p1, p2)
    end
end

return comms