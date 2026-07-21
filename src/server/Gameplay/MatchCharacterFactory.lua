--!strict
local Players=game:GetService("Players")
local AppearanceApplier=require(script.Parent.AppearanceApplier)
local KitApplier=require(script.Parent.KitApplier)
local Factory={}
local function stat(data:any,key:string):number return tonumber(data.mainStats and data.mainStats[key])or tonumber(data.overall)or 60 end
local function value(data:any,detailed:any,key:string,attribute:string?,fallback:number):number
	return tonumber(data[key])or tonumber(data[attribute or key])or tonumber(detailed[key])or tonumber(detailed[attribute or key])or fallback
end
local function normalizeId(value:any):string
	local clean=tostring(value or""):lower():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
	return clean
end
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
local function ensureVisibleFootballer(model:Model)
	for _,descendant in model:GetDescendants()do
		if descendant:IsA("BasePart")then
			descendant.LocalTransparencyModifier=0
			if descendant.Name~="HumanoidRootPart" and descendant.Name~="ChestBadgePlate" then
				descendant.Transparency=0
			end
		elseif descendant:IsA("Decal")or descendant:IsA("Texture")then
			descendant.Transparency=0
		end
	end
end
function Factory.Create(data:any,team:any,side:string,index:number,kit:any):Model
	local model=createStandardR6();model:SetAttribute("VTRRigSource","RobloxStandardR6");model.Name=side.."_"..index.."_"..tostring(data.shortName or data.playerId);local root=model:FindFirstChild("HumanoidRootPart")::BasePart?;if root then model.PrimaryPart=root end
