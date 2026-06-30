--!strict
local HttpService=game:GetService("HttpService")
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local CardFactoryService=require(script.Parent.CardFactoryService)
local Service={};Service.__index=Service
function Service.new(inventory:any)
	local self=setmetatable({Inventory=inventory,SearchCache={},SearchOrder={},ValidationReport=nil},Service)
	task.defer(function()local report=PlayerDatabase.Validate();local cardReady=0;for _,player in PlayerDatabase.Players do if CardFactoryService.ValidateDefinition(player)then cardReady+=1 end end;report.CardReady=cardReady;report.Success=report.ErrorCount==0 and cardReady==report.Total;self.ValidationReport=report;local message=string.format("[VTR PLAYER IMPORT] source=%s players=%d valid=%d cardReady=%d shards=%d errors=%d",report.Source,report.Total,report.Valid,cardReady,report.ShardCount,report.ErrorCount);if report.Success then print(message)else warn(message,table.concat(report.Errors," | "))end end)
	return self
end
function Service:GetOwnedPlayerDetails(player:Player,cardInstanceId:string):any?if type(cardInstanceId)~="string"or#cardInstanceId>80 then return nil end;return self.Inventory:GetCardDetails(player,cardInstanceId)end
function Service:GetDatabaseCount():number return PlayerDatabase.Count end
function Service:GetValidationReport():any return self.ValidationReport or{Source=PlayerDatabase.Source,Total=PlayerDatabase.Count,Status="VALIDATING"}end
function Service:Search(filters:any,offset:number?,limit:number?):any
	filters=type(filters)=="table"and filters or{};local safe={name=string.sub(tostring(filters.name or""),1,40),country=string.sub(tostring(filters.country or""),1,40),club=string.sub(tostring(filters.club or""),1,60),position=string.sub(tostring(filters.position or""),1,5),rarity=string.sub(tostring(filters.rarity or""),1,16),minimumOverall=math.clamp(tonumber(filters.minimumOverall)or 0,0,99),maximumOverall=math.clamp(tonumber(filters.maximumOverall)or 99,0,99),sort=table.find({"overall","potential","value","name"},filters.sort)and filters.sort or"overall"};local key=HttpService:JSONEncode({safe,offset or 0,limit or 50});if self.SearchCache[key]then return self.SearchCache[key]end;local result=PlayerDatabase.Search(safe,offset,limit);self.SearchCache[key]=result;table.insert(self.SearchOrder,key);if#self.SearchOrder>64 then self.SearchCache[table.remove(self.SearchOrder,1)]=nil end;return result
end
return Service
