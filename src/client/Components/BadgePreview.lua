--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local BadgeSymbolLibrary = require(script.Parent.BadgeSymbolLibrary)

local BadgePreview = {}

local legacySymbols = {
	Lightning = "Lightning Bolt", Ball = "Football", ["VTR Mark"] = "Volt V",
	Wolf = "Wolf Head", Dragon = "Dragon Head",
}

local function resolvedColor(value: any): Color3
	if typeof(value) == "Color3" then return value end
	return Color3.fromHex(Config.ResolveColor(value))
end

local function syncZIndex(root: GuiObject)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = root.ZIndex
		end
	end
end

function BadgePreview.new(parent: Instance, identity: any, size: UDim2?): Frame
	local root=Instance.new("Frame");root.Name="GeneratedBadge";root.BackgroundTransparency=1;root.Size=size or UDim2.fromOffset(110,110);root.Parent=parent
	local primary=resolvedColor(identity.PrimaryColor);local secondary=resolvedColor(identity.SecondaryColor);local accent=resolvedColor(identity.AccentColor)
	local behavior=identity.BadgeColorBehavior or"Tri Color"
	if behavior=="Secondary Focus"then primary,secondary=secondary,primary elseif behavior=="Accent Focus"then primary,accent=accent,primary elseif behavior=="High Contrast"then secondary=primary:Lerp(Color3.new(1,1,1),.85)end

	local badge=Instance.new("Frame");badge.Name=identity.BadgeShape or"Shield";badge.AnchorPoint=Vector2.new(.5,.5);badge.Position=UDim2.fromScale(.5,.5);badge.Size=UDim2.fromScale(.72,.82);badge.BackgroundColor3=primary;badge.BorderSizePixel=0;badge.Parent=root
	local shape=identity.BadgeShape or"Shield";local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(shape=="Circle"and 1 or 0,shape=="Circle"and 0 or(shape=="Crest"and 18 or 8));corner.Parent=badge
	if shape=="Diamond"then badge.Rotation=45;badge.Size=UDim2.fromScale(.58,.58)elseif shape=="Hex"then badge.Rotation=30 elseif shape=="V Badge"then badge.Size=UDim2.fromScale(.68,.68);badge.Rotation=45 end

	local preset=identity.BadgePreset or"Modern";local border=Instance.new("UIStroke");border.Color=accent;border.Thickness=preset=="Elite"and 6 or preset=="Minimal"and 2 or 4;border.Transparency=preset=="Heritage"and .25 or .05;border.Parent=badge
	local inset=preset=="Minimal"and 7 or preset=="Classic"and 18 or 14
	local inner=Instance.new("Frame");inner.Name="SymbolField";inner.AnchorPoint=Vector2.new(.5,.5);inner.Position=UDim2.fromScale(.5,.5);inner.Size=UDim2.new(1,-inset,1,-inset);inner.BackgroundColor3=secondary;inner.BorderSizePixel=0;inner.Rotation=-badge.Rotation;inner.ClipsDescendants=true;inner.Parent=badge
	local innerCorner=corner:Clone();innerCorner.Parent=inner

	local selected=identity.BadgeSymbol or"Lightning Bolt"
	BadgeSymbolLibrary.render(inner,legacySymbols[selected]or selected,{Primary=primary,Secondary=secondary,Accent=accent},UDim2.fromScale(.78,.78))
	syncZIndex(root)
	root:GetPropertyChangedSignal("ZIndex"):Connect(function()
		syncZIndex(root)
	end)
	return root
end

return BadgePreview
