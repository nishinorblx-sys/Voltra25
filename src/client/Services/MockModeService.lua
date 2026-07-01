--!strict

local MockModeService = {}
MockModeService.__index = MockModeService
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)

function MockModeService.new(spec: any, defaults: any?)
	return setmetatable({ Spec = spec, State = defaults or { Owned = {}, Equipped = {}, Claimed = {}, Values = {}, Selections = {} } }, MockModeService)
end

function MockModeService:GetSpec(): any return self.Spec end
function MockModeService:GetState(): any return self.State end

local function tab(spec:any,id:string):any? for _,value in spec.Tabs do if value.Id==id then return value end end;return nil end
local function hasValue(values:any,target:any):boolean for _,value in values do if value==target then return true end end;return false end

function MockModeService:Hydrate(ui:any,progression:any)
	self.State.Owned=self.State.Owned or {};self.State.Equipped=self.State.Equipped or {};self.State.Claimed=self.State.Claimed or {};self.State.Values=self.State.Values or {};self.State.Selections=self.State.Selections or {}
	self.State.SelectedTab=ui.SelectedTabs[self.Spec.Id]
	self.State.Progression=progression
	if self.Spec.Id=="UltimateTeam" then
		self.State.Equipped=table.clone(ui.SelectedSquad);for key,value in ui.EquippedCosmetics do self.State.Equipped[key]=value end
		local selected={};local total,count,chemistry=0,0,0;for _,card in progression.PlayerCardInventory do if hasValue(ui.SelectedSquad,card.Name) then table.insert(selected,card);total+=card.Rating;count+=1 end end;chemistry=count
		for first=1,#selected do for second=first+1,#selected do local a,b=selected[first],selected[second];if a.Club==b.Club then chemistry+=2 end;if a.Nation and a.Nation==b.Nation then chemistry+=1 end;if a.RoleTag and a.RoleTag==b.RoleTag then chemistry+=1 end end end;chemistry=math.min(33,chemistry)
		local squad=tab(self.Spec,"Squad");if squad then local overall=count>0 and math.floor(total/count+.5) or 0;squad.Description="SERVER SQUAD • "..count.." / 11 FILLED";squad.Cards={{Title=progression.ClubMembership.Name,Subtitle="TEAM OVERALL "..overall,Meta="CHEMISTRY "..chemistry.." / 33 • CLUB / NATION / ROLE TAGS",Accent=true,Action={Label="MANAGE SQUAD",TargetTab="Cards"}},{Title=count<11 and "EMPTY SQUAD SLOTS" or "STARTING XI READY",Subtitle=count<11 and (11-count).." POSITIONS OPEN" or "11 PLAYERS SELECTED",Meta="Ownership validated by server",Empty=count<11,Action={Label=count<11 and "ADD PLAYERS" or "VIEW CARDS",TargetTab="Cards"}}} end
		local cards=tab(self.Spec,"Cards");if cards then cards.Cards={};for _,card in progression.PlayerCardInventory do local slot=nil;for equippedSlot,name in ui.SelectedSquad do if name==card.Name then slot=equippedSlot;break end end;if not slot then if card.Position=="CB" then slot=ui.SelectedSquad.CB and "CB2" or "CB" elseif card.Position=="CM" then slot=ui.SelectedSquad.CM1 and "CM2" or "CM1" else slot=card.Position end end;table.insert(cards.Cards,{Id=card.Id,CardInstanceId=card.cardInstanceId,PlayerData=card,Title=card.Name,Subtitle=card.Rating.." "..card.Position.." • "..card.Club,Meta=(card.Nation or "VTR").." • "..(card.RoleTag or "PLAYER").." • OWNED",Accent=card.Rating>=90,Detail="Server-owned card. Chemistry uses fictional club, nation and role tags.",Action={Label="VIEW / EQUIP",Operation="EquipToggle",Item=card.Name,Slot=slot,Confirm=true}}) end end
		local packs=tab(self.Spec,"Packs");if packs then packs.Cards={};for _,pack in progression.PackInventory do if (pack.status or pack.Status)=="unopened" then table.insert(packs.Cards,{Title=pack.name or pack.Name,Subtitle=string.upper(pack.description or pack.Description or "PLAYER PACK"),Meta="1 UNOPENED",Accent=(pack.packId or pack.Id)=="voltra_pack",Action={Label="OPEN PACK",Operation="ComingSoon",ServerAction="OpenPack",ServerId=pack.packInstanceId or pack.PackInstanceId,Message="Pack opening presentation ready.",Loading=true}}) end end;if #packs.Cards==0 then table.insert(packs.Cards,{Title="NO PACKS",Subtitle="INVENTORY EMPTY",Meta="Earn packs through objectives",Empty=true,Action={Label="VIEW OBJECTIVES",TargetTab="Objectives"}}) end end
		local objectives=tab(self.Spec,"Objectives");if objectives then objectives.Cards={};for _,objective in progression.Objectives do table.insert(objectives.Cards,{Title=objective.Title,Subtitle=string.upper(objective.Cadence).." OBJECTIVE",Meta=objective.Progress.." / "..objective.Target.." • +"..objective.Reward.Amount.." "..objective.Reward.Type,Accent=objective.Progress>=objective.Target,Action={Label=objective.Claimed and "CLAIMED" or (objective.Progress>=objective.Target and "CLAIM REWARD" or "TRACK OBJECTIVE"),Operation=objective.Progress>=objective.Target and "Claim" or "Toast",Item=objective.Title,ServerId=objective.Id,ServerKind="Objective",Message="Objective pinned to progression tracking.",Confirm=objective.Progress>=objective.Target and not objective.Claimed}}) end end
		local clubTab=tab(self.Spec,"Club");if clubTab then clubTab.Cards={};for _,kit in Catalog.Kits do if hasValue(progression.StoreOwnership.Kits,kit.Id) then table.insert(clubTab.Cards,{Title=kit.Name,Subtitle="OWNED CLUB KIT",Meta=ui.EquippedCosmetics.ActiveKit==kit.Id and "EQUIPPED" or "AVAILABLE",Accent=ui.EquippedCosmetics.ActiveKit==kit.Id,Action={Label="EQUIP KIT",Operation="Select",Key="ActiveKit",Item=kit.Id}}) end end;for _,stadium in Catalog.Stadiums do if hasValue(progression.StoreOwnership.Stadiums,stadium.Id) then table.insert(clubTab.Cards,{Title=stadium.Name,Subtitle="OWNED STADIUM",Meta=ui.EquippedCosmetics.StadiumTheme==stadium.Id and "EQUIPPED" or "AVAILABLE",Action={Label="EQUIP STADIUM",Operation="Select",Key="StadiumTheme",Item=stadium.Id}}) end end end
	elseif self.Spec.Id=="Ranked" then
		self.Spec.Title="RANKED "..progression.Season.Name;local ranked=progression.Ranked;local division=tab(self.Spec,"Division");if division then local voltra=(ranked.DivisionNumber or 10)==0;local progress=ranked.DivisionWins or ranked.RP or 0;local protected=ranked.ProtectedWins or 0;division.Cards={{Title="RANKED 1V1",Subtitle="YOUR CURRENT SQUAD HUB XI",Meta="8 MIN  ?  WORLD CLASS  ?  RANDOM CONDITIONS",Accent=true,Action={Label="FIND MATCH",Operation="RankedQueue",Loading=true}},{Title="SEASON RECORD",Subtitle=ranked.Wins.." W  ?  "..ranked.Draws.." D  ?  "..ranked.Losses.." L",Meta=#ranked.History==0 and"NO MATCH HISTORY"or#ranked.History.." RECENT MATCHES",Action={Label="VIEW MATCH HISTORY",TargetTab="History"}}}end
		local history=tab(self.Spec,"History");if history then history.Cards={};local function statLine(label:string,home:any,away:any)return label.."  "..tostring(home or 0).." - "..tostring(away or 0)end;local function details(match:any):string local stats=match.Stats or{};local full=stats.Full or{};local home=full.Home or{};local away=full.Away or{};local lines={};for _,goal in full.Goals or{}do local minute=math.max(1,math.floor((tonumber(goal.GameSeconds)or 0)/60)+1);local assist=goal.Assist and(" / A - "..tostring(goal.Assist))or"";table.insert(lines,tostring(minute).."' "..tostring(goal.Scorer or"Unknown")..assist)end;if#lines==0 then table.insert(lines,"NO GOAL EVENTS RECORDED")end;table.insert(lines,"");table.insert(lines,statLine("POSSESSION",home.Possession,away.Possession));table.insert(lines,statLine("SHOTS",home.Shots,away.Shots));table.insert(lines,statLine("ON TARGET",home.ShotsOnTarget,away.ShotsOnTarget));table.insert(lines,statLine("XG",home.ExpectedGoals,away.ExpectedGoals));table.insert(lines,statLine("PASSES",home.PassesCompleted,away.PassesCompleted));table.insert(lines,statLine("FOULS",home.Fouls,away.Fouls));return table.concat(lines,"\n")end;for _,match in ranked.History or{}do table.insert(history.Cards,{Title=string.upper(match.Result).."  "..match.Score,Subtitle="VS "..string.upper(match.Opponent),Meta=(match.RPDelta>=0 and"+"or"")..match.RPDelta.." PROGRESS  ?  "..os.date("%Y-%m-%d",match.At),Accent=match.Result=="Win",Action={Label="MATCH DETAILS",Operation="Toast",Message=details(match)}})end;if#history.Cards==0 then history.Cards={{Title="NO RANKED MATCHES",Subtitle="YOUR HISTORY STARTS HERE",Meta="Find an opponent in Rivals Reloaded",Empty=true,Action={Label="VIEW RIVALS",TargetTab="Division"}}}end end
		local leaders=tab(self.Spec,"Leaders");if leaders then if(ranked.DivisionNumber or 10)==0 then leaders.Cards={{Title="VOLTRA RATING "..(ranked.VoltraRating or 1000),Subtitle="YOU ARE LEADERBOARD ELIGIBLE",Meta="GLOBAL BOARD UPDATES FROM VOLTRA MATCHES",Accent=true,Action={Label="REFRESH BOARD",Operation="Toast",Message="Leaderboard refreshed."}}}else leaders.Cards={{Title="VOLTRA DIVISION ONLY",Subtitle="EARN PROMOTION THROUGH DIVISION 1",Meta="NO ELIGIBLE PLAYERS TO DISPLAY",Empty=true,Action={Label="VIEW DIVISION",TargetTab="Division"}}}end end
		local rewards=tab(self.Spec,"Rewards");if rewards then rewards.Cards={};for _,reward in progression.RankedRewards do if reward.Claimed then self.State.Claimed[reward.Title]=true end;table.insert(rewards.Cards,{Title=reward.Title,Subtitle=reward.Description,Meta=reward.Claimed and "CLAIMED" or "READY TO CLAIM",Accent=not reward.Claimed,Action={Label=reward.Claimed and "CLAIMED" or "CLAIM REWARD",Operation="Claim",Item=reward.Title,ServerId=reward.Id,ServerKind="Ranked",Confirm=not reward.Claimed}}) end end
		local seasonTab=tab(self.Spec,"Season");if seasonTab then seasonTab.Description=progression.Season.Name.." • LEVEL "..progression.Season.Level;seasonTab.Cards={};for _,reward in progression.SeasonRewards do table.insert(seasonTab.Cards,{Title="SEASON LEVEL "..reward.Level,Subtitle=reward.Type.." REWARD",Meta=reward.Amount and tostring(reward.Amount) or reward.Item,Action={Label="PREVIEW REWARD",Operation="Toast",Message="Season rewards are granted by server progression."}}) end end
	elseif self.Spec.Id=="Clubs" then
		local club=progression.ProClubMembership or{ClubId="",Name="NO PRO CLUB",Tag="",Role="FREE AGENT",Members=0,Capacity=24,Reputation="UNRANKED"};local dashboard=tab(self.Spec,"Dashboard");if club.ClubId=="" then self.State.SelectedTab="Start";if dashboard then dashboard.Description="NO PRO CLUB MEMBERSHIP";dashboard.Cards={{Title="CREATE OR JOIN A PRO CLUB",Subtitle="SEPARATE FROM YOUR ULTIMATE TEAM",Meta="Search, invite codes and league entry",Empty=true,Action={Label="GO TO CLUB SETUP",TargetTab="Start"}}}end elseif dashboard then if not ui.SelectedTabs.Clubs then self.State.SelectedTab="Dashboard"end;dashboard.Description=club.Name.." • "..club.Members.." / "..club.Capacity.." MEMBERS";dashboard.Cards={{Title=club.Name,Subtitle=(club.Tag or"VTR").." • "..club.Role,Meta=club.Reputation.." • PRO CLUB",Accent=true,Action={Label="CLUB DETAILS",Operation="Toast",Message="Pro Club membership loaded from the server profile."}},{Title="CLUB MEMBERS",Subtitle=club.Members.." / "..club.Capacity,Meta="Owner and captain permissions",Action={Label="VIEW MEMBERS",TargetTab="Members"}}}end
	elseif self.Spec.Id=="Career" then
		self.State.Selections.SaveSlot="Slot "..ui.CareerSaveSelection
		local activeSave=nil;local emptyCount=0;local saves=tab(self.Spec,"Saves");if saves then saves.Cards={};for _,save in progression.CareerSaveSlots do local empty=save.Type=="Empty";if empty then emptyCount+=1 elseif save.Slot==ui.CareerSaveSelection then activeSave=save end;table.insert(saves.Cards,{Title="SLOT "..save.Slot,Subtitle=empty and "EMPTY" or save.Name.." • "..save.Season,Meta=empty and "Create a new career" or save.Type.." CAREER • OVR "..(save.Overall or "N/A"),Empty=empty,Accent=save.Slot==ui.CareerSaveSelection,Action=empty and {Label="NEW CAREER",Operation="CareerSetup",TargetTab="Choose"} or {Label="LOAD SAVE",Operation="Select",Key="SaveSlot",Item="Slot "..save.Slot,AfterTab="Dashboard"}}) end end
		if emptyCount==#progression.CareerSaveSlots and not ui.SelectedTabs.Career then self.State.SelectedTab="Saves" end;local dashboard=tab(self.Spec,"Dashboard");if dashboard then if activeSave then dashboard.Description="ACTIVE "..string.upper(activeSave.Type).." CAREER • SLOT "..activeSave.Slot;dashboard.Cards={{Title=activeSave.Name,Subtitle=activeSave.Season.." • "..progression.ClubMembership.Name,Meta=activeSave.Type=="Player" and "OVERALL "..(activeSave.Overall or 62) or "MANAGER RATING "..(activeSave.Rating or 50),Accent=true,Action={Label="CONTINUE CAREER",Operation="ComingSoon",Message="Career dashboard is live; match gameplay remains disconnected."}},{Title="CAREER DATA",Subtitle="SERVER PROFILE SAVE",Meta="LAST UPDATED "..(activeSave.UpdatedAt or "NOW"),Action={Label="VIEW STATS",TargetTab="Stats"}}} else dashboard.Description="NO ACTIVE CAREER SAVE";dashboard.Cards={{Title="CREATE YOUR FIRST CAREER",Subtitle="PLAYER OR MANAGER",Meta="Three save slots available",Empty=true,Action={Label="CHOOSE CAREER",TargetTab="Choose"}}} end end
	elseif self.Spec.Id=="Store" then
		local serverCatalog=progression.StoreCatalog or {}
		local coinBundles=serverCatalog.CoinBundles or Catalog.CoinBundles or {}
		local coinsTab=tab(self.Spec,"Coins")
		if coinsTab then
			coinsTab.Cards={}
			local order={"coin_small","coin_medium","coin_large","coin_elite"}
			for index,id in order do
				local bundle=coinBundles[id]
				if bundle then
					table.insert(coinsTab.Cards,{
						Title=bundle.Name,
						Subtitle=tostring(bundle.Coins).." COINS",
						Meta="R$ "..tostring(bundle.Robux).."  /  PRODUCT PLACEHOLDER",
						Accent=index==#order,
						Action={Label="BUY COINS",Operation="RobuxCoins",ServerAction="BuyCoins",ServerId=id,Confirm=true,Description="This currently grants test coins through the server. Replace ProductId later to use Roblox receipts."},
					})
				end
			end
		end
		local packOrder={"common_pack","bronze_pack","silver_pack","gold_pack","rare_pack","elite_pack","legendary_pack","icon_pack","mythic_pack","voltra_pack"}
		local packsTab=tab(self.Spec,"Packs")
		if packsTab then
			packsTab.Cards={}
			for _,id in packOrder do
				local pack=(serverCatalog.Packs or Catalog.Packs)[id]
				if pack then
					local best=(pack.Odds and pack.Odds.Mythic and "MYTHIC")or(pack.Odds and pack.Odds.Icon and "ICON")or(pack.Odds and pack.Odds.Legendary and "LEGENDARY")or(pack.Odds and pack.Odds.Elite and "ELITE")or(pack.Odds and pack.Odds.Rare and "RARE")or(pack.Odds and pack.Odds.Gold and "GOLD")or"BRONZE"
					table.insert(packsTab.Cards,{
						Title=pack.Name,
						Subtitle=pack.CardCount.." CARDS  /  BEST "..best,
						Meta="◈ "..tostring(pack.PriceCoins or 0),
						Accent=id=="voltra_pack" or id=="mythic_storm_pack",
						Detail=(pack.Description or "VTR player pack").."\n\nGuaranteed: "..tostring(pack.GuaranteedMinRarity or "Weighted odds"),
						Action={Label="PURCHASE PACK",Operation="Purchase",Item=id,ServerId=id,ItemType="Pack",Confirm=true},
					})
				end
			end
		end
	elseif self.Spec.Id=="Settings" then self.State.Values=table.clone(ui.Settings);for key,value in ui.Settings do if type(value)=="string" then self.State.Selections[key]=value end end end
end

function MockModeService:GetSummary():string
	local p=self.State.Progression;if not p then return "MOCK DATA READY" end
	if self.Spec.Id=="UltimateTeam" then local packs=0;for _,item in p.PackInventory do if (item.status or item.Status)=="unopened" then packs+=1 end end;return #p.PlayerCardInventory.." PLAYER CARDS  •  "..packs.." PACKS  •  SEASON LEVEL "..p.Season.Level
	elseif self.Spec.Id=="Ranked" then return p.Ranked.Division.."  •  "..p.Ranked.RP.." / "..p.Ranked.RequiredRP.." RP"
	elseif self.Spec.Id=="Clubs" then return p.ClubMembership.Name.."  •  "..p.ClubMembership.Role.."  •  "..p.ClubMembership.Members.." / "..p.ClubMembership.Capacity
	elseif self.Spec.Id=="Career" then return "ACTIVE SAVE: SLOT "..self.State.Selections.SaveSlot:gsub("Slot ","").."  •  "..#p.CareerSaveSlots.." SLOTS"
	elseif self.Spec.Id=="Store" then return p.Currency.Coins.." COINS  •  "..p.Currency.Bolts.." BOLTS"
	elseif self.Spec.Id=="Settings" then return "LOCAL UI PREFERENCES  •  AUTO-SAVED" end
	return "SESSION STATE READY"
end

function MockModeService:Perform(action: any): string
	local operation = action.Operation or "ComingSoon"
	if operation == "EquipToggle" then
		if self.State.Equipped[action.Slot] == action.Item then
			self.State.Equipped[action.Slot] = nil
			return action.Item .. " removed from squad."
		end
		self.State.Equipped[action.Slot] = action.Item
		return action.Item .. " equipped to " .. action.Slot .. "."
	elseif operation == "Purchase" then
		if action.ItemType == "Pack" then return "Pack purchased and delivered to unopened inventory." end
		if self.State.Owned[action.Item] then return action.Item .. " is already owned." end
		self.State.Owned[action.Item] = true
		return "Purchase complete: " .. action.Item
	elseif operation == "Claim" then
		if self.State.Claimed[action.Item] then return "Reward already claimed." end
		self.State.Claimed[action.Item] = true
		return "Reward claimed: " .. action.Item
	elseif operation == "Toggle" then
		self.State.Values[action.Key] = not self.State.Values[action.Key]
		return action.Label .. " is now " .. (self.State.Values[action.Key] and "ON" or "OFF") .. "."
	elseif operation == "Select" then
		self.State.Selections[action.Key] = action.Item
		return action.Item .. " selected."
	elseif operation == "Create" then
		self.State.Values[action.Key or "Created"] = true
		return action.Success or "Created successfully."
	elseif operation == "Save" then
		self.State.Values.SavedAt = os.time()
		return "Settings saved for this session."
	end
	return action.Message or "Coming soon — this flow is ready for gameplay services."
end

return MockModeService
