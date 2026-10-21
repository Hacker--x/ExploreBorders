-- Run from the repository root: lua ExploreBorders.test.lua
local realPrint = print
local messages, objects, frames = {}, {}, {}
print = function(message) messages[#messages + 1] = message end
local function Object(kind, parent)
    local o = {kind = kind, parent = parent, shown = true, scripts = {}}
    objects[#objects + 1] = o
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
    function o:SetAllPoints(target) self.allPoints = target end
    function o:EnableMouse(value) self.mouse = value end
    function o:RegisterEvent() end
    function o:SetScript(key, fn) self.scripts[key] = fn end
    function o:SetPoint(...) self.point = {...} end
    function o:ClearAllPoints() self.point = nil end
    function o:SetWidth(value) self.width = value end
    function o:SetText(value) self.text = value end
    function o:SetTextColor() end
    function o:SetShadowColor() end
    function o:SetShadowOffset() end
    function o:SetThickness(value) self.thickness = value end
    function o:SetColorTexture(r,g,b,a) self.color = {r,g,b,a} end
    function o:SetStartPoint(_, _, x, y) self.start = {x, y} end
    function o:SetEndPoint(_, _, x, y) self.finish = {x, y} end
    function o:CreateFontString() return Object("label", self) end
    function o:CreateLine() return Object("line", self) end
    function o:GetSize() return self.width, self.height end
    return o
end
CreateFrame = function(_, _, parent)
    local f = Object("frame", parent)
    frames[#frames + 1] = f
    return f
end
CreateVector2D = function(x, y) return {GetXY = function() return x, y end} end
SlashCmdList = {}
time = function() return 1792600000 end
GetZoneText = function() return "Durotar" end
GetSubZoneText = function() return "Razor Hill" end
GetBuildInfo = function() return "1.60.1", "test-build" end
local ns, playerMap, apiMode = {}, 1411, "live"
local syntheticInstances = {}
-- These synthetic IDs are mocks, not asserted client UI IDs.
C_Map = {
    GetWorldPosFromMapPos = function(id, p)
        if apiMode == "error" then error("unavailable") end
        if apiMode == "wrong" then return 999, CreateVector2D(0, 0) end
        local data = ns.Data.maps[syntheticInstances[id] or id]
        if not data then return end
        local x, y = p:GetXY()
        local f = data.sourceFrame
        return data.worldMapID, CreateVector2D(f.north-y*(f.north-f.south), f.west-x*(f.west-f.east))
    end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return CreateVector2D(0.52, 0.42) end,
}
for _, path in ipairs({"Data", "Geometry", "ExploreBorders"}) do
    assert(loadfile(path .. ".lua"))("ExploreBorders", ns)
end
local instanceCount = 0
for key in pairs(ns.Data.maps) do
    if key < 0 then instanceCount = instanceCount + 1; syntheticInstances[90000+instanceCount] = key end
end
assert(instanceCount == 11)
local event = frames[1]
local function Tick() event.scripts.OnUpdate(event, 0.2) end
local function Command(input) SlashCmdList.EXPLOREBORDERS(input) end
local function Refresh() event.scripts.OnEvent(event, "PLAYER_ENTERING_WORLD"); Tick() end
event.scripts.OnEvent(event, "ADDON_LOADED", "other")
assert(ExploreBordersDB == nil)
event.scripts.OnEvent(event, "ADDON_LOADED", "ExploreBorders")
Tick()
assert(#frames == 1, "Must tolerate late-loaded world map")
-- Simulate WoW loading the replacement Durotar addon and its saved variables.
DurotarBordersDB = {enabled = true, labels = false, marks = {{note = "old test", uiMapID = 1411}}}
local importer = {scripts = {OnEvent = function(_, _, name)
    if name == "DurotarBorders" then ExploreBorders_ImportLegacy(DurotarBordersDB) end
end}}
importer.scripts.OnEvent(importer, "ADDON_LOADED", "other")
assert(#ExploreBordersDB.marks == 0)
importer.scripts.OnEvent(importer, "ADDON_LOADED", "DurotarBorders")
assert(ExploreBordersDB.legacyImportDone and not ExploreBordersDB.labels)
assert(#ExploreBordersDB.marks == 1 and ExploreBordersDB.marks[1].note == "old test")
ExploreBordersDB.marks[1].note = "copied"
assert(DurotarBordersDB.marks[1].note == "old test", "Migration must not mutate legacy storage")
importer.scripts.OnEvent(importer, "ADDON_LOADED", "DurotarBorders")
assert(#ExploreBordersDB.marks == 1, "No duplicate imports")
local canvas = Object("canvas")
canvas.width, canvas.height = 1000, 666
WorldMapFrame = Object("map")
WorldMapFrame.mapID = 1411
WorldMapFrame.GetMapID = function(self) return self.mapID end
WorldMapFrame.GetCanvas = function() return canvas end
Tick()
local overlay = frames[#frames]
assert(overlay:IsShown() and overlay.mouse == false and overlay.parent == canvas)
assert(ns.activeMapID == 1411 and ns.visibleSegments > 600)
local function CheckClip()
    local n = 0
    for _, o in ipairs(objects) do
        if o.kind == "line" and o.shown then
            n = n + 1
            for _, p in ipairs({o.start, o.finish}) do
                assert(p[1] >= -0.00001 and p[1] <= canvas.width + 0.00001)
                assert(p[2] <= 0.00001 and p[2] >= -canvas.height - 0.00001)
            end
        end
    end
    assert(n == ns.visibleSegments)
end
CheckClip()
Command("labels")
assert(ExploreBordersDB.labels)
local maps, areas, rings, vertices = 0, 0, 0, 0
for id, data in pairs(ns.Data.maps) do
    if id > 0 then
        maps = maps + 1
        WorldMapFrame.mapID = id; Tick()
        assert(overlay:IsShown() and ns.activeMapID == id, data.name)
        assert(ns.visibleSegments > 0, data.name .. " has no visible edges")
        assert(ns.Resolve(id).source == "live client map frame", data.name)
        CheckClip()
        local created = #objects
        Tick()
        assert(#objects == created, "Steady-state polling must not allocate")
    end
    areas = areas + #data.areas
    for _, area in ipairs(data.areas) do
        rings = rings + #area.rings
        for _, ring in ipairs(area.rings) do vertices = vertices + #ring end
    end
end
assert(maps == 48 and areas == 812 and rings == 1014 and vertices == 25334)
-- Large-to-small map transitions must hide leftover lines and names.
WorldMapFrame.mapID = 1440; Tick(); local large = ns.visibleSegments
WorldMapFrame.mapID = 1453; Tick(); assert(ns.visibleSegments < large); CheckClip()
local validNames = {}
for _, area in ipairs(ns.Data.maps[1453].areas) do validNames[area.name] = true end
for _, o in ipairs(objects) do
    if o.kind == "label" and o.shown and o.text and not o.text:find("Explore Borders:",1,true) then
        assert(validNames[o.text], "Stale label from another map: " .. o.text)
    end
end
local created = #objects
canvas.width, canvas.height = 1500, 1000; Tick(); CheckClip()
assert(#objects == created)
for _, id in ipairs({1414, 1415, 947, 1455, 99999}) do
    WorldMapFrame.mapID = id; Tick()
    assert(not overlay:IsShown() and ns.activeMapID == nil and ns.visibleSegments == 0)
end
WorldMapFrame.mapID = 1454; Tick()
assert(ns.activeMapID == 1454 and ns.visibleSegments > 0, "Orgrimmar perimeter should be visible")
for _, o in ipairs(objects) do
    if o.kind == "line" and o.shown then assert(o.color[1] == 0.25, "Perimeter must be cyan") end
end
Command("perimeters"); assert(ns.visibleSegments == 0)
Command("perimeters"); assert(ns.visibleSegments > 0)
WorldMapFrame.mapID = 1412; Tick(); assert(overlay:IsShown())
WorldMapFrame:Hide(); Tick(); assert(not overlay:IsShown())
WorldMapFrame:Show(); Tick(); assert(overlay:IsShown())
Command("hide"); assert(not overlay:IsShown())
Command("show"); assert(overlay:IsShown())
Command("labels"); assert(not ExploreBordersDB.labels)
Command("labels"); assert(ExploreBordersDB.labels)
-- Player marks must use the player's zone, even when browsing a different map.
Command("mark before")
local mark = ExploreBordersDB.marks[#ExploreBordersDB.marks]
assert(mark.uiMapID == 1411 and mark.predicted[1] == "Razor Hill")
assert(mark.clientBuild == "test-build" and mark.note == "before")
assert(ns.activeMapID == 1412, "Marking must not move/misproject the displayed map")
local n = #ExploreBordersDB.marks
playerMap = 99999; Command("mark elsewhere"); assert(#ExploreBordersDB.marks == n)
playerMap = 1411
local positionAPI = C_Map.GetPlayerMapPosition
C_Map.GetPlayerMapPosition = function() return nil end
Command("mark unavailable"); assert(#ExploreBordersDB.marks == n)
C_Map.GetPlayerMapPosition = positionAPI
for i = 1, 205 do Command("mark " .. i) end
assert(#ExploreBordersDB.marks == 200 and ExploreBordersDB.marks[1].note == "6")
apiMode = "error"; Refresh()
for id in pairs(ns.Data.maps) do
    if id > 0 then assert(ns.Resolve(id).source == "published map frame (fallback)") end
end
Command("mark fallback"); assert(ExploreBordersDB.marks[200].predicted[1] == "Razor Hill")
apiMode = "wrong"; Refresh()
assert(ns.Resolve(1411).source == "published map frame (fallback)")
apiMode = "live"; Refresh()
for mockID, sourceID in pairs(syntheticInstances) do
    WorldMapFrame.mapID = mockID; Tick(); CheckClip()
    assert(overlay:IsShown() and ns.Resolve(mockID).data.key == sourceID)
    assert(ns.Resolve(mockID).source == "live client map frame")
end
apiMode = "error"; Refresh()
assert(not overlay:IsShown(), "Instance IDs cannot be guessed without a live transform")
assert(not ns.Resolve(-2998))
-- Retain the original clip/hole checks.
local G = ns.Geometry
assert(G.Clip(-1,-1,-0.5,-0.5) == nil)
local a,b,c,d = G.Clip(-1,0.5,2,0.5)
assert(a == 0 and b == 0.5 and c == 1 and d == 0.5)
local hole = {{{0,0},{4,0},{4,4},{0,4}},{{1,1},{1,3},{3,3},{3,1}}}
assert(G.Contains(hole,0.5,0.5) and not G.Contains(hole,2,2))
-- Reload: settings/marks survive, migration does not duplicate old marks.
local ns2 = {}
ExploreBordersDB.enabled = false
for _, path in ipairs({"Data", "Geometry", "ExploreBorders"}) do
    assert(loadfile(path .. ".lua"))("ExploreBorders", ns2)
end
local event2 = frames[#frames]
event2.scripts.OnEvent(event2,"ADDON_LOADED","ExploreBorders")
ExploreBorders_ImportLegacy(DurotarBordersDB)
assert(not ExploreBordersDB.enabled and #ExploreBordersDB.marks == 200)
realPrint("PASS: all 48 named maps, 812 subareas, 59 perimeters; live/fallback projection; 11 mock-resolved instances; cyan perimeter toggle; map-switch cleanup; clipping/resizing/pooling; marks independent of viewed map; one-time legacy migration; persisted settings")
