from pathlib import Path
import re

root = Path.cwd()

ranked_path = root / "src/client/Pages/RankedPage.lua"

text = ranked_path.read_text(encoding="utf-8", errors="ignore")
original = text

text = re.sub(r"\nlocal function vtrRankedPathDirectFix\(root\).*?\nend\s*", "\n", text, flags=re.S)
text = re.sub(r"\nlocal function vtrStartRankedPathDirectFix\(root\).*?\nend\s*", "\n", text, flags=re.S)
text = re.sub(r"\n\s*vtrStartRankedPathDirectFix\(gui\)\s*", "\n", text)
text = re.sub(r"\n\s*vtrRankedPathDirectFix\(gui\)\s*", "\n", text)

helper = r'''
local function vtrRankedPathDirectFix(root)
	if not root then
		return
	end

	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local function lower(value)
		return string.lower(tostring(value or ""))
	end

	local function isLabel(obj)
		return obj:IsA("TextLabel") or obj:IsA("TextButton")
	end

	local function labelText(obj)
		if isLabel(obj) then
			return tostring(obj.Text or "")
		end
		return ""
	end

	local function findExact(text)
		for _, obj in ipairs(root:GetDescendants()) do
			if isLabel(obj) and lower(labelText(obj)) == lower(text) then
				return obj
			end
		end
		return nil
	end

	local function findRecord()
		for _, obj in ipairs(root:GetDescendants()) do
			if isLabel(obj) then
				local wins, draws, losses = string.match(labelText(obj), "(%d+)%s*W%s*/%s*(%d+)%s*D%s*/%s*(%d+)%s*L")
				if wins and draws and losses then
					return obj, tonumber(wins) or 0, tonumber(draws) or 0, tonumber(losses) or 0
				end
			end
		end

		return nil, tonumber(player:GetAttribute("PathWins")) or tonumber(player:GetAttribute("DivisionPathWins")) or 0, 0, tonumber(player:GetAttribute("PathLosses")) or tonumber(player:GetAttribute("DivisionPathLosses")) or 0
	end

	local function makeStable(name)
		local obj = root:FindFirstChild(name)

		if obj and obj:IsA("TextLabel") then
			return obj
		end

		obj = Instance.new("TextLabel")
		obj.Name = name
		obj.BackgroundTransparency = 1
		obj.BorderSizePixel = 0
		obj.Font = Enum.Font.GothamBlack
		obj.TextSize = 30
		obj.TextColor3 = Color3.fromRGB(255, 255, 255)
		obj.TextXAlignment = Enum.TextXAlignment.Left
		obj.TextYAlignment = Enum.TextYAlignment.Center
		obj.TextWrapped = false
		obj.TextScaled = false
		obj.AutomaticSize = Enum.AutomaticSize.None
		obj.ZIndex = 9999
		obj.Parent = root

		return obj
	end

	local function rel(pos)
		return Vector2.new(pos.X - root.AbsolutePosition.X, pos.Y - root.AbsolutePosition.Y)
	end

	local function place(valueLabel, header, value, y)
		if not header then
			return
		end

		local pos = rel(Vector2.new(header.AbsolutePosition.X, y))
		valueLabel.AnchorPoint = Vector2.new(0, 0)
		valueLabel.Position = UDim2.fromOffset(pos.X, pos.Y)
		valueLabel.Size = UDim2.fromOffset(160, 48)
		valueLabel.Text = tostring(value)
		valueLabel.Visible = true
		valueLabel.TextTransparency = 0
		valueLabel.LayoutOrder = 0
	end

	local recordLabel, wins, draws, losses = findRecord()
	local winsHeader = findExact("PATH WINS")
	local lossesHeader = findExact("PATH LOSSES")
	local recordHeader = findExact("PATH RECORD")
	local gamesHeader = findExact("GAMES")

	if winsHeader then
		winsHeader.Text = "PATH WINS"
	end

	if lossesHeader then
		lossesHeader.Text = "PATH LOSSES"
	end

	if recordHeader then
		recordHeader.Text = "PATH RECORD"
	end

	local games = wins + losses
	local attrGames = tonumber(player:GetAttribute("PathGames")) or tonumber(player:GetAttribute("DivisionPathGames"))
	if attrGames ~= nil and attrGames < games then
		games = attrGames
	end

	if recordLabel then
		recordLabel.Text = tostring(wins) .. "W / " .. tostring(draws) .. "D / " .. tostring(losses) .. "L"
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if isLabel(obj) and obj.Name ~= "VTRStablePathWinsDirect" and obj.Name ~= "VTRStablePathLossesDirect" then
			local clean = string.gsub(labelText(obj), "%s+", "")
			local name = lower(obj.Name)
			local parentName = lower(obj.Parent and obj.Parent.Name or "")

			if string.match(clean, "^%d+$") and obj.AbsoluteSize.X < 180 and obj.AbsoluteSize.Y < 90 then
				if string.find(name, "path") or string.find(parentName, "path") or string.find(name, "wins") or string.find(name, "losses") or string.find(parentName, "wins") or string.find(parentName, "losses") then
					obj.Visible = false
					obj.TextTransparency = 1
				end
			end
		end
	end

	if recordLabel and winsHeader and lossesHeader then
		local y = recordLabel.AbsolutePosition.Y
		place(makeStable("VTRStablePathWinsDirect"), winsHeader, wins, y)
		place(makeStable("VTRStablePathLossesDirect"), lossesHeader, losses, y)
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if isLabel(obj) then
			local txt = lower(labelText(obj))
			local name = lower(obj.Name)

			if string.find(txt, "claim") or string.find(name, "claim") then
				if games < 7 then
					obj.Visible = false
					obj.TextTransparency = 1
					if obj:IsA("TextButton") then
						obj.Active = false
						obj.AutoButtonColor = false
					end
				end
			end
		elseif obj:IsA("GuiObject") then
			local name = lower(obj.Name)
			if string.find(name, "claim") and games < 7 then
				obj.Visible = false
			end
		end
	end
end

local function vtrStartRankedPathDirectFix(root)
	task.defer(function()
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer

		local function hookClaims()
			for _, obj in ipairs(root:GetDescendants()) do
				if obj:IsA("TextButton") then
					local txt = string.lower(tostring(obj.Text or ""))
					local name = string.lower(tostring(obj.Name or ""))

					if string.find(txt, "claim") or string.find(name, "claim") then
						if obj:GetAttribute("VTRClaimResetHooked") ~= true then
							obj:SetAttribute("VTRClaimResetHooked", true)
							obj.MouseButton1Click:Connect(function()
								task.delay(0.35, function()
									player:SetAttribute("PathWins", 0)
									player:SetAttribute("PathLosses", 0)
									player:SetAttribute("PathGames", 0)
									player:SetAttribute("DivisionPathWins", 0)
									player:SetAttribute("DivisionPathLosses", 0)
									player:SetAttribute("DivisionPathGames", 0)
									vtrRankedPathDirectFix(root)
								end)
							end)
						end
					end
				end
			end
		end

		while root.Parent do
			hookClaims()
			vtrRankedPathDirectFix(root)
			task.wait(0.08)
		end
	end)
end
'''

