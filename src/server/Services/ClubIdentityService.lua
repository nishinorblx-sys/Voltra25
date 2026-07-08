--!strict
local Templates=require(script.Parent.Parent.Data.ClubTemplates)
local ClubNameFilterService=require(script.Parent.ClubNameFilterService)
local ClubIdentityService={};ClubIdentityService.__index=ClubIdentityService
local function copy(value:any):any if type(value)~="table" then return value end;local r={};for k,v in value do r[k]=copy(v) end;return r end
function ClubIdentityService.new(profiles:any) return setmetatable({Profiles=profiles},ClubIdentityService) end
function ClubIdentityService:Create(player:Player,name:string,tag:string):boolean
	local p=self.Profiles:GetProfile(player)
	local nameOk,cleanName=ClubNameFilterService.Validate(player,name,24)
	local tagOk,cleanTag=ClubNameFilterService.ValidateTag(player,tag)
	if not p or p.ClubMembership.ClubId~="" or not nameOk or not tagOk then return false end
	local club=copy(p.ClubMembership or{})
	for key,value in Templates.NewClub do if club[key]==nil or club[key]==""then club[key]=copy(value)end end
	club.ClubId="club_"..player.UserId;club.Name=cleanName;club.Abbreviation=cleanTag;club.Tag=cleanTag;club.Role=club.Role=="FREE AGENT"and"FOUNDER"or club.Role;club.Members=math.max(1,tonumber(club.Members)or 0);club.Capacity=tonumber(club.Capacity)or 24;club.Reputation=club.Reputation=="UNRANKED"and"ROOKIE"or club.Reputation;p.ClubMembership=club;p.Profile.SelectedClub=club.Name;return true
end
function ClubIdentityService:SetKit(player:Player,kitId:string):boolean local p=self.Profiles:GetProfile(player);if not p or not table.find(p.StoreOwnership.Kits,kitId) then return false end;p.UIState.EquippedCosmetics.ActiveKit=kitId;return true end
function ClubIdentityService:SetStadium(player:Player,id:string):boolean local p=self.Profiles:GetProfile(player);if not p or not table.find(p.StoreOwnership.Stadiums,id) then return false end;p.UIState.EquippedCosmetics.StadiumTheme=id;return true end
return ClubIdentityService