model:SetAttribute("playerId",data.playerId);model:SetAttribute("cardInstanceId","");model:SetAttribute("teamId",team.teamId);model:SetAttribute("teamSide",side);model:SetAttribute("VTRTeam",side);model:SetAttribute("VTRIndex",index);model:SetAttribute("ShirtNumber",index);model:SetAttribute("position",data.bestPosition or"CM");model:SetAttribute("overall",data.overall or 60);model:SetAttribute("DisplayName",data.displayName or"VTR Player");model:SetAttribute("rarity",data.rarity or data.Rarity or"Common");model:SetAttribute("cardType",data.cardType or data.CardType or"Base");for _,key in{"PAC","SHO","PAS","DRI","DEF","PHY"}do model:SetAttribute(key,stat(data,key))end;model:SetAttribute("Acceleration",tonumber(data.acceleration)or tonumber(data.PAC)or 60);model:SetAttribute("Agility",tonumber(data.agility)or tonumber(data.DRI)or 60);model:SetAttribute("Stamina",tonumber(data.stamina)or(data.detailedStats and tonumber(data.detailedStats.stamina))or tonumber(data.PHY)or 65);model:SetAttribute("VTRStamina",100);model:SetAttribute("BodyBuild",data.bodyBuild or data.bodyType or(data.appearance and data.appearance.bodyBuild)or"Balanced");model:SetAttribute("Curve",tonumber(data.curve)or tonumber(data.PAS)or 60);model:SetAttribute("FkAccuracy",tonumber(data.fkAccuracy)or(data.detailedStats and tonumber(data.detailedStats.fkAccuracy))or tonumber(data.PAS)or 60);model:SetAttribute("Penalties",tonumber(data.penalties)or(data.detailedStats and tonumber(data.detailedStats.penalties))or tonumber(data.SHO)or 60);model:SetAttribute("Finishing",tonumber(data.finishing)or tonumber(data.SHO)or 60);model:SetAttribute("WeakFoot",tonumber(data.weakFoot)or 3);model:SetAttribute("PreferredFoot",data.preferredFoot or"Right");model:SetAttribute("BallControl",tonumber(data.ballControl)or tonumber(data.DRI)or 60);model:SetAttribute("Composure",tonumber(data.composure)or tonumber(data.DRI)or 60);model:SetAttribute("controlledByUser",false);model:SetAttribute("aiControlled",true)
	model:SetAttribute("cardInstanceId",data.cardInstanceId or"")
	local instructions=type(data.PlayerInstructions)=="table"and data.PlayerInstructions or{}
	model:SetAttribute("VTRAttackInstruction",tostring(instructions.OffBall or data.OffBallInstruction or"SupportBall"))
	model:SetAttribute("VTRDefensiveInstruction",tostring(instructions.Defending or data.DefensiveInstruction or"Balanced"))
	model:SetAttribute("VTRInstructionCardId",tostring(data.cardInstanceId or data.Id or""))
	model:SetAttribute("VTRAIMovementProfile",nil)
	local detailed=data.detailedStats or data.DetailedStats or{}
	local overall=tonumber(data.overall)or 60
	local pac=stat(data,"PAC");local sho=stat(data,"SHO");local pas=stat(data,"PAS");local dri=stat(data,"DRI");local def=stat(data,"DEF");local phy=stat(data,"PHY")
	local detailedMap={
		Acceleration={"acceleration","Acceleration",pac},SprintSpeed={"sprintSpeed","SprintSpeed",pac},Finishing={"finishing","Finishing",sho},ShotPower={"shotPower","ShotPower",sho},LongShots={"longShots","LongShots",sho},Volleys={"volleys","Volleys",sho},Penalties={"penalties","Penalties",sho},ShortPassing={"shortPassing","ShortPassing",pas},LongPassing={"longPassing","LongPassing",pas},Vision={"vision","Vision",pas},Crossing={"crossing","Crossing",pas},Curve={"curve","Curve",pas},FkAccuracy={"fkAccuracy","FkAccuracy",pas},Dribbling={"dribbling","Dribbling",dri},BallControl={"ballControl","BallControl",dri},Agility={"agility","Agility",dri},Balance={"balance","Balance",dri},Reactions={"reactions","Reactions",overall},DefensiveAwareness={"defensiveAwareness","DefensiveAwareness",def},StandingTackle={"standingTackle","StandingTackle",def},SlidingTackle={"slidingTackle","SlidingTackle",def},Interceptions={"interceptions","Interceptions",def},Strength={"strength","Strength",phy},Stamina={"stamina","Stamina",phy},Aggression={"aggression","Aggression",phy},Jumping={"jumping","Jumping",phy},HeadingAccuracy={"headingAccuracy","HeadingAccuracy",sho},AttackingPosition={"attackingPosition","AttackingPosition",sho},Composure={"composure","Composure",overall},GKDiving={"gkDiving","GKDiving",overall},GKHandling={"gkHandling","GKHandling",overall},GKKicking={"gkKicking","GKKicking",overall},GKPositioning={"gkPositioning","GKPositioning",overall},GKReflexes={"gkReflexes","GKReflexes",overall}
	}
	for attribute,keys in pairs(detailedMap)do model:SetAttribute(attribute,value(data,detailed,keys[1],keys[2],keys[3]))end
	for _,source in ipairs({data.PlayStyles,data.playStyles,data.specialties,data.Specialties})do
		if type(source)=="table"then
			for key,item in pairs(source)do
				local id=type(item)=="table"and(item.id or item.Id or item.name or item.Name)or key
				local tier=type(item)=="table"and(item.tier or item.Tier or item.level or item.Level)or item
				local normalized=normalizeId(id)
				if normalized~=""then model:SetAttribute("VTRPlayStyle_"..normalized,math.clamp(math.floor(tonumber(tier)or 1),1,3))end
			end
		end
	end
	if type(data.PlayTraitLevels)=="table"then for id,level in pairs(data.PlayTraitLevels)do model:SetAttribute("VTRPlayTrait_"..tostring(id),math.clamp(math.floor(tonumber(level)or 0),0,3))end end
	model:SetAttribute("ShotPower",tonumber(data.shotPower)or tonumber(data.ShotPower)or tonumber(detailed.shotPower)or tonumber(detailed.ShotPower)or stat(data,"SHO"))
	model:SetAttribute("LongShots",tonumber(data.longShots)or tonumber(data.LongShots)or tonumber(detailed.longShots)or tonumber(detailed.LongShots)or stat(data,"SHO"))
	model:SetAttribute("StandingTackle",tonumber(data.standingTackle)or tonumber(detailed.standingTackle)or stat(data,"DEF"));model:SetAttribute("SlidingTackle",tonumber(data.slidingTackle)or tonumber(detailed.slidingTackle)or stat(data,"DEF"));model:SetAttribute("Dribbling",tonumber(data.dribbling)or tonumber(detailed.dribbling)or stat(data,"DRI"));model:SetAttribute("SkillMoves",tonumber(data.skillMoves)or 1)
	model:SetAttribute("VTRSprintEnergy",100);model:SetAttribute("VTREndurance",100);model:SetAttribute("VTRSprintStamina",100);model:SetAttribute("VTRStamina",100);model:SetAttribute("VTRSprintLocked",false);model:SetAttribute("VTRSprinting",false)
	local appearanceOk,appearanceError=pcall(AppearanceApplier.Apply,model,data.appearance);if not appearanceOk then warn("[VTR APPEARANCE] "..tostring(appearanceError))end
	local avatarUserId=tonumber(data.AppearanceUserId or data.UserId or data.userId)
	if avatarUserId and avatarUserId>0 then
		model:SetAttribute("VTRPreserveAvatarHead", true)
		model:SetAttribute("VTRAvatarHeadUserId", avatarUserId)
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local avatarOk,avatarResult=pcall(function()
				local description=Players:GetHumanoidDescriptionFromUserId(avatarUserId)
				humanoid:ApplyDescription(description)
				description:Destroy()
			end)
			if not avatarOk then warn("[VTR AVATAR] "..tostring(avatarResult))end
		end
	end
	local kitOk,kitError=pcall(KitApplier.Apply,model,kit,index,data.shortName or data.displayName or"PLAYER",team.logo or"V");if not kitOk then warn("[VTR KIT] "..tostring(kitError))end
	ensureVisibleFootballer(model)
	local humanoid=model:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff;humanoid.NameDisplayDistance=0;humanoid.HealthDisplayDistance=0;humanoid.DisplayName="";lockFootballerPhysics(humanoid);if not humanoid:FindFirstChildOfClass("Animator")then local animator=Instance.new("Animator");animator.Parent=humanoid end end
	return model
end
return Factory
