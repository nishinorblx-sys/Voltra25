--!strict
local function vtrLoadWorldCampaignWinProgress()
	VTRWorldCampaignWinProgress.TryRegisterFromArgs(nil)
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("WorldCampaignWinProgressService") then
			VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)
			return require(services:WaitForChild("WorldCampaignWinProgressService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("WorldCampaignWinProgressService") then
				VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)
				return require(sibling:WaitForChild("WorldCampaignWinProgressService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("WorldCampaignWinProgressService"))
end

local VTRWorldCampaignWinProgress = vtrLoadWorldCampaignWinProgress()
local function vtrLoadPackInventoryConsume()
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("PackInventoryConsumeService") then
			return require(services:WaitForChild("PackInventoryConsumeService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("PackInventoryConsumeService") then
				return require(sibling:WaitForChild("PackInventoryConsumeService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("PackInventoryConsumeService"))
end

local VTRPackInventoryConsume = vtrLoadPackInventoryConsume()
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local ClubIdentityConfig=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local Schema=require(ReplicatedStorage.VTR.Shared.UIStateSchema)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local RunService=game:GetService("RunService")
local EconomyConfig=require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local DeveloperConfig=require(ReplicatedStorage.VTR.Shared.DeveloperConfig)
local DeveloperAccessService=require(script.Parent.DeveloperAccessService)
local ProClubsConfig=require(ReplicatedStorage.VTR.Shared.ProClubsConfig)
local VTRLiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local ClubNameFilterService=require(script.Parent.ClubNameFilterService)
local LaunchService={};LaunchService.__index=LaunchService
local function find(list:any,id:string):any? for _,item in list do if item.Id==id then return item end end;return nil end
	VTRWorldCampaignWinProgress.TryRegisterFromArgs(nil)
local function has(list:any,value:string):boolean return table.find(list,value)~=nil end
local function recordItem(profile:any,id:string,kind:string,quantity:number) profile.Inventory=profile.Inventory or {Items={}};for _,item in profile.Inventory.Items do if item.Id==id and item.Kind==kind then item.Quantity+=quantity;return end end;table.insert(profile.Inventory.Items,{Id=id,Kind=kind,Quantity=quantity,AcquiredAt=os.time()}) end
local function setObjectiveProgress(profile:any,id:string,value:number)
	for _,objective in profile.Objectives do if objective.objectiveId==id and objective.status~="claimed" then objective.progress=math.min(objective.target,value);if objective.status=="active" and objective.progress>=objective.target then objective.status="claimable" end;return end end
end
local function cleanClubName(player:Player,value:any):(boolean,string) return ClubNameFilterService.Validate(player,value,20) end
local function cleanClubTag(player:Player,value:any):(boolean,string) return ClubNameFilterService.ValidateTag(player,value) end
local function identityDesign(payload:any):(boolean,any)
	local primary=ClubIdentityConfig.ColorId(payload.PrimaryColor);local secondary=ClubIdentityConfig.ColorId(payload.SecondaryColor);local accent=ClubIdentityConfig.ColorId(payload.AccentColor)
	if not primary or not secondary or not accent or primary==secondary or primary==accent or secondary==accent then return false,"Choose three different approved club colors."end
	local style=ClubIdentityConfig.ResolveStyle(payload.KitStyle)
	if not ClubIdentityConfig.IsChoice(ClubIdentityConfig.KitStyles,style)then return false,"Invalid kit style."end
	if not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgePresets,payload.BadgePreset)or not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgeShapes,payload.BadgeShape)or not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgeSymbols,payload.BadgeSymbol)or not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgeColorBehaviors,payload.BadgeColorBehavior)then return false,"Invalid badge design."end
	return true,{PrimaryColor=primary,SecondaryColor=secondary,AccentColor=accent,KitStyle=style,BadgePreset=payload.BadgePreset,BadgeShape=payload.BadgeShape,BadgeSymbol=payload.BadgeSymbol,BadgeColorBehavior=payload.BadgeColorBehavior}
end
local function applyIdentity(target:any,design:any)for key,value in design do target[key]=value end end
local function autoFill(profile:any)
	local slots={{"GK","GK"},{"LB","LB"},{"CB1","CB"},{"CB2","CB"},{"RB","RB"},{"CDM","CM"},{"CM1","CM"},{"CM2","CM"},{"LW","LW"},{"ST","ST"},{"RW","RW"}};local used={}
	for _,slot in slots do local best=nil;for _,card in profile.PlayerCardInventory do if not used[card.Id] and card.Position==slot[2] and (not best or card.Rating>best.Rating) then best=card end end;if not best then for _,card in profile.PlayerCardInventory do if not used[card.Id] and (not best or card.Rating>best.Rating) then best=card end end end;if best then used[best.Id]=true;profile.UIState.SelectedSquad[slot[1]]=best.Name;profile.Squad[slot[1]]=best.Name end end
	profile.Bench={};profile.Reserves={};local remaining={};for _,card in profile.PlayerCardInventory do if not used[card.Id] then table.insert(remaining,card) end end;table.sort(remaining,function(a,b) return a.Rating>b.Rating end);for index,card in remaining do if index<=7 then profile.Bench[index]=card.Id else table.insert(profile.Reserves,card.Id) end end
end
local function sanitizeTactics(payload:any):any
	local identity=type(payload.Identity)=="string"and payload.Identity or"Balanced"
	if not VTRLiteConfig.TacticPresets[identity]then identity="Balanced"end
	local sliders={}
	local source=type(payload.Sliders)=="table"and payload.Sliders or{}
	local preset=VTRLiteConfig.TacticPresets[identity]or VTRLiteConfig.TacticPresets.Balanced
	for index,name in VTRLiteConfig.TacticSliderNames do
		local value=tonumber(source[name])or preset[index]or 50
		sliders[name]=math.clamp(math.floor(value+.5),0,100)
	end
	return{Identity=identity,Sliders=sliders}
end

function LaunchService.new(profiles:any,progression:any,publish:(Player,string,any)->(),inventory:any,packs:any) return setmetatable({Profiles=profiles,Progression=progression,Publish=publish,Inventory=inventory,Packs=packs,RankedProfiles=nil},LaunchService) end
function LaunchService:SetRankedProfiles(rankedProfiles:any) self.RankedProfiles=rankedProfiles end
function LaunchService:_push(player:Player,p:any) if self.Profiles.Save then self.Profiles:Save(player) end;self.Publish(player,"Progression",self.Progression:GetClientData(player));self.Publish(player,"UIState",p.UIState);self.Publish(player,"Currency",{Coins=p.Currency.Coins,Bolts=p.Currency.Bolts,VoltraPoints=p.Currency.VoltraPoints or 0});self.Publish(player,"PlayerProfile",self.Profiles:GetClientData(player)) end
function LaunchService:Handle(player:Player,action:string,payload:any):(boolean,string,any?)
	if action=="DeveloperResetProfile"then if not RunService:IsStudio()then return false,"Developer reset is only available in Studio.",nil end;local reset=self.Profiles:ResetProfile(player);if not reset then return false,"Profile reset failed.",nil end;self:_push(player,reset);return true,"Profile reset to fresh launch state. Restart Play to run onboarding.",{Reset=true}
	elseif action=="DeveloperGrantCoins"then if not DeveloperAccessService.IsAuthorized(player)then return false,"Developer authorization required.",nil end;local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;profile.Currency.Coins=math.min(EconomyConfig.MaximumCoins,profile.Currency.Coins+DeveloperConfig.CoinGrantAmount);self:_push(player,profile);return true,"Developer vault added 10,000,000 coins.",{Coins=profile.Currency.Coins}end
	local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",nil end;payload=type(payload)=="table" and payload or {};local o=p.Onboarding;local responseData:any=nil;local responseMessage="Profile updated."
	if action=="SaveTeamTactics"then p.TeamTactics=sanitizeTactics(payload);responseMessage="AI tactics saved.";responseData={TeamTactics=p.TeamTactics}
	elseif action=="SetClubName" then if o.Complete or o.StarterPackClaimed then return false,"Club identity is locked.",nil end;local valid,result=cleanClubName(player,payload.Name);if not valid then return false,result,nil end;o.ClubName=result;p.Profile.SelectedClub=result;p.ClubMembership.Name=result;o.Step=math.max(o.Step,2);responseData={Name=result}
	elseif action=="SetAbbreviation" then local tagOk,tag=cleanClubTag(player,payload.Value);if o.ClubName=="" or o.StarterPackClaimed or not tagOk then return false,tag,nil end;o.Abbreviation=tag;p.ClubMembership.Abbreviation=tag;o.Step=math.max(o.Step,3);responseData={Tag=tag}
	elseif action=="SetIdentityDesign"then if o.Abbreviation==""or o.StarterPackClaimed then return false,"Club design cannot be changed during this step.",nil end;local valid,design=identityDesign(payload);if not valid then return false,design,nil end;applyIdentity(o,design);applyIdentity(p.ClubMembership,design);o.IdentityConfigured=true;o.Step=math.max(o.Step,5)
	elseif action=="SaveClubIdentity"then local nameOk,name=cleanClubName(player,payload.Name);local tagOk,abbreviation=cleanClubTag(player,payload.Abbreviation);if not nameOk then return false,name,nil end;if not tagOk then return false,abbreviation,nil end;local designOk,design=identityDesign(payload);if not designOk then return false,design,nil end;p.ClubMembership.ClubId=p.ClubMembership.ClubId~=""and p.ClubMembership.ClubId or("identity_"..player.UserId);p.ClubMembership.Name=name;p.ClubMembership.Abbreviation=abbreviation;p.ClubMembership.Role=p.ClubMembership.Role=="FREE AGENT"and"FOUNDER"or p.ClubMembership.Role;p.ClubMembership.Members=math.max(1,p.ClubMembership.Members or 0);p.ClubMembership.Reputation=p.ClubMembership.Reputation=="UNRANKED"and"ROOKIE"or p.ClubMembership.Reputation;applyIdentity(p.ClubMembership,design);p.Profile.SelectedClub=name;responseMessage="Club identity saved."
	elseif action=="SetColors" then local primary=find(Catalog.ColorPresets,payload.Primary);local secondary=find(Catalog.ColorPresets,payload.Secondary);if not primary or not secondary or primary.Id==secondary.Id or o.Abbreviation=="" or o.StarterPackClaimed then return false,"Choose two different preset colors.",nil end;o.PrimaryColor=primary.Id;o.SecondaryColor=secondary.Id;p.ClubMembership.PrimaryColor=primary.Id;p.ClubMembership.SecondaryColor=secondary.Id;o.Step=math.max(o.Step,4)
	elseif action=="SetKitStyle" then local style=find(Catalog.StarterKitStyles,payload.Id);if not style or o.PrimaryColor=="" or o.StarterPackClaimed then return false,"Invalid starter kit style.",nil end;o.KitStyle=style.Id;p.ClubMembership.KitStyle=style.Id;o.Step=math.max(o.Step,5)
	elseif action=="ClaimStarterPack" then if o.ClubName=="" or o.Abbreviation==""or not o.IdentityConfigured or o.PrimaryColor=="" or o.SecondaryColor==""or o.AccentColor==""or o.BadgeShape==""or o.BadgeSymbol==""or o.KitStyle=="" or o.StarterPackClaimed then return false,"Starter pack unavailable.",nil end;if not self.Inventory:AddPack(player,"starter_launch",Catalog.Packs.starter_launch.Name,"Onboarding",1) then return false,"Starter pack grant failed.",nil end;o.StarterPackClaimed=true;o.Step=6
	elseif action=="OpenStarterPack" then
		if not o.StarterPackClaimed or o.StarterPackOpened then return false,"Starter pack cannot be opened.",nil end;if not self.Inventory:ConsumePack(player,"starter_launch") then return false,"Starter pack missing.",nil end
			VTRPackInventoryConsume.ConsumeOpen(self, player, payload, data, request, pack, packId, packInstanceId)
		local reveals={};local required={"GK","LB","CB","CB","RB","CM","CM","CM","LW","ST","RW"};local usedPlayers={}
		for _,position in required do local candidates={};for _,definition in PlayerDatabase.Pools.Starter do if definition.bestPosition==position and not usedPlayers[definition.playerId] then table.insert(candidates,definition) end end;local definition=candidates[math.random(1,#candidates)];usedPlayers[definition.playerId]=true;local added,instance=self.Inventory:AddCard(player,definition);if added and instance then table.insert(reveals,instance);recordItem(p,instance.cardInstanceId,"PlayerCard",1) end end
		while #reveals<18 do local pool=math.random(1,100)<=94 and PlayerDatabase.Pools.Starter or PlayerDatabase.Pools.Rare;local definition=pool[math.random(1,#pool)];if not usedPlayers[definition.playerId] then usedPlayers[definition.playerId]=true;local added,instance=self.Inventory:AddCard(player,definition);if added and instance then table.insert(reveals,instance);recordItem(p,instance.cardInstanceId,"PlayerCard",1) end end end
		local bestRating=0;for _,card in reveals do bestRating=math.max(bestRating,math.floor(tonumber(card.Rating or card.overall)or 0))end;if self.RankedProfiles and self.RankedProfiles.RecordPackRating then self.RankedProfiles:RecordPackRating(player,bestRating)end;autoFill(p);o.StarterPackOpened=true;o.SquadFilled=true;o.ObjectivesActivated=true;o.Step=8;for _,objective in p.Objectives do if objective.groupId=="starter_journey" then if objective.objectiveId=="build_first_xi" then objective.progress=11;objective.status="claimable" elseif objective.objectiveId=="open_first_pack" then objective.progress=1 end elseif objective.status=="locked" then objective.status=objective.progress>=objective.target and "claimable" or "active" end end;self:_push(player,p);return true,"Starter pack opened and best XI selected.",reveals
			VTRPackInventoryConsume.ConsumeOpen(self, player, payload, data, request, pack, packId, packInstanceId)
	elseif action=="AutoFillSquad" then if not o.StarterPackOpened then return false,"Open the starter pack first.",nil end;autoFill(p);o.SquadFilled=true
		VTRPackInventoryConsume.ConsumeOpen(self, player, payload, data, request, pack, packId, packInstanceId)
	elseif action=="CompleteOnboarding" then if not o.SquadFilled or not o.ObjectivesActivated or o.ClubName=="" or o.Abbreviation=="" or o.PrimaryColor=="" or o.SecondaryColor==""or o.AccentColor==""or o.KitStyle=="" then return false,"Onboarding requirements are incomplete.",nil end;o.Complete=true;o.Step=10;p.OnboardingCompleted=true;p.ClubMembership.ClubId=p.ClubMembership.ClubId~=""and p.ClubMembership.ClubId or("identity_"..player.UserId);p.ClubMembership.Role="FOUNDER";p.ClubMembership.Members=math.max(1,p.ClubMembership.Members or 0);p.ClubMembership.Reputation="ROOKIE"
		VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)
	elseif action=="ClaimInbox" then local reward=find(p.RewardsInbox,payload.Id);if not reward or reward.Claimed then return false,"Reward unavailable.",nil end;reward.Claimed=true;if reward.Id=="launch_welcome" then p.Currency.Coins+=500;p.Currency.Bolts+=50 end;setObjectiveProgress(p,"claim_daily_reward",1)
	elseif action=="OpenPack" then local opened,result=self.Packs:Open(player,payload.PackInstanceId or payload.Id);if not opened then return false,result,nil end;local reveals=result::any;for _,instance in reveals do recordItem(p,instance.cardInstanceId,"PlayerCard",1) end;setObjectiveProgress(p,"open_first_pack",1);self:_push(player,p);return true,"Pack opened on server.",reveals
		VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)
		VTRPackInventoryConsume.ConsumeOpen(self, player, payload, data, request, pack, packId, packInstanceId)
	elseif action=="BuyCoins" then local bundle=Catalog.CoinBundles[payload.Id or payload.BundleId];if not bundle then return false,"Unknown coin bundle.",nil end;p.Currency.Coins=math.min(EconomyConfig.MaximumCoins,p.Currency.Coins+(bundle.Coins or 0));recordItem(p,bundle.Id,"Currency",bundle.Coins or 0);self:_push(player,p);return true,(bundle.Coins or 0).." coins added.",{Coins=p.Currency.Coins,Bundle=bundle.Id,Robux=bundle.Robux,ProductId=bundle.ProductId}
	elseif action=="Purchase" then local itemType=payload.ItemType;local itemId=payload.Id;local item;if itemType=="Pack" then item=Catalog.Packs[itemId] elseif itemType=="Kit" then item=find(Catalog.Kits,itemId) elseif itemType=="Stadium" then item=find(Catalog.Stadiums,itemId) elseif itemType=="Cosmetic" then item=find(Catalog.Cosmetics,itemId) end;if not item then return false,"Unknown store item.",nil end;local quantity=itemType=="Pack" and math.clamp(math.floor(tonumber(payload.Quantity)or 1),1,25) or 1;local bucket=nil;if itemType~="Pack" then bucket=itemType=="Kit" and p.StoreOwnership.Kits or itemType=="Stadium" and p.StoreOwnership.Stadiums or p.StoreOwnership.Cosmetics;if has(bucket,itemId) then return false,"Item already owned.",nil end end;local coins=(item.PriceCoins or 0)*quantity;local bolts=(item.PriceBolts or 0)*quantity;local voltraPoints=(item.PriceVoltraPoints or 0)*quantity;p.Currency.VoltraPoints=tonumber(p.Currency.VoltraPoints)or 0;local infiniteCoins=DeveloperConfig.InfiniteCoinsEveryone==true;if (not infiniteCoins and p.Currency.Coins<coins) or p.Currency.Bolts<bolts or p.Currency.VoltraPoints<voltraPoints then return false,"Insufficient currency.",nil end;if infiniteCoins then p.Currency.Coins=EconomyConfig.MaximumCoins else p.Currency.Coins-=coins end;p.Currency.Bolts-=bolts;p.Currency.VoltraPoints-=voltraPoints;if itemType=="Pack" then local delivered,instances=self.Inventory:AddPack(player,itemId,item.Name,"Store",quantity);if not delivered or not instances or not instances[1] then if not infiniteCoins then p.Currency.Coins+=coins end;p.Currency.Bolts+=bolts;p.Currency.VoltraPoints+=voltraPoints;return false,"Pack delivery failed; currency was restored.",nil end;local pack=instances[1];responseData={Pack={packInstanceId=pack.packInstanceId,packId=pack.packId,name=pack.name,description=pack.description,quantity=quantity,status=pack.status,purchasedAt=pack.purchasedAt,openedAt=pack.openedAt},Packs=instances,Quantity=quantity};responseMessage=quantity>1 and(quantity.." packs added to inventory.")or"Pack added to inventory.";recordItem(p,itemId,"Pack",quantity) else table.insert(bucket,itemId);recordItem(p,itemId,itemType=="Stadium" and "StadiumTheme" or itemType,1) end
	if player and typeof(player) == "Instance" and player:IsA("Player") then
		VTRPendingPackAnimation.Queue(player, itemId)
	end
	elseif action=="EquipCard" then return false,"Use the authoritative Squad Builder to change the starting XI.",nil
	elseif action=="EquipCosmetic" then local owned=has(p.StoreOwnership.Kits,payload.Id) or has(p.StoreOwnership.Stadiums,payload.Id) or has(p.StoreOwnership.Cosmetics,payload.Id);if not owned or not Schema.CosmeticSlots[payload.Slot] then return false,"Cosmetic ownership validation failed.",nil end;p.UIState.EquippedCosmetics[payload.Slot]=payload.Id
	elseif action=="CreateCareer" then if payload.Type~="Player" and payload.Type~="Manager" then return false,"Invalid career type.",nil end;local slot=nil;for _,save in p.CareerSaveSlots do if save.Type=="Empty" then slot=save;break end end;if not slot then return false,"No empty career slots.",nil end;slot.Type=payload.Type;slot.Name=payload.Type=="Player" and "ALEX VOLT" or "MORGAN VALE";slot.Season="2026/27";slot.Overall=payload.Type=="Player" and 62 or nil;p.UIState.CareerSaveSelection=slot.Slot
	elseif action=="CreateClub" then if p.ProClubMembership.ClubId~="" then return false,"You already belong to a Pro Club.",nil end;local valid,name=cleanClubName(player,payload.Name);local tagOk,abbreviation=cleanClubTag(player,payload.Tag);if not valid then return false,name,nil end;if not tagOk then return false,abbreviation,nil end;p.ProClubMembership={ClubId="proclub_"..player.UserId,Name=name,Tag=abbreviation,Role="OWNER",Members=1,Capacity=24,Reputation="ROOKIE",LeagueId="",JoinPolicy="InviteOnly",MatchHistory={}}
	elseif action=="CreateProPlayer"then local pro=p.ProClubsPlayer;if pro.Created then return false,"Your Pro already exists.",nil end;local first=type(payload.FirstName)=="string"and string.match(payload.FirstName,"^%s*([%a][%a '%-]+)%s*$")or nil;local last=type(payload.LastName)=="string"and string.match(payload.LastName,"^%s*([%a][%a '%-]+)%s*$")or nil;if not first or#first>18 or not last or#last>18 then return false,"Use valid first and last names (18 characters maximum).",nil end;pro.Created=true;pro.FirstName=first;pro.LastName=last;pro.JerseyName=string.upper(last);pro.Position=type(payload.Position)=="string"and payload.Position or"ST";pro.PreferredFoot=payload.PreferredFoot=="Left"and"Left"or"Right";pro.Attributes={};for _,attributes in ProClubsConfig.Categories do for _,attribute in attributes do pro.Attributes[attribute]=55 end end;responseMessage="Pro created with 20 attribute points.";responseData={Pro=pro}
	elseif action=="SpendProAttribute"then local pro=p.ProClubsPlayer;local attribute=payload.Attribute;local amount=math.floor(tonumber(payload.Amount)or 0);if not pro.Created or type(attribute)~="string"or amount<1 or amount>10 then return false,"Invalid attribute request.",nil end;local valid=false;for _,attributes in ProClubsConfig.Categories do if table.find(attributes,attribute)then valid=true;break end end;if not valid or pro.AttributePointsAvailable<amount then return false,"Not enough attribute points.",nil end;pro.Attributes=pro.Attributes or{};local current=tonumber(pro.Attributes[attribute])or 55;if current+amount>99 then return false,"Attribute cap reached.",nil end;pro.Attributes[attribute]=current+amount;pro.SpentAttributePoints[attribute]=(pro.SpentAttributePoints[attribute]or 0)+amount;pro.AttributePointsAvailable-=amount;local total=0;for _,spent in pro.SpentAttributePoints do total+=spent end;pro.Overall=math.min(99,60+math.floor(total/6));responseMessage=attribute.." upgraded to "..pro.Attributes[attribute]..".";responseData={Pro=pro}
	elseif action=="SelectProBuild"then local pro=p.ProClubsPlayer;local build=payload.Build;if not pro.Created or pro.Level<20 or type(build)~="string"or not table.find(ProClubsConfig.BuildPaths,build)then return false,"Build paths unlock at Level 20.",nil end;pro.BuildPath=build;responseMessage=build.." selected.";responseData={Pro=pro}
	else return false,"Unsupported launch action.",nil end
	self:_push(player,p);return true,responseMessage,responseData
end
return LaunchService
