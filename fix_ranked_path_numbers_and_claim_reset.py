from pathlib import Path
import re

root = Path.cwd()

old_files = [
	root / "src/client/Services/RankedStatsPanelFixClient.lua",
	root / "src/client/RankedStatsPanelFix.client.lua",
]

for path in old_files:
	if path.exists():
		path.unlink()
		print("removed", path.relative_to(root).as_posix())

ranked_page = root / "src/client/Pages/RankedPage.lua"
if ranked_page.exists():
	text = ranked_page.read_text(encoding="utf-8", errors="ignore")

	text = re.sub(r"\nlocal function vtrSafeRankNumber\(value\).*?\nend\s*\n\s*local function vtrRankedPathData\(value\).*?\nend\s*\n\s*local function vtrFixPathStatText\(root, rankedData\).*?\nend\s*", "\n", text, flags=re.S)
	text = re.sub(r"\n\s*vtrFixPathStatText\([^\n]*\)\s*", "\n", text)
	text = text.replace("Seven-Game Path", "Division Path")
	text = text.replace("7-Game Path", "Division Path")
	text = text.replace("Seven Game Path", "Division Path")
	text = text.replace("7 Game Path", "Division Path")
	text = text.replace("SEVEN-GAME PATH", "DIVISION PATH")
	text = text.replace("7-GAME PATH", "DIVISION PATH")
	text = text.replace("SEVEN GAME PATH", "DIVISION PATH")
	text = text.replace("7 GAME PATH", "DIVISION PATH")

	ranked_page.write_text(text.strip() + "\n", encoding="utf-8")
	print("cleaned src/client/Pages/RankedPage.lua")

fix_client = root / "src/client/Services/RankedPathUiFixClient.lua"
fix_client.parent.mkdir(parents=True, exist_ok=True)

fix_client.write_text(r'''
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local RankedPathUiFixClient = {}

local started = false
local accumulator = 0

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function isText(obj, text)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
		return false
	end

	return lower(obj.Text) == lower(text)
end

local function findHeader(playerGui, text)
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if isText(obj, text) then
			return obj
		end
	end

	return nil
end

local function findRankedRoot(playerGui)
	local record = findHeader(playerGui, "PATH RECORD")
	if not record then
		return nil
	end

	local current = record.Parent
	local best = current

	while current and current ~= playerGui do
		if current:IsA("GuiObject") then
			local hasDivision = false
			local hasGames = false

			for _, obj in ipairs(current:GetDescendants()) do
				if obj:IsA("TextLabel") or obj:IsA("TextButton") then
					local text = lower(obj.Text)
					if string.find(text, "division") then
						hasDivision = true
					elseif text == "games" then
						hasGames = true
					end
				end
			end

			if hasDivision and hasGames then
				best = current
			end
		end

		current = current.Parent
	end

	return best
end

local function findRecord(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local wins, draws, losses = string.match(tostring(obj.Text or ""), "(%d+)%s*W%s*/%s*(%d+)%s*D%s*/%s*(%d+)%s*L")
			if wins and draws and losses then
				return obj, tonumber(wins) or 0, tonumber(draws) or 0, tonumber(losses) or 0
			end
		end
	end

	return nil, tonumber(localPlayer:GetAttribute("PathWins")) or 0, 0, tonumber(localPlayer:GetAttribute("PathLosses")) or 0
end

local function findClaimObjects(root)
	local out = {}

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("Frame") then
			local text = obj:IsA("TextLabel") or obj:IsA("TextButton") and lower(obj.Text) or ""
			local name = lower(obj.Name)

			if string.find(text, "claim") or string.find(text, "claimed") or string.find(name, "claim") or string.find(name, "claimed") then
				table.insert(out, obj)
			end
		end
	end

	return out
end

local function makeStable(root, name)
	local label = root:FindFirstChild(name)

	if label and label:IsA("TextLabel") then
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
	label.ZIndex = 999
	label.Parent = root

	return label
end

local function rel(root, pos)
	return Vector2.new(pos.X - root.AbsolutePosition.X, pos.Y - root.AbsolutePosition.Y)
end

local function place(label, root, header, value, y)
	if not header then
		return
	end

	local p = rel(root, Vector2.new(header.AbsolutePosition.X, y))
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromOffset(p.X, p.Y)
	label.Size = UDim2.fromOffset(160, 48)
	label.Text = tostring(value)
	label.Visible = true
	label.TextTransparency = 0
end

local function hideBadDigits(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Name ~= "VTRPathWinsStable" and obj.Name ~= "VTRPathLossesStable" then
				local clean = string.gsub(tostring(obj.Text or ""), "%s+", "")

				if string.match(clean, "^%d+$") then
					local pos = obj.AbsolutePosition
					local size = obj.AbsoluteSize
					local nearTopPanel = size.X < 180 and size.Y < 90

					if nearTopPanel then
						local current = obj.Parent
						local isRanked = false

						while current and current ~= root.Parent do
							if current == root then
								isRanked = true
								break
							end
							current = current.Parent
						end

						if isRanked then
							obj.Visible = false
							obj.TextTransparency = 1
						end
					end
				end
			end
		end
	end
end

local function fixClaim(root)
	local wins = tonumber(localPlayer:GetAttribute("PathWins")) or tonumber(localPlayer:GetAttribute("DivisionPathWins")) or 0
	local losses = tonumber(localPlayer:GetAttribute("PathLosses")) or tonumber(localPlayer:GetAttribute("DivisionPathLosses")) or 0
	local games = tonumber(localPlayer:GetAttribute("PathGames")) or tonumber(localPlayer:GetAttribute("DivisionPathGames")) or (wins + losses)

	if games < 7 then
		for _, obj in ipairs(findClaimObjects(root)) do
			obj.Visible = false
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				obj.TextTransparency = 1
				obj.Active = false
			end
		end
	end
end

function RankedPathUiFixClient.Fix()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local root = findRankedRoot(playerGui)
	if not root or not root:IsA("GuiObject") then
		return
	end

	local recordLabel, wins, _, losses = findRecord(root)
	local winsHeader = findHeader(root, "PATH WINS")
	local lossesHeader = findHeader(root, "PATH LOSSES")

	if not recordLabel then
		return
	end

	local y = recordLabel.AbsolutePosition.Y
	local winsLabel = makeStable(root, "VTRPathWinsStable")
	local lossesLabel = makeStable(root, "VTRPathLossesStable")

	place(winsLabel, root, winsHeader, wins, y)
	place(lossesLabel, root, lossesHeader, losses, y)

	hideBadDigits(root)
	fixClaim(root)

	if root:IsA("ScrollingFrame") then
		root.CanvasPosition = Vector2.new(0, 0)
	end
end

function RankedPathUiFixClient.Start()
	if started then
		return
	end

	started = true

	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.08 then
			accumulator = 0
			RankedPathUiFixClient.Fix()
		end
	end)

	task.defer(function()
		for _ = 1, 30 do
			RankedPathUiFixClient.Fix()
			task.wait(0.1)
		end
	end)
end

RankedPathUiFixClient.Start()

return RankedPathUiFixClient
'''.strip() + "\n", encoding="utf-8")

