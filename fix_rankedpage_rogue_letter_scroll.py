from pathlib import Path
import re

root = Path.cwd()
path = root / "src/client/Pages/RankedPage.lua"

text = path.read_text(encoding="utf-8", errors="ignore")
original = text

helper = r'''
local function vtrIsRankedUiRoot(obj)
	local current = obj

	while current do
		local name = string.lower(tostring(current.Name or ""))
		if string.find(name, "ranked") or string.find(name, "division") or string.find(name, "path") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function vtrFixRankedRogueText(root)
	if not root then
		return
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local txt = tostring(obj.Text or "")
			local clean = string.gsub(txt, "%s+", "")

			if vtrIsRankedUiRoot(obj) and string.match(clean, "^[A-Za-z]$") then
				obj.Visible = false
				obj.Text = ""
			end

			if vtrIsRankedUiRoot(obj) then
				obj.ClipsDescendants = false
			end
		elseif obj:IsA("ScrollingFrame") and vtrIsRankedUiRoot(obj) then
			obj.ScrollBarThickness = 0
			obj.ScrollingEnabled = false
			obj.AutomaticCanvasSize = Enum.AutomaticSize.None
			obj.CanvasPosition = Vector2.new(0, 0)
			obj.CanvasSize = UDim2.fromScale(0, 0)
		elseif obj:IsA("GuiObject") and vtrIsRankedUiRoot(obj) then
			local p = obj.Position
			if math.abs(p.X.Scale) > 2 or math.abs(p.Y.Scale) > 2 then
				obj.Visible = false
			end
		end
	end
end
'''

if "local function vtrFixRankedRogueText" not in text:
    insert_at = 0
    matches = list(re.finditer(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*.*require\(.*\)", text))
    if matches:
        insert_at = matches[-1].end()
    else:
        m = re.search(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=", text)
        insert_at = m.end() if m else 0

    text = text[:insert_at] + "\n" + helper.strip() + "\n" + text[insert_at:]

if "vtrFixRankedRogueText(gui)" not in text:
    text = re.sub(
        r"(return\s+gui\s*$)",
        "vtrFixRankedRogueText(gui)\n\n\\1",
        text,
        flags=re.M
    )

if "vtrFixRankedRogueText(root)" not in text and "return gui" not in text:
    text += "\ntask.defer(function()\n\tvtrFixRankedRogueText(script.Parent)\nend)\n"

text = text.replace("ScrollBarThickness = 6", "ScrollBarThickness = 0")
text = text.replace("ScrollBarThickness = 8", "ScrollBarThickness = 0")
text = text.replace("ScrollingEnabled = true", "ScrollingEnabled = false")

path.write_text(text.strip() + "\n", encoding="utf-8")

print("patched src/client/Pages/RankedPage.lua")