local MATCHUP_PANEL_DELAY = 0.85
--!strict

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local SquadSlots=require(ReplicatedStorage.VTR.Shared.UIStateSchema).SquadSlots
local FormationConfig=require(ReplicatedStorage.VTR.Shared.FormationConfig)
local ObjectiveService=require(script.Parent.ObjectiveService)
local EconomyConfig=require(ReplicatedStorage.VTR.Shared.EconomyConfig)

local SquadService={};SquadService.__index=SquadService
local ORDER=FormationConfig.Order
local LINKS={{"GK","CB1"},{"GK","CB2"},{"LB","CB1"},{"RB","CB2"},{"CB1","CDM"},{"CB2","CDM"},{"CDM","CM1"},{"CDM","CM2"},{"CM1","LW"},{"CM2","RW"},{"CM1","ST"},{"CM2","ST"}}
local POSITION_POINTS={
	GK={0,0},CB={0,1},LB={-1,1},RB={1,1},LWB={-1,1.4},RWB={1,1.4},
	CDM={0,2},CM={0,3},CAM={0,4},LM={-1,3.5},RM={1,3.5},LW={-1,5},RW={1,5},CF={0,5},ST={0,6},
}

function SquadService.new(profiles:any,publish:(Player,string,any)->(),progression:any) return setmetatable({Profiles=profiles,Publish=publish,Progression=progression},SquadService) end
function SquadService:_card(profile:any,reference:any):any? if type(reference)~="string" then return nil end;for _,card in profile.PlayerCardInventory do if card.Id==reference or card.cardInstanceId==reference or card.Name==reference then return card end end;return nil end
function SquadService:_formation(profile:any):any return FormationConfig.Formations[profile.Formation] or FormationConfig.Formations[FormationConfig.Default] end
function SquadService:_expected(profile:any,slot:string):string return self:_formation(profile)[slot].Expected end
local function normalizedPosition(value:any):string
	local text=string.upper(tostring(value or "")):gsub("%d","")
	if text=="LCB"or text=="RCB"then return"CB"end
	if text=="LCM"or text=="RCM"then return"CM"end
	if text=="LAM"or text=="RAM"then return"CAM"end
	return text
end
local function matchdayIdentity(card:any):string
	if not card then return "" end
	local name=string.lower(tostring(card.displayName or card.Name or card.shortName or card.ShortName or "")):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
	if name~=""then return "name:"..name end
	local playerId=tostring(card.BasePlayerId or card.basePlayerId or card.playerId or card.PlayerId or "")
	if playerId~=""then
		for _,suffix in{"_team_of_the_week","_rising_star","_voltra_hero","_champion","_event","_limited","_spark","_electrum","_hero","_storm","_mythic"}do
			if string.sub(playerId,-#suffix)==suffix then
				return string.sub(playerId,1,#playerId-#suffix)
			end
		end
		return playerId
	end
	return tostring(card.Id or card.cardInstanceId or "")
end
local function positionPenalty(card:any,expected:any):number
	local target=normalizedPosition(expected)
	local targetPoint=POSITION_POINTS[target]
	if not targetPoint then return 0 end
	local candidates={}
	local primary=normalizedPosition(card and (card.Position or card.bestPosition))
	if primary~=""then table.insert(candidates,primary)end
	local alternatePositions=card and (card.positions or card.Positions) or {}
	for _,position in alternatePositions do
		local normalized=normalizedPosition(position)
		if normalized~=""then table.insert(candidates,normalized)end
	end
	local bestPenalty=30
	for _,position in candidates do
		if position==target then return 0 end
		local point=POSITION_POINTS[position]
		if point then
			local keeperMismatch=(position=="GK")~=(target=="GK")
			local dx=point[1]-targetPoint[1]
			local dy=point[2]-targetPoint[2]
			local distance=math.sqrt(dx*dx+dy*dy)
			local penalty=keeperMismatch and 38 or math.floor(distance*5.4+.5)
			if position=="ST"and(target=="CB"or target=="LB"or target=="RB")then penalty+=9 end
			if (position=="CB"or position=="LB"or position=="RB")and(target=="ST"or target=="LW"or target=="RW")then penalty+=9 end
			bestPenalty=math.min(bestPenalty,penalty)
		end
	end
	return math.clamp(bestPenalty,0,36)
end
local function ratingForSlot(card:any,expected:any):number
	return math.max(1,math.floor((tonumber(card and card.BaseRating)or tonumber(card and card.overall)or tonumber(card and card.Rating)or 0)-positionPenalty(card,expected)+.5))
end
local function copyForSlot(card:any,expected:any,meta:any?):any?
	if not card then return nil end
	local copy=table.clone(card)
	local base=tonumber(copy.Rating)or tonumber(copy.overall)or 0
	local penalty=positionPenalty(copy,expected)
	copy.BaseRating=base
	copy.PositionPenalty=penalty
	copy.EffectiveRating=math.max(1,math.floor(base-penalty+.5))
	copy.Rating=copy.EffectiveRating
	copy.Meta=meta and table.clone(meta)or copy.Meta
	return copy
end

function SquadService:_writeState(profile:any)
	local state=profile.SquadState or {};state.startingXI=table.clone(profile.Squad or {});state.bench={};for index=1,7 do state.bench["slot"..index]=profile.Bench and profile.Bench[index] or nil end;state.reserves=table.clone(profile.Reserves or {});state.transferList=table.clone(profile.TransferList or state.transferList or {});profile.SquadState=state
	for _,card in profile.PlayerCardInventory do card.location="club";card.Location="club" end
	for _,id in state.startingXI do local card=self:_card(profile,id);if card then card.location="starting";card.Location="starting" end end
	for _,id in state.bench do local card=self:_card(profile,id);if card then card.location="bench";card.Location="bench" end end
	for _,id in state.reserves do local card=self:_card(profile,id);if card then card.location="reserves";card.Location="reserves" end end
	for _,id in state.transferList do local card=self:_card(profile,id);if card then card.location="transfer_list";card.Location="transfer_list" end end
end

function SquadService:_normalize(profile:any)
	profile.Squad=profile.Squad or {};profile.Bench=profile.Bench or {};profile.Reserves=profile.Reserves or {};profile.TransferList=profile.TransferList or {};profile.PlayerCardMeta=profile.PlayerCardMeta or {};profile.Formation=FormationConfig.Formations[profile.Formation] and profile.Formation or FormationConfig.Default;profile.UIState.SelectedSquad=profile.UIState.SelectedSquad or {}
	local state=profile.SquadState or {startingXI={},bench={},reserves={},transferList={}};state.startingXI=state.startingXI or {};state.bench=state.bench or {};state.reserves=state.reserves or {};state.transferList=state.transferList or {}
	local stateHasPlayers=next(state.startingXI)~=nil or next(state.bench)~=nil or next(state.reserves)~=nil or next(state.transferList)~=nil
	if stateHasPlayers then profile.Squad=table.clone(state.startingXI);profile.Bench={};for index=1,7 do profile.Bench[index]=state.bench["slot"..index] end;profile.Reserves=table.clone(state.reserves);profile.TransferList=table.clone(state.transferList) end
	local used={};local usedPlayers={};local squad={};local names={}
	for _,slot in ORDER do local card=self:_card(profile,profile.Squad[slot] or profile.UIState.SelectedSquad[slot]);local playerId=matchdayIdentity(card);if card and not used[card.Id] and not usedPlayers[playerId] then squad[slot]=card.Id;names[slot]=card.Name;used[card.Id]=true;usedPlayers[playerId]=true end end
	local bench={};for index=1,7 do local card=self:_card(profile,profile.Bench[index]);local playerId=matchdayIdentity(card);if card and not used[card.Id] and not usedPlayers[playerId] then bench[index]=card.Id;used[card.Id]=true;usedPlayers[playerId]=true end end
	local reserves={};for _,reference in profile.Reserves do local card=self:_card(profile,reference);if card and not used[card.Id] then table.insert(reserves,card.Id);used[card.Id]=true end end
	local transferList={};for _,reference in profile.TransferList do local card=self:_card(profile,reference);if card and not used[card.Id] then table.insert(transferList,card.Id);used[card.Id]=true end end
	profile.Squad=squad;profile.Bench=bench;profile.Reserves=reserves;profile.TransferList=transferList;profile.UIState.SelectedSquad=names;self:_writeState(profile)
end

function SquadService:_calculate(profile:any):(number,number,number)
	local filled,total,cards=0,0,{};for _,slot in ORDER do local card=self:_card(profile,profile.Squad[slot]);if card then filled+=1;total+=ratingForSlot(card,self:_expected(profile,slot));cards[slot]=card end end
	local chemistry=0;for slot,card in cards do if table.find(card.positions or {},self:_expected(profile,slot)) or card.Position==self:_expected(profile,slot) then chemistry+=2 end end
	for _,pair in LINKS do local a,b=cards[pair[1]],cards[pair[2]];if a and b then if a.Club==b.Club then chemistry+=1 end;if a.Nation==b.Nation then chemistry+=1 end;if a.RoleTag==b.RoleTag then chemistry+=1 end end end
	return filled,filled>0 and math.floor(total/filled+.5) or 0,math.min(33,chemistry)
end
function SquadService:_objective(profile:any,id:string):any? for _,objective in profile.Objectives do if objective.objectiveId==id then return objective end end;return nil end
function SquadService:_visibleObjective(profile:any):(any?,boolean) local all=true;for _,o in profile.Objectives do if o.groupId=="starter_journey" then if o.status~="claimed" then all=false end;if o.status=="active" or o.status=="completed" or o.status=="claimable" then return o,false end end end;return nil,all end
function SquadService:_update(player:Player,profile:any):(boolean)
	self:_writeState(profile);local filled,rating=self:_calculate(profile);local first=self:_objective(profile,"build_first_xi");local completed=false
	if first and first.status~="claimed" then local old=first.status;first.progress=filled;if first.status~="locked" then first.status=filled>=first.target and "claimable" or "active" end;completed=old~="claimable" and first.status=="claimable" end
	local upgrade=self:_objective(profile,"upgrade_squad_rating");if upgrade and upgrade.status~="claimed" then upgrade.progress=math.min(upgrade.target,rating);if upgrade.status~="locked" then upgrade.status=upgrade.progress>=upgrade.target and "claimable" or "active" end end
	if self.Profiles.Save then self.Profiles:Save(player) end
	self.Publish(player,"Objective",ObjectiveService.Serialize(profile.Objectives));self.Publish(player,"Progression",self.Progression:GetClientData(player));self.Publish(player,"UIState",profile.UIState);return completed
end

function SquadService:_locate(profile:any,cardId:string):(string,any?)
	for slot,id in profile.Squad do if id==cardId then return "StartingXI",slot end end
	for index=1,7 do if profile.Bench[index]==cardId then return "Bench",index end end
	for index,id in profile.Reserves do if id==cardId then return "Reserves",index end end
	for index,id in profile.TransferList do if id==cardId then return "TransferList",index end end
	return "Club",nil
end
function SquadService:_at(profile:any,kind:string,slot:any):string?
	if kind=="StartingXI" then return profile.Squad[slot] elseif kind=="Bench" then return profile.Bench[slot] elseif kind=="Reserves" and slot then return profile.Reserves[slot] elseif kind=="TransferList" and slot then return profile.TransferList[slot] end;return nil
end
function SquadService:_duplicateMatchdayPlayer(profile:any,card:any,destinationType:string,destinationSlot:any):boolean
	if destinationType~="StartingXI" and destinationType~="Bench" then return false end
	local playerId=matchdayIdentity(card)
	if playerId=="" then return false end
	local cardId=card.Id
	for slot,reference in profile.Squad do
		if not (destinationType=="StartingXI" and slot==destinationSlot) then
			local existing=self:_card(profile,reference)
			if existing and existing.Id~=cardId and matchdayIdentity(existing)==playerId then return true end
		end
	end
	for index,reference in profile.Bench do
		if not (destinationType=="Bench" and index==destinationSlot) then
			local existing=self:_card(profile,reference)
			if existing and existing.Id~=cardId and matchdayIdentity(existing)==playerId then return true end
		end
	end
	return false
end
function SquadService:_remove(profile:any,kind:string,slot:any)
	if kind=="StartingXI" then profile.Squad[slot]=nil;profile.UIState.SelectedSquad[slot]=nil elseif kind=="Bench" then profile.Bench[slot]=nil elseif kind=="Reserves" and slot then table.remove(profile.Reserves,slot) elseif kind=="TransferList" and slot then table.remove(profile.TransferList,slot) end
end
function SquadService:_place(profile:any,kind:string,slot:any,cardId:string)
	if kind=="StartingXI" then profile.Squad[slot]=cardId;local card=self:_card(profile,cardId);profile.UIState.SelectedSquad[slot]=card and card.Name or nil
	elseif kind=="Bench" then profile.Bench[slot]=cardId
	elseif kind=="Reserves" then if slot and slot>=1 and slot<=#profile.Reserves+1 then table.insert(profile.Reserves,slot,cardId) else table.insert(profile.Reserves,cardId) end
	elseif kind=="TransferList" then if slot and slot>=1 and slot<=#profile.TransferList+1 then table.insert(profile.TransferList,slot,cardId) else table.insert(profile.TransferList,cardId) end end
end
function SquadService:_validDestination(kind:string,slot:any):boolean
	if kind=="Club" or (kind=="Reserves" or kind=="TransferList") and slot==nil then return true end
	if kind=="StartingXI" then return type(slot)=="string" and SquadSlots[slot]==true end
	if kind=="Bench" then return type(slot)=="number" and slot%1==0 and slot>=1 and slot<=7 end
	if kind=="Reserves" then return type(slot)=="number" and slot%1==0 and slot>=1 end
	if kind=="TransferList" then return type(slot)=="number" and slot%1==0 and slot>=1 end
	return false
end

function SquadService:MovePlayer(player:Player,cardId:string,destinationType:string,destinationSlot:any):(boolean,string,boolean)
	local p=self.Profiles:GetProfile(player);if not p or type(cardId)~="string" or not self:_validDestination(destinationType,destinationSlot) then return false,"Invalid roster move.",false end;self:_normalize(p);local card=self:_card(p,cardId);if not card or (card.Id~=cardId and card.cardInstanceId~=cardId) then return false,"Player card instance is not owned.",false end
	if self:_duplicateMatchdayPlayer(p,card,destinationType,destinationSlot) then return false,"You cannot use repeat players in the Starting XI or bench.",false end
	local originType,originSlot=self:_locate(p,card.Id);if originType==destinationType and originSlot==destinationSlot then return true,"Player is already there.",false end
	if originType==destinationType then
		if originType=="StartingXI" or originType=="Bench" then local occupied=self:_at(p,destinationType,destinationSlot);self:_place(p,destinationType,destinationSlot,card.Id);if occupied then self:_place(p,originType,originSlot,occupied) else self:_remove(p,originType,originSlot) end
		elseif originType=="Reserves" or originType=="TransferList" then local list=originType=="Reserves" and p.Reserves or p.TransferList;local occupied=self:_at(p,originType,destinationSlot);if occupied then list[originSlot],list[destinationSlot]=occupied,card.Id else table.remove(list,originSlot);table.insert(list,card.Id) end end
	else
		local occupied=self:_at(p,destinationType,destinationSlot);self:_remove(p,originType,originSlot)
		if destinationType~="Club" then if destinationType=="Reserves" and destinationSlot and occupied then p.Reserves[destinationSlot]=card.Id elseif destinationType=="TransferList" and destinationSlot and occupied then p.TransferList[destinationSlot]=card.Id else self:_place(p,destinationType,destinationSlot,card.Id) end end
		if occupied and originType~="Club" then self:_place(p,originType,originSlot,occupied) end
	end
	local completed=self:_update(player,p);return true,"Squad saved.",completed
end

function SquadService:SetFormation(player:Player,formation:string):(boolean,string,boolean) local p=self.Profiles:GetProfile(player);if not p or type(formation)~="string" or not FormationConfig.Formations[formation] then return false,"Unknown formation.",false end;p.Formation=formation;self:_update(player,p);return true,"Formation saved.",false end
function SquadService:SetCardFlag(player:Player,cardId:string,flag:string,value:boolean):(boolean,string,boolean) local p=self.Profiles:GetProfile(player);local card=p and self:_card(p,cardId);if not p or not card or (card.Id~=cardId and card.cardInstanceId~=cardId) or (flag~="Locked" and flag~="Favorite") or type(value)~="boolean" then return false,"Invalid player flag.",false end;p.PlayerCardMeta[card.Id]=p.PlayerCardMeta[card.Id] or {};p.PlayerCardMeta[card.Id][flag]=value;if self.Profiles.Save then self.Profiles:Save(player)end;return true,flag..(value and " enabled." or " disabled."),false end

function SquadService:GetSquad(player:Player):any?
	local p=self.Profiles:GetProfile(player);if not p then return nil end;self:_normalize(p);local filled,rating,chemistry=self:_calculate(p);local formation=self:_formation(p);local slots={}
	for _,slot in ORDER do local card=self:_card(p,p.Squad[slot]);local expected=formation[slot].Expected;local penalty=card and positionPenalty(card,expected)or 0;local cardCopy=copyForSlot(card,expected,card and p.PlayerCardMeta[card.Id]or nil);slots[slot]={Position=slot,Label=formation[slot].Label,ExpectedPosition=expected,Card=cardCopy,OutOfPosition=penalty>0,PositionPenalty=penalty,Coordinate={X=formation[slot].X,Y=formation[slot].Y}} end
	local bench={};for index=1,7 do local card=self:_card(p,p.Bench[index]);local copy=card and table.clone(card)or nil;if copy then copy.Meta=table.clone(p.PlayerCardMeta[card.Id]or{})end;bench[index]={Index=index,Card=copy} end
	local reserves={};for _,id in p.Reserves do local card=self:_card(p,id);if card then local copy=table.clone(card);copy.Meta=table.clone(p.PlayerCardMeta[card.Id]or{});table.insert(reserves,copy) end end
	local club={};for _,card in p.PlayerCardInventory do local copy=table.clone(card);local kind,slot=self:_locate(p,card.Id);copy.RosterLocation=kind;copy.RosterSlot=slot;copy.Meta=table.clone(p.PlayerCardMeta[card.Id] or {});if kind=="Club" then copy.location="club";copy.Location="club" end;table.insert(club,copy) end
	local objective,groupCompleted=self:_visibleObjective(p);local objectiveData=objective and {objectiveId=objective.objectiveId,title=objective.title,description=objective.description,progress=objective.progress,target=objective.target,status=objective.status,reward=objective.reward} or nil
	local transferList={};for _,id in p.TransferList do local card=self:_card(p,id);if card then table.insert(transferList,table.clone(card)) end end
	return {Slots=slots,SlotOrder=ORDER,Bench=bench,Reserves=reserves,TransferList=transferList,Club=club,Rating=rating,Chemistry=chemistry,Filled=filled,Formation=p.Formation,FormationOptions={"4-3-3","4-4-2","4-2-3-1","3-5-2","5-3-2"},TeamName=p.ClubMembership.Name,ClubIdentity=table.clone(p.ClubMembership),Objective=objectiveData,ObjectiveGroupCompleted=groupCompleted,CardMeta=p.PlayerCardMeta,SavedAt=os.time()}
end

function SquadService:GetSquadState(player:Player):any?
	local p=self.Profiles:GetProfile(player);if not p then return nil end;self:_normalize(p);local filled,rating,chemistry=self:_calculate(p)
	return {startingXI=table.clone(p.SquadState.startingXI),bench=table.clone(p.SquadState.bench),reserves=table.clone(p.SquadState.reserves),transferList=table.clone(p.SquadState.transferList),rating=rating,chemistry=chemistry,filled=filled,formation=p.Formation}
end
function SquadService:GetClubPlayers(player:Player):any?
	local p=self.Profiles:GetProfile(player);if not p then return nil end;self:_normalize(p);local players={};for _,card in p.PlayerCardInventory do if card.location=="club" then table.insert(players,table.clone(card)) end end;return players
end
function SquadService:MoveCardToStarting(player:Player,cardInstanceId:string,positionSlot:string):(boolean,string,any?) local ok,message=self:MovePlayer(player,cardInstanceId,"StartingXI",positionSlot);return ok,message,self:GetSquadState(player) end
function SquadService:MoveCardToBench(player:Player,cardInstanceId:string,benchSlot:any):(boolean,string,any?) local index=type(benchSlot)=="string" and tonumber(string.match(benchSlot,"^slot(%d+)$")) or benchSlot;local ok,message=self:MovePlayer(player,cardInstanceId,"Bench",index);return ok,message,self:GetSquadState(player) end
function SquadService:MoveCardToReserves(player:Player,cardInstanceId:string):(boolean,string,any?) local ok,message=self:MovePlayer(player,cardInstanceId,"Reserves",nil);return ok,message,self:GetSquadState(player) end
function SquadService:SwapCards(player:Player,cardInstanceIdA:string,cardInstanceIdB:string):(boolean,string,any?)
	local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",nil end;self:_normalize(p);local a,b=self:_card(p,cardInstanceIdA),self:_card(p,cardInstanceIdB);if not a or not b or (a.Id~=cardInstanceIdA and a.cardInstanceId~=cardInstanceIdA) or (b.Id~=cardInstanceIdB and b.cardInstanceId~=cardInstanceIdB) then return false,"Both card instances must be owned.",self:GetSquadState(player) end;if a.Id==b.Id then return true,"Cards are identical.",self:GetSquadState(player) end
	local typeA,slotA=self:_locate(p,a.Id);local typeB,slotB=self:_locate(p,b.Id)
	if self:_duplicateMatchdayPlayer(p,b,typeA,slotA) or self:_duplicateMatchdayPlayer(p,a,typeB,slotB) then return false,"You cannot use repeat players in the Starting XI or bench.",self:GetSquadState(player) end
	local function assign(kind:string,slot:any,id:string) if kind=="StartingXI" then p.Squad[slot]=id;local card=self:_card(p,id);p.UIState.SelectedSquad[slot]=card and card.Name or nil elseif kind=="Bench" then p.Bench[slot]=id elseif kind=="Reserves" then p.Reserves[slot]=id elseif kind=="TransferList" then p.TransferList[slot]=id end end
	if typeA~="Club" then assign(typeA,slotA,b.Id) end;if typeB~="Club" then assign(typeB,slotB,a.Id) end
	self:_update(player,p);return true,"Cards swapped.",self:GetSquadState(player)
end
function SquadService:RemoveCardFromStarting(player:Player,positionSlot:string):(boolean,string,any?) local p=self.Profiles:GetProfile(player);if not p or not SquadSlots[positionSlot] then return false,"Invalid starting position.",nil end;self:_normalize(p);local id=p.Squad[positionSlot];if not id then return true,"Starting slot is empty.",self:GetSquadState(player) end;local ok,message=self:MovePlayer(player,id,"Club",nil);return ok,message,self:GetSquadState(player) end
function SquadService:LockCard(player:Player,cardInstanceId:string,locked:boolean):(boolean,string,any?) local ok,message=self:SetCardFlag(player,cardInstanceId,"Locked",locked);return ok,message,self:GetSquadState(player) end
function SquadService:FavoriteCard(player:Player,cardInstanceId:string,favorite:boolean):(boolean,string,any?) local ok,message=self:SetCardFlag(player,cardInstanceId,"Favorite",favorite);return ok,message,self:GetSquadState(player) end

local function quickSellValue(card:any):number
	local normalized=math.clamp(((tonumber(card and card.Rating)or 45)-45)/54,0,1)
	return math.floor(1000+4000*(normalized^1.55)+.5)
end

function SquadService:QuickSellCard(player:Player,cardInstanceId:string):(boolean,string,any?)
	local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",nil end;self:_normalize(p);local card=self:_card(p,cardInstanceId);if not card then return false,"Player card is not owned.",nil end;local meta=p.PlayerCardMeta[card.Id]or{};if meta.Locked then return false,"Unlock this player before quick selling.",nil end;if meta.Loan==true then return false,"Loan players cannot be quick sold.",nil end
	local kind,slot=self:_locate(p,card.Id);self:_remove(p,kind,slot);for index,item in p.PlayerCardInventory do if item.Id==card.Id then table.remove(p.PlayerCardInventory,index);break end end;p.PlayerCardMeta[card.Id]=nil
	local coins=quickSellValue(card);p.Currency.Coins=math.min(EconomyConfig.MaximumCoins,(tonumber(p.Currency.Coins)or 0)+coins);self:_update(player,p);self.Publish(player,"Currency",{Coins=p.Currency.Coins,Bolts=p.Currency.Bolts,VoltraPoints=p.Currency.VoltraPoints or 0});if self.Profiles.GetClientData then self.Publish(player,"PlayerProfile",self.Profiles:GetClientData(player))end;local snapshot=self:GetSquad(player);if snapshot then snapshot.QuickSellCoins=coins;snapshot.Currency={Coins=p.Currency.Coins,Bolts=p.Currency.Bolts,VoltraPoints=p.Currency.VoltraPoints or 0} end;return true,"Quick sold for "..coins.." coins.",snapshot
end

function SquadService:BulkQuickSellCards(player:Player,cardInstanceIds:any):(boolean,string,any?)
	local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",nil end
	if type(cardInstanceIds)~="table"then return false,"Select players to quick sell.",nil end
	self:_normalize(p)
	local seen={}
	local cards={}
	local total=0
	for _,reference in cardInstanceIds do
		local id=tostring(reference or"")
		if id~=""and not seen[id]then
			seen[id]=true
			local card=self:_card(p,id)
			if not card then return false,"One selected player is no longer owned.",nil end
			local meta=p.PlayerCardMeta[card.Id]or{}
			if meta.Locked then return false,"Unlock selected players before bulk quick selling.",nil end
			if meta.Loan==true then return false,"Loan players cannot be quick sold.",nil end
			table.insert(cards,card)
			total+=quickSellValue(card)
			if #cards>=80 then break end
		end
	end
	if #cards<=0 then return false,"Select players to quick sell.",nil end
	local removeSet={}
	for _,card in cards do
		local kind,slot=self:_locate(p,card.Id)
		self:_remove(p,kind,slot)
		removeSet[card.Id]=true
		p.PlayerCardMeta[card.Id]=nil
	end
	for index=#p.PlayerCardInventory,1,-1 do
		local card=p.PlayerCardInventory[index]
		if card and removeSet[card.Id]then table.remove(p.PlayerCardInventory,index)end
	end
	p.Currency.Coins=math.min(EconomyConfig.MaximumCoins,(tonumber(p.Currency.Coins)or 0)+total)
	self:_update(player,p)
	self.Publish(player,"Currency",{Coins=p.Currency.Coins,Bolts=p.Currency.Bolts,VoltraPoints=p.Currency.VoltraPoints or 0})
	if self.Profiles.GetClientData then self.Publish(player,"PlayerProfile",self.Profiles:GetClientData(player))end
	local snapshot=self:GetSquad(player)
	if snapshot then snapshot.QuickSellCoins=total;snapshot.BulkQuickSellCount=#cards;snapshot.Currency={Coins=p.Currency.Coins,Bolts=p.Currency.Bolts,VoltraPoints=p.Currency.VoltraPoints or 0}end
	return true,"Quick sold "..#cards.." players for "..total.." coins.",snapshot
end

function SquadService:GetEligiblePlayersForSlot(player:Player,slot:string):any? local p=self.Profiles:GetProfile(player);if not p or not SquadSlots[slot] then return nil end;self:_normalize(p);local expected=self:_expected(p,slot);local result={};for _,card in p.PlayerCardInventory do local copy=copyForSlot(card,expected,p.PlayerCardMeta[card.Id]);if copy then copy.OutOfPosition=(copy.PositionPenalty or 0)>0;copy.ExpectedPosition=expected;table.insert(result,copy) end end;table.sort(result,function(a,b) if a.OutOfPosition~=b.OutOfPosition then return not a.OutOfPosition end;return (a.Rating or 0)>(b.Rating or 0) end);return result end
function SquadService:SetSquadSlot(player:Player,slot:string,cardId:string):(boolean,string,boolean) return self:MovePlayer(player,cardId,"StartingXI",slot) end
function SquadService:RemoveSquadSlot(player:Player,slot:string):(boolean,string,boolean) local p=self.Profiles:GetProfile(player);if not p or not SquadSlots[slot] then return false,"Invalid squad slot.",false end;self:_normalize(p);local id=p.Squad[slot];if not id then return true,"Slot is already empty.",false end;return self:MovePlayer(player,id,"Club",nil) end
function SquadService:ClearSquad(player:Player):(boolean,string,boolean) local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",false end;self:_normalize(p);for _,slot in ORDER do local id=p.Squad[slot];if id then table.insert(p.Reserves,id) end;p.Squad[slot]=nil;p.UIState.SelectedSquad[slot]=nil end;self:_normalize(p);self:_update(player,p);return true,"Starting XI cleared to reserves.",false end

local function cardId(card:any):string return tostring(card and (card.Id or card.cardInstanceId) or "") end
local function playerIdentity(card:any):string return matchdayIdentity(card) end
local function hasNaturalPosition(card:any,expected:string):boolean return card and (card.Position==expected or table.find(card.positions or card.Positions or{},expected)~=nil) or false end
local function isUsableMatchdayCard(card:any,meta:any?):boolean
	if not card then return false end
	if meta and meta.Loan==true and (tonumber(meta.LoanMatchesRemaining)or 0)<=0 then return false end
	return cardId(card)~=""
end
local function autoSlotScore(card:any,expected:string):number
	local effective=ratingForSlot(card,expected)
	local natural=hasNaturalPosition(card,expected) and 2.2 or 0
	local penalty=positionPenalty(card,expected)
	local special=(card.CardType and card.CardType~="Base" or card.cardType and card.cardType~="Base") and 0.35 or 0
	return effective+natural+special-(penalty>=20 and 2 or 0)
end
local function candidateCardsForSlot(cards:{any},meta:any,expected:string):{any}
	local candidates={}
	for _,card in cards do
		if isUsableMatchdayCard(card,meta[cardId(card)]) then
			table.insert(candidates,{Card=card,Score=autoSlotScore(card,expected),Effective=ratingForSlot(card,expected),Natural=hasNaturalPosition(card,expected)})
		end
	end
	table.sort(candidates,function(a,b)
		if a.Natural~=b.Natural then return a.Natural end
		if a.Score~=b.Score then return a.Score>b.Score end
		return (a.Card.Rating or a.Card.overall or 0)>(b.Card.Rating or b.Card.overall or 0)
	end)
	while #candidates>28 do table.remove(candidates) end
	return candidates
end
local function cloneUsed(source:any):any local result={};for key,value in source do result[key]=value end;return result end
local function lineupChemistry(profile:any,squad:any,formationName:string,cardById:any?):number
	local oldFormation=profile.Formation;profile.Formation=formationName
	local cards={};for _,slot in ORDER do local id=squad[slot];local card=id and cardById and cardById[id] or nil;if not card then for _,owned in profile.PlayerCardInventory do if owned.Id==id then card=owned;break end end end;if card then cards[slot]=card end end
	local chemistry=0;local formation=FormationConfig.Formations[formationName] or FormationConfig.Formations[FormationConfig.Default]
	for slot,card in cards do local expected=formation[slot].Expected;if hasNaturalPosition(card,expected) then chemistry+=2 end end
	for _,pair in LINKS do local a,b=cards[pair[1]],cards[pair[2]];if a and b then if a.Club==b.Club then chemistry+=1 end;if a.Nation==b.Nation then chemistry+=1 end;if a.RoleTag==b.RoleTag then chemistry+=1 end end end
	profile.Formation=oldFormation
	return math.min(33,chemistry)
end
local function buildBestLineup(profile:any,formationName:string):any
	local formation=FormationConfig.Formations[formationName] or FormationConfig.Formations[FormationConfig.Default]
	local cardById={};for _,card in profile.PlayerCardInventory or{}do cardById[cardId(card)]=card end
	local candidatesBySlot={};for _,slot in ORDER do candidatesBySlot[slot]=candidateCardsForSlot(profile.PlayerCardInventory or{},profile.PlayerCardMeta or{},formation[slot].Expected) end
	local states={{Squad={},UsedCards={},UsedPlayers={},Score=0,Filled=0}}
	for _,slot in ORDER do
		local nextStates={}
		for _,state in states do
			for _,entry in candidatesBySlot[slot] do
				local card=entry.Card;local id=cardId(card);local playerId=playerIdentity(card)
				if not state.UsedCards[id] and not state.UsedPlayers[playerId] then
					local squad=table.clone(state.Squad);squad[slot]=id
					local usedCards=cloneUsed(state.UsedCards);usedCards[id]=true
					local usedPlayers=cloneUsed(state.UsedPlayers);usedPlayers[playerId]=true
					table.insert(nextStates,{Squad=squad,UsedCards=usedCards,UsedPlayers=usedPlayers,Score=state.Score+entry.Score,Filled=state.Filled+1})
				end
			end
			if state.Filled<#ORDER then table.insert(nextStates,state) end
		end
		table.sort(nextStates,function(a,b)
			if a.Filled~=b.Filled then return a.Filled>b.Filled end
			return a.Score>b.Score
		end)
		while #nextStates>220 do table.remove(nextStates) end
		states=nextStates
	end
	local best=states[1] or {Squad={},UsedCards={},UsedPlayers={},Score=0,Filled=0}
	for _,state in states do
		local chemistry=lineupChemistry(profile,state.Squad,formationName,cardById)
		local score=state.Score+chemistry*.55+state.Filled*3
		if score>((best.FinalScore or best.Score) :: number) then
			state.Chemistry=chemistry;state.FinalScore=score;best=state
		end
	end
	best.Chemistry=best.Chemistry or lineupChemistry(profile,best.Squad,formationName,cardById)
	best.FinalScore=best.FinalScore or best.Score+best.Chemistry*.55+best.Filled*3
	return best
end
function SquadService:AutoBuildSquad(player:Player):(boolean,string,boolean)
	local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",false end;self:_normalize(p)
	local bestFormation=p.Formation;local bestLineup:any=nil
	for _,formationName in {"4-3-3","4-4-2","4-2-3-1","3-5-2","5-3-2"} do
		local lineup=buildBestLineup(p,formationName)
		if not bestLineup or lineup.FinalScore>bestLineup.FinalScore then bestLineup=lineup;bestFormation=formationName end
	end
	p.Formation=bestFormation;p.Squad={};p.Bench={};p.Reserves={};p.UIState.SelectedSquad={}
	local used=cloneUsed(bestLineup and bestLineup.UsedCards or{})
	local usedPlayers=cloneUsed(bestLineup and bestLineup.UsedPlayers or{})
	for _,slot in ORDER do
		local id=bestLineup and bestLineup.Squad[slot]
		local card=id and self:_card(p,id)
		if card then p.Squad[slot]=card.Id;p.UIState.SelectedSquad[slot]=card.Name end
	end
	local remaining={};for _,card in p.PlayerCardInventory do if not used[card.Id] then table.insert(remaining,card) end end;table.sort(remaining,function(a,b) return (a.Rating or 0)>(b.Rating or 0) end)
	local benchIndex=1
	for _,card in remaining do
		local playerId=playerIdentity(card)
		if benchIndex<=7 and isUsableMatchdayCard(card,p.PlayerCardMeta[cardId(card)]) and not usedPlayers[playerId] then
			p.Bench[benchIndex]=card.Id;usedPlayers[playerId]=true;benchIndex+=1
		else
			table.insert(p.Reserves,card.Id)
		end
	end
	local completed=self:_update(player,p);return true,"Best XI selected in "..bestFormation..".",completed
end

return SquadService
