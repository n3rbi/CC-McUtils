local nav = {}

local HIGH_Y_OFFSET = 25
local HIGH_Y_CAP = 100

local function getPos()
    local x, y, z = gps.locate()
    return math.floor(x), math.floor(y), math.floor(z)
end

local function turnToFacing(currentFacing, targetFacing)
    local order = { north = 0, east = 1, south = 2, west = 3 }
    local diff = (order[targetFacing] - order[currentFacing] + 4) % 4
    if diff == 1 then
        turtle.turnRight()
    elseif diff == 3 then
        turtle.turnLeft()
    elseif diff == 2 then
        turtle.turnRight()
        turtle.turnRight()
    end
    return targetFacing
end

local function moveUp()
    if turtle.inspectUp() then
        turtle.digUp()
    end
    return turtle.up()
end

local function moveDown(mining)
    if turtle.inspectDown() then
        if mining then
            turtle.digDown()
        else
            return false
        end
    end
    return turtle.down()
end

local function moveForward(mining)
    local blocked = turtle.inspect()
    if blocked then
        if mining then
            turtle.dig()
        else
            return false
        end
    end
    return turtle.forward()
end

local function avoidForward(facing, mining)
    if turtle.up() then return facing end

    turtle.turnRight()
    if moveForward(mining) then return turnToFacing(facing, "east") end
    turtle.turnLeft()

    turtle.turnLeft()
    if moveForward(mining) then return turnToFacing(facing, "west") end
    turtle.turnRight()

    if moveDown(mining) then return facing end

    if mining then
        turtle.dig()
        turtle.forward()
    end

    return facing
end

local function getFacing()
    local x1, y1, z1 = getPos()
    turtle.forward()
    local x2, y2, z2 = getPos()
    turtle.back()

    local dx = x2 - x1
    local dz = z2 - z1

    if dx > 0 then return "east"
    elseif dx < 0 then return "west"
    elseif dz > 0 then return "south"
    else return "north"
    end
end

local function matchAxis(current, target, facing, axisX, mining)
    local diff = target - current
    if diff == 0 then return facing end

    local targetFacing
    if axisX then
        targetFacing = diff > 0 and "east" or "west"
    else
        targetFacing = diff > 0 and "south" or "north"
    end

    facing = turnToFacing(facing, targetFacing)

    while true do
        local x, y, z = getPos()
        local cur = axisX and x or z
        if cur == target then break end

        local moved = moveForward(mining)
        if not moved then
            facing = avoidForward(facing, mining)
        end
    end

    return facing
end

function nav.goto(targetX, targetY, targetZ, mining)
    mining = mining or false

    local x, y, z = getPos()
    local highY = math.min(y + HIGH_Y_OFFSET, HIGH_Y_CAP)

    while true do
        local cx, cy, cz = getPos()
        if cy >= highY then break end
        moveUp()
    end

    local facing = getFacing()

    facing = matchAxis(({getPos()})[1], targetX, facing, true, mining)

    facing = matchAxis(({getPos()})[3], targetZ, facing, false, mining)

    while true do
        local cx, cy, cz = getPos()
        if cy == targetY then break end
        if cy > targetY then
            if not moveDown(mining) then
                print("Blocked moving down, cannot reach target Y.")
                return false
            end
        else
            moveUp()
        end
    end

    return true
end

return nav

