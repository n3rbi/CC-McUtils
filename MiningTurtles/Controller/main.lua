local comms       = require("comms")
local connections = require("connections")

local PROTOCOL = "mining_turtles"
local scrollOffset = 0

local monitors = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        table.insert(monitors, peripheral.wrap(name))
    end
end

local mainMonitor = monitors[1]
local numpadMonitor = monitors[2]

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

local fieldOrder  = {"fromX","fromY","fromZ","toX","toY","toZ"}
local fieldLabels = {"FX","FY","FZ","TX","TY","TZ"}

local numpadLayout = {
    {"7","8","9"},
    {"4","5","6"},
    {"1","2","3"},
    {"-","0","<"},
    {"    OK    "},
}

local function drawNumpad()
    if not numpadMonitor then return end
    numpadMonitor.setTextScale(0.5)
    numpadMonitor.setBackgroundColor(colors.black)
    numpadMonitor.clear()
    local w, h = numpadMonitor.getSize()

    local function writeBtn(x, row, text, fg, bg)
        numpadMonitor.setCursorPos(x, row)
        numpadMonitor.setTextColor(fg or colors.white)
        numpadMonitor.setBackgroundColor(bg or colors.gray)
        numpadMonitor.write(text)
        numpadMonitor.setBackgroundColor(colors.black)
    end

    numpadMonitor.setCursorPos(1,1)
    numpadMonitor.setTextColor(colors.yellow)
    numpadMonitor.write("Numpad")

    for rowIdx, row in ipairs(numpadLayout) do
        if #row == 1 then
            writeBtn(1, rowIdx + 1, row[1], colors.white, colors.green)
        else
            local colW = math.floor(w / 3)
            for colIdx, btn in ipairs(row) do
                local x = (colIdx - 1) * colW + 1
                writeBtn(x, rowIdx + 1, " " .. btn .. " ", colors.white, colors.gray)
            end
        end
    end

    -- Show currently selected field and its value
    local key   = fieldOrder[jobInput.field]
    local label = fieldLabels[jobInput.field]
    numpadMonitor.setCursorPos(1, #numpadLayout + 3)
    numpadMonitor.setTextColor(colors.lime)
    numpadMonitor.write(label .. ": " .. (jobInput[key] == "" and "_" or jobInput[key]))
end

local function handleNumpadTouch(x, y)
    if not numpadMonitor then return end
    local w = numpadMonitor.getSize()
    local colW = math.floor(w / 3)

    local rowIdx = y - 1
    if rowIdx < 1 or rowIdx > #numpadLayout then return end

    local row = numpadLayout[rowIdx]
    local key = fieldOrder[jobInput.field]

    if #row == 1 then
        -- OK button
        jobInput.field = (jobInput.field % #fieldOrder) + 1
    else
        local colIdx = math.min(3, math.floor((x - 1) / colW) + 1)
        local btn    = row[colIdx]
        if btn == "<" then
            if #jobInput[key] > 0 then
                jobInput[key] = jobInput[key]:sub(1, -2)
            end
        elseif btn == "-" then
            if jobInput[key] == "" then
                jobInput[key] = "-"
            end
        else
            jobInput[key] = jobInput[key] .. btn
        end
    end
end

local function drawMainMonitor()
    if not mainMonitor then return end
    mainMonitor.setTextScale(0.5)
    mainMonitor.setBackgroundColor(colors.black)
    mainMonitor.clear()
    local w, h = mainMonitor.getSize()

    local function write(x, row, text, fg, bg)
        mainMonitor.setCursorPos(x, row)
        mainMonitor.setTextColor(fg or colors.white)
        mainMonitor.setBackgroundColor(bg or colors.black)
        mainMonitor.write(text:sub(1, w - x + 1))
        mainMonitor.setBackgroundColor(colors.black)
    end

    local function hline(row, col)
        write(1, row, string.rep("-", w), col or colors.gray)
    end

    write(1, 1, "Mining Controller #" .. state.id, colors.yellow)
    hline(2)

    local bodyStart  = 3
    local bodyEnd    = h - 6
    local bodyHeight = bodyEnd - bodyStart + 1

    local rows = {}

    local sortedDocks = {}
    for id, d in pairs(state.docks) do table.insert(sortedDocks, d) end
    table.sort(sortedDocks, function(a, b) return a.id < b.id end)

    for _, dock in ipairs(sortedDocks) do
        local minerStr = dock.miner_id and ("Miner #" .. dock.miner_id) or "Unassigned"
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

    local maxScroll = math.max(0, #rows - bodyHeight)
    scrollOffset    = math.max(0, math.min(scrollOffset, maxScroll))

    for i = 1, bodyHeight do
        local rowIdx    = i + scrollOffset
        local row       = rows[rowIdx]
        local screenRow = bodyStart + i - 1
        if row then write(1, screenRow, row.text, row.col) end
    end

    if maxScroll > 0 then
        local pct      = scrollOffset / maxScroll
        local indicRow = bodyStart + math.floor(pct * (bodyHeight - 1))
        write(w, indicRow, "\x95", colors.gray)
    end

    hline(h - 5)

    write(1, h - 4, "New Job:", colors.yellow)

    local inputRow = h - 3
    local col = 1
    for i, key in ipairs(fieldOrder) do
        local label = fieldLabels[i] .. ":"
        local val   = jobInput[key] == "" and "_____" or jobInput[key]
        local fg    = (jobInput.field == i) and colors.lime or colors.white
        mainMonitor.setCursorPos(col, inputRow)
        mainMonitor.setTextColor(colors.gray)
        mainMonitor.write(label)
        mainMonitor.setTextColor(fg)
        mainMonitor.write(val .. " ")
        col = col + #label + #val + 2
    end

    local btnText = "[ Start Job ]"
    local btnX    = math.floor((w - #btnText) / 2) + 1
    mainMonitor.setCursorPos(btnX, h - 1)
    mainMonitor.setBackgroundColor(colors.green)
    mainMonitor.setTextColor(colors.white)
    mainMonitor.write(btnText)
    mainMonitor.setBackgroundColor(colors.black)

    write(1, h, "Touch field to select, use numpad to input.", colors.gray)
end

local function handleMainMonitorTouch(x, y)
    if not mainMonitor then return end
    local w, h = mainMonitor.getSize()

    local btnText = "[ Start Job ]"
    local btnX    = math.floor((w - #btnText) / 2) + 1
    if y == h - 1 and x >= btnX and x <= btnX + #btnText - 1 then
        local from = {
            x = tonumber(jobInput.fromX),
            y = tonumber(jobInput.fromY),
            z = tonumber(jobInput.fromZ)
        }
        local to = {
            x = tonumber(jobInput.toX),
            y = tonumber(jobInput.toY),
            z = tonumber(jobInput.toZ)
        }
        if from.x and from.y and from.z and to.x and to.y and to.z then
            comms.broadcastJob(state, from, to)
            jobInput = { fromX="", fromY="", fromZ="", toX="", toY="", toZ="", field=1 }
            print("Job dispatched.")
        else
            print("Invalid coordinates.")
        end
        return
    end

    if y == h - 3 then
        local c = 1
        for i, key in ipairs(fieldOrder) do
            local label   = fieldLabels[i] .. ":"
            local val     = jobInput[key] == "" and "_____" or jobInput[key]
            local fieldEnd = c + #label + #val + 1
            if x >= c and x <= fieldEnd then
                jobInput.field = i
                break
            end
            c = fieldEnd + 1
        end
    end
end

local x, y, z = gps.locate()
state.pos = { x = x, y = y, z = z }
print("Controller #" .. state.id .. " booting at " .. x .. "," .. y .. "," .. z)

comms.init(state)
drawMainMonitor()
drawNumpad()

while true do
    drawMainMonitor()
    drawNumpad()

    local ev, p1, p2, p3, p4 = os.pullEvent()

    if ev == "rednet_message" and p3 == PROTOCOL then
        comms.handleMessage(p1, p2, state, connections)

    elseif ev == "monitor_touch" then
        local mon = peripheral.wrap(p1)
        if mon == mainMonitor then
            handleMainMonitorTouch(p2, p3)
        elseif mon == numpadMonitor then
            handleNumpadTouch(p2, p3)
        end

    elseif ev == "monitor_scroll" then
        scrollOffset = scrollOffset - p3
    end
end