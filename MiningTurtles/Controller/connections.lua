local connections = {}

local function distance(a, b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end

function connections.tryPair(state, send)
    -- Find all free docks and free miners
    local freeDocks  = {}
    local freeMiners = {}

    for id, dock in pairs(state.docks) do
        if not dock.miner_id then
            table.insert(freeDocks, dock)
        end
    end

    for id, miner in pairs(state.miners) do
        if not miner.dock_id then
            table.insert(freeMiners, miner)
        end
    end

    if #freeDocks == 0 or #freeMiners == 0 then return end

    -- Pair each free miner to its closest free dock
    for _, miner in ipairs(freeMiners) do
        local bestDock = nil
        local bestDist = math.huge

        for _, dock in ipairs(freeDocks) do
            if not dock.miner_id then
                local dist = distance(miner.pos, dock.pos)
                if dist < bestDist then
                    bestDist = dist
                    bestDock = dock
                end
            end
        end

        if bestDock then
            bestDock.miner_id = miner.id
            miner.dock_id     = bestDock.id

            print(("Paired Miner #%d <-> Dock #%d (dist: %d)"):format(
                miner.id, bestDock.id, math.floor(bestDist)
            ))

            send(bestDock.id, {
                type     = "PAIR_MINER",
                miner_id = miner.id,
            })

            send(miner.id, {
                type    = "PAIR_DOCK",
                dock_id = bestDock.id,
                dock_pos = bestDock.pos,
            })
        end
    end
end

return connections