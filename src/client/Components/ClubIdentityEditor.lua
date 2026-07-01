--!strict

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Panel=require(script.Parent.Panel)
local Button=require(script.Parent.Button)
local KitPreview=require(script.Parent.KitPreview)
local BadgePreview=require(script.Parent.BadgePreview)
local BadgeSymbolLibrary=require(script.Parent.BadgeSymbolLibrary)
local Editor={}

local function text(parent:Instance,value:string,pos:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Position=pos;t.Size=size;t.Text=value;t.TextColor3=color;t.TextSize=textSize;t.Font=font;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=parent;return t end
local function input(parent:Instance,value:string,placeholder:string,pos:UDim2,size:UDim2):TextBox local b=Instance.new("TextBox");b.BackgroundColor3=Theme.Colors.Gunmetal;b.BorderSizePixel=0;b.Position=pos;b.Size=size;b.Text=value;b.PlaceholderText=placeholder;b.TextColor3=Theme.Colors.White;b.PlaceholderColor3=Theme.Colors.Muted;b.Font=Theme.Fonts.Strong;b.TextSize=11;b.ClearTextOnFocus=false;b.Parent=parent;local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=b;return b end
local function indexOf(list:{string},value:any):number return table.find(list,value)or 1 end
local function badgeSymbol(value:any):string local legacy={Lightning="Lightning Bolt",Ball="Football",["VTR Mark"]="Volt V",Wolf="Wolf Head",Dragon="Dragon Head"};local resolved=legacy[value]or value;return table.find(Config.BadgeSymbols,resolved)and resolved or Config.Default.BadgeSymbol end

function Editor.open(parent:Instance,identity:any,options:any)
	local state={Name=identity.Name or identity.ClubName or"VOLTAGE FC",Abbreviation=identity.Abbreviation or"VTR",PrimaryColor=Config.ColorId(identity.PrimaryColor)or Config.Default.PrimaryColor,SecondaryColor=Config.ColorId(identity.SecondaryColor)or Config.Default.SecondaryColor,AccentColor=Config.ColorId(identity.AccentColor)or Config.Default.AccentColor,KitStyle=Config.ResolveStyle(identity.KitStyle),BadgePreset=identity.BadgePreset or Config.Default.BadgePreset,BadgeShape=identity.BadgeShape or Config.Default.BadgeShape,BadgeSymbol=badgeSymbol(identity.BadgeSymbol),BadgeColorBehavior=identity.BadgeColorBehavior or Config.Default.BadgeColorBehavior}
	local overlay=Instance.new("Frame");overlay.Name="ClubIdentityEditor";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.05;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=210;overlay.Parent=parent
	local modal=Panel.new({Name="IdentityStudio",Size=UDim2.new(.9,0,.9,0)});modal.AnchorPoint=Vector2.new(.5,.5);modal.Position=UDim2.fromScale(.5,.5);modal.ZIndex=211;modal.ClipsDescendants=false;modal.Parent=overlay;local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(1080,680);constraint.MinSize=Vector2.new(760,540);constraint.Parent=modal
	text(modal,"VTR CLUB IDENTITY STUDIO",UDim2.fromOffset(24,16),UDim2.new(1,-180,0,30),22,Theme.Colors.White,Theme.Fonts.Display)
	text(modal,"LIVE KIT + BADGE GENERATOR  /  SERVER-VALIDATED COLORS",UDim2.fromOffset(24,48),UDim2.new(1,-48,0,18),8,Theme.Colors.White,Theme.Fonts.Strong)
	local close=Button.new({Text="CANCEL",Variant="Secondary",Size=UDim2.fromOffset(110,34),OnActivated=function()overlay:Destroy();if options.OnCancel then options.OnCancel()end end});close.Position=UDim2.new(1,-134,0,18);close.ZIndex=215;close.Parent=modal
	local preview=Panel.new({Name="LivePreview",Position=UDim2.fromOffset(24,82),Size=UDim2.new(.34,-8,1,-164)});preview.ZIndex=212;preview.Parent=modal
	local controls=Instance.new("ScrollingFrame");controls.BackgroundTransparency=1;controls.BorderSizePixel=0;controls.Position=UDim2.new(.36,8,0,82);controls.Size=UDim2.new(.64,-32,1,-164);controls.CanvasSize=UDim2.fromOffset(0,940);controls.ScrollBarThickness=3;controls.ScrollBarImageColor3=Theme.Colors.White;controls.ZIndex=212;controls.Parent=modal
	local nameBox=input(controls,state.Name,"CLUB NAME",UDim2.fromOffset(0,0),UDim2.new(.72,-6,0,40));local tagBox=input(controls,state.Abbreviation,"TAG",UDim2.new(.72,6,0,0),UDim2.new(.28,-6,0,40));tagBox.MaxVisibleGraphemes=4
	local previewHolder=Instance.new("Frame");previewHolder.BackgroundTransparency=1;previewHolder.Position=UDim2.fromOffset(10,54);previewHolder.Size=UDim2.new(1,-20,1,-64);previewHolder.Parent=preview
	local activeChannel="PrimaryColor";local paletteHolder=Instance.new("Frame");paletteHolder.BackgroundTransparency=1;paletteHolder.Position=UDim2.fromOffset(0,104);paletteHolder.Size=UDim2.new(1,0,0,145);paletteHolder.Parent=controls
	local optionHolder=Instance.new("Frame");optionHolder.BackgroundTransparency=1;optionHolder.Position=UDim2.fromOffset(0,275);optionHolder.Size=UDim2.new(1,0,0,650);optionHolder.Parent=controls
	local renderPreview:()->();local renderPalette:()->();local renderOptions:()->()
	renderPreview=function()for _,child in previewHolder:GetChildren()do child:Destroy()end;state.Name=nameBox.Text;state.Abbreviation=string.upper(tagBox.Text);text(previewHolder,state.Name.."  ["..state.Abbreviation.."]",UDim2.fromOffset(0,0),UDim2.new(1,0,0,28),15,Theme.Colors.White,Theme.Fonts.Display).TextXAlignment=Enum.TextXAlignment.Center;local kit=KitPreview.new(previewHolder,state,UDim2.new(1,-24,0,330));kit.Position=UDim2.fromOffset(12,35);local badge=BadgePreview.new(previewHolder,state,UDim2.fromOffset(92,92));badge.AnchorPoint=Vector2.new(.5,0);badge.Position=UDim2.new(.5,0,1,-100);text(previewHolder,string.upper(state.KitStyle),UDim2.new(0,0,1,-24),UDim2.new(1,0,0,20),8,Theme.Colors.White,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Center end
	local channels={{"PRIMARY","PrimaryColor"},{"SECONDARY","SecondaryColor"},{"ACCENT","AccentColor"}}
	for index,item in channels do local button=Button.new({Text=item[1],Variant=index==1 and"Primary"or"Secondary",Size=UDim2.new(.333,-5,0,36),OnActivated=function()activeChannel=item[2];renderPalette()end});button.Position=UDim2.new((index-1)/3,(index-1)*3,0,54);button.Parent=controls end
	renderPalette=function()for _,child in paletteHolder:GetChildren()do child:Destroy()end;text(paletteHolder,"COLOR PALETTE  /  "..string.upper(activeChannel:gsub("Color","")),UDim2.fromOffset(0,0),UDim2.new(1,0,0,18),8,Theme.Colors.White,Theme.Fonts.Strong);local swatches=Instance.new("Frame");swatches.BackgroundTransparency=1;swatches.Position=UDim2.fromOffset(0,24);swatches.Size=UDim2.new(1,0,1,-24);swatches.Parent=paletteHolder;local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(.125,-5,0,34);grid.CellPadding=UDim2.fromOffset(5,5);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=swatches;for index,color in Config.Colors do local swatch=Instance.new("TextButton");swatch.Name=color.Id;swatch.AutoButtonColor=false;swatch.Text=state[activeChannel]==color.Id and"✓"or"";swatch.TextColor3=Color3.new();swatch.TextSize=14;swatch.Font=Theme.Fonts.Display;swatch.BackgroundColor3=Color3.fromHex(color.Hex);swatch.BorderSizePixel=0;swatch.LayoutOrder=index;swatch.Selectable=false;swatch.Parent=swatches;local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,5);c.Parent=swatch;swatch.Activated:Connect(function()local duplicate=false;for _,channel in{"PrimaryColor","SecondaryColor","AccentColor"}do if channel~=activeChannel and state[channel]==color.Id then duplicate=true end end;if not duplicate then state[activeChannel]=color.Id;renderPalette();renderPreview()end end)end end
	local optionRows={{"KIT STYLE","KitStyle",Config.KitStyles},{"BADGE PRESET","BadgePreset",Config.BadgePresets},{"BADGE SHAPE","BadgeShape",Config.BadgeShapes}}
	renderOptions=function()
		for _,child in optionHolder:GetChildren()do child:Destroy()end
		for row,data in optionRows do
			local y=(row-1)*70;text(optionHolder,data[1],UDim2.fromOffset(0,y),UDim2.new(.34,0,0,34),8,Theme.Colors.Muted,Theme.Fonts.Strong)
			local cycle=Button.new({Text=string.upper(state[data[2]]),Variant="Secondary",Size=UDim2.new(.64,0,0,38),OnActivated=function()local list=data[3];state[data[2]]=list[indexOf(list,state[data[2]])%#list+1];renderOptions();renderPreview()end});cycle.Position=UDim2.new(.36,0,0,y);cycle.Parent=optionHolder
		end

		text(optionHolder,"BADGE SYMBOL  /  SELECT A MARK",UDim2.fromOffset(0,210),UDim2.new(1,0,0,24),8,Theme.Colors.White,Theme.Fonts.Strong)
		local symbolGrid=Instance.new("Frame");symbolGrid.Name="BadgeSymbolGrid";symbolGrid.BackgroundTransparency=1;symbolGrid.Position=UDim2.fromOffset(0,238);symbolGrid.Size=UDim2.new(1,0,0,280);symbolGrid.Parent=optionHolder
		local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(.2,-6,0,50);grid.CellPadding=UDim2.fromOffset(6,6);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=symbolGrid
		local primary=Color3.fromHex(Config.ResolveColor(state.PrimaryColor));local secondary=Color3.fromHex(Config.ResolveColor(state.SecondaryColor));local accent=Color3.fromHex(Config.ResolveColor(state.AccentColor))
		for order,symbolName in BadgeSymbolLibrary.Symbols do
			local choice=Instance.new("TextButton");choice.Name=symbolName;choice.Text="";choice.AutoButtonColor=false;choice.BackgroundColor3=state.BadgeSymbol==symbolName and Theme.Colors.Gunmetal or Theme.Colors.Graphite;choice.BorderSizePixel=0;choice.LayoutOrder=order;choice.Selectable=false;choice.Parent=symbolGrid
			local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=choice
			local selection=Instance.new("UIStroke");selection.Color=Theme.Colors.White;selection.Thickness=state.BadgeSymbol==symbolName and 2 or 1;selection.Transparency=state.BadgeSymbol==symbolName and 0 or .78;selection.Parent=choice
			BadgeSymbolLibrary.render(choice,symbolName,{Primary=primary,Secondary=secondary,Accent=accent},UDim2.fromScale(.72,.72))
			choice.Activated:Connect(function()state.BadgeSymbol=symbolName;renderOptions();renderPreview()end)
		end

		text(optionHolder,"BADGE COLORS",UDim2.fromOffset(0,540),UDim2.new(.34,0,0,34),8,Theme.Colors.Muted,Theme.Fonts.Strong)
		local colors=Button.new({Text=string.upper(state.BadgeColorBehavior),Variant="Secondary",Size=UDim2.new(.64,0,0,38),OnActivated=function()local list=Config.BadgeColorBehaviors;state.BadgeColorBehavior=list[indexOf(list,state.BadgeColorBehavior)%#list+1];renderOptions();renderPreview()end});colors.Position=UDim2.new(.36,0,0,540);colors.Parent=optionHolder
	end
	nameBox.FocusLost:Connect(renderPreview);tagBox.FocusLost:Connect(function()tagBox.Text=string.upper(tagBox.Text);renderPreview()end);renderPalette();renderOptions();renderPreview()
	local save=Button.new({Text=options.SaveLabel or"SAVE CLUB IDENTITY",Variant="Primary",Size=UDim2.fromOffset(230,44),OnActivated=function()state.Name=nameBox.Text;state.Abbreviation=string.upper(tagBox.Text);local result=options.OnSave(state);if result~=false and overlay.Parent then overlay:Destroy()end end});save.Position=UDim2.new(1,-254,1,-62);save.ZIndex=215;save.Parent=modal
	return overlay
end
return Editor
