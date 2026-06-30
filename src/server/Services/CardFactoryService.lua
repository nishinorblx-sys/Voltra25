--!strict
local CardInstanceFactory=require(script.Parent.Parent.Data.CardInstanceFactory)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local Service={}
function Service.ValidateDefinition(definition:any):boolean return type(definition)=="table"and type(definition.playerId)=="string"and type(definition.overall)=="number"and type(definition.rarity)=="string"and type(definition.cardType)=="string"and type(definition.appearance)=="table"and type(definition.mainStats)=="table"end
function Service.Create(playerOrId:any):any?local definition=type(playerOrId)=="string"and PlayerDatabase.Get(playerOrId)or playerOrId;if not Service.ValidateDefinition(definition)then return nil end;return CardInstanceFactory.Create(definition)end
function Service.Hydrate(instance:any):boolean return CardInstanceFactory.Hydrate(instance)end
function Service.GetDetails(instance:any):any?return CardInstanceFactory.GetDetails(instance)end
return Service
