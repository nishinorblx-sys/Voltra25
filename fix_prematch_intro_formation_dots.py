from pathlib import Path
import re

path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
text = path.read_text(encoding="utf-8")

new_block = '''local function positionFromEntry(entry: any): string
\tif type(entry) ~= "table" then return "" end
\treturn string.upper(tostring(entry.Position or entry.bestPosition or entry.position or entry.role or ""))
end

local function positionFromModel(model: Model?): string
\tif not model then return "" end
\treturn string.upper(tostring(model:GetAttribute("position") or model:GetAttribute("bestPosition") or ""))
end

local function lineGroupForPosition(position: string): string
\tif position == "GK" then return "GK" end
\tif position == "CB" or position == "LB" or position == "RB" or position == "LWB" or position == "RWB" then return "DEF" end
\tif position == "ST" or position == "CF" or position == "SS" or position == "LW" or position == "RW" then return "ATT" end
\treturn "MID"
end

local function roleKey(position: string): string
\tif position == "GK" then return "GK" end
\tif position == "LB" or position == "LWB" then return "LB" end
\tif position == "RB" or position == "RWB" then return "RB" end
\tif position == "CB" then return "CB" end
\tif position == "CDM" then return "CDM" end
\tif position == "CAM" then return "CAM" end
\tif position == "CM" then return "CM" end
\tif position == "LM" then return "LM" end
\tif position == "RM" then return "RM" end
\tif position == "LW" then return "LW" end
\tif position == "RW" then return "RW" end
\tif position == "ST" or position == "CF" or position == "SS" then return "ST" end
\treturn "OTHER"
end

local function spread(key: string, baseX: number, counts: any, seen: any): number
\tseen[key] = (seen[key] or 0) + 1
\tlocal count = counts[key] or 1
\tif count <= 1 then return baseX end
\tlocal gap = math.min(0.22, 0.68 / math.max(1, count - 1))
\treturn math.clamp(baseX + (seen[key] - (count + 1) / 2) * gap, 0.1, 0.9)
end

local function coordForPosition(position: string, counts: any, seen: any, index: number): Vector2
\tlocal key = roleKey(position)
\tif key == "GK" then return Vector2.new(0.50, 0.88) end
\tif key == "LB" then return Vector2.new(0.18, 0.69) end
\tif key == "RB" then return Vector2.new(0.82, 0.69) end
\tif key == "CB" then return Vector2.new(spread("CB", 0.50, counts, seen), 0.69) end
\tif key == "CDM" then return Vector2.new(spread("CDM", 0.50, counts, seen), 0.55) end
\tif key == "CM" then return Vector2.new(spread("CM", 0.50, counts, seen), 0.45) end
\tif key == "CAM" then return Vector2.new(spread("CAM", 0.50, counts, seen), 0.34) end
\tif key == "LM" then return Vector2.new(0.18, 0.36) end
\tif key == "RM" then return Vector2.new(0.82, 0.36) end
\tif key == "LW" then return Vector2.new(0.18, 0.23) end
\tif key == "RW" then return Vector2.new(0.82, 0.23) end
\tif key == "ST" then return Vector2.new(spread("ST", 0.50, counts, seen), 0.16) end
\treturn Vector2.new(0.18 + ((index - 1) % 4) * 0.21, 0.28 + math.floor((index - 1) / 4) * 0.18)
end

local function formationEntries(data: any, side: string): {any}
\tlocal models = sortedModels(data, side)
\tlocal players = lineupData(data, side)
\tlocal result = {}
\tfor index = 1, 11 do
\t\tlocal model = models[index]
\t\tlocal player = players[index]
\t\tlocal position = positionFromModel(model)
\t\tif position == "" then position = positionFromEntry(player) end
\t\tif position == "" then
\t\t\tlocal fallback = {"GK", "LB", "CB", "CB", "RB", "CDM", "CM", "CM", "LW", "ST", "RW"}
\t\t\tposition = fallback[index] or "CM"
\t\tend
\t\ttable.insert(result, {Model = model, Player = player, Position = position, Index = index})
\tend
\treturn result
end

local function groupRange(data: any, side: string, groupName: string, fallbackFirst: number, fallbackLast: number): (number, number)
\tlocal entries = formationEntries(data, side)
\tlocal first = nil
\tlocal last = nil
\tfor index, entry in entries do
\t\tif lineGroupForPosition(entry.Position) == groupName then
\t\t\tfirst = first or index
\t\t\tlast = index
\t\tend
\tend
\treturn first or fallbackFirst, last or fallbackLast
end

local function updateFormationDots(dots: {Frame}, data: any, side: string)
\tlocal entries = formationEntries(data, side)
\tlocal counts = {}
\tfor _, entry in entries do
\t\tlocal key = roleKey(entry.Position)
\t\tcounts[key] = (counts[key] or 0) + 1
\tend
\tlocal seen = {}
\tfor index, dot in dots do
\t\tlocal entry = entries[index]
\t\tlocal coord = coordForPosition(entry.Position, counts, seen, index)
\t\tdot.Position = UDim2.fromScale(coord.X, coord.Y)
\t\tdot:SetAttribute("VTRLineGroup", lineGroupForPosition(entry.Position))
\t\tdot:SetAttribute("VTRPosition", entry.Position)
\t\tdot.BackgroundColor3 = Theme.Colors.White
\t\tdot.Size = UDim2.fromOffset(11, 11)
\tend
end

local function formationDots(parent: Instance, data: any, side: string)
\tlocal dots = {}
\tfor index = 1, 11 do
\t\tlocal dot = Instance.new("Frame")
\t\tdot.AnchorPoint = Vector2.new(0.5, 0.5)
\t\tdot.Size = UDim2.fromOffset(11, 11)
\t\tdot.BackgroundColor3 = Theme.Colors.White
\t\tdot.BorderSizePixel = 0
\t\tdot.ZIndex = 207
\t\tdot.Parent = parent
\t\tlocal corner = Instance.new("UICorner")
\t\tcorner.CornerRadius = UDim.new(1, 0)
\t\tcorner.Parent = dot
\t\tlocal stroke = Instance.new("UIStroke")
\t\tstroke.Color = Theme.Colors.Electric
\t\tstroke.Transparency = 0.55
\t\tstroke.Thickness = 1
\t\tstroke.Parent = dot
\t\ttable.insert(dots, dot)
\tend
\tupdateFormationDots(dots, data, side)
\treturn dots
end'''

