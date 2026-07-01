--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local ProClubsConfig=require(ReplicatedStorage.VTR.Shared.ProClubsConfig)
local Button=require(script.Parent.Button)
local Modal=require(script.Parent.Modal)
local LaunchService=require(script.Parent.Parent.Services.LaunchService)

local Builder={}

local function label(parent:Instance,text:string,pos:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel
	local object=Instance.new("TextLabel")
	object.BackgroundTransparency=1
	object.Position=pos
	object.Size=size
	object.Font=font
	object.Text=text
	object.TextColor3=color
	object.TextSize=textSize
	object.TextXAlignment=Enum.TextXAlignment.Left
	object.TextYAlignment=Enum.TextYAlignment.Center
	object.TextTruncate=Enum.TextTruncate.AtEnd
	object.ZIndex=72
	object.Parent=parent
	return object
end

local function round(parent:Instance,radius:number)
	local corner=Instance.new("UICorner")
	corner.CornerRadius=UDim.new(0,radius)
	corner.Parent=parent
end

function Builder.open(parent:Instance,context:any)
	local old=parent:FindFirstChild("ProClubsPlayerBuilder")
	if old then old:Destroy()end

	local overlay=Instance.new("CanvasGroup")
	overlay.Name="ProClubsPlayerBuilder"
	overlay.BackgroundColor3=Theme.Colors.Black
	overlay.BackgroundTransparency=.04
	overlay.BorderSizePixel=0
	overlay.Size=UDim2.fromScale(1,1)
	overlay.ZIndex=70
	overlay.Active=true
	overlay.Selectable=false
	overlay.Parent=parent

	local top=Instance.new("Frame")
	top.BackgroundColor3=Theme.Colors.Graphite
	top.BorderSizePixel=0
	top.Size=UDim2.new(1,0,0,92)
	top.ZIndex=71
	top.Parent=overlay
	local accent=Instance.new("Frame")
	accent.BackgroundColor3=Theme.Colors.White
	accent.BorderSizePixel=0
	accent.Size=UDim2.new(0,5,1,0)
	accent.ZIndex=72
	accent.Parent=top
	label(top,"PRO CLUBS",UDim2.fromOffset(28,12),UDim2.fromOffset(220,18),9,Theme.Colors.White,Theme.Fonts.Strong)
	label(top,"PLAYER BUILDER",UDim2.fromOffset(28,30),UDim2.new(1,-250,0,42),27,Theme.Colors.White,Theme.Fonts.Display)
	local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(128,38),OnActivated=function()overlay:Destroy()end})
	close.AnchorPoint=Vector2.new(1,.5)
	close.Position=UDim2.new(1,-24,.5,0)
	close.ZIndex=73
	close.Parent=top

	local content=Instance.new("ScrollingFrame")
	content.Name="BuilderContent"
	content.Active=true
	content.BackgroundTransparency=1
	content.BorderSizePixel=0
	content.Position=UDim2.fromOffset(24,108)
	content.Size=UDim2.new(1,-48,1,-132)
	content.ScrollBarImageColor3=Theme.Colors.White
	content.ScrollBarThickness=4
	content.AutomaticCanvasSize=Enum.AutomaticSize.Y
	content.CanvasSize=UDim2.new()
	content.ZIndex=71
	content.Parent=overlay
	local layout=Instance.new("UIListLayout")
	layout.Padding=UDim.new(0,12)
	layout.SortOrder=Enum.SortOrder.LayoutOrder
	layout.Parent=content

	local function clearContent()
		for _,child in content:GetChildren()do if child~=layout then child:Destroy()end end
	end

	local function panel(height:number):Frame
		local frame=Instance.new("Frame")
		frame.BackgroundColor3=Theme.Colors.Graphite
		frame.BackgroundTransparency=.08
		frame.BorderSizePixel=0
		frame.Size=UDim2.new(1,-8,0,height)
		frame.ZIndex=71
		frame.Parent=content
		round(frame,Theme.Radius.Medium)
		local stroke=Instance.new("UIStroke")
		stroke.Color=Theme.Colors.Gunmetal
		stroke.Thickness=1
		stroke.Transparency=.15
		stroke.Parent=frame
		return frame
	end

	local render:any
	render=function(pro:any)
		clearContent()
		if not pro or pro.Created~=true then
			local empty=panel(250)
			label(empty,"CREATE YOUR PRO",UDim2.fromOffset(24,20),UDim2.new(1,-48,0,34),22,Theme.Colors.White,Theme.Fonts.Display)
			label(empty,"Build a separate Pro Clubs footballer. Ultimate Team cards and club identity remain untouched.",UDim2.fromOffset(24,60),UDim2.new(1,-48,0,54),12,Theme.Colors.Muted,Theme.Fonts.Body).TextWrapped=true
			label(empty,"STARTING OVR 60  •  20 ATTRIBUTE POINTS  •  LEVEL CAP 100",UDim2.fromOffset(24,122),UDim2.new(1,-48,0,24),10,Theme.Colors.White,Theme.Fonts.Strong)
			local create=Button.new({Text="CREATE PRO",Variant="Primary",Size=UDim2.fromOffset(190,44),OnActivated=function()
				Modal.open(overlay,{Kicker="PRO CLUBS",Title="CREATE YOUR PLAYER",Description="Choose a fictional first and last name. You can develop the player after creation.",Fields={{Key="FirstName",Placeholder="FIRST NAME",Default="Alex"},{Key="LastName",Placeholder="LAST NAME",Default="Volt"}},ConfirmLabel="CREATE PLAYER",OnConfirm=function(values:any)
					local result=LaunchService:Request("CreateProPlayer",{FirstName=values.FirstName,LastName=values.LastName,Position="ST",PreferredFoot="Right"})
					context.Toast({Title=result.Success and"PRO CREATED"or"CREATION FAILED",Message=result.Message,Kind=result.Success and"Success"or"Error"})
					if result.Success and result.Data and result.Data.Pro then context.Data.Progression.ProClubsPlayer=result.Data.Pro;render(result.Data.Pro)end
				end})
			end})
			create.Position=UDim2.fromOffset(24,178)
			create.ZIndex=73
			create.Parent=empty
			return
		end

		local summary=panel(132)
		local fullName=((pro.FirstName or"").." "..(pro.LastName or"")):upper()
		label(summary,fullName,UDim2.fromOffset(24,14),UDim2.new(1,-270,0,34),24,Theme.Colors.White,Theme.Fonts.Display)
		label(summary,(pro.Position or"ST").."  •  "..(pro.PreferredFoot or"Right"):upper().." FOOT  •  LEVEL "..tostring(pro.Level or 1),UDim2.fromOffset(24,50),UDim2.new(1,-270,0,22),10,Theme.Colors.Muted,Theme.Fonts.Strong)
		label(summary,"BUILD: "..((pro.BuildPath~=""and pro.BuildPath)or"UNSELECTED"),UDim2.fromOffset(24,82),UDim2.new(1,-270,0,22),10,Theme.Colors.White,Theme.Fonts.Strong)
		local overall=label(summary,tostring(pro.Overall or 60),UDim2.new(1,-228,0,16),UDim2.fromOffset(88,58),43,Theme.Colors.White,Theme.Fonts.Display)
		overall.TextXAlignment=Enum.TextXAlignment.Center
		label(summary,"OVR",UDim2.new(1,-228,0,76),UDim2.fromOffset(88,20),9,Theme.Colors.Muted,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Center
		local ap=label(summary,tostring(pro.AttributePointsAvailable or 0),UDim2.new(1,-126,0,16),UDim2.fromOffset(88,58),43,Theme.Colors.White,Theme.Fonts.Display)
		ap.TextXAlignment=Enum.TextXAlignment.Center
		label(summary,"ATTRIBUTE POINTS",UDim2.new(1,-126,0,76),UDim2.fromOffset(88,20),8,Theme.Colors.Muted,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Center

		for category,attributes in ProClubsConfig.Categories do
			local categoryPanel=panel(54+#attributes*46)
			label(categoryPanel,string.upper(category),UDim2.fromOffset(20,10),UDim2.new(1,-40,0,28),15,Theme.Colors.White,Theme.Fonts.Display)
			for index,attribute in attributes do
				local y=45+(index-1)*46
				local row=Instance.new("Frame")
				row.BackgroundColor3=Theme.Colors.Gunmetal
				row.BackgroundTransparency=.35
				row.BorderSizePixel=0
				row.Position=UDim2.fromOffset(16,y)
				row.Size=UDim2.new(1,-32,0,38)
				row.ZIndex=72
				row.Parent=categoryPanel
				round(row,Theme.Radius.Small)
				label(row,string.upper(attribute),UDim2.fromOffset(12,0),UDim2.new(1,-150,1,0),10,Theme.Colors.White,Theme.Fonts.Strong)
				local value=tonumber((pro.Attributes or{})[attribute])or 55
				local score=label(row,tostring(value),UDim2.new(1,-132,0,0),UDim2.fromOffset(46,38),14,value>=80 and Theme.Colors.White or Theme.Colors.White,Theme.Fonts.Display)
				score.TextXAlignment=Enum.TextXAlignment.Center
				local upgrade=Button.new({Text="+1",Variant="Primary",Size=UDim2.fromOffset(66,30),OnActivated=function()
					local result=LaunchService:Request("SpendProAttribute",{Attribute=attribute,Amount=1})
					if not result.Success then context.Toast({Title="ATTRIBUTE",Message=result.Message,Kind="Error"})end
					if result.Success and result.Data and result.Data.Pro then context.Data.Progression.ProClubsPlayer=result.Data.Pro;render(result.Data.Pro)end
				end})
				upgrade.AnchorPoint=Vector2.new(1,.5)
				upgrade.Position=UDim2.new(1,-6,.5,0)
				upgrade.ZIndex=74
				upgrade.Parent=row
			end
		end

		local builds=panel(136)
		label(builds,"BUILD PATH",UDim2.fromOffset(20,10),UDim2.new(1,-40,0,28),15,Theme.Colors.White,Theme.Fonts.Display)
		label(builds,(pro.Level or 1)>=20 and"Select a specialization for your Pro."or"Unlocks at Level 20.",UDim2.fromOffset(20,38),UDim2.new(1,-40,0,24),10,Theme.Colors.Muted,Theme.Fonts.Body)
		for index,build in {"Poacher","Box To Box","Ball Playing Defender","Sweeper Keeper"}do
			local option=Button.new({Text=string.upper(build),Variant=pro.BuildPath==build and"Primary"or"Secondary",Size=UDim2.fromOffset(170,38),OnActivated=function()
				local result=LaunchService:Request("SelectProBuild",{Build=build})
				context.Toast({Title="BUILD PATH",Message=result.Message,Kind=result.Success and"Success"or"Info"})
				if result.Success and result.Data and result.Data.Pro then context.Data.Progression.ProClubsPlayer=result.Data.Pro;render(result.Data.Pro)end
			end})
			option.Position=UDim2.fromOffset(20+(index-1)*180,78)
			option.ZIndex=73
			option.Parent=builds
		end
	end

	render(context.Data.Progression.ProClubsPlayer)
	return overlay
end

return Builder
