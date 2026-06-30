--!strict
local PitchConfig=require(script.Parent.PitchConfig)
local Service={};Service.__index=Service
local function root(model:Model):BasePart?return model:FindFirstChild("HumanoidRootPart")::BasePart?end
function Service.new(remote:RemoteEvent,stats:any,teams:any,pitchCFrame:CFrame,onRestart:(string,Vector3)->())return setmetatable({Remote=remote,Stats=stats,Teams=teams,PitchCFrame=pitchCFrame,OnRestart=onRestart,Half=1},Service)end
function Service:SetHalf(half:number?)self.Half=half or 1 end
function Service:IsOffside(passer:Model,receiver:Model,ballPosition:Vector3):boolean
	local side=tostring(passer:GetAttribute("VTRTeam")or"Home");if receiver:GetAttribute("VTRTeam")~=side then return false end
	local receiverRoot=root(receiver);if not receiverRoot then return false end;local sign=PitchConfig.GetAttackDirection(side,{AttackSigns={Home=(self.Half or 1)>=2 and 1 or -1,Away=(self.Half or 1)>=2 and -1 or 1}})
	local receiverProgress=self.PitchCFrame:PointToObjectSpace(receiverRoot.Position).Z*sign;local ballProgress=self.PitchCFrame:PointToObjectSpace(ballPosition).Z*sign
	if receiverProgress<=0 or receiverProgress<=ballProgress+.5 then return false end
	local opponents=self.Teams[side=="Home"and"Away"or"Home"];local lines={}
	for _,opponent in opponents do local opponentRoot=root(opponent);if opponentRoot then table.insert(lines,self.PitchCFrame:PointToObjectSpace(opponentRoot.Position).Z*sign)end end
	table.sort(lines,function(a,b)return a>b end);local secondLast=lines[2]or lines[1]or math.huge
	return receiverProgress>secondLast+.5
end
function Service:Call(receiver:Model)
	local side=tostring(receiver:GetAttribute("VTRTeam")or"Home");local receiverRoot=root(receiver);if not receiverRoot then return end
	self.Stats:Add(side,"Offsides");self.Stats:Event(receiver,"Offside");self.Remote:FireAllClients({Type="Offside",Actor=receiver,Location=receiverRoot.Position})
	task.defer(self.OnRestart,side=="Home"and"Away"or"Home",receiverRoot.Position)
end
return Service
