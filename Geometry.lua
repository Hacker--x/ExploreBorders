local _, ns = ...
local G = {}
ns.Geometry = G

function G.Project(frame, worldX, worldY)
    return (frame.west - worldY) / (frame.west - frame.east),
        (frame.north - worldX) / (frame.north - frame.south)
end

-- Liang-Barsky clipping. Never draw the off-map portion of a polygon edge.
function G.Clip(x1, y1, x2, y2)
    local dx, dy, low, high = x2 - x1, y2 - y1, 0, 1
    local p, q = {-dx, dx, -dy, dy}, {x1, 1 - x1, y1, 1 - y1}
    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then return end
        else
            local t = q[i] / p[i]
            if p[i] < 0 then low = math.max(low, t) else high = math.min(high, t) end
            if low > high then return end
        end
    end
    if low == high then return end
    return x1 + low * dx, y1 + low * dy, x1 + high * dx, y1 + high * dy
end

function G.Contains(rings, x, y)
    local inside = false
    for _, ring in ipairs(rings) do
        local previous = ring[#ring]
        for _, point in ipairs(ring) do
            local ax, ay, bx, by = previous[1], previous[2], point[1], point[2]
            if (ay > y) ~= (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax then
                inside = not inside
            end
            previous = point
        end
    end
    return inside
end
