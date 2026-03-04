local comms       = require("comms")
local connections = require("connections")

local PROTOCOL = "mining_turtles"
local scrollOffset = 0

local monitor = peripheral.find("monitor")

local state = {
    id       = os.getComputerID(),
    pos      = nil,
    docks    = {},
    miners   = {},
}

local jobInput = {
    fromX = "", fromY = "", fromZ = "",
    toX   = "", toY   = "", toZ   = "",
    field = 1
}

local fieldOrder = {"fromX","fromY","fromZ","toX","toY","toZ"}
local fieldLabels = {"FX","FY","FZ","TX","TY","TZ"}

local function drawMonitor()
    if not monitor then return end
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    local w, h = monitor.getSize()

    local function write(x, row, text, fg, bg)
        monitor.setCursorPos(x, row)
        monitor.setTextColor(fg or colors.white)
        monitor.setBackgroundColor(bg or colors.black)
        monitor.write(text:sub(1, w - x + 1))
    end

    local function hline(row, col)
        write(1, row, string.rep("-", w), col or colors.gray)
    end

    -- Header
    write(1, 1, "Mining Controller #" .. state.id, colors.yellow)
    hline(2)

    -- Body rows available (leave 5 rows at bottom for job input)
    local bodyStart = 3
    local bodyEnd   = h - 6
    local bodyHeight = bodyEnd - bodyStart + 1

    -- Build render list
    local rows = {}

    local sortedDocks = {}
    for id, d in pairs(state.docks) do table.insert(sortedDocks, d) end
    table.sort(sortedDocks, function(a, b) return a.id < b.id end)

    for _, dock in ipairs(sortedDocks) do
        local miner = dock.miner_id and state.miners[dock.miner_id]
        local minerStr = miner and ("Miner #" .. dock.miner_id) or "Unassigned"
        local typeStr  = dock.miner_type and ("[" .. dock.miner_type .. "]") or "[?]"
        table.insert(rows, {
            text = ("Dock #%-4d %-8s <-> %s"):format(dock.id, typeStr, minerStr),
            col  = colors.white
        })
        table.insert(rows, {
            text = ("  Status: %-16s Queue: %d"):format(
                dock.miner_status or "Unknown",
                dock.queue_length or 0
            ),
            col = colors.lightGray
        })
        table.insert(rows, { text = "", col = colors.black })
    end

    -- Unassigned miners
    local unassigned = {}
    for id, m in pairs(state.miners) do
        if not m.dock_id then table.insert(unassigned, "#" .. id) end
    end
    if #unassigned > 0 then
        table.insert(rows, {
            text = "Unassigned Miners: " .. table.concat(unassigned, ", "),
            col  = colors.orange
        })
    end

    -- Scroll indicator
    local maxScroll = math.max(0, #rows - bodyHeight)
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))

    for i = 1, bodyHeight do
        local rowIdx = i + scrollOffset
        local row    = rows[rowIdx]
        local screenRow = bodyStart + i - 1
        if row then
            write(1, screenRow, row.text, row.col)
        end
    end

    if maxScroll > 0 then
        local pct      = scrollOffset / maxScroll
        local indicRow = bodyStart + math.floor(pct * (bodyHeight - 1))
        write(w, indicRow, "\x95", colors.gray)
    end

    -- Divider
    hline(h - 5)

    -- Job input
    write(1, h - 4, "New Job:", colors.yellow)

    local inputRow = h - 3
    local col = 1
    for i, key in ipairs(fieldOrder) do
        local label = fieldLabels[i] .. ":"
        local val   = jobInput[key] == "" and "_____" or jobInput[key]
        local fg    = (jobInput.field == i) and colors.lime or colors.white
        monitor.setCursorPos(col, inputRow)
        monitor.setTextColor(colors.gray)
        monitor.write(label)
        monitor.setTextColor(fg)
        monitor.write(val .. " ")
        col = col + #label + #val + 2
    end

    -- Start button
    local btnText = "[ Start Job ]"
    local btnX    = math.floor((w - #btnText) / 2) + 1
    monitor.setCursorPos(btnX, h - 1)
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.white)
    monitor.write(btnText)
    monitor.setBackgroundColor(colors.black)

    write(1, h, "Click fields to select, type coords, click Start.", colors.gray)
end

local function handleMonitorTouch(x, y)
    if not monitor then return end
    local w, h = monitor.getSize()

    -- Check start button
    local btnText = "[ Start Job ]"
    local btnX    = math.floor((w - #btnText) / 2) + 1
    if y == h - 1 and x >= btnX and x <= btnX + #btnText - 1 then
        local from = { x = tonumber(jobInput.fromX), y = tonumber(jobInput.fromY), z = tonumber(jobInput.fromZ) }
        local to   = { x = tonumber(jobInput.toX),   y = tonumber(jobInput.toY),   z = tonumber(jobInput.toZ)   }
        if from.x and from.y and from.z and to.x and to.y and to.z then
            comms.broadcastJob(state, from, to)
            jobInput = { fromX="", fromY="", fromZ="", toX="", toY="", toZ="", field=1 }
            print("Job dispatched.")
        else
            print("Invalid coordinates.")
        end
        return
    end

    -- Check field clicks on input row
    if y == h - 3 then
        local col = 1
        for i, key in ipairs(fieldOrder) do
            local label = fieldLabels[i] .. ":"
            local val   = jobInput[key] == "" and "_____" or jobInput[key]
            local fieldEnd = col + #label + #val + 1
            if x >= col and x <= fieldEnd then
                jobInput.field = i
                break
            end
            col = fieldEnd + 1
        end
    end
end

local function handleChar(c)
    local key = fieldOrder[jobInput.field]
    if c == "-" or tonumber(c) then
        jobInput[key] = jobInput[key] .. c
    end
end

local function handleBackspace()
    local key = fieldOrder[jobInput.field]
    if #jobInput[key] > 0 then
        jobInput[key] = jobInput[key]:sub(1, -2)
    end
end

local function handleTab()
    jobInput.field = (jobInput.field % #fieldOrder) + 1
end

-- Boot
local x, y, z = gps.locate()
state.pos = { x = x, y = y, z = z }
print("Controller #" .. state.id .. " booting at " .. x .. "," .. y .. "," .. z)

comms.init(state)
drawMonitor()

while true do
    drawMonitor()
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "rednet_message" and p3 == PROTOCOL then
        comms.handleMessage(p1, p2, state, connections)
        drawMonitor()

    elseif ev == "monitor_scroll" then
        scrollOffset = scrollOffset - p3

    elseif ev == "monitor_touch" then
        handleMonitorTouch(p2, p3)

    elseif ev == "char" then
        handleChar(p1)

    elseif ev == "key" then
        if p1 == keys.backspace then handleBackspace()
        elseif p1 == keys.tab   then handleTab()
        end
    end
end