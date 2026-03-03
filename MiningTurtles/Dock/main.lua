print("This is a Dock")

local dock_posX, dock_posY, dock_posZ = gps.locate()
local modem = peripheral.find("modem")

local facing

function configure_facing()
    -- find the modem, the modem is always behind the block. Use cords to determine facing North, East, South, West.

    if modem then
        local modem_posX, modem_posY, modem_posZ = gps.locate()
        if modem_posX > dock_posX then
            facing = "East"
        elseif modem_posX < dock_posX then
            facing = "West"
        elseif modem_posZ > dock_posZ then
            facing = "South"
        elseif modem_posZ < dock_posZ then
            facing = "North"
        else
            print("Error: Modem is at the same position as the dock.")
        end
    else
        print("Error: No modem found. Please place a modem behind the dock.")
    end

    print("Dock is facing " .. facing)
end
