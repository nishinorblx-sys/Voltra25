from pathlib import Path
import re

path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
text = path.read_text(encoding="utf-8")

new_block = '''local function cleanPosition(value: any): string
	local position = string.upper(tostring(value or ""))
	position = string.gsub(position, "%s+", "")
	if position == "GOALKEEPER" then return "GK" end
	if position == "FULLBACK" then return "FB" end
	if position == "LEFTBACK" then return "LB" end
	if position == "RIGHTBACK" then return "RB" end
	if position == "CENTREBACK" or position == "CENTERBACK" then return "CB" end
	if position == "DEFENSIVEMID" or position == "DEFENSIVEMIDFIELDER" then return "CDM" end
	if position == "ATTACKINGMID" or position == "ATTACKINGMIDFIELDER" then return "CAM" end
	if position == "LEFTMID" then return "LM" end
	if position == "RIGHTMID" then return "RM" end
	if position == "LEFTWING" then return "LW" end
	if position == "RIGHTWING" then return "RW" end
	if position == "STRIKER" or position == "FORWARD" then return "ST" end
	return position
end

local function positionFromEntry(entry: any): string
	if type(entry) ~= "table" then return "" end
	return cleanPosition(entry.Position or entry.position or entry.bestPosition or entry.BestPosition or entry.Pos or entry.pos or entry.Role or entry.role)
end

local function positionFromModel(model: Model?): string
	if not model then return "" end
	return cleanPosition(model:GetAttribute("position") or model:GetAttribute("bestPosition") or model:GetAttribute("Role") or model:GetAttribute("VTRRole"))
end

local function roleKey(position: string): string
	position = cleanPosition(position)
	if position == "GK" then return "GK" end
	if position == "LB" or position == "LWB" then return "LB" end
	if position == "RB" or position == "RWB" then return "RB" end
	if position == "CB" or position == "LCB" or position == "RCB" then return "CB" end
	if position == "CDM" or position == "DM" then return "CDM" end
	if position == "CAM" or position == "AM" then return "CAM" end
	if position == "CM" or position == "LCM" or position == "RCM" then return "CM" end
	if position == "LM" then return "LM" end
	if position == "RM" then return "RM" end
	if position == "LW" then return "LW" end
	if position == "RW" then return "RW" end
	if position == "ST" or position == "CF" or position == "SS" then return "ST" end
	if position == "WINGER" then return "WINGER" end
	if position == "FB" then return "FB" end
	return "OTHER"
end

local function lineGroupForPosition(position: string): string
	local key = roleKey(position)
	if key == "GK" then return "GK" end
	if key == "LB" or key == "RB" or key == "CB" or key == "FB" then return "DEF" end
	if key == "ST" then return "ATT" end
	return "MID"
end

local function formationRoleOrder(position: string): number
	local key = roleKey(position)
	local order = {
		GK = 1,
		LB = 2,
		FB = 3,
		CB = 4,
		RB = 5,
		CDM = 6,
		LM = 7,
		CM = 8,
		RM = 9,
		CAM = 10,
		LW = 11,
		WINGER = 12,
		RW = 13,
		ST = 14,
	}
	return order[key] or 20
end

local function formationGroupOrder(position: string): number
	local group = lineGroupForPosition(position)
	if group == "GK" then return 1 end
	if group == "DEF" then return 2 end
	if group == "MID" then return 3 end
	if group == "ATT" then return 4 end
	return 5
end

local function modelNameKey(model: Model?): string
	if not model then return "" end
	return string.lower(tostring(model:GetAttribute("DisplayName") or model.Name))
end

local function playerNameKey(player: any): string
	if type(player) ~= "table" then return "" end
	return string.lower(tostring(player.DisplayName or player.displayName or player.Name or player.name or player.playerName or player.shortName or ""))
end

local function formationEntries(data: any, side: string): {any}
	local models = sortedModels(data, side)
	local players = side == "Home" and (data.HomeLineup or {}) or (data.AwayLineup or {})
	local usedModels: {[Model]: boolean} = {}
	local result = {}
	for index = 1, 11 do
		local player = players[index]
		local position = positionFromEntry(player)
		local matched: Model? = nil
		local playerKey = playerNameKey(player)
		if playerKey ~= "" then
			for _, model in ipairs(models) do
				if not usedModels[model] and modelNameKey(model) == playerKey then
					matched = model
					break
				end
			end
		end
		if not matched then
			matched = models[index]
		end
		if matched then
			usedModels[matched] = true
		end
		if position == "" then position = positionFromModel(matched) end
		if position == "" then
			local fallback = {"GK", "LB", "CB", "CB", "RB", "CDM", "CM", "CAM", "LM", "RM", "ST"}
			position = fallback[index] or "CM"
		end
		table.insert(result, {Model = matched, Player = player, Position = position, OriginalIndex = index})
	end
	table.sort(result, function(a, b)
		local groupA = formationGroupOrder(a.Position)
		local groupB = formationGroupOrder(b.Position)
		if groupA ~= groupB then return groupA < groupB end
		local roleA = formationRoleOrder(a.Position)
		local roleB = formationRoleOrder(b.Position)
		if roleA ~= roleB then return roleA < roleB end
		return (a.OriginalIndex or 0) < (b.OriginalIndex or 0)
	end)
	return result
end

local function entriesForGroup(data: any, side: string, groupName: string): {any}
	local result = {}
	for _, entry in ipairs(formationEntries(data, side)) do
		if lineGroupForPosition(entry.Position) == groupName then
			table.insert(result, entry)
		end
	end
	return result
end

local function groupRange(data: any, side: string, groupName: string, fallbackFirst: number, fallbackLast: number): (number, number)
	local entries = formationEntries(data, side)
	local first = nil
	local last = nil
	for index, entry in ipairs(entries) do
		if lineGroupForPosition(entry.Position) == groupName then
			first = first or index
			last = index
		end
	end
	return first or fallbackFirst, last or fallbackLast
end

local function formationText(data: any, side: string): string
	local sideSetup = side == "Home" and data.HomeSetup or data.AwaySetup
	local function valid(value: any): string?
		if type(value) == "string" and value ~= "" then return value end
		return nil
	end
	return valid(side == "Home" and data.HomeFormation or data.AwayFormation)
		or valid(side == "Home" and data.HomeFormationName or data.AwayFormationName)
		or valid(sideSetup and sideSetup.Formation)
		or valid(sideSetup and sideSetup.formation)
		or valid(data.Formation)
		or valid(data.FormationName)
		or ""
end

local function formationSpecRows(name: string): {any}?
	local clean = string.upper(tostring(name or ""))
	clean = string.gsub(clean, "%s+", "")
	if string.find(clean, "4%-2%-3%-1") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 4, Y = .70},
			{Name = "DM", Count = 2, Y = .58},
			{Name = "AM", Count = 3, Y = .38},
			{Name = "FWD", Count = 1, Y = .17},
		}
	elseif string.find(clean, "4%-3%-3") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 4, Y = .70},
			{Name = "MID", Count = 3, Y = .50},
			{Name = "FWD", Count = 3, Y = .20},
		}
	elseif string.find(clean, "4%-4%-2") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 4, Y = .70},
			{Name = "MID", Count = 4, Y = .47},
			{Name = "FWD", Count = 2, Y = .20},
		}
	elseif string.find(clean, "3%-5%-2") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 3, Y = .70},
			{Name = "MID", Count = 5, Y = .47},
			{Name = "FWD", Count = 2, Y = .20},
		}
	elseif string.find(clean, "5%-3%-2") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 5, Y = .70},
			{Name = "MID", Count = 3, Y = .47},
			{Name = "FWD", Count = 2, Y = .20},
		}
	elseif string.find(clean, "3%-4%-3") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 3, Y = .70},
			{Name = "MID", Count = 4, Y = .48},
			{Name = "FWD", Count = 3, Y = .20},
		}
	end
	return nil
end

local function rowAccepts(rowName: string, position: string): boolean
	local key = roleKey(position)
	if rowName == "GK" then return key == "GK" end
	if rowName == "DEF" then return key == "LB" or key == "RB" or key == "CB" or key == "FB" end
	if rowName == "DM" then return key == "CDM" or key == "CM" end
	if rowName == "AM" then return key == "CAM" or key == "LM" or key == "RM" or key == "LW" or key == "RW" or key == "WINGER" end
	if rowName == "MID" then return key == "CDM" or key == "CM" or key == "CAM" or key == "LM" or key == "RM" end
	if rowName == "FWD" then return key == "ST" or key == "LW" or key == "RW" or key == "WINGER" end
	return false
end

local function horizontalOrder(rowName: string, entry: any): number
	local key = roleKey(entry.Position)
	if rowName == "DEF" then
		if key == "LB" then return 1 end
		if key == "FB" then return 2 end
		if key == "CB" then return 3 + (entry.OriginalIndex or 0) * .01 end
		if key == "RB" then return 8 end
	elseif rowName == "AM" or rowName == "MID" then
		if key == "LM" or key == "LW" then return 1 end
		if key == "CDM" then return 2 end
		if key == "CM" then return 3 end
		if key == "CAM" then return 4 end
		if key == "WINGER" then return 5 + (entry.OriginalIndex or 0) * .01 end
		if key == "RM" or key == "RW" then return 8 end
	elseif rowName == "DM" then
		if key == "CDM" then return 2 + (entry.OriginalIndex or 0) * .01 end
		if key == "CM" then return 3 + (entry.OriginalIndex or 0) * .01 end
	elseif rowName == "FWD" then
		if key == "LW" then return 1 end
		if key == "ST" then return 4 + (entry.OriginalIndex or 0) * .01 end
		if key == "RW" then return 8 end
	end
	return 5 + (entry.OriginalIndex or 0) * .01
end

local function sortRow(rowName: string, row: {any})
	table.sort(row, function(a, b)
		local ax = horizontalOrder(rowName, a)
		local bx = horizontalOrder(rowName, b)
		if ax ~= bx then return ax < bx end
		return (a.OriginalIndex or 0) < (b.OriginalIndex or 0)
	end)
end

local function xFor(rowName: string, index: number, count: number): number
	if count <= 1 then return .50 end
	if rowName == "DEF" and count == 4 then
		local values = {.18, .39, .61, .82}
		return values[index] or .50
	elseif rowName == "DEF" and count == 5 then
		local values = {.12, .30, .50, .70, .88}
		return values[index] or .50
	elseif rowName == "DEF" and count == 3 then
		local values = {.28, .50, .72}
		return values[index] or .50
	elseif rowName == "DM" and count == 2 then
		local values = {.38, .62}
		return values[index] or .50
	elseif rowName == "AM" and count == 3 then
		local values = {.20, .50, .80}
		return values[index] or .50
	elseif rowName == "FWD" and count == 3 then
		local values = {.22, .50, .78}
		return values[index] or .50
	elseif rowName == "FWD" and count == 2 then
		local values = {.40, .60}
		return values[index] or .50
	end
	return .16 + (index - 1) * (.68 / math.max(1, count - 1))
end

local function takeRow(entries: {any}, used: any, rowName: string, count: number, y: number): any
	local row = {}
	for _, entry in ipairs(entries) do
		if not used[entry] and rowAccepts(rowName, entry.Position) and #row < count then
			used[entry] = true
			table.insert(row, entry)
		end
	end
	for _, entry in ipairs(entries) do
		if not used[entry] and #row < count then
			used[entry] = true
			table.insert(row, entry)
		end
	end
	sortRow(rowName, row)
	return {Name = rowName, Entries = row, Y = y}
end

local function dynamicRows(entries: {any}): {any}
	local rowsByName = {GK = {}, DEF = {}, DM = {}, MID = {}, AM = {}, FWD = {}}
	local hasAM = false
	for _, entry in ipairs(entries) do
		local key = roleKey(entry.Position)
		if key == "CAM" or key == "LM" or key == "RM" or key == "LW" or key == "RW" or key == "WINGER" then
			hasAM = true
		end
	end
	for _, entry in ipairs(entries) do
		local key = roleKey(entry.Position)
		local rowName = "MID"
		if key == "GK" then
			rowName = "GK"
		elseif key == "LB" or key == "RB" or key == "CB" or key == "FB" then
			rowName = "DEF"
		elseif key == "ST" then
			rowName = "FWD"
		elseif key == "CAM" or key == "LM" or key == "RM" or key == "LW" or key == "RW" or key == "WINGER" then
			rowName = "AM"
		elseif key == "CDM" or (key == "CM" and hasAM) then
			rowName = "DM"
		end
		table.insert(rowsByName[rowName], entry)
	end
	local output = {}
	local order = {
		{Name = "GK", Y = .88},
		{Name = "DEF", Y = .70},
		{Name = "DM", Y = .58},
		{Name = "MID", Y = .48},
		{Name = "AM", Y = .38},
		{Name = "FWD", Y = .17},
	}
	for _, spec in ipairs(order) do
		local row = rowsByName[spec.Name]
		if row and #row > 0 then
			sortRow(spec.Name, row)
			table.insert(output, {Name = spec.Name, Entries = row, Y = spec.Y})
		end
	end
	return output
end

local function buildDotRows(data: any, side: string): {any}
	local entries = formationEntries(data, side)
	local specRows = formationSpecRows(formationText(data, side))
	if not specRows then
		return dynamicRows(entries)
	end
	local used = {}
	local rows = {}
	for _, spec in ipairs(specRows) do
		table.insert(rows, takeRow(entries, used, spec.Name, spec.Count, spec.Y))
	end
	for _, entry in ipairs(entries) do
		if not used[entry] then
			local key = roleKey(entry.Position)
			local rowName = key == "ST" and "FWD" or lineGroupForPosition(entry.Position) == "DEF" and "DEF" or "MID"
			table.insert(rows, {Name = rowName, Entries = {entry}, Y = rowName == "FWD" and .17 or rowName == "DEF" and .70 or .48})
		end
	end
	return rows
end

local function updateFormationDots(dots: {Frame}, data: any, side: string)
	local rows = buildDotRows(data, side)
	local dotIndex = 1
	for _, row in ipairs(rows) do
		local count = #row.Entries
		for rowIndex, entry in ipairs(row.Entries) do
			local dot = dots[dotIndex]
			if dot then
				dot.Position = UDim2.fromScale(xFor(row.Name, rowIndex, count), row.Y)
				dot:SetAttribute("VTRLineGroup", lineGroupForPosition(entry.Position))
				dot:SetAttribute("VTRPosition", entry.Position)
				dot:SetAttribute("VTRShapeRow", row.Name)
				dot.BackgroundColor3 = Theme.Colors.White
				dot.Size = UDim2.fromOffset(11, 11)
				dot.Visible = true
			end
			dotIndex += 1
		end
	end
	for index = dotIndex, #dots do
		dots[index].Visible = false
	end
end

'''

pattern = r'local function positionFromEntry\(entry: any\): string.*?local function formationDots'
new_text, count = re.subn(pattern, new_block + "local function formationDots", text, count=1, flags=re.S)

if count == 0:
	print("could not patch prematch formation functions")
else:
	path.write_text(new_text, encoding="utf-8", newline="\n")
	print("fixed prematch dots to follow squad-builder formation shape")