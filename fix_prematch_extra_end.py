from pathlib import Path

path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
text = path.read_text(encoding="utf-8")

text = text.replace(
'''	updateFormationDots(dots, data, side)
	return dots
end
	return dots
end

local function setLineHighlight''',
'''	updateFormationDots(dots, data, side)
	return dots
end

local function setLineHighlight''',
1
)

text = text.replace(
'''	for index, dot in dots do
		local active = dot:GetAttribute("VTRLineGroup") == groupName
		if not active and groupName == "" then
			active = index >= first and index <= last
		end
		TweenService:Create(dot, TweenInfo.new(0.22), {
			BackgroundColor3 = active and Theme.Colors.Electric or Theme.Colors.White,
			Size = active and UDim2.fromOffset(16, 16) or UDim2.fromOffset(11, 11),
		}):Play()
	end
end
end

local function makePitchLine''',
'''	for index, dot in dots do
		local active = dot:GetAttribute("VTRLineGroup") == groupName
		if not active and groupName == "" then
			active = index >= first and index <= last
		end
		TweenService:Create(dot, TweenInfo.new(0.22), {
			BackgroundColor3 = active and Theme.Colors.Electric or Theme.Colors.White,
			Size = active and UDim2.fromOffset(16, 16) or UDim2.fromOffset(11, 11),
		}):Play()
	end
end

local function makePitchLine''',
1
)

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed extra end in PrematchBroadcastPresentation")