--!strict
local Templates=require(script.Parent.Parent.Data.CareerTemplates)
local CareerService={};CareerService.__index=CareerService
function CareerService.new(profiles:any) return setmetatable({Profiles=profiles},CareerService) end
function CareerService:Create(player:Player,careerType:string):number?
	local template=Templates[careerType];local p=self.Profiles:GetProfile(player);if not template or not p then return nil end;for _,slot in p.CareerSaveSlots do if slot.Type=="Empty" then local number=slot.Slot;for key,value in template do slot[key]=type(value)=="table" and table.clone(value) or value end;slot.Slot=number;slot.CreatedAt=os.time();slot.UpdatedAt=os.time();p.UIState.CareerSaveSelection=number;return number end end;return nil
end
function CareerService:Select(player:Player,slotNumber:number):boolean local p=self.Profiles:GetProfile(player);if not p or slotNumber%1~=0 or slotNumber<1 or slotNumber>3 then return false end;p.UIState.CareerSaveSelection=slotNumber;return true end
function CareerService:Delete(player:Player,slotNumber:number):boolean local p=self.Profiles:GetProfile(player);if not p then return false end;for index,slot in p.CareerSaveSlots do if slot.Slot==slotNumber then p.CareerSaveSlots[index]={Slot=slotNumber,Type="Empty"};return true end end;return false end
return CareerService