runner = root / "src/client/RankedPathUiFix.client.lua"
runner.write_text('require(script.Parent.Services.RankedPathUiFixClient)\n', encoding="utf-8")

service = root / "src/server/Services/SevenWinLoginRewardService.lua"
if service.exists():
	text = service.read_text(encoding="utf-8", errors="ignore")

	text = re.sub(
		r'local store = DataStoreService:GetDataStore\([^\n]+\)',
		'local store = DataStoreService:GetDataStore(Config.ClaimKey .. "_Path_v4")',
		text
	)

	text = re.sub(
		r'confirmRemote\.OnServerInvoke = function\(player\).*?\nend\s*\n\s*local SevenWinLoginRewardService',
		r'''confirmRemote.OnServerInvoke = function(player)
	local pending = pendingByUserId[player.UserId]
	local pathWins, totalWins, state = getPathWins(player)

	if pathWins < Config.MinimumWins then
		state.claimedWins = totalWins
		state.updatedAt = os.time()
		writeState(player, state)
		pendingByUserId[player.UserId] = nil

		player:SetAttribute("PathWins", 0)
		player:SetAttribute("PathLosses", 0)
		player:SetAttribute("PathGames", 0)
		player:SetAttribute("DivisionPathWins", 0)
		player:SetAttribute("DivisionPathLosses", 0)
		player:SetAttribute("DivisionPathGames", 0)

		return false, {}
	end

	if not pending then
		pending = {
			rewards = rollRewards(pathWins),
			pathWins = pathWins,
			totalWins = totalWins,
		}
	end

	if typeof(pending.rewards) ~= "table" or #pending.rewards == 0 then
		state.claimedWins = totalWins
		state.updatedAt = os.time()
		writeState(player, state)
		pendingByUserId[player.UserId] = nil
		return false, {}
	end

	for _, packName in ipairs(pending.rewards) do
		grantPack(player, packName)
	end

	state.claimedWins = totalWins
	state.lastClaimedPathWins = pending.pathWins
	state.updatedAt = os.time()
	writeState(player, state)

	pendingByUserId[player.UserId] = nil

	player:SetAttribute("PathWins", 0)
	player:SetAttribute("PathLosses", 0)
	player:SetAttribute("PathGames", 0)
	player:SetAttribute("DivisionPathWins", 0)
	player:SetAttribute("DivisionPathLosses", 0)
	player:SetAttribute("DivisionPathGames", 0)

	return true, pending.rewards
end

local SevenWinLoginRewardService''',
		text,
		flags=re.S
	)

	service.write_text(text.strip() + "\n", encoding="utf-8")
	print("patched src/server/Services/SevenWinLoginRewardService.lua")

print("patched src/client/Services/RankedPathUiFixClient.lua")
print("patched src/client/RankedPathUiFix.client.lua")