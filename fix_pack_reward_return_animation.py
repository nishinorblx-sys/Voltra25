from pathlib import Path
import re

root = Path.cwd()

def write(path, text):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip() + "\n", encoding="utf-8")

write("src/server/Services/PendingPackAnimationService.lua", r'''
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local folder = ReplicatedStorage:FindFirstChild("PackRewardAnimationRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "PackRewardAnimationRemotes"
	folder.Parent = ReplicatedStorage
end

local showRemote = folder:FindFirstChild("ShowPackRewardAnimation")
if not showRemote then
	showRemote = Instance.new("RemoteEvent")
	showRemote.Name = "ShowPackRewardAnimation"
	showRemote.Parent = folder
end

local ackRemote = folder:FindFirstChild("AckPackRewardAnimation")
if not ackRemote then
	ackRemote = Instance.new("RemoteEvent")
	ackRemote.Name = "AckPackRewardAnimation"
	ackRemote.Parent = folder
end

local store = DataStoreService:GetDataStore("PendingPackRewardAnimations_v2")
local pending = {}
local started = false

local function normalizePack(pack)
	if typeof(pack) == "string" then
		return pack
	end

	if typeof(pack) == "table" then
		return pack.Id or pack.id or pack.Name or pack.name or pack.PackId or pack.packId or pack.Key or pack.key
	end

	if typeof(pack) == "Instance" then
		return pack:GetAttribute("PackId") or pack:GetAttribute("PackName") or pack.Name
	end

	return nil
end

local function keyFor(playerOrUserId)
	local userId = typeof(playerOrUserId) == "Instance" and playerOrUserId.UserId or playerOrUserId
	return tostring(userId)
end

local function cleanQueue(queue)
	local out = {}

	if typeof(queue) ~= "table" then
		return out
	end

	for _, entry in ipairs(queue) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and typeof(entry.pack) == "string" and entry.pack ~= "" then
			table.insert(out, entry)
		end
	end

	return out
end

local function loadQueue(player)
	local ok, result = pcall(function()
		return store:GetAsync(keyFor(player))
	end)

	local queue = ok and cleanQueue(result) or {}
	pending[player.UserId] = queue
	return queue
end

local function saveQueue(playerOrUserId, queue)
	pcall(function()
		store:SetAsync(keyFor(playerOrUserId), cleanQueue(queue))
	end)
end

local function fireQueue(player, queue)
	if typeof(queue) ~= "table" or #queue == 0 then
		return
	end

	showRemote:FireClient(player, queue)
end

local PendingPackAnimationService = {}

function PendingPackAnimationService.Queue(player, pack)
	if not player or not player:IsA("Player") then
		return nil
	end

	local packName = normalizePack(pack)
	if not packName or packName == "" then
		return nil
	end

	local entry = {
		id = HttpService:GenerateGUID(false),
		pack = packName,
		t = os.time(),
	}

	local queue = pending[player.UserId]
	if typeof(queue) ~= "table" then
		queue = loadQueue(player)
	end

	table.insert(queue, entry)
	pending[player.UserId] = queue
	saveQueue(player, queue)

	task.delay(2, function()
		if player.Parent == Players then
			fireQueue(player, { entry })
		end
	end)

	return entry.id
end

function PendingPackAnimationService.Flush(player)
	local queue = pending[player.UserId]
	if typeof(queue) ~= "table" then
		queue = loadQueue(player)
	end

	fireQueue(player, queue)
end

function PendingPackAnimationService.Ack(player, ids)
	if not player or not player:IsA("Player") then
		return
	end

	if typeof(ids) ~= "table" then
		return
	end

	local remove = {}
	for _, id in ipairs(ids) do
		if typeof(id) == "string" then
			remove[id] = true
		end
	end

	local queue = pending[player.UserId]
	if typeof(queue) ~= "table" then
		queue = loadQueue(player)
	end

	local kept = {}
	for _, entry in ipairs(queue) do
		if not remove[entry.id] then
			table.insert(kept, entry)
		end
	end

	pending[player.UserId] = kept
	saveQueue(player, kept)
end

function PendingPackAnimationService.Start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent ~= Players then
				return
			end

			local queue = loadQueue(player)
			fireQueue(player, queue)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pending[player.UserId] = nil
	end)

	ackRemote.OnServerEvent:Connect(function(player, ids)
		PendingPackAnimationService.Ack(player, ids)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			local queue = loadQueue(player)
			fireQueue(player, queue)
		end)
	end
end

PendingPackAnimationService.Start()

return PendingPackAnimationService
''')

