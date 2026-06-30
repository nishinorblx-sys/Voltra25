--!strict
local MatchCharacterFactory=require(script.Parent.MatchCharacterFactory)
local FormationService=require(script.Parent.FormationService)
local Service={}
local styles={Home="Vertical Stripes",Away="Solid",Third="Diagonal Sash"}
local function selectedKit(team:any,name:string):any local source=team.kits[name]or team.kits.Home;local result=table.clone(source);result.Style=result.Style or styles[name]or"Solid";result.Accent=result.Accent or team.colors.Accent;result.NumberColor=result.NumberColor or team.colors.Accent;return result end
function Service.Spawn(folder:Folder,pitchCFrame:CFrame,width:number,length:number,player:Player,home:any,away:any,setup:any):any
	local formationNames={Home=home.Formation or"4-3-3",Away=away.Formation or"4-3-3"};local activeFormation={Home=FormationService.Build(formationNames.Home,width,length),Away=FormationService.Build(formationNames.Away,width,length),Names=formationNames}
	local teams={Home={},Away={}};local kits={Home=selectedKit(home.Team,setup.HomeKit),Away=selectedKit(away.Team,setup.AwayKit)}
	for _,side in{"Home","Away"}do
		local roster=side=="Home"and home.StartingXI or away.StartingXI;local team=side=="Home"and home.Team or away.Team;local sign=side=="Home"and 1 or-1
		for index,data in roster do
			local model=MatchCharacterFactory.Create(data,team,side,index,kits[side]);model:SetAttribute("VTRFormation",formationNames[side]);model.Parent=folder;local matchHumanoid=model:FindFirstChildOfClass("Humanoid");if matchHumanoid then matchHumanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;matchHumanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff;matchHumanoid.NameDisplayDistance=0;matchHumanoid.HealthDisplayDistance=0;matchHumanoid.DisplayName=""end
			local point=activeFormation[side][index]or Vector2.zero;local position=pitchCFrame:PointToWorldSpace(Vector3.new(point.X,3,point.Y*sign));local target=pitchCFrame:PointToWorldSpace(Vector3.new(point.X,3,point.Y*sign-sign*8));model:PivotTo(CFrame.lookAt(position,target));table.insert(teams[side],model)
			local networkRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?
			if networkRoot then local ownerOk,ownerError=pcall(function()networkRoot:SetNetworkOwner(nil)end);if not ownerOk then warn("[VTR NETWORK OWNER] "..tostring(ownerError))end end
		end
	end
	local accountCharacter=player.Character;local accountRoot=accountCharacter and accountCharacter:FindFirstChild("HumanoidRootPart")::BasePart?
	if accountCharacter and accountRoot then accountCharacter:PivotTo(pitchCFrame*CFrame.new(0,-30,0));accountRoot.Anchored=true;accountCharacter:SetAttribute("VTRParked",true)end
	return teams,activeFormation
end
return Service
