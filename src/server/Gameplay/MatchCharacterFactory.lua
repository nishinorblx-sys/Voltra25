--!strict
local Players=game:GetService("Players")
local AppearanceApplier=require(script.Parent.AppearanceApplier)
local KitApplier=require(script.Parent.KitApplier)
local Factory={}
local function stat(data:any,key:string):number return tonumber(data.mainStats and data.mainStats[key])or tonumber(data.overall)or 60 end
local function createStandardR6():Model
	local lastError:any=nil
	for _=1,3 do
		local ok,result=pcall(function()
			local description=Instance.new("HumanoidDescription")
			local created=Players:CreateHumanoidModelFromDescription(description,Enum.HumanoidRigType.R6)
			description:Destroy()
			return created
		end)
		if ok and result and result:IsA("Model")then return result end
		lastError=result;task.wait(.08)
	end
	error("Roblox could not create a standard R6 Humanoid model: "..tostring(lastError))
end
local function lockFootballerPhysics(humanoid:Humanoid)
	for _,state in{Enum.HumanoidStateType.FallingDown,Enum.HumanoidStateType.Ragdoll,Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.PlatformStanding}do
		humanoid:SetStateEnabled(state,false)
	end
	humanoid.PlatformStand=false
	humanoid.Sit=false
	humanoid.AutoRotate=true
end
function Factory.Create(data:any,team:any,side:string,index:number,kit:any):Model
	local model=createStandardR6();model:SetAttribute("VTRRigSource","RobloxStandardR6");model.Name=side.."_"..index.."_"..tostring(data.shortName or data.playerId);local root=model:FindFirstChild("HumanoidRootPart")::BasePart?;if root then model.PrimaryPart=root end
model:SetAttribute("playerId",data.playerId);model:SetAttribute("cardInstanceId","");model:SetAttribute("teamId",team.teamId);model:SetAttribute("teamSide",side);model:SetAttribute("VTRTeam",side);model:SetAttribute("VTRIndex",index);model:SetAttribute("ShirtNumber",index);model:SetAttribute("position",data.bestPosition or"CM");model:SetAttribute("overall",data.overall or 60);model:SetAttribute("DisplayName",data.displayName or"VTR Player");for _,key in{"PAC","SHO","PAS","DRI","DEF","PHY"}do model:SetAttribute(key,stat(data,key))end;model:SetAttribute("Acceleration",tonumber(data.acceleration)or tonumber(data.PAC)or 60);model:SetAttribute("Agility",tonumber(data.agility)or tonumber(data.DRI)or 60);model:SetAttribute("Stamina",tonumber(data.stamina)or(data.detailedStats and tonumber(data.detailedStats.stamina))or tonumber(data.PHY)or 65);model:SetAttribute("VTRStamina",100);model:SetAttribute("BodyBuild",data.bodyBuild or data.bodyType or(data.appearance and data.appearance.bodyBuild)or"Balanced");model:SetAttribute("Curve",tonumber(data.curve)or tonumber(data.PAS)or 60);model:SetAttribute("FkAccuracy",tonumber(data.fkAccuracy)or(data.detailedStats and tonumber(data.detailedStats.fkAccuracy))or tonumber(data.PAS)or 60);model:SetAttribute("Penalties",tonumber(data.penalties)or(data.detailedStats and tonumber(data.detailedStats.penalties))or tonumber(data.SHO)or 60);model:SetAttribute("Finishing",tonumber(data.finishing)or tonumber(data.SHO)or 60);model:SetAttribute("WeakFoot",tonumber(data.weakFoot)or 3);model:SetAttribute("PreferredFoot",data.preferredFoot or"Right");model:SetAttribute("BallControl",tonumber(data.ballControl)or tonumber(data.DRI)or 60);model:SetAttribute("Composure",tonumber(data.composure)or tonumber(data.DRI)or 60);model:SetAttribute("controlledByUser",false);model:SetAttribute("aiControlled",true)
	model:SetAttribute("cardInstanceId",data.cardInstanceId or"")
	local detailed=data.detailedStats or data.DetailedStats or{}
	model:SetAttribute("ShotPower",tonumber(data.shotPower)or tonumber(data.ShotPower)or tonumber(detailed.shotPower)or tonumber(detailed.ShotPower)or stat(data,"SHO"))
	model:SetAttribute("LongShots",tonumber(data.longShots)or tonumber(data.LongShots)or tonumber(detailed.longShots)or tonumber(detailed.LongShots)or stat(data,"SHO"))
	model:SetAttribute("StandingTackle",tonumber(data.standingTackle)or tonumber(detailed.standingTackle)or stat(data,"DEF"));model:SetAttribute("SlidingTackle",tonumber(data.slidingTackle)or tonumber(detailed.slidingTackle)or stat(data,"DEF"));model:SetAttribute("Dribbling",tonumber(data.dribbling)or tonumber(detailed.dribbling)or stat(data,"DRI"));model:SetAttribute("SkillMoves",tonumber(data.skillMoves)or 1)
	model:SetAttribute("VTREndurance",100);model:SetAttribute("VTRSprintStamina",100)
	local appearanceOk,appearanceError=pcall(AppearanceApplier.Apply,model,data.appearance);if not appearanceOk then warn("[VTR APPEARANCE] "..tostring(appearanceError))end;local kitOk,kitError=pcall(KitApplier.Apply,model,kit,index,data.shortName or data.displayName or"PLAYER",team.logo or"V");if not kitOk then warn("[VTR KIT] "..tostring(kitError))end
	local humanoid=model:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff;humanoid.NameDisplayDistance=0;humanoid.HealthDisplayDistance=0;humanoid.DisplayName="";lockFootballerPhysics(humanoid);if not humanoid:FindFirstChildOfClass("Animator")then local animator=Instance.new("Animator");animator.Parent=humanoid end end
	return model
end
return Factory
