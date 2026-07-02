from pathlib import Path
import re

root = Path.cwd()

helper_path = root / "src/client/Services/PackRouletteAlignmentService.lua"
helper_path.parent.mkdir(parents=True, exist_ok=True)
helper_path.write_text(r'''
local TweenService = game:GetService("TweenService")

local PackRouletteAlignmentService = {}

local function packKey(value)
	if typeof(value) == "string" then
		return value
	end

	if typeof(value) == "table" then
		return value.Id or value.id or value.Name or value.name or value.PackId or value.packId or value.Key or value.key
	end

	if typeof(value) == "Instance" then
		return value:GetAttribute("PackId") or value:GetAttribute("PackName") or value.Name
	end

	return nil
end

local function samePack(a, b)
	local ak = packKey(a)
	local bk = packKey(b)
	return ak ~= nil and bk ~= nil and tostring(ak) == tostring(bk)
end

function PackRouletteAlignmentService.GetPackKey(value)
	return packKey(value)
end

function PackRouletteAlignmentService.FindWinningIndex(sequence, winningPack, preferredIndex)
	if typeof(sequence) ~= "table" then
		return nil
	end

	if preferredIndex and sequence[preferredIndex] and samePack(sequence[preferredIndex], winningPack) then
		return preferredIndex
	end

	local best
	for index, pack in ipairs(sequence) do
		if samePack(pack, winningPack) then
			best = index
		end
	end

	return best
end

function PackRouletteAlignmentService.FindItemByPack(container, winningPack, preferredIndex)
	if not container then
		return nil
	end

	local children = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			table.insert(children, child)
		end
	end

	table.sort(children, function(a, b)
		if a.LayoutOrder == b.LayoutOrder then
			return a.Name < b.Name
		end
		return a.LayoutOrder < b.LayoutOrder
	end)

	if preferredIndex and children[preferredIndex] and samePack(children[preferredIndex], winningPack) then
		return children[preferredIndex]
	end

	local best
	for _, child in ipairs(children) do
		if samePack(child, winningPack) then
			best = child
		end
	end

	return best
end

function PackRouletteAlignmentService.CenterOffset(scroller, item)
	if not scroller or not item then
		return 0
	end

	local scrollerCenter = scroller.AbsolutePosition.X + scroller.AbsoluteSize.X * 0.5
	local itemCenter = item.AbsolutePosition.X + item.AbsoluteSize.X * 0.5
	return itemCenter - scrollerCenter
end

function PackRouletteAlignmentService.SnapToItem(scroller, item)
	if not scroller or not item then
		return
	end

	local offset = PackRouletteAlignmentService.CenterOffset(scroller, item)
	scroller.CanvasPosition = Vector2.new(scroller.CanvasPosition.X + offset, scroller.CanvasPosition.Y)
end

function PackRouletteAlignmentService.TweenToItem(scroller, item, duration)
	if not scroller or not item then
		return nil
	end

	local offset = PackRouletteAlignmentService.CenterOffset(scroller, item)
	local target = Vector2.new(scroller.CanvasPosition.X + offset, scroller.CanvasPosition.Y)
	local tween = TweenService:Create(scroller, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		CanvasPosition = target,
	})
	tween:Play()
	return tween
end

function PackRouletteAlignmentService.GetCenteredItem(scroller, container)
	if not scroller or not container then
		return nil
	end

	local center = scroller.AbsolutePosition.X + scroller.AbsoluteSize.X * 0.5
	local best
	local bestDistance = math.huge

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			local itemCenter = child.AbsolutePosition.X + child.AbsoluteSize.X * 0.5
			local distance = math.abs(itemCenter - center)
			if distance < bestDistance then
				bestDistance = distance
				best = child
			end
		end
	end

	return best
end

function PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, preferredIndex)
	if not scroller or not container or not winningPack then
		return nil
	end

	task.wait()

	local item = PackRouletteAlignmentService.FindItemByPack(container, winningPack, preferredIndex)
	if not item then
		return nil
	end

	PackRouletteAlignmentService.SnapToItem(scroller, item)
	return item
end

return PackRouletteAlignmentService
'''.strip() + "\n", encoding="utf-8")

candidates = []
for path in (root / "src").rglob("*.lua"):
	text = path.read_text(encoding="utf-8", errors="ignore")
	low = text.lower()
	if "pack" in low and any(x in low for x in ["roulette", "spin", "spinner", "wheel", "reward"]):
		candidates.append(path)

def rel(path):
	return path.relative_to(root).as_posix()

def ensure_require(text, path):
	if "PackRouletteAlignmentService" in text:
		return text

	require_line = 'local PackRouletteAlignmentService = require(game:GetService("ReplicatedStorage"):WaitForChild("Client"):WaitForChild("Services"):WaitForChild("PackRouletteAlignmentService"))'

	if "src/client/Services/" in rel(path):
		require_line = 'local PackRouletteAlignmentService = require(script.Parent:WaitForChild("PackRouletteAlignmentService"))'
	elif "src/client/Components/" in rel(path):
		require_line = 'local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))'
	elif "src/client/Pages/" in rel(path):
		require_line = 'local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))'
	elif "src/client/Gameplay/" in rel(path):
		require_line = 'local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))'

	lines = text.splitlines()
	index = 0
	while index < len(lines) and lines[index].startswith("--!"):
		index += 1
	while index < len(lines) and (lines[index].startswith("local ") and "require" in lines[index]):
		index += 1

	lines.insert(index, require_line)
	return "\n".join(lines) + "\n"