write("src/server/PendingPackAnimation.server.lua", r'''
require(script.Parent.Services.PendingPackAnimationService)
''')

write("src/client/Components/PackRewardFlyinAnimation.lua", r'''
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local PackRewardFlyinAnimation = {}

local function lowerText(obj)
	local values = { obj.Name }

	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		table.insert(values, obj.Text)
	end

	for _, value in ipairs(values) do
		local s = string.lower(tostring(value or ""))
		if s ~= "" then
			return s
		end
	end

	return ""
end

local function findInventoryTarget()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local best
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("GuiObject") then
			local s = lowerText(obj)
			if string.find(s, "inventory") or string.find(s, "inv") or string.find(s, "backpack") or string.find(s, "packs") then
				if obj.Visible and obj.AbsoluteSize.X > 8 and obj.AbsoluteSize.Y > 8 then
					best = obj
					if obj:IsA("GuiButton") then
						return obj
					end
				end
			end
		end
	end

	return best
end

local function guiPosFromAbsolute(gui, absoluteCenter)
	local root = gui.AbsolutePosition
	return UDim2.fromOffset(absoluteCenter.X - root.X, absoluteCenter.Y - root.Y)
end

local function makeGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("PackRewardFlyinGui")

	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "PackRewardFlyinGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15000
	gui.Parent = playerGui

	return gui
end

function PackRewardFlyinAnimation.Play(packName)
	local gui = makeGui()

	local card = Instance.new("Frame")
	card.Name = "PackRewardPopup"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.47)
	card.Size = UDim2.fromOffset(310, 190)
	card.BackgroundColor3 = Color3.fromRGB(20, 25, 38)
	card.BackgroundTransparency = 0.02
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(136, 255, 72)
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 16)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(136, 255, 72)
	title.Text = "PACK EARNED"
	title.Parent = card

	local pack = Instance.new("TextLabel")
	pack.Name = "PackName"
	pack.BackgroundColor3 = Color3.fromRGB(33, 42, 61)
	pack.Position = UDim2.fromOffset(28, 62)
	pack.Size = UDim2.new(1, -56, 0, 86)
	pack.Font = Enum.Font.GothamBlack
	pack.TextSize = 26
	pack.TextWrapped = true
	pack.TextColor3 = Color3.fromRGB(255, 255, 255)
	pack.Text = tostring(packName)
	pack.Parent = card

	local packCorner = Instance.new("UICorner")
	packCorner.CornerRadius = UDim.new(0, 16)
	packCorner.Parent = pack

	card.Size = UDim2.fromOffset(250, 150)
	TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(310, 190),
	}):Play()

	task.wait(1.05)

	local target = findInventoryTarget()
	local endPosition = UDim2.fromScale(0.91, 0.91)
	local endSize = UDim2.fromOffset(62, 42)

	if target then
		local center = target.AbsolutePosition + target.AbsoluteSize * 0.5
		endPosition = guiPosFromAbsolute(gui, center)
		endSize = UDim2.fromOffset(math.max(42, target.AbsoluteSize.X * 0.35), math.max(32, target.AbsoluteSize.Y * 0.35))
	end

	local fly = TweenService:Create(card, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = endPosition,
		Size = endSize,
		BackgroundTransparency = 0.45,
	})
	fly:Play()
	fly.Completed:Wait()

	local fade = TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	fade:Play()
	fade.Completed:Wait()

	card:Destroy()
end

return PackRewardFlyinAnimation
''')

