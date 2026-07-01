--!strict
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Controller={};Controller.__index=Controller

local function root(model:Model):BasePart?
	return model:FindFirstChild("HumanoidRootPart")::BasePart?
end

local function isKeeper(model:Model):boolean
	return tostring(model:GetAttribute("position")or"")=="GK"
end

function Controller.new(data:any,remote:RemoteEvent,hud:any)
	local self=setmetatable({Data=data,Remote=remote,HUD=hud,Connections={},Labels={},Active=true,Candidates={}},Controller)
	local teamModels=data.TeamModels and data.TeamModels[data.Team] or {}
	for _,model in teamModels do
		local modelRoot=root(model)
		if model~=data.Taker and modelRoot and not isKeeper(model) then
			local localPosition=data.PitchCFrame:PointToObjectSpace(modelRoot.Position)
			local inBox=math.abs(localPosition.X)<=data.PitchWidth*.43 and ((tonumber(data.GoalSign)or 1)>0 and localPosition.Z>=data.PitchLength*.5-132 or (tonumber(data.GoalSign)or 1)<0 and localPosition.Z<=-data.PitchLength*.5+132)
			if inBox then
				table.insert(self.Candidates,model)
				local gui=Instance.new("BillboardGui")
				gui.Name="VTRCornerReceiverPick"
				gui.Adornee=modelRoot
				gui.Size=UDim2.fromOffset(132,34)
				gui.StudsOffsetWorldSpace=Vector3.new(0,4.2,0)
				gui.AlwaysOnTop=true
				gui.Parent=Players.LocalPlayer.PlayerGui
				local text=Instance.new("TextLabel")
				text.Size=UDim2.fromScale(1,1)
				text.BackgroundColor3=Color3.fromRGB(2,4,2)
				text.BackgroundTransparency=.18
				text.BorderSizePixel=0
				text.Text=string.upper(tostring(model:GetAttribute("DisplayName")or model.Name))
				text.TextColor3=Color3.fromRGB(245,247,242)
				text.TextStrokeTransparency=.6
				text.Font=Enum.Font.GothamBlack
				text.TextSize=9
				text.Parent=gui
				table.insert(self.Labels,gui)
			end
		end
	end
	local trainer=Instance.new("BillboardGui")
	trainer.Name="VTRCornerTrainer"
	trainer.Adornee=data.Ball
	trainer.Size=UDim2.fromOffset(240,54)
	trainer.StudsOffsetWorldSpace=Vector3.new(0,3.4,0)
	trainer.AlwaysOnTop=true
	trainer.Parent=Players.LocalPlayer.PlayerGui
	local text=Instance.new("TextLabel")
	text.Size=UDim2.fromScale(1,1)
	text.BackgroundTransparency=1
	text.Text="CLICK A TARGET IN THE BOX"
	text.TextColor3=Color3.fromRGB(240,244,238)
	text.TextStrokeTransparency=.55
	text.Font=Enum.Font.GothamBold
	text.TextSize=12
	text.Parent=trainer
	self.Trainer=trainer
	table.insert(self.Connections,UserInputService.InputBegan:Connect(function(input,processed)
		if processed or not self.Active then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			self:_release()
		end
	end))
	return self
end

function Controller:_screenBest():Model?
	local camera=workspace.CurrentCamera
	if not camera then return self.Candidates[1] end
	local mouse=UserInputService:GetMouseLocation()
	local best=nil
	local bestScore=math.huge
	for _,model in self.Candidates do
		local modelRoot=root(model)
		if modelRoot then
			local point,visible=camera:WorldToViewportPoint(modelRoot.Position+Vector3.new(0,3,0))
			if visible and point.Z>0 then
				local distance=(Vector2.new(point.X,point.Y)-mouse).Magnitude
				if distance<bestScore then
					bestScore=distance
					best=model
				end
			end
		end
	end
	return best or self.Candidates[1]
end

function Controller:_release()
	if not self.Active then return end
	local receiver=self:_screenBest()
	if not receiver then return end
	local receiverRoot=root(receiver)
	if not receiverRoot then return end
	self.Active=false
	self.Remote:FireServer({Type="CornerKick",Delivery="Cross",Power=.66,Target=receiverRoot.Position,Receiver=receiver})
end

function Controller:Update()
	if not self.Active then return end
	if self.HUD then self.HUD:SetCharge(0,"")end
end

function Controller:GetTarget():Vector3
	local receiver=self:_screenBest()
	local receiverRoot=receiver and root(receiver)
	return receiverRoot and receiverRoot.Position or self.Data.Ball.Position
end

function Controller:Destroy()
	self.Active=false
	for _,connection in self.Connections do connection:Disconnect()end
	for _,gui in self.Labels do if gui.Parent then gui:Destroy()end end
	if self.Trainer then self.Trainer:Destroy()end
	if self.HUD then self.HUD:SetCharge(0,"")end
end

return Controller
