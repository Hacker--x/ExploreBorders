EXPLORE BORDERS 0.2.0 - WoW Forever / Interface 16001
Previously Durotar Borders.

INSTALL / UPGRADE
1. Exit WoW.
2. Remove the old DurotarBorders folder from Interface/AddOns if installed.
3. Extract the ExploreBorders folder into your Forever client's Interface/AddOns.
4. Start WoW and enable Explore Borders in the AddOns list.
5. Open a covered zone map. Gold lines are subareas; cyan lines are zone perimeters.

This standalone package contains only ExploreBorders. No legacy importer is
included or required. Existing ExploreBorders settings and marks are retained;
settings from the old DurotarBorders addon are not imported.

CONTROLS
/eborders             Toggle all outlines.
/eborders show        Turn outlines on.
/eborders hide        Turn outlines off.
/eborders labels      Toggle subarea names.
/eborders perimeters  Toggle cyan outer zone boundaries.
/eborders status      Show coverage/projection for the viewed map or your location.
/eborders mark note   Save your current location with an optional note.

/exploreborders and the old /dborders and /durotarborders commands also work.

COVERAGE
All geometry available in the retained source is included:
- 812 subareas across 47 named maps and two instance datasets.
- 59 outer zone perimeters, extending total coverage to 48 named maps plus
  11 instance datasets resolved through the live client map API.
- Includes the source's Mount Hyjal, Zephras Isle, Riverglades and Shen'dralas.
- Orgrimmar has a zone perimeter only. Some cities have only partial subarea data.
- Instances without known UI IDs are matched by their live world-map transform;
  their rendering has only been tested with simulated API responses.

COVERAGE.txt lists every map and count, including maps without supplied geometry.
This does not cover every map in WoW: Ironforge, Undercity and several interiors
have no geometry in this source. Continent/world overview maps do not draw the
zone detail layer. A blank map can mean missing data; use /eborders status.

TESTING IN GAME
Browse Durotar, Mulgore and Elwynn Forest and confirm the outlines change with
the map. Resize/zoom/pan to check alignment. Toggle names if the map is crowded.
Walk across an edge and compare the game's subzone name with the map outline.
Use '/eborders mark before' and '/eborders mark after' to record either side.
Marks always use your character's current map, even while viewing another zone.
For actual first-discovery credit, use an unexplored area and note the position
where the game awards credit or reveals fog. Previously explored characters can
still check subzone-name transitions. Marks are manual observations, not automatic
discovery-event capture. The latest 200 marks are retained.

New settings and marks are saved after /reload or normal logout in your account's
WTF/.../SavedVariables/ExploreBorders.lua. Old marks retain their original fields.

LIMITS
These are experimental TERRAIN boundaries. Durotar rendering was reported working
by the user; exact discovery-trigger accuracy has not been established. Other maps
still need live testing. The source does not identify a client build. Terrain
cells do not model cave/building interiors, height, floors, phases or server timing.
An instance's terrain perimeter is not a complete interior/floor exploration map.
Not every outlined subarea awards discovery XP or reveals fog. All included lines
remain visible regardless of exploration progress; this is not a completion tracker.

The live client map frame is used when consistent with the source. Known named
maps fall back to published frames if that API is unavailable. Instance placeholders
are never treated as real UI map IDs and require a working live transform.
Default Blizzard world map; replacements have not been tested. No runtime network
requests or companion libraries. Lines and names do not intercept mouse clicks.

VALIDATION
All 812 subareas and 59 perimeters match their source terrain-cell counts after
grid recovery. Automated Lua mock tests cover all 48 named maps, all 11 simulated
instance mappings, map-switch cleanup, clipping, resizing, pooled drawing objects,
colors/toggles, fallback transforms, player marks and one-time settings migration.
This is not a live-client verification of the added maps.
