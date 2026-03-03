local nav = {}

local function getPos()
    local x, y, z = gps.locate()
    return x, y, z
end

local function faceDirection(dx, dz, currentFacing)
    local targetFacing
    if dx > 0 then targetFacing = "east"
    elseif dx < 0 then targetFacing = "west"
    elseif dz > 0 then targetFacing = "south"
    elseif dz < 0 then targetFacing = "north"
    end

    if targetFacing == currentFacing then return currentFacing end

    local order = { north = 0, east = 1, south = 2, west = 3 }
    local current = order[currentFacing]
    local target = order[targetFacing]
    local diff = (target - current + 4) % 4

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
    for i = 1, 10 do
        local frontBlocked = turtle.inspect()
        local backBlocked = turtle.inspectDown()

        if not frontBlocked then
            local x1, y, z1 = gps.locate()
            turtle.forward()
            local x2, y2, z2 = gps.locate()
            turtle.back()
            local dx = x2 - x1
            local dz = z2 - z1
            if dx > 0 then return "east"
            elseif dx < 0 then return "west"
            elseif dz > 0 then return "south"
            else return "north"
            end
        end

        turtle.turnRight()
        frontBlocked = turtle.inspect()
        if not frontBlocked then
            local x1, y, z1 = gps.locate()
            turtle.forward()
            local x2, y2, z2 = gps.locate()
            turtle.back()
            turtle.turnLeft()
            local dx = x2 - x1
            local dz = z2 - z1
            if dx > 0 then return "east"
            elseif dx < 0 then return "west"
            elseif dz > 0 then return "south"
            else return "north"
            end
        end
        turtle.turnLeft()

        turtle.turnLeft()
        frontBlocked = turtle.inspect()
        if not frontBlocked then
            local x1, y, z1 = gps.locate()
            turtle.forward()
            local x2, y2, z2 = gps.locate()
            turtle.back()
            turtle.turnRight()
            local dx = x2 - x1
            local dz = z2 - z1
            if dx > 0 then return "east"
            elseif dx < 0 then return "west"
            elseif dz > 0 then return "south"
            else return "north"
            end
        end
        turtle.turnRight()

        if not turtle.inspectUp() then
            turtle.up()
        elseif not turtle.inspectDown() then
            turtle.down()
        end
    end

    print("All sides blocked, digging forward to clear...")
    turtle.dig()
    local x1, y, z1 = gps.locate()
    turtle.forward()
    local x2, y2, z2 = gps.locate()
    turtle.back()
    local dx = x2 - x1
    local dz = z2 - z1
    if dx > 0 then return "east"
    elseif dx < 0 then return "west"
    elseif dz > 0 then return "south"
    else return "north"
    end
end

local function tryMoveForward(mining)
    local blocked, block = turtle.inspect()
    if blocked then
        if mining then
            turtle.dig()
            return turtle.forward()
        else
            return false
        end
    end
    return turtle.forward()
end

local function tryMoveUp(mining)
    local blocked = turtle.inspectUp()
    if blocked then
        if mining then
            turtle.digUp()
            return turtle.up()
        else
            return false
        end
    end
    return turtle.up()
end

local function tryMoveDown(mining)
    local blocked = turtle.inspectDown()
    if blocked then
        if mining then
            turtle.digDown()
            return turtle.down()
        else
            return false
        end
    end
    return turtle.down()
end

local function avoidObstacle(facing, mining)
    local attempts = { "up", "right", "left", "down" }
    for _, dir in ipairs(attempts) do
        if dir == "up" then
            if tryMoveUp(mining) then return true end
        elseif dir == "down" then
            if tryMoveDown(mining) then return true end
        elseif dir == "right" then
            turtle.turnRight()
            local moved = tryMoveForward(mining)
            if not moved then turtle.turnLeft() end
            return moved
        elseif dir == "left" then
            turtle.turnLeft()
            local moved = tryMoveForward(mining)
            if not moved then turtle.turnRight() end
            return moved
        end
    end
    return false
end

function nav.goto(targetX, targetY, targetZ, mining)
    mining = mining or false
    local facing = getFacing()
    local stuckCount = 0
    local MAX_STUCK = 10

    while true do
        local x, y, z = getPos()

        if math.floor(x) == targetX and math.floor(y) == targetY and math.floor(z) == targetZ then
            break
        end

        local dx = targetX - math.floor(x)
        local dy = targetY - math.floor(y)
        local dz = targetZ - math.floor(z)

        local moved = false

        if dy ~= 0 then
            if dy > 0 then
                moved = tryMoveUp(mining)
            else
                moved = tryMoveDown(mining)
            end
        end

        if not moved and dx ~= 0 then
            facing = faceDirection(dx, 0, facing)
            moved = tryMoveForward(mining)
        end

        if not moved and dz ~= 0 then
            facing = faceDirection(0, dz, facing)
            moved = tryMoveForward(mining)
        end

        if not moved then
            moved = avoidObstacle(facing, mining)
            stuckCount = stuckCount + 1
        else
            stuckCount = 0
        end

        if stuckCount >= MAX_STUCK then
            print("Nav stuck, cannot reach target.")
            return false
        end
    end

    return true
end

return nav