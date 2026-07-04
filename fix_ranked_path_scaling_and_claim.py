from pathlib import Path
import re

root = Path.cwd()

for rel in [
	"src/client/Services/RankedStatsPanelFixClient.lua",
	"src/client/RankedStatsPanelFix.client.lua",
	"src/client/Services/RankedPathUiFixClient.lua",
	"src/client/RankedPathUiFix.client.lua",
	"src/client/Services/RankedPathHardFixClient.lua",
]:
	path = root / rel
	if path.exists():
		path.unlink()
		print("removed", rel)

app = root / "src/client/App.lua"
if app.exists():
	text = app.read_text(encoding="utf-8", errors="ignore")
	text = text.replace('pcall(function() require(script.Parent.Services.RankedPathHardFixClient) end)', "")
	text = re.sub(r"\n\s*\n\s*\n", "\n\n", text)
	app.write_text(text.strip() + "\n", encoding="utf-8")
	print("cleaned src/client/App.lua")

ranked = root / "src/client/Pages/RankedPage.lua"
text = ranked.read_text(encoding="utf-8", errors="ignore")

for name in [
	"vtrRankedPathDirectFix",
	"vtrStartRankedPathDirectFix",
	"vtrSafeRankNumber",
	"vtrRankedPathData",
	"vtrFixPathStatText",
	"vtrIsRankedUiRoot",
	"vtrFixRankedRogueText",
	"vtrStabilizeRankedPathNumberFrames",
	"vtrStartRankedPathFrameStabilizer",
]:
	text = re.sub(r"\nlocal function " + name + r"\(.*?\nend\s*", "\n", text, flags=re.S)
	text = re.sub(r"\n\s*" + name + r"\([^\n]*\)\s*", "\n", text)

text = text.replace("SEVEN-GAME PATH", "DIVISION PATH")
text = text.replace("7-GAME PATH", "DIVISION PATH")
text = text.replace("SEVEN GAME PATH", "DIVISION PATH")
text = text.replace("7 GAME PATH", "DIVISION PATH")
text = text.replace("Seven-Game Path", "Division Path")
text = text.replace("7-Game Path", "Division Path")
text = text.replace("Seven Game Path", "Division Path")
text = text.replace("7 Game Path", "Division Path")

helper = r'''
local function vtrStabilizeRankedPathNumberFrames(root)
	if not root then
		return
	end

	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local function lower(value)
		return string.lower(tostring(value or ""))
	end

	local function isText(obj)
		return obj:IsA("TextLabel") or obj:IsA("TextButton")
	end

	local function textValue(obj)
		if isText(obj) then
			return tostring(obj.Text or "")
		end
		return ""
	end

	local function findFrameByHeader(headerText)
		for _, obj in ipairs(root:GetDescendants()) do
			if isText(obj) and lower(textValue(obj)) == lower(headerText) then
				local current = obj.Parent
				while current and current ~= root do
					if current:IsA("GuiObject") then
						return current
					end
					current = current.Parent
				end
				return obj.Parent
			end
		end

		return nil
	end

	local function findNumberLabel(frame)
		if not frame then
			return nil
		end

		local best

		for _, obj in ipairs(frame:GetDescendants()) do
			if isText(obj) then
				local clean = string.gsub(textValue(obj), "%s+", "")
				if string.match(clean, "^%d+$") then
					best = obj
				end
			end
		end

		return best
	end

	local function fixNumber(label, value)
		if not label then
			return
		end

		label.Text = tostring(value)
		label.Visible = true
		label.TextTransparency = 0
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 0)
		label.Position = UDim2.new(0, 0, 0.43, 0)
		label.Size = UDim2.new(1, 0, 0.52, 0)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.TextScaled = false
		label.TextWrapped = false
		label.TextSize = 30
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.ZIndex = math.max(label.ZIndex, 50)
	end

	local function pathStatsFromRecord()
		for _, obj in ipairs(root:GetDescendants()) do
			if isText(obj) then
				local wins, draws, losses = string.match(textValue(obj), "(%d+)%s*W%s*/%s*(%d+)%s*D%s*/%s*(%d+)%s*L")
				if wins and draws and losses then
					return tonumber(wins) or 0, tonumber(losses) or 0
				end
			end
		end

		local wins = tonumber(player:GetAttribute("PathWins")) or tonumber(player:GetAttribute("DivisionPathWins")) or 0
		local losses = tonumber(player:GetAttribute("PathLosses")) or tonumber(player:GetAttribute("DivisionPathLosses")) or 0
		return wins, losses
	end

	local function hideClaimIfNotReady()
		local wins = tonumber(player:GetAttribute("PathWins")) or tonumber(player:GetAttribute("DivisionPathWins")) or 0
		local losses = tonumber(player:GetAttribute("PathLosses")) or tonumber(player:GetAttribute("DivisionPathLosses")) or 0
		local games = tonumber(player:GetAttribute("PathGames")) or tonumber(player:GetAttribute("DivisionPathGames")) or wins + losses

		if games >= 7 then
			return
		end

		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local name = lower(obj.Name)
				local text = isText(obj) and lower(textValue(obj)) or ""

				if string.find(name, "claim") or string.find(text, "claim") or string.find(text, "claimed") then
					obj.Visible = false
					if isText(obj) then
						obj.TextTransparency = 1
					end
					if obj:IsA("TextButton") then
						obj.Active = false
						obj.AutoButtonColor = false
					end
				end
			end
		end
	end

	local wins, losses = pathStatsFromRecord()
	local winsFrame = findFrameByHeader("PATH WINS")
	local lossesFrame = findFrameByHeader("PATH LOSSES")

	fixNumber(findNumberLabel(winsFrame), wins)
	fixNumber(findNumberLabel(lossesFrame), losses)
	hideClaimIfNotReady()
end

local function vtrStartRankedPathFrameStabilizer(root)
	task.defer(function()
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer

		local function run()
			vtrStabilizeRankedPathNumberFrames(root)
		end

		for _ = 1, 60 do
			if not root.Parent then
				return
			end
			run()
			task.wait(0.1)
		end

		for _, attr in ipairs({ "PathWins", "PathLosses", "PathGames", "DivisionPathWins", "DivisionPathLosses", "DivisionPathGames" }) do
			player:GetAttributeChangedSignal(attr):Connect(run)
		end

		root.DescendantAdded:Connect(function()
			task.defer(run)
		end)

		while root.Parent do
			run()
			task.wait(0.5)
		end
	end)
end
'''

