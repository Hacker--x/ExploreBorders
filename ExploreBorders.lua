local ADDON, ns = ...
local D, G = ns.Data, ns.Geometry
local events = CreateFrame("Frame")
local overlay, canvas, caption, db, active
local lines, labels, cache = {}, {}, {}
local dirty, elapsed, supported = true, 0, true
local lastMap, lastWidth, lastHeight

local function Say(text) print("|cffffcc55Explore Borders:|r " .. text) end

local function InitDB()
    if type(ExploreBordersDB) ~= "table" then ExploreBordersDB = {} end
    db = ExploreBordersDB
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.labels) ~= "boolean" then db.labels = true end
    if type(db.perimeters) ~= "boolean" then db.perimeters = true end
    if type(db.marks) ~= "table" then db.marks = {} end
    db.version = 2
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Copy(v) end
    return result
end

-- Called by the tiny legacy addon after WoW loads its old SavedVariables file.
function ExploreBorders_ImportLegacy(legacy)
    if not db then InitDB() end
    if db.legacyImportDone or type(legacy) ~= "table" then return end
    if not db.userConfigured then
        if type(legacy.enabled) == "boolean" then db.enabled = legacy.enabled end
        if type(legacy.labels) == "boolean" then db.labels = legacy.labels end
    end
    if type(legacy.marks) == "table" then
        for _, mark in ipairs(legacy.marks) do
            if type(mark) == "table" then db.marks[#db.marks + 1] = Copy(mark) end
        end
        while #db.marks > 200 do table.remove(db.marks, 1) end
    end
    db.legacyImportDone = true
    dirty = true
    Say("Imported your Durotar Borders settings and test marks.")
end

local function LiveFrame(uiMapID)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, world, frame = pcall(function()
        local m1, p1 = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(0, 0))
        local m2, p2 = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(1, 1))
        if m1 ~= m2 or not p1 or not p2 then return end
        local north, west = p1:GetXY()
        local south, east = p2:GetXY()
        local f = {north = north, south = south, west = west, east = east}
        for _, value in pairs(f) do
            if type(value) ~= "number" or value ~= value or math.abs(value) > 1000000 then return end
        end
        if not (north and south and west and east and north > south and west > east) then return end
        return m1, f
    end)
    if ok then return world, frame end
end

local function Resolve(uiMapID)
    if not uiMapID or uiMapID <= 0 then return end
    if cache[uiMapID] ~= nil then return cache[uiMapID] or nil end
    local data = D.maps[uiMapID]
    local world, frame = LiveFrame(uiMapID)
    local source = "live client map frame"
    if data then
        local matches = world == data.worldMapID and frame ~= nil
        if matches then
            for key, expected in pairs(data.sourceFrame) do
                if math.abs(frame[key] - expected) > 100 then matches = false; break end
            end
        end
        if not matches then frame, source = data.sourceFrame, "published map frame (fallback)" end
    elseif world and frame then
        -- The source uses negative placeholders here, never valid client UI IDs.
        data = D.instances[world]
    end
    if not data or not frame then cache[uiMapID] = false; return end
    local result = {data = data, frame = frame, source = source, uiMapID = uiMapID}
    cache[uiMapID] = result
    return result
end
ns.Resolve = Resolve

local function Attach()
    if overlay then return true end
    local map = WorldMapFrame
    if not (map and map.GetCanvas and map.GetMapID) then return false end
    canvas = map:GetCanvas()
    if not canvas then return false end
    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:EnableMouse(false)
    if not overlay.CreateLine then
        supported = false
        Say("This client's map renderer does not support line overlays.")
        overlay:Hide()
        return false
    end
    caption = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("TOP", overlay, "TOP", 0, -8)
    caption:SetTextColor(1, 0.82, 0.35)
    caption:SetShadowColor(0, 0, 0, 1)
    caption:SetShadowOffset(1, -1)
    return true
end

local function Draw(width, height)
    for _, line in ipairs(lines) do line:Hide() end
    for _, label in ipairs(labels) do label:Hide() end
    local count, projection = 0, active.frame
    local function DrawRings(rings, perimeter)
        for _, ring in ipairs(rings) do
            local previous = ring[#ring]
            for _, point in ipairs(ring) do
                local x1, y1 = G.Project(projection, previous[1] * D.gridStep, previous[2] * D.gridStep)
                local x2, y2 = G.Project(projection, point[1] * D.gridStep, point[2] * D.gridStep)
                x1, y1, x2, y2 = G.Clip(x1, y1, x2, y2)
                if x1 then
                    count = count + 1
                    local line = lines[count]
                    if not line then
                        line = overlay:CreateLine(nil, "OVERLAY")
                        lines[count] = line
                        line:SetThickness(1.5)
                    end
                    if perimeter then line:SetColorTexture(0.25, 0.85, 1, 0.95)
                    else line:SetColorTexture(1, 0.78, 0.15, 0.9) end
                    line:SetStartPoint("TOPLEFT", overlay, x1 * width, -y1 * height)
                    line:SetEndPoint("TOPLEFT", overlay, x2 * width, -y2 * height)
                    line:Show()
                end
                previous = point
            end
        end
    end
    if db.perimeters and active.data.perimeter then DrawRings(active.data.perimeter, true) end
    for index, area in ipairs(active.data.areas) do
        DrawRings(area.rings, false)
        if db.labels then
            local x, y = G.Project(projection, area.label[1], area.label[2])
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local label = labels[index]
                if not label then
                    label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    labels[index] = label
                    label:SetTextColor(1, 0.94, 0.65)
                    label:SetShadowColor(0, 0, 0, 1)
                    label:SetShadowOffset(1, -1)
                    label:SetWidth(110)
                end
                label:ClearAllPoints()
                label:SetPoint("CENTER", overlay, "TOPLEFT", x * width, -y * height)
                label:SetText(area.name)
                label:Show()
            end
        end
    end
    caption:SetText("Explore Borders: " .. active.data.name ..
        (#active.data.areas == 0 and " | zone perimeter only" or " | gold: subareas / cyan: zone") .. " | /eborders help")
    ns.visibleSegments, ns.activeMapID = count, active.uiMapID
    lastWidth, lastHeight, dirty = width, height, false
end

local function Update()
    if not db or not supported then return end
    if not db.enabled or not WorldMapFrame or not WorldMapFrame:IsShown() then
        if overlay then overlay:Hide() end
        return
    end
    if not Attach() then return end
    local mapID = WorldMapFrame:GetMapID()
    if mapID ~= lastMap or dirty then
        active, lastMap, dirty = Resolve(mapID), mapID, true
    end
    if not active then
        overlay:Hide()
        ns.visibleSegments, ns.activeMapID, dirty = 0, nil, false
        return
    end
    local width, height = canvas:GetSize()
    if width <= 0 or height <= 0 then overlay:Hide(); return end
    if dirty or width ~= lastWidth or height ~= lastHeight then Draw(width, height) end
    overlay:Show()
end

local function PlayerMap()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

local function Mark(note)
    local uiMapID = PlayerMap()
    local resolved = Resolve(uiMapID)
    local position = resolved and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(uiMapID, "player")
    if not position then Say("No covered map/player position is available here."); return end
    local x, y = position:GetXY()
    if not x or not y or (x == 0 and y == 0) then Say("Player position is unavailable."); return end
    local frame = resolved.frame
    local wx = frame.north - y * (frame.north - frame.south)
    local wy = frame.west - x * (frame.west - frame.east)
    local predicted = {}
    for _, area in ipairs(resolved.data.areas) do
        if G.Contains(area.rings, wx / D.gridStep, wy / D.gridStep) then predicted[#predicted + 1] = area.name end
    end
    local mark = {time = time(), x = x, y = y, uiMapID = uiMapID, dataMapKey = resolved.data.key,
        worldMapID = resolved.data.worldMapID, zone = GetZoneText(), subzone = GetSubZoneText(),
        predicted = predicted, note = note:sub(1, 240), projection = resolved.source}
    if GetBuildInfo then mark.clientVersion, mark.clientBuild = GetBuildInfo() end
    db.marks[#db.marks + 1] = mark
    if #db.marks > 200 then table.remove(db.marks, 1) end
    Say(string.format("Mark saved in %s at %.2f, %.2f. Game: %s. Terrain: %s.", resolved.data.name,
        x * 100, y * 100, mark.subzone ~= "" and mark.subzone or mark.zone,
        #predicted > 0 and table.concat(predicted, ", ") or "no polygon"))
end

SLASH_EXPLOREBORDERS1 = "/eborders"
SLASH_EXPLOREBORDERS2 = "/exploreborders"
SLASH_EXPLOREBORDERS3 = "/dborders"
SLASH_EXPLOREBORDERS4 = "/durotarborders"
SlashCmdList.EXPLOREBORDERS = function(input)
    if not db then InitDB() end
    local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "toggle" then
        db.enabled, db.userConfigured = not db.enabled, true
        Say(db.enabled and "Outlines on. Open a covered zone map." or "Outlines off.")
    elseif command == "show" or command == "hide" then
        db.enabled, db.userConfigured = command == "show", true
        Say(db.enabled and "Outlines on. Open a covered zone map." or "Outlines off.")
    elseif command == "labels" then
        db.labels, db.userConfigured = not db.labels, true
        Say(db.labels and "Area labels on." or "Area labels off.")
    elseif command == "perimeters" then
        db.perimeters = not db.perimeters
        Say(db.perimeters and "Cyan zone perimeters on." or "Cyan zone perimeters off.")
    elseif command == "mark" then Mark(rest)
    elseif command == "status" then
        cache = {}
        local viewed = WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() or PlayerMap()
        local r = Resolve(viewed)
        Say("0.2.0 | 812 subareas + 59 zone perimeters | 48 named maps + 11 runtime-resolved instances | " .. #db.marks .. " marks.")
        Say(r and (r.data.name .. ": " .. #r.data.areas .. " subareas; " .. r.source) or
            ("No geometry for UI map " .. tostring(viewed) .. ". See COVERAGE.txt."))
        Say("Outlines " .. (db.enabled and "on" or "off") .. "; labels " .. (db.labels and "on" or "off") ..
            "; renderer " .. (supported and "awaiting/available" or "unsupported") .. ".")
    else
        Say("/eborders toggles outlines; show, hide, labels, perimeters, status; mark [note] saves a test position.")
    end
    dirty = true
    Update()
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then InitDB() end
    if event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        Say("Loaded: 48 named maps. /eborders help for controls. Experimental terrain outlines.")
    end
    cache, dirty = {}, true
end)
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    Update()
end)