text = re.sub(
    r'local FORMATION_COORDS = \{.*?local function formationDots\(parent: Instance\).*?end\n',
    new_block + "\n",
    text,
    count=1,
    flags=re.S
)

text = re.sub(
    r'local function setLineHighlight\(dots: \{Frame\}, first: number, last: number\).*?end\n',
    '''local function setLineHighlight(dots: {Frame}, groupName: string, first: number, last: number)
\tfor index, dot in dots do
\t\tlocal active = dot:GetAttribute("VTRLineGroup") == groupName
\t\tif not active and groupName == "" then
\t\t\tactive = index >= first and index <= last
\t\tend
\t\tTweenService:Create(dot, TweenInfo.new(0.22), {
\t\t\tBackgroundColor3 = active and Theme.Colors.Electric or Theme.Colors.White,
\t\t\tSize = active and UDim2.fromOffset(16, 16) or UDim2.fromOffset(11, 11),
\t\t}):Play()
\tend
end
''',
    text,
    count=1,
    flags=re.S
)

text = text.replace(
    "local dots = formationDots(pitch)",
    'local dots = formationDots(pitch, data, "Home")'
)

text = text.replace(
    '''\tlocal lineGroups = {
\t\t{16.2, "HOME GOALKEEPER", "Home", 1, 1},
\t\t{20.1, "HOME DEFENDERS", "Home", 2, 5},
\t\t{24.0, "HOME MIDFIELDERS", "Home", 6, 8},
\t\t{27.9, "HOME ATTACKERS", "Home", 9, 11},
\t\t{36.0, "AWAY GOALKEEPER", "Away", 1, 1},
\t\t{39.9, "AWAY DEFENDERS", "Away", 2, 5},
\t\t{43.8, "AWAY MIDFIELDERS", "Away", 6, 8},
\t\t{47.7, "AWAY ATTACKERS", "Away", 9, 11},
\t}''',
    '''\tlocal lineGroups = {
\t\t{16.2, "HOME GOALKEEPER", "Home", 1, 1, "GK"},
\t\t{20.1, "HOME DEFENDERS", "Home", 2, 5, "DEF"},
\t\t{24.0, "HOME MIDFIELDERS", "Home", 6, 8, "MID"},
\t\t{27.9, "HOME ATTACKERS", "Home", 9, 11, "ATT"},
\t\t{36.0, "AWAY GOALKEEPER", "Away", 1, 1, "GK"},
\t\t{39.9, "AWAY DEFENDERS", "Away", 2, 5, "DEF"},
\t\t{43.8, "AWAY MIDFIELDERS", "Away", 6, 8, "MID"},
\t\t{47.7, "AWAY ATTACKERS", "Away", 9, 11, "ATT"},
\t}'''
)

text = text.replace(
    '''\t\t\tif side == "Away" and formationTitle.Text ~= shortCode(away) then
\t\t\t\tformationTitle.Text = shortCode(away)
\t\t\tend
\t\t\tsetLineHighlight(dots, group[4], group[5])
\t\t\tlocal list = sortedModels(data, side)
\t\t\tintroTitle.Text = group[2]
\t\t\tshowPlayerGroupPreview(groupPreview, list, lineupData(data, side), group[4], group[5])''',
    '''\t\t\tif side == "Away" and formationTitle.Text ~= shortCode(away) then
\t\t\t\tformationTitle.Text = shortCode(away)
\t\t\t\tupdateFormationDots(dots, data, side)
\t\t\telseif side == "Home" and formationTitle.Text ~= shortCode(home) then
\t\t\t\tformationTitle.Text = shortCode(home)
\t\t\t\tupdateFormationDots(dots, data, side)
\t\t\tend
\t\t\tsetLineHighlight(dots, group[6], group[4], group[5])
\t\t\tlocal list = sortedModels(data, side)
\t\t\tlocal players = lineupData(data, side)
\t\t\tlocal firstIndex, lastIndex = groupRange(data, side, group[6], group[4], group[5])
\t\t\tintroTitle.Text = group[2]
\t\t\tshowPlayerGroupPreview(groupPreview, list, players, firstIndex, lastIndex)'''
)

text = text.replace(
    '''\t\tformationTitle.Text = shortCode(away)
\t\tslideIn(formation, UDim2.fromScale(0.04, 0.13), UDim2.fromScale(-0.32, 0.13))''',
    '''\t\tformationTitle.Text = shortCode(away)
\t\tupdateFormationDots(dots, data, "Away")
\t\tslideIn(formation, UDim2.fromScale(0.04, 0.13), UDim2.fromScale(-0.32, 0.13))'''
)

path.write_text(text, encoding="utf-8", newline="\n")
print("prematch intro formation dots now use the actual squad formation")