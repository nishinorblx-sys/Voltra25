--!strict
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Panel=require(script.Parent.Panel)
local Button=require(script.Parent.Button)
local KitPreview=require(script.Parent.KitPreview)
local Preview={}
local function text(parent:Instance,value:string,position:UDim2,size:UDim2,textSize:number):TextLabel local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=position;label.Size=size;label.Text=value;label.TextColor3=Theme.Colors.White;label.TextSize=textSize;label.Font=Theme.Fonts.Display;label.TextXAlignment=Enum.TextXAlignment.Left;label.ZIndex=83;label.Parent=parent;return label end
function Preview.open(parent:Instance,item:any,kind:string)
	local overlay=Instance.new("Frame");overlay.Name="InventoryItemPreview";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.15;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=80;overlay.Parent=parent
	local panel=Panel.new({Name="Preview",Size=UDim2.fromOffset(650,520),ClipsDescendants=true});panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.ZIndex=81;panel.Parent=overlay;text(panel,string.upper(item.Name or item.Id),UDim2.fromOffset(24,18),UDim2.new(1,-150,0,34),22)
	local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(100,36),OnActivated=function()overlay:Destroy()end});close.Position=UDim2.new(1,-124,0,18);close.ZIndex=84;close.Parent=panel
	if kind=="Kits"then local kit=KitPreview.new(panel,{PrimaryColor=item.Primary or"050505",SecondaryColor=item.Secondary or"B7FF1A",AccentColor=item.Accent or item.Secondary or"D9D9D9",KitStyle=item.Style or"Solid"},UDim2.fromOffset(360,410));kit.AnchorPoint=Vector2.new(.5,0);kit.Position=UDim2.new(.5,0,0,76);kit.ZIndex=82
	else
		local viewport=Instance.new("ViewportFrame");viewport.Name="StadiumViewport";viewport.BackgroundColor3=Color3.fromHex("090C09");viewport.BorderSizePixel=0;viewport.Position=UDim2.fromOffset(24,72);viewport.Size=UDim2.new(1,-48,1,-96);viewport.Ambient=Color3.fromRGB(155,165,155);viewport.LightColor=Color3.fromRGB(255,255,240);viewport.LightDirection=Vector3.new(-1,-1,-1);viewport.ZIndex=82;viewport.Parent=panel
		local world=Instance.new("WorldModel");world.Parent=viewport;local source=workspace:FindFirstChild(item.Id or"",true)or workspace:FindFirstChild(item.Name or"",true);local model=Instance.new("Model");model.Name="PreviewStadium";model.Parent=world
		if source then local clone=source:Clone();clone.Parent=model else local pitch=Instance.new("Part");pitch.Size=Vector3.new(70,1,105);pitch.Color=Color3.fromHex("1D5B24");pitch.Anchored=true;pitch.Parent=model;for _,x in{-44,44}do local stand=Instance.new("Part");stand.Size=Vector3.new(12,20,115);stand.Position=Vector3.new(x,8,0);stand.Color=Color3.fromHex("191919");stand.Anchored=true;stand.Parent=model end end
		for _,descendant in model:GetDescendants()do if descendant:IsA("BasePart")then descendant.Anchored=true;descendant.CanCollide=false end end
		local camera=Instance.new("Camera");camera.FieldOfView=42;camera.Parent=viewport;viewport.CurrentCamera=camera;local center,size=model:GetBoundingBox();local radius=math.max(size.X,size.Y,size.Z);local yaw=0
		local function update()local focus=center.Position;local offset=CFrame.Angles(0,yaw,0):VectorToWorldSpace(Vector3.new(radius*.95,radius*.55,radius*.95));camera.CFrame=CFrame.lookAt(focus+offset,focus)end;update()
		local dragging=false;local lastX=0;viewport.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;lastX=input.Position.X end end);viewport.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end);local connection=UserInputService.InputChanged:Connect(function(input)if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then yaw+=(input.Position.X-lastX)*.008;lastX=input.Position.X;update()end end);overlay.Destroying:Connect(function()connection:Disconnect()end)
		local hint=text(panel,"DRAG TO ROTATE STADIUM PREVIEW",UDim2.fromOffset(24,486),UDim2.new(1,-48,0,18),8);hint.TextColor3=Theme.Colors.White;hint.TextXAlignment=Enum.TextXAlignment.Center
	end
	return overlay
end
return Preview