def add_alignment_function(text):
	if "local function vtrForceRouletteWinningCenter" in text:
		return text

	fn = r'''
local function vtrFindRouletteGuiObjects(root)
	local scroller
	local container

	if typeof(root) ~= "Instance" then
		return nil, nil
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ScrollingFrame") then
			local n = string.lower(obj.Name)
			if string.find(n, "roulette") or string.find(n, "spin") or string.find(n, "reward") or string.find(n, "pack") then
				scroller = obj
				break
			end
			scroller = scroller or obj
		end
	end

	if scroller then
		for _, obj in ipairs(scroller:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local hasPack = obj:GetAttribute("PackId") or obj:GetAttribute("PackName")
				local n = string.lower(obj.Name)
				if hasPack or string.find(n, "pack") or string.find(n, "card") or string.find(n, "item") then
					container = obj.Parent
					break
				end
			end
		end
	end

	return scroller, container
end

local function vtrForceRouletteWinningCenter(root, winningPack, winningIndex)
	if not winningPack then
		return
	end

	task.defer(function()
		local scroller, container = vtrFindRouletteGuiObjects(root)
		if scroller and container then
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
			task.wait(0.05)
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
		end
	end)
end
'''
	m = re.search(r"\nreturn\s+\w+\s*$", text)
	if m:
		return text[:m.start()] + "\n" + fn.strip() + "\n" + text[m.start():]
	return text + "\n" + fn.strip() + "\n"

def patch_text(text, path):
	original = text
	text = ensure_require(text, path)
	text = add_alignment_function(text)

	text = re.sub(
		r"(\b(?:winningPack|rewardPack|selectedPack|resultPack|packReward|awardedPack|finalPack)\s*=\s*([^\n]+))",
		r"\1\nvtrForceRouletteWinningCenter(script.Parent, \2)",
		text,
		flags=re.I,
	)

	text = re.sub(
		r"(\b(?:winningIndex|rewardIndex|selectedIndex|resultIndex|finalIndex)\s*=\s*([^\n]+))",
		r"\1\nif winningPack or rewardPack or selectedPack or resultPack or finalPack then vtrForceRouletteWinningCenter(script.Parent, winningPack or rewardPack or selectedPack or resultPack or finalPack, \2) end",
		text,
		flags=re.I,
	)

	text = re.sub(
		r"(TweenService:Create\(([^,\n]+),\s*TweenInfo\.new\([^\n]+CanvasPosition\s*=\s*[^}]+}\):Play\(\))",
		r"\1\nif winningPack or rewardPack or selectedPack or resultPack or finalPack then vtrForceRouletteWinningCenter(script.Parent, winningPack or rewardPack or selectedPack or resultPack or finalPack, winningIndex or rewardIndex or selectedIndex or resultIndex or finalIndex) end",
		text,
		flags=re.S,
	)

	text = re.sub(
		r"(\bConfirm[A-Za-z0-9_]*\.MouseButton1Click:Connect\(function\([^\)]*\)\n)",
		r"\1\tif winningPack or rewardPack or selectedPack or resultPack or finalPack then vtrForceRouletteWinningCenter(script.Parent, winningPack or rewardPack or selectedPack or resultPack or finalPack, winningIndex or rewardIndex or selectedIndex or resultIndex or finalIndex) end\n",
		text,
		flags=re.I,
	)

	text = re.sub(
		r"(\bconfirm[A-Za-z0-9_]*\.MouseButton1Click:Connect\(function\([^\)]*\)\n)",
		r"\1\tif winningPack or rewardPack or selectedPack or resultPack or finalPack then vtrForceRouletteWinningCenter(script.Parent, winningPack or rewardPack or selectedPack or resultPack or finalPack, winningIndex or rewardIndex or selectedIndex or resultIndex or finalIndex) end\n",
		text,
		flags=re.I,
	)

	text = text.replace("vtrForceRouletteWinningCenter(script.Parent, script.Parent", "vtrForceRouletteWinningCenter(script.Parent")
	text = text.replace("PackRouletteAlignmentService = require(script.Parent:WaitForChild(\"PackRouletteAlignmentService\"))\nlocal PackRouletteAlignmentService", "PackRouletteAlignmentService")

	return text if text != original else original

patched = []
for path in candidates:
	if "src/client/" not in rel(path):
		continue

	text = path.read_text(encoding="utf-8", errors="ignore")
	new = patch_text(text, path)

	if new != text:
		path.write_text(new, encoding="utf-8")
		patched.append(rel(path))

print("patched helper", rel(helper_path))
for item in patched:
	print("patched", item)

if not patched:
	print("no roulette client file auto-patched")
	print("search these:")
	for item in candidates:
		print(rel(item))