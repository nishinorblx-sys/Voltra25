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

function DragController.new(root:GuiObject,options:any)
	local self=setmetatable({Root=root,Threshold=options.Threshold or 8,HitTest=options.HitTest,OnDrop=options.OnDrop,OnCancel=options.OnCancel,State=nil,Connections={}},DragController)
	table.insert(self.Connections,UserInputService.InputChanged:Connect(function(input) self:_changed(input) end))
	table.insert(self.Connections,UserInputService.InputEnded:Connect(function(input) self:_ended(input) end))
	return self
end

function DragController:_startVisual(state:any,position:Vector2)
	state.Dragging=true
	local preview=state.CardRoot:Clone()
	preview.Name="FullCardDragPreview"
	preview.AnchorPoint=Vector2.new(.5,.5)
	preview.Position=UDim2.fromOffset(position.X-self.Root.AbsolutePosition.X,position.Y-self.Root.AbsolutePosition.Y)
	preview.Size=UDim2.fromOffset(state.CardRoot.AbsoluteSize.X,state.CardRoot.AbsoluteSize.Y)
	preview.LayoutOrder=0
	preview.Selectable=false
	preview.Active=false
	raiseZIndex(preview,100)
	preview.Parent=self.Root
	repairViewports(preview)
	state.Preview=preview
	state.CardRoot.Visible=false
end

function DragController:_changed(input:InputObject)
	local state=self.State;if not state then return end
	if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
	local position=pointer(input)
	-- Touch cards use tap actions; swipes belong to their scrolling tray.
	-- Mobile player moves are intentionally initiated from the action menu.
	if input.UserInputType==Enum.UserInputType.Touch and not state.Dragging and (position-state.Start).Magnitude>=self.Threshold then
		self.State=nil
		return
	end
	if not state.Dragging and (position-state.Start).Magnitude>=self.Threshold then self:_startVisual(state,position) end
	if state.Preview then state.Preview.Position=UDim2.fromOffset(position.X-self.Root.AbsolutePosition.X,position.Y-self.Root.AbsolutePosition.Y) end
end

function DragController:_ended(input:InputObject)
	local state=self.State;if not state then return end
	if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
	self.State=nil
	if state.Dragging then
		state.CardRoot.Visible=true
		if state.Preview then state.Preview:Destroy() end
		local destination=self.HitTest and self.HitTest(pointer(input)) or nil
		if destination then self.OnDrop(state.Payload,destination) elseif self.OnCancel then self.OnCancel(state.Payload) end
	elseif state.OnClick then self.SuppressActivatedUntil=os.clock()+.12;state.OnClick(state.Payload) end
end

function DragController:Attach(cardRoot:GuiButton,payload:any,onClick:(any)->())
	cardRoot.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
		self.State={CardRoot=cardRoot,Payload=payload,OnClick=onClick,Start=pointer(input),Dragging=false}
	end)
	cardRoot.Activated:Connect(function() if not self.State and os.clock()>(self.SuppressActivatedUntil or 0) then onClick(payload) end end)
end

function DragController:Destroy()
	if self.State then if self.State.CardRoot then self.State.CardRoot.Visible=true end;if self.State.Preview then self.State.Preview:Destroy() end end
	for _,connection in self.Connections do connection:Disconnect() end;table.clear(self.Connections);self.State=nil
end

return DragController
