from pathlib import Path
import re

root = Path.cwd()

for rel in [
	"src/client/Services/RankedStatsPanelFixClient.lua",
	"src/client/RankedStatsPanelFix.client.lua",
	"src/client/Services/RankedPathUiFixClient.lua",
	"src/client/RankedPathUiFix.client.lua",
]:
	path = root / rel
	if path.exists():
		path.unlink()
		print("removed", rel)

ranked_page = root / "src/client/Pages/RankedPage.lua"
if ranked_page.exists():
	text = ranked_page.read_text(encoding="utf-8", errors="ignore")

	for name in [
		"vtrRankedPathDirectFix",
		"vtrStartRankedPathDirectFix",
		"vtrSafeRankNumber",
		"vtrRankedPathData",
		"vtrFixPathStatText",
		"vtrIsRankedUiRoot",
		"vtrFixRankedRogueText",
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

	ranked_page.write_text(text.strip() + "\n", encoding="utf-8")
	print("cleaned src/client/Pages/RankedPage.lua")

service = root / "src/client/Services/RankedPathHardFixClient.lua"
service.parent.mkdir(parents=True, exist_ok=True)

service.write_text(r'''
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local RankedPathHardFixClient = {}

local started = false
local overlayGui = nil
local fixedRoot = nil
local fixedPositions = nil
local accumulator = 0

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function isLabel(obj)
	return obj:IsA("TextLabel") or obj:IsA("TextButton")
end

local function textOf(obj)
	if isLabel(obj) then
		return tostring(obj.Text or "")
	end
	return ""
end

local function clean(value)
	return string.gsub(tostring(value or ""), "%s+", "")
end

local function getOverlay()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	if overlayGui and overlayGui.Parent then
		return overlayGui
	end

	overlayGui = Instance.new("ScreenGui")
	overlayGui.Name = "VTRRankedPathHardFixGui"
	overlayGui.IgnoreGuiInset = true
	overlayGui.ResetOnSpawn = false
	overlayGui.DisplayOrder = 19000
	overlayGui.Parent = playerGui

	return overlayGui
end

local function findText(root, value)
	for _, obj in ipairs(root:GetDescendants()) do
		if isLabel(obj) and lower(textOf(obj)) == lower(value) then
			return obj
		end
	end

	return nil
end

local function findRankedRoot(playerGui)
	local pathRecord = findText(playerGui, "PATH RECORD")
	if not pathRecord then
		return nil
	end

	local best = pathRecord.Parent
	local current = pathRecord.Parent

	while current and current ~= playerGui do
		if current:IsA("GuiObject") then
			local hasDivision = false
			local hasGames = false
			local hasGoalDiff = false

			for _, obj in ipairs(current:GetDescendants()) do
				if isLabel(obj) then
					local text = lower(textOf(obj))
					if string.find(text, "division") then
						hasDivision = true
					elseif text == "games" then
						hasGames = true
					elseif text == "goal difference" then
						hasGoalDiff = true
					end
				end
			end

			if hasDivision and hasGames and hasGoalDiff then
				best = current
			end
		end

		current = current.Parent
	end

	return best
end

local function parseRecord(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if isLabel(obj) then
			local wins, draws, losses = string.match(textOf(obj), "(%d+)%s*W%s*/%s*(%d+)%s*D%s*/%s*(%d+)%s*L")
			if wins and draws and losses then
				return obj, tonumber(wins) or 0, tonumber(draws) or 0, tonumber(losses) or 0
			end
		end
	end

	local wins = tonumber(localPlayer:GetAttribute("PathWins")) or tonumber(localPlayer:GetAttribute("DivisionPathWins")) or 0
	local losses = tonumber(localPlayer:GetAttribute("PathLosses")) or tonumber(localPlayer:GetAttribute("DivisionPathLosses")) or 0

	return nil, wins, 0, losses
end

local function makeOverlayLabel(name)
	local gui = getOverlay()
	if not gui then
		return nil
	end

	local label = gui:FindFirstChild(name)
	if label then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.TextScaled = false
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Size = UDim2.fromOffset(150, 48)
	label.ZIndex = 9999
	label.Parent = gui

	return label
end

local function sameRoot(root)
	return fixedRoot == root and fixedRoot and fixedRoot.Parent ~= nil
end

local function lockPositions(root, recordLabel)
	if not root or not recordLabel then
		return
	end

	if sameRoot(root) and fixedPositions then
		return
	end

	local winsHeader = findText(root, "PATH WINS")
	local lossesHeader = findText(root, "PATH LOSSES")

	if not winsHeader or not lossesHeader then
		return
	end

	fixedRoot = root
	fixedPositions = {
		wins = Vector2.new(winsHeader.AbsolutePosition.X, recordLabel.AbsolutePosition.Y),
		losses = Vector2.new(lossesHeader.AbsolutePosition.X, recordLabel.AbsolutePosition.Y),
	}
end

local function hideOriginalPathDigits(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if isLabel(obj) then
			local raw = clean(textOf(obj))
			if string.match(raw, "^%d+$") and obj.AbsoluteSize.X < 190 and obj.AbsoluteSize.Y < 90 then
				local name = lower(obj.Name)
				local parentName = lower(obj.Parent and obj.Parent.Name or "")
				if string.find(name, "path") or string.find(parentName, "path") or string.find(name, "wins") or string.find(parentName, "wins") or string.find(name, "losses") or string.find(parentName, "losses") then
					obj.Visible = false
					obj.TextTransparency = 1
				end
			end
		end
	end
end

local function updatePathValues(root)
	local recordLabel, wins, draws, losses = parseRecord(root)
	lockPositions(root, recordLabel)

	if recordLabel then
		recordLabel.Text = tostring(wins) .. "W / " .. tostring(draws) .. "D / " .. tostring(losses) .. "L"
	end

	hideOriginalPathDigits(root)

	if not fixedPositions then
		return
	end

	local winsLabel = makeOverlayLabel("VTRStablePathWins")
	local lossesLabel = makeOverlayLabel("VTRStablePathLosses")

	if winsLabel then
		winsLabel.Position = UDim2.fromOffset(fixedPositions.wins.X, fixedPositions.wins.Y)
		winsLabel.Text = tostring(wins)
		winsLabel.Visible = root.Visible
	end

	if lossesLabel then
		lossesLabel.Position = UDim2.fromOffset(fixedPositions.losses.X, fixedPositions.losses.Y)
		lossesLabel.Text = tostring(losses)
		lossesLabel.Visible = root.Visible
	end
end

local function pathGames(root)
	local _, wins, _, losses = parseRecord(root)
	local games = tonumber(localPlayer:GetAttribute("PathGames")) or tonumber(localPlayer:GetAttribute("DivisionPathGames")) or wins + losses
	return games
end

local function hideClaim(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("GuiObject") then
			local name = lower(obj.Name)
			local text = isLabel(obj) and lower(textOf(obj)) or ""

			if string.find(name, "claim") or string.find(text, "claim") or string.find(text, "claimed") then
				obj.Visible = false

				if obj:IsA("TextButton") then
					obj.Active = false
					obj.AutoButtonColor = false
				end

				if isLabel(obj) then
					obj.TextTransparency = 1
				end
			end
		end
	end
end

local function hookClaim(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextButton") then
			local name = lower(obj.Name)
			local text = lower(textOf(obj))

			if string.find(name, "claim") or string.find(text, "claim") or string.find(text, "claimed") then
				if obj:GetAttribute("VTRHardClaimHook") ~= true then
					obj:SetAttribute("VTRHardClaimHook", true)

					obj.MouseButton1Click:Connect(function()
						task.delay(0.2, function()
							localPlayer:SetAttribute("PathWins", 0)
							localPlayer:SetAttribute("PathLosses", 0)
							localPlayer:SetAttribute("PathGames", 0)
							localPlayer:SetAttribute("DivisionPathWins", 0)
							localPlayer:SetAttribute("DivisionPathLosses", 0)
							localPlayer:SetAttribute("DivisionPathGames", 0)
							hideClaim(root)
						end)
					end)
				end
			end
		end
	end
end

function RankedPathHardFixClient.Fix()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local root = findRankedRoot(playerGui)
	if not root then
		return
	end

	updatePathValues(root)
	hookClaim(root)

	if pathGames(root) < 7 then
		hideClaim(root)
	end

	if root:IsA("ScrollingFrame") then
		root.CanvasPosition = Vector2.new(0, 0)
	end
end

function RankedPathHardFixClient.Start()
	if started then
		return
	end

	started = true

	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.05 then
			accumulator = 0
			RankedPathHardFixClient.Fix()
		end
	end)

	task.defer(function()
		for _ = 1, 80 do
			RankedPathHardFixClient.Fix()
			task.wait(0.05)
		end
	end)
end

RankedPathHardFixClient.Start()

return RankedPathHardFixClient
'''.strip() + "\n", encoding="utf-8")

app_path = root / "src/client/App.lua"
if app_path.exists():
	text = app_path.read_text(encoding="utf-8", errors="ignore")

	line = 'pcall(function() require(script.Parent.Services.RankedPathHardFixClient) end)'
	if line not in text:
		insert_at = 0
		matches = list(re.finditer(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=", text))
		if matches:
			insert_at = matches[-1].end()
		text = text[:insert_at] + "\n" + line + "\n" + text[insert_at:]

	app_path.write_text(text.strip() + "\n", encoding="utf-8")
	print("patched src/client/App.lua")

server_service = root / "src/server/Services/SevenWinLoginRewardService.lua"
if server_service.exists():
	text = server_service.read_text(encoding="utf-8", errors="ignore")
	text = re.sub(
		r"local store = DataStoreService:GetDataStore\([^\n]+\)",
		'local store = DataStoreService:GetDataStore(Config.ClaimKey .. "_Path_v6")',
		text
	)
	text = re.sub(r"state\.claimedWins\s*=\s*totalWins", "state.claimedWins = getWins(player)", text)
	server_service.write_text(text.strip() + "\n", encoding="utf-8")
	print("patched src/server/Services/SevenWinLoginRewardService.lua")

for path in (root / "src/server").rglob("*.lua"):
	text = path.read_text(encoding="utf-8", errors="ignore")
	original = text

	text = re.sub(
		r"([A-Za-z_][A-Za-z0-9_\.]*)\.RewardClaimed\s*=\s*true",
		lambda m: m.group(0) + "\n" + "\t" + m.group(1) + ".PathWins = 0\n" + "\t" + m.group(1) + ".PathLosses = 0\n" + "\t" + m.group(1) + ".PathGames = 0",
		text
	)

	text = text.replace(".PathWins = 0\n\t.PathWins = 0", ".PathWins = 0")

	if text != original:
		path.write_text(text.strip() + "\n", encoding="utf-8")
		print("patched", path.relative_to(root).as_posix())

print("patched src/client/Services/RankedPathHardFixClient.lua")