--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver=require(script.Parent.RemoteResolver)
local remote=RemoteResolver.WaitForFunction(NetworkConfig.SquadFunction)
local SquadService={}
local function request(action:string,payload:any?):any local ok,response=pcall(function() return remote:InvokeServer(action,payload or {}) end);if not ok or type(response)~="table" then return {Success=false,Message="Squad unavailable right now."} end;return response end
function SquadService:GetSquad():any return request("GetSquad") end
function SquadService:SetSquadSlot(slot:string,cardId:string):any return request("SetSquadSlot",{Slot=slot,CardId=cardId}) end
function SquadService:RemoveSquadSlot(slot:string):any return request("RemoveSquadSlot",{Slot=slot}) end
function SquadService:AutoBuildSquad():any return request("AutoBuildSquad") end
function SquadService:ClearSquad():any return request("ClearSquad") end
function SquadService:GetEligiblePlayersForSlot(slot:string):any return request("GetEligiblePlayersForSlot",{Slot=slot}) end
function SquadService:MovePlayer(cardId:string,destinationType:string,destinationSlot:any?):any return request("MovePlayer",{CardId=cardId,DestinationType=destinationType,DestinationSlot=destinationSlot}) end
function SquadService:SetFormation(formation:string):any return request("SetFormation",{Formation=formation}) end
function SquadService:SetMovementProfile(slot:string,profileId:string):any return request("SetMovementProfile",{Slot=slot,ProfileId=profileId}) end
function SquadService:SetPlayerInstructions(cardInstanceId:string,offBall:string,defending:string):any return request("SetPlayerInstructions",{CardInstanceId=cardInstanceId,OffBall=offBall,Defending=defending}) end
function SquadService:SetCardFlag(cardId:string,flag:string,value:boolean):any return request("SetCardFlag",{CardId=cardId,Flag=flag,Value=value}) end
function SquadService:GetSquadState():any return request("GetSquadState") end
function SquadService:GetClubPlayers():any return request("GetClubPlayers") end
function SquadService:MoveCardToStarting(cardInstanceId:string,positionSlot:string):any return request("MoveCardToStarting",{CardInstanceId=cardInstanceId,PositionSlot=positionSlot}) end
function SquadService:MoveCardToBench(cardInstanceId:string,benchSlot:any):any return request("MoveCardToBench",{CardInstanceId=cardInstanceId,BenchSlot=benchSlot}) end
function SquadService:MoveCardToReserves(cardInstanceId:string):any return request("MoveCardToReserves",{CardInstanceId=cardInstanceId}) end
function SquadService:SwapCards(cardInstanceIdA:string,cardInstanceIdB:string):any return request("SwapCards",{CardInstanceIdA=cardInstanceIdA,CardInstanceIdB=cardInstanceIdB}) end
function SquadService:RemoveCardFromStarting(positionSlot:string):any return request("RemoveCardFromStarting",{PositionSlot=positionSlot}) end
function SquadService:LockCard(cardInstanceId:string,locked:boolean):any return request("LockCard",{CardInstanceId=cardInstanceId,Locked=locked}) end
function SquadService:FavoriteCard(cardInstanceId:string,favorite:boolean):any return request("FavoriteCard",{CardInstanceId=cardInstanceId,Favorite=favorite}) end
function SquadService:QuickSellCard(cardInstanceId:string):any return request("QuickSellCard",{CardInstanceId=cardInstanceId}) end
function SquadService:BulkQuickSellCards(cardInstanceIds:any):any return request("BulkQuickSellCards",{CardInstanceIds=cardInstanceIds}) end
function SquadService:CreateTransferListing(cardInstanceId:string,startPrice:number,duration:number):any return request("CreateTransferListing",{CardInstanceId=cardInstanceId,StartPrice=startPrice,Duration=duration})end
function SquadService:GetTransferListings():any return request("GetTransferListings")end
function SquadService:PlaceTransferBid(listingId:string,amount:number):any return request("PlaceTransferBid",{ListingId=listingId,Amount=amount})end
return SquadService