write("src/client/Services/PackRewardFlyinClient.lua", r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animation = require(script.Parent.Parent.Components.PackRewardFlyinAnimation)

local remotes = ReplicatedStorage:WaitForChild("PackRewardAnimationRemotes")
local showRemote = remotes:WaitForChild("ShowPackRewardAnimation")
local ackRemote = remotes:WaitForChild("AckPackRewardAnimation")

local running = false
local queue = {}

local function push(entries)
	if typeof(entries) ~= "table" then
		return
	end

	for _, entry in ipairs(entries) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and typeof(entry.pack) == "string" then
			table.insert(queue, entry)
		end
	end
end

local function drain()
	if running then
		return
	end

	running = true

	while #queue > 0 do
		local entry = table.remove(queue, 1)
		Animation.Play(entry.pack)
		ackRemote:FireServer({ entry.id })
		task.wait(0.18)
	end

	running = false
end

showRemote.OnClientEvent:Connect(function(entries)
	push(entries)
	task.defer(drain)
end)
''')

write("src/client/PackRewardFlyin.client.lua", r'''
require(script.Parent.Services.PackRewardFlyinClient)
''')

server_paths = []
for path in (root / "src/server").rglob("*.lua"):
	text = path.read_text(encoding="utf-8", errors="ignore")
	low = text.lower()
	if "pack" in low and any(x in low for x in ["grant", "give", "award", "addpack", "inventory", "roulette", "spin", "reward"]):
		server_paths.append(path)

grant_words = r"(?:GrantPack|AddPack|GivePack|AwardPack|AddPackToInventory|GrantPackToPlayer|GivePackToPlayer|AwardPackToPlayer|AddToInventory)"

def rel(path):
	return path.relative_to(root).as_posix()

def require_line_for(path):
	r = rel(path)
	if r.startswith("src/server/Services/"):
		return 'local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))'
	if r.startswith("src/server/Gameplay/"):
		return 'local VTRPendingPackAnimation = require(script.Parent.Parent.Services:WaitForChild("PendingPackAnimationService"))'
	return 'local VTRPendingPackAnimation = require(script.Parent.Services:WaitForChild("PendingPackAnimationService"))'

def insert_require(text, path):
	if "VTRPendingPackAnimation" in text:
		return text

	lines = text.splitlines()
	index = 0

	while index < len(lines) and lines[index].startswith("--!"):
		index += 1

	while index < len(lines) and lines[index].startswith("local ") and "require" in lines[index]:
		index += 1

	lines.insert(index, require_line_for(path))
	return "\n".join(lines) + "\n"

def split_args(raw):
	out = []
	depth = 0
	current = ""

	for ch in raw:
		if ch in "({[":
			depth += 1
		elif ch in ")}]":
			depth -= 1

		if ch == "," and depth == 0:
			out.append(current.strip())
			current = ""
		else:
			current += ch

	if current.strip():
		out.append(current.strip())

	return out

def patch_grants(text):
	lines = text.splitlines()
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if "VTRPendingPackAnimation.Queue" in line:
			continue

		if re.search(r"\bfunction\b", line) and re.search(grant_words, line):
			continue

		m = re.search(r"(?::|\.)" + grant_words + r"\((.*)\)", line)
		if not m:
			m = re.search(r"\b" + grant_words + r"\((.*)\)", line)

		if not m:
			continue

		if i + 1 < len(lines) and "VTRPendingPackAnimation.Queue" in lines[i + 1]:
			continue

		args = split_args(m.group(1))
		if len(args) < 2:
			continue

		player_expr = args[0]
		pack_expr = args[1]

		if re.search(r"UserId|userId|userid", player_expr):
			continue

		indent = re.match(r"^(\s*)", line).group(1)
		out.append(f"{indent}if {player_expr} and typeof({player_expr}) == \"Instance\" and {player_expr}:IsA(\"Player\") then")
		out.append(f"{indent}\tVTRPendingPackAnimation.Queue({player_expr}, {pack_expr})")
		out.append(f"{indent}end")

	return "\n".join(out) + "\n"

patched = []
for path in server_paths:
	if rel(path).endswith("PendingPackAnimationService.lua"):
		continue

	original = path.read_text(encoding="utf-8", errors="ignore")
	text = insert_require(original, path)
	text = patch_grants(text)

	if text != original:
		path.write_text(text, encoding="utf-8")
		patched.append(rel(path))

print("created src/server/Services/PendingPackAnimationService.lua")
print("created src/server/PendingPackAnimation.server.lua")
print("created src/client/Components/PackRewardFlyinAnimation.lua")
print("created src/client/Services/PackRewardFlyinClient.lua")
print("created src/client/PackRewardFlyin.client.lua")
for item in patched:
	print("patched", item)