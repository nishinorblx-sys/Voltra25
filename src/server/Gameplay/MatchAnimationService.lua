--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local AnimationConfig = require(ReplicatedStorage.VTR.Shared.AnimationConfig)

local Service = {}
Service.__index = Service

local MOVEMENT = {Idle=true,Walk=true,Jog=true,Sprint=true,Dribble=true,Jockey=true,GoalkeeperIdle=true,GoalkeeperMove=true,Turn=true}
local ACTION = {ReceiveBall=true,Receive=true,Pass=true,Shoot=true,Tackle=true,SlideTackle=true,DribbleMove1=true,DribbleMove4=true,Header=true,GoalkeeperDive=true,Celebrate=true,GoalCelebration=true}

local function loadModel(model: Model): any
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator=Instance.new("Animator");animator.Parent=humanoid end
	local state = {Model=model,Animator=animator,Tracks={},Animations={},Movement=nil,Action=nil}
	for name,id in AnimationConfig do
		local animation=Instance.new("Animation");animation.Name="VTR_"..name;animation.AnimationId=id;state.Animations[name]=animation
		pcall(function()ContentProvider:PreloadAsync({animation})end)
		local ok,result=pcall(function()return animator:LoadAnimation(animation)end)
		if ok and result then
			local track:AnimationTrack=result
			track.Looped=MOVEMENT[name]==true
			track.Priority=(name=="Shoot"or name=="Pass"or name=="Tackle"or name=="GoalkeeperDive"or name=="SlideTackle")and Enum.AnimationPriority.Action4 or ACTION[name]and Enum.AnimationPriority.Action or(name=="Idle"or name=="GoalkeeperIdle")and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
			state.Tracks[name]=track
		else warn(string.format("[VTR ANIMATION] %s failed on %s: %s",name,model.Name,tostring(result)))end
	end
	model:SetAttribute("VTRServerAnimations",true)
	model:SetAttribute("VTRAnimationTracksLoaded",0)
	local loadedCount=0;for _ in state.Tracks do loadedCount+=1 end;model:SetAttribute("VTRAnimationTracksLoaded",loadedCount)
	task.delay(3,function()
		if not model.Parent then return end
		for name,track in state.Tracks do if track.Length<=0 then warn(string.format("[VTR ANIMATION] %s did not load on %s. Check that the animation is R6 and permitted for this experience.",name,model.Name))end end
	end)
	return state
end

function Service.new(models:{Model})
	local states={}
	for _,model in models do local state=loadModel(model);if state then states[model]=state end end
	local self=setmetatable({States=states,PreviousOwner=nil},Service)
	for model,_ in states do self:_movement(model,model:GetAttribute("position")=="GK"and"GoalkeeperIdle"or"Idle",1)end
	return self
end

function Service:_movement(model:Model,name:string,speed:number?)
	local state=self.States[model];if not state then return end
	local track=state.Tracks[name];if not track then return end
	if state.Movement~=track or not track.IsPlaying then
		if state.Movement and state.Movement.IsPlaying then state.Movement:Stop(.14)end
		state.Movement=track;track:Play(.14)
		model:SetAttribute("VTRAnimationState",name)
	end
	if speed and track.Length>0 then track:AdjustSpeed(math.clamp(speed,0.72,1.35))end
end

function Service:PlayAction(model:Model,name:string)
	local state=self.States[model];if not state then return end
	local track=state.Tracks[name];if not track then return end
	if state.Action and state.Action~=track and state.Action.IsPlaying then state.Action:Stop(.06)end
	state.Action=track;if track.IsPlaying then track:Stop(.025)end;track:Play(.04);track:AdjustSpeed(name=="Shoot"and.78 or name=="Tackle"and 2 or 1)
	model:SetAttribute("VTRAnimationAction",name)
end

function Service:PlayActionTimed(model:Model,name:string,duration:number)
	self:PlayAction(model,name)
	local state=self.States[model];local track=state and state.Tracks[name]
	if not track then return end
	duration=math.max(duration,.12)
	if track.Length>0 then track:AdjustSpeed(math.clamp(track.Length/duration,.2,2.5))end
	model:SetAttribute("VTRAnimationDuration",duration)
end

function Service:SyncActionToArrival(model:Model,name:string,remaining:number)
	local state=self.States[model];local track=state and state.Tracks[name]
	if not track or track.Length<=0 then return end
	local extensionPoint=track.Length*.92
	if remaining<=.045 then track.TimePosition=math.min(extensionPoint,track.Length);track:AdjustSpeed(0);return end
	local animationRemaining=math.max(extensionPoint-track.TimePosition,.01)
	track:AdjustSpeed(math.clamp(animationRemaining/remaining,.18,3.5))
end

function Service:StopAction(model:Model,fade:number?)
	local state=self.States[model];if not state or not state.Action then return end
	state.Action:AdjustSpeed(1);state.Action:Stop(fade or .1);state.Action=nil
end

function Service:ForceIdle(model:Model)
	local state=self.States[model];if not state then return end
	if state.Action and state.Action.IsPlaying then state.Action:Stop(.05)end
	state.Action=nil
	if state.Movement and state.Movement.IsPlaying then state.Movement:Stop(.05)end
	state.Movement=nil
	self:_movement(model,model:GetAttribute("position")=="GK"and"GoalkeeperIdle"or"Idle",1)
end

function Service:Step(owner:Model?)
	if owner and owner~=self.PreviousOwner then self:PlayAction(owner,"ReceiveBall")end
	self.PreviousOwner=owner
	for model,_ in self.States do
		if not model.Parent then continue end
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?;if not root then continue end
		if model:GetAttribute("VTRForceIdle")==true then self:_movement(model,model:GetAttribute("position")=="GK"and"GoalkeeperIdle"or"Idle",1);continue end
		local speed=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
		local goalkeeper=model:GetAttribute("position")=="GK"
		if speed<.55 then self:_movement(model,goalkeeper and"GoalkeeperIdle"or"Idle",1)
		elseif goalkeeper then self:_movement(model,"GoalkeeperMove",math.clamp(speed/14,.75,1.25))
		elseif owner==model then self:_movement(model,"Dribble",math.clamp(speed/16,.75,1.3))
		elseif model:GetAttribute("VTRSprinting")==true or speed>20 then self:_movement(model,"Sprint",math.clamp(speed/22,.8,1.35))
		elseif speed<8 then self:_movement(model,"Walk",math.clamp(speed/7,.72,1.2))
		else self:_movement(model,"Jog",math.clamp(speed/14,.75,1.3))end
	end
end

function Service:Destroy()
	for model,state in self.States do
		if model.Parent then model:SetAttribute("VTRServerAnimations",nil)end
		for _,track in state.Tracks do track:Stop(.08);track:Destroy()end
		for _,animation in state.Animations do animation:Destroy()end
	end
	table.clear(self.States)
end

return Service
