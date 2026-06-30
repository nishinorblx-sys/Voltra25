--!strict
local Templates=require(script.Parent.Parent.Data.ClubTemplates)
local ClubIdentityService={};ClubIdentityService.__index=ClubIdentityService
local function copy(value:any):any if type(value)~="table" then return value end;local r={};for k,v in value do r[k]=copy(v) end;return r end
function ClubIdentityService.new(profiles:any) return setmetatable({Profiles=profiles},ClubIdentityService) end
function ClubIdentityService:Create(player:Player,name:string,tag:string):boolean local p=self.Profiles:GetProfile(player);if not p or p.ClubMembership.ClubId~="" or type(name)~="string" or #name<3 or #name>24 or type(tag)~="string" or #tag<2 or #tag>5 then return false end;local club=copy(Templates.NewClub);club.ClubId="club_"..player.UserId;club.Name=string.upper(name);club.Tag=string.upper(tag);p.ClubMembership=club;p.Profile.SelectedClub=club.Name;return true end
function ClubIdentityService:SetKit(player:Player,kitId:string):boolean local p=self.Profiles:GetProfile(player);if not p or not table.find(p.StoreOwnership.Kits,kitId) then return false end;p.UIState.EquippedCosmetics.ActiveKit=kitId;return true end
function ClubIdentityService:SetStadium(player:Player,id:string):boolean local p=self.Profiles:GetProfile(player);if not p or not table.find(p.StoreOwnership.Stadiums,id) then return false end;p.UIState.EquippedCosmetics.StadiumTheme=id;return true end
return ClubIdentityService
