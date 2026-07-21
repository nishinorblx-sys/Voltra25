--!strict

local UserInputService=game:GetService("UserInputService")

local DragController={};DragController.__index=DragController

local function pointer(input:InputObject):Vector2 return Vector2.new(input.Position.X,input.Position.Y) end
local function raiseZIndex(root:Instance,amount:number)
	if root:IsA("GuiObject") then root.ZIndex+=amount end
	for _,descendant in root:GetDescendants() do if descendant:IsA("GuiObject") then descendant.ZIndex+=amount end end
end
local function repairViewports(root:Instance)
	for _,descendant in root:GetDescendants() do if descendant:IsA("ViewportFrame") and not descendant.CurrentCamera then local camera=descendant:FindFirstChildWhichIsA("Camera",true);if camera then descendant.CurrentCamera=camera end end end
end
local function absoluteScale(root: Instance): number
	local scale = 1
	local current: Instance? = root
	while current do
		for _, child in current:GetChildren() do
			if child:IsA("UIScale") then
				scale *= child.Scale
			end
		end
		current = current.Parent
	end
	return math.max(scale, 0.001)
end
local function toRootLocal(root: GuiObject, screenPosition: Vector2): Vector2
	local scale = absoluteScale(root)
	return (screenPosition - root.AbsolutePosition) / scale
end

function DragController.new(root:GuiObject,options:any)
	local self=setmetatable({Root=root,Threshold=options.Threshold or 8,AllowTouchDrag=options.AllowTouchDrag==true,HitTest=options.HitTest,OnDragStart=options.OnDragStart,OnHover=options.OnHover,OnDrop=options.OnDrop,OnCancel=options.OnCancel,OnDragEnd=options.OnDragEnd,State=nil,Connections={}},DragController)
	table.insert(self.Connections,UserInputService.InputChanged:Connect(function(input) self:_changed(input) end))
	table.insert(self.Connections,UserInputService.InputEnded:Connect(function(input) self:_ended(input) end))
	return self
end

function DragController:_setHover(state:any,destination:any?)
	if state.HoverDestination==destination then return end
	local previous=state.HoverDestination
	state.HoverDestination=destination
	if self.OnHover then self.OnHover(destination,previous,state.Payload) end
end

function DragController:_ensureVisual(state:any,position:Vector2)
	local localPosition = toRootLocal(self.Root, position)
	local dragOffset = state.DragOffset or Vector2.zero
	if state.Preview then
		local nextPosition = localPosition - dragOffset
		state.Preview.Position=UDim2.fromOffset(nextPosition.X,nextPosition.Y)
		return
	end
	local preview=state.CardRoot:Clone()
	preview.Name="FullCardDragPreview"
	preview.AnchorPoint=Vector2.zero
	local nextPosition = localPosition - dragOffset
	preview.Position=UDim2.fromOffset(nextPosition.X,nextPosition.Y)
	local scale = absoluteScale(self.Root)
	preview.Size=UDim2.fromOffset(state.CardRoot.AbsoluteSize.X/scale,state.CardRoot.AbsoluteSize.Y/scale)
	preview.LayoutOrder=0
	preview.Selectable=false
	preview.Active=false
	raiseZIndex(preview,100)
	local liftScale=Instance.new("UIScale")
	liftScale.Name="DragLiftScale"
	liftScale.Scale=.97
	liftScale.Parent=preview
	preview.Parent=self.Root
	repairViewports(preview)
	state.Preview=preview
end

function DragController:_startDrag(state:any,position:Vector2)
	if state.Dragging then return end
	state.Dragging=true
	self:_ensureVisual(state,position)
	state.CardRoot.Visible=false
	if self.OnDragStart then self.OnDragStart(state.Payload) end
	local scale=state.Preview and state.Preview:FindFirstChild("DragLiftScale")
	if scale and scale:IsA("UIScale") then scale.Scale=1.03 end
end

function DragController:_finishVisual(state:any)
	self:_setHover(state,nil)
	if state.CardRoot then state.CardRoot.Visible=true end
	if state.Preview then state.Preview:Destroy();state.Preview=nil end
end

function DragController:_changed(input:InputObject)
	local state=self.State;if not state then return end
	if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
	local position=pointer(input)
	-- Some screens keep touch swipes for scrolling; squad management opts into direct touch drag.
	if input.UserInputType==Enum.UserInputType.Touch and not self.AllowTouchDrag and not state.Dragging and (position-state.Start).Magnitude>=self.Threshold then
		self:_finishVisual(state)
		self.State=nil
		return
	end
	if not state.Dragging and (position-state.Start).Magnitude>=self.Threshold then self:_startDrag(state,position) end
	if state.Dragging then
		self:_ensureVisual(state,position)
		self:_setHover(state,self.HitTest and self.HitTest(position) or nil)
	end
end

function DragController:_ended(input:InputObject)
	local state=self.State;if not state then return end
	if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
	self.State=nil
	if state.Dragging then
		local destination=self.HitTest and self.HitTest(pointer(input)) or nil
		self:_finishVisual(state)
		if destination then self.OnDrop(state.Payload,destination) elseif self.OnCancel then self.OnCancel(state.Payload) end
		if self.OnDragEnd then self.OnDragEnd(state.Payload) end
	else
		self:_finishVisual(state)
		if state.OnClick then self.SuppressActivatedUntil=os.clock()+.12;state.OnClick(state.Payload) end
	end
end

function DragController:Attach(cardRoot:GuiButton,payload:any,onClick:(any)->())
	cardRoot.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
		if self.State then self:_finishVisual(self.State) end
		local start = pointer(input)
		local scale = absoluteScale(self.Root)
		self.State={CardRoot=cardRoot,Payload=payload,OnClick=onClick,Start=start,Dragging=false,DragOffset=(start-cardRoot.AbsolutePosition)/scale}
	end)
	cardRoot.Activated:Connect(function() if not self.State and os.clock()>(self.SuppressActivatedUntil or 0) then onClick(payload) end end)
end

function DragController:Destroy()
	if self.State then self:_finishVisual(self.State) end
	for _,connection in self.Connections do connection:Disconnect() end;table.clear(self.Connections);self.State=nil
end

return DragController