matches = list(re.finditer(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*.*require\(.*\)", text))
insert_at = matches[-1].end() if matches else 0
text = text[:insert_at] + "\n" + helper.strip() + "\n" + text[insert_at:]

if "vtrStartRankedPathFrameStabilizer(gui)" not in text:
	text = re.sub(
		r"(return\s+gui\s*$)",
		"vtrStartRankedPathFrameStabilizer(gui)\n\n\\1",
		text,
		flags=re.M
	)

ranked.write_text(text.strip() + "\n", encoding="utf-8")
print("patched src/client/Pages/RankedPage.lua")

service = root / "src/server/Services/SevenWinLoginRewardService.lua"
if service.exists():
	text = service.read_text(encoding="utf-8", errors="ignore")

	text = re.sub(
		r"local store = DataStoreService:GetDataStore\([^\n]+\)",
		'local store = DataStoreService:GetDataStore(Config.ClaimKey .. "_Path_v7")',
		text
	)

	text = re.sub(
		r"local function getPathWins\(player\).*?\nend",
		r'''local function getPathWins(player)
	local wins = getWins(player)
	local state = readState(player)
	local claimedWins = tonumber(state.claimedWins) or 0

	if claimedWins > wins then
		claimedWins = wins
		state.claimedWins = wins
		writeState(player, state)
	end

	return math.max(0, wins - claimedWins), wins, state
end''',
		text,
		flags=re.S
	)

	text = re.sub(
		r"state\.claimedWins\s*=\s*totalWins",
		"state.claimedWins = getWins(player)",
		text
	)

	if 'player:SetAttribute("PathWins", 0)' not in text:
		text = text.replace(
			"pendingByUserId[player.UserId] = nil\n\n\treturn true, pending.rewards",
			'''pendingByUserId[player.UserId] = nil

	player:SetAttribute("PathWins", 0)
	player:SetAttribute("PathLosses", 0)
	player:SetAttribute("PathGames", 0)
	player:SetAttribute("DivisionPathWins", 0)
	player:SetAttribute("DivisionPathLosses", 0)
	player:SetAttribute("DivisionPathGames", 0)

	return true, pending.rewards'''
		)

	service.write_text(text.strip() + "\n", encoding="utf-8")
	print("patched src/server/Services/SevenWinLoginRewardService.lua")