--!strict
local PitchConfig=require(script.Parent.PitchConfig)
local OffsidePositionUtil=require(script.Parent.OffsidePositionUtil)
local Service={};Service.__index=Service
local function root(model:Model):BasePart?return model:FindFirstChild("HumanoidRootPart")::BasePart?end
function Service.new(remote:RemoteEvent,stats:any,teams:any,pitchCFrame:CFrame,onRestart:(string,Vector3)->())return setmetatable({Remote=remote,Stats=stats,Teams=teams,PitchCFrame=pitchCFrame,OnRestart=onRestart,Half=1},Service)end
function Service:SetHalf(half:number?)self.Half=half or 1 end
function Service:IsOffside(passer:Model,receiver:Model,ballPosition:Vector3):boolean
	local side=tostring(passer:GetAttribute("VTRTeam")or"Home");if receiver:GetAttribute("VTRTeam")~=side then return false end
	local options={PitchCFrame=self.PitchCFrame,AttackSigns={Home=(self.Half or 1)>=2 and 1 or -1,Away=(self.Half or 1)>=2 and -1 or 1}}
	local opponents={}
	for _,opponent in (self.Teams[side=="Home"and"Away"or"Home"]or{}) do local opponentRoot=root(opponent);if opponentRoot then table.insert(opponents,{Root=opponentRoot,World=opponentRoot.Position})end end
	return OffsidePositionUtil.IsModelOffsideAt({Options=options,Teams={[side=="Home"and"Away"or"Home"]={List=opponents}}},passer,receiver,ballPosition,.5)
end
function Service:Call(receiver:Model)
	local side=tostring(receiver:GetAttribute("VTRTeam")or"Home");local receiverRoot=root(receiver);if not receiverRoot then return end
	self.Stats:Add(side,"Offsides");self.Stats:Event(receiver,"Offside");self.Remote:FireAllClients({Type="Offside",Actor=receiver,Location=receiverRoot.Position})
	task.defer(self.OnRestart,side=="Home"and"Away"or"Home",receiverRoot.Position)
end
return Service