matches = list(re.finditer(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*.*require\(.*\)", text))
insert_at = matches[-1].end() if matches else 0
text = text[:insert_at] + "\n" + helper.strip() + "\n" + text[insert_at:]

if "vtrStartRankedPathDirectFix(gui)" not in text:
	text = re.sub(
		r"(return\s+gui\s*$)",
		"vtrStartRankedPathDirectFix(gui)\n\n\\1",
		text,
		flags=re.M
	)

ranked_page.write_text(text.strip() + "\n", encoding="utf-8")
print("patched src/client/Pages/RankedPage.lua")

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

service = root / "src/server/Services/SevenWinLoginRewardService.lua"
if service.exists():
	text = service.read_text(encoding="utf-8", errors="ignore")

	text = re.sub(
		r"local store = DataStoreService:GetDataStore\([^\n]+\)",
		'local store = DataStoreService:GetDataStore(Config.ClaimKey .. "_Path_v5")',
		text
	)

	text = re.sub(
		r"state\.claimedWins\s*=\s*totalWins",
		"state.claimedWins = getWins(player)",
		text
	)

	text = re.sub(
		r"player:SetAttribute\(\"PathWins\",\s*0\)\s*player:SetAttribute\(\"PathLosses\",\s*0\)\s*player:SetAttribute\(\"PathGames\",\s*0\)\s*player:SetAttribute\(\"DivisionPathWins\",\s*0\)\s*player:SetAttribute\(\"DivisionPathLosses\",\s*0\)\s*player:SetAttribute\(\"DivisionPathGames\",\s*0\)",
		'player:SetAttribute("PathWins", 0)\n\tplayer:SetAttribute("PathLosses", 0)\n\tplayer:SetAttribute("PathGames", 0)\n\tplayer:SetAttribute("DivisionPathWins", 0)\n\tplayer:SetAttribute("DivisionPathLosses", 0)\n\tplayer:SetAttribute("DivisionPathGames", 0)',
		text
	)

	service.write_text(text.strip() + "\n", encoding="utf-8")
	print("patched src/server/Services/SevenWinLoginRewardService.lua")