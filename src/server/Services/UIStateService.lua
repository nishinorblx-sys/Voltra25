--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Schema=require(ReplicatedStorage.VTR.Shared.UIStateSchema)
local UIStateService={};UIStateService.__index=UIStateService

local function copy(value:any):any if type(value)~="table" then return value end;local result={};for key,child in value do result[key]=copy(child) end;return result end
local function safeString(value:any,max:number):boolean return type(value)=="string" and #value>0 and #value<=max end
local function clampTutorialStep(value:any):number
	local step=math.floor(tonumber(value) or 1)
	return math.clamp(step,1,20)
end
local function ownsGamePass(profile:any,id:string):boolean
	local passes=profile and profile.StoreOwnership and profile.StoreOwnership.GamePasses
	return type(passes)=="table" and table.find(passes,id)~=nil
end
local function normalizeSoundId(value:any):string
	local raw=tostring(value or "")
	local digits=string.match(raw,"(%d+)")
	if not digits or #digits<3 or #digits>18 then return "" end
	return "rbxassetid://"..digits
end

function UIStateService.new(profiles:any,remote:RemoteEvent,publish:(Player,string,any)->()) return setmetatable({Profiles=profiles,Remote=remote,Publish=publish,LastUpdate={}},UIStateService) end
function UIStateService:GetClientData(player:Player):any? local profile=self.Profiles:GetProfile(player);return profile and copy(profile.UIState) or nil end

function UIStateService:Start()
	self.Remote.OnServerEvent:Connect(function(player,payload)
		if type(payload)~="table" or type(payload.Type)~="string" then return end
		local kind=payload.Type
		local now=os.clock();if kind~="TutorialProgress" and now-(self.LastUpdate[player] or 0)<.05 then return end;self.LastUpdate[player]=now
		local profile=self.Profiles:GetProfile(player);if not profile then return end;local state=profile.UIState
		if kind=="LastPage" and Schema.Pages[payload.Page] then state.LastPage=payload.Page
		elseif kind=="Tab" and safeString(payload.Mode,24) and safeString(payload.Tab,32) and Schema.Tabs[payload.Mode] and Schema.Tabs[payload.Mode][payload.Tab] then state.SelectedTabs[payload.Mode]=payload.Tab
		elseif kind=="Setting" and safeString(payload.Key,32) and Schema.Settings[payload.Key] and type(payload.Value)==Schema.Settings[payload.Key] and (type(payload.Value)~="string" or #payload.Value<=32) then state.Settings[payload.Key]=payload.Value;profile.Settings[payload.Key]=payload.Value
		elseif kind=="TutorialProgress" then
			local step=clampTutorialStep(payload.Step)
			local device=tostring(payload.Device or ""):sub(1,32)
			local complete=payload.Complete==true
			state.Settings.TutorialStep=complete and 1 or step
			state.Settings.TutorialDevice=device
			state.Settings.TutorialComplete=complete
			profile.Settings.TutorialStep=state.Settings.TutorialStep
			profile.Settings.TutorialDevice=device
			profile.Settings.TutorialComplete=complete
		elseif kind=="Squad" then
			-- Squad mutations must use SquadAction so ownership, uniqueness,
			-- chemistry and objective progress are validated together.
			return
		elseif kind=="Cosmetic" and Schema.CosmeticSlots[payload.Slot] and safeString(payload.Item,48) then local owned=table.find(profile.StoreOwnership.Kits,payload.Item) or table.find(profile.StoreOwnership.Stadiums,payload.Item) or table.find(profile.StoreOwnership.Cosmetics,payload.Item);if not owned then return end;state.EquippedCosmetics[payload.Slot]=payload.Item;profile.OwnedCosmetics[payload.Slot]=payload.Item;if payload.Slot=="GoalMusic"then player:SetAttribute("VTRGoalMusic",payload.Item)elseif payload.Slot=="GoalEffect"then player:SetAttribute("VTRGoalEffect",payload.Item)elseif payload.Slot=="Celebration"then player:SetAttribute("VTRCelebration",payload.Item)elseif payload.Slot=="Walkout"then player:SetAttribute("VTRWalkout",payload.Item)elseif payload.Slot=="BootStyle"then player:SetAttribute("VTRBootStyle",payload.Item)end
		elseif kind=="CosmeticClear" and payload.Slot=="ActiveKit" then state.EquippedCosmetics.ActiveKit="home_kit";profile.OwnedCosmetics.ActiveKit="home_kit"
		elseif kind=="CosmeticClear" and Schema.CosmeticSlots[payload.Slot] then state.EquippedCosmetics[payload.Slot]="";profile.OwnedCosmetics[payload.Slot]="";if payload.Slot=="GoalMusic"then player:SetAttribute("VTRGoalMusic","")elseif payload.Slot=="GoalEffect"then player:SetAttribute("VTRGoalEffect","")elseif payload.Slot=="Celebration"then player:SetAttribute("VTRCelebration","")elseif payload.Slot=="Walkout"then player:SetAttribute("VTRWalkout","")elseif payload.Slot=="BootStyle"then player:SetAttribute("VTRBootStyle","")end
		elseif kind=="CustomGoalMusic" then
			if not ownsGamePass(profile,"custom_goal_music") then return end
			local soundId=normalizeSoundId(payload.SoundId)
			if soundId=="" then return end
			local startSecond=math.clamp(math.floor((tonumber(payload.StartSecond)or 0)*10)/10,0,600)
			state.EquippedCosmetics.CustomGoalMusicId=soundId
			state.EquippedCosmetics.CustomGoalMusicStart=startSecond
			profile.OwnedCosmetics.CustomGoalMusicId=soundId
			profile.OwnedCosmetics.CustomGoalMusicStart=startSecond
			player:SetAttribute("VTRCustomGoalMusicId",soundId)
			player:SetAttribute("VTRCustomGoalMusicStart",startSecond)
		elseif kind=="CareerSave" and type(payload.Slot)=="number" and payload.Slot%1==0 and payload.Slot>=1 and payload.Slot<=3 then state.CareerSaveSelection=payload.Slot
		else return end
		self.Publish(player,"UIState",self:GetClientData(player))
	end)
end
return UIStateService
