local nav = {}

local function getPos()
    local x, y, z = gps.locate()
    return math.floor(x), math.floor(y), math.floor(z)
end

local function turnToFacing(currentFacing, targetFacing)
    local order = { north = 0, east = 1, south = 2, west = 3 }
    local diff  = (order[targetFacing] - order[currentFacing] + 4) % 4
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

local function getFacing()
    local x1, y1, z1 = getPos()
    turtle.forward()
    local x2, y2, z2 = getPos()
    turtle.back()
    if x2 > x1 then return "east"
    elseif x2 < x1 then return "west"
    elseif z2 > z1 then return "south"
    else return "north"
    end
end

local function tryUp(mining)
    if turtle.inspectUp() then
        if mining then turtle.digUp() else return false end
    end
    return turtle.up()
end

local function tryDown(mining)
    if turtle.inspectDown() then
        if mining then turtle.digDown() else return false end
    end
    return turtle.down()
end

local function tryForward(mining)
    if turtle.inspect() then
        if mining then turtle.dig() else return false end
    end
    return turtle.forward()
end

local function avoidObstacle(facing, mining)
    if tryUp(mining) then return facing end

    turtle.turnRight()
    if tryForward(mining) then return facing end
    turtle.turnLeft()

    turtle.turnLeft()
    if tryForward(mining) then return facing end
    turtle.turnRight()

    if tryDown(mining) then return facing end

    if mining then
        turtle.dig()
        turtle.forward()
    end

    return facing
end

function nav.goto(targetX, targetY, targetZ, mining)
    mining  = mining or false
    local facing = getFacing()
    local MAX_STUCK = 50
    local stuck = 0

    while true do
        local x, y, z = getPos()
        if x == targetX and y == targetY and z == targetZ then break end

        local moved = false

        local dx = targetX - x
        local dz = targetZ - z
        local dy = targetY - y

        if dx ~= 0 then
            local targetFacing = dx > 0 and "east" or "west"
            facing = turnToFacing(facing, targetFacing)
            moved  = tryForward(mining)
            if not moved then
                facing = avoidObstacle(facing, mining)
                moved  = true
            end

        elseif dz ~= 0 then
            local targetFacing = dz > 0 and "south" or "north"
            facing = turnToFacing(facing, targetFacing)
            moved  = tryForward(mining)
            if not moved then
                facing = avoidObstacle(facing, mining)
                moved  = true
            end

        elseif dy ~= 0 then
            if dy > 0 then
                moved = tryUp(mining)
            else
                moved = tryDown(mining)
            end
            if not moved then
                facing = avoidObstacle(facing, mining)
                moved  = true
            end
        end

        if not moved then
            stuck = stuck + 1
            if stuck >= MAX_STUCK then
                print("Nav: stuck, cannot reach target.")
                return false
            end
        else
            stuck = 0
        end
    end

    return true
end

return nav