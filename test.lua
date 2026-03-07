local LENGTH = 31  -- blocks forward per row
local WIDTH  = 30  -- number of rows

local function mineForward()
  while not turtle.forward() do
    turtle.dig()
    turtle.attack()
  end
end

local function mineRow()
  for i = 1, LENGTH - 1 do
    turtle.dig()
    mineForward()
  end
end

local function turnLeft()
  turtle.turnLeft()
end

local function turnRight()
  turtle.turnRight()
end

local function stepOver(turnFunc, oppFunc)
  turnFunc()
  turtle.dig()
  mineForward()
  oppFunc()
end

for row = 1, WIDTH do
  mineRow()

  if row < WIDTH then
    if row % 2 == 1 then
      stepOver(turnRight, turnLeft)
    else
      stepOver(turnLeft, turnRight)
    end
  end
end

print("Done! Mined area.")
