--!strict
local DataStoreService=game:GetService("DataStoreService")
local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local EconomyConfig=require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local DeveloperConfig=require(ReplicatedStorage.VTR.Shared.DeveloperConfig)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local Service={};Service.__index=Service
local VALID_DURATIONS={[3600]=true,[10800]=true,[21600]=true,[43200]=true,[86400]=true}
local function findCard(profile:any,id:string):any?for _,card in profile.PlayerCardInventory or{}do if card.Id==id or card.cardInstanceId==id then return card end end;return nil end
local function hasBudget(requestType:any):boolean local ok,budget=pcall(function()return DataStoreService:GetRequestBudgetForRequestType(requestType)end);return not ok or(tonumber(budget)or 0)>0 end
function Service.new(profiles:any,inventory:any,squad:any)
	return setmetatable({Profiles=profiles,Inventory=inventory,Squad=squad,Listings=DataStoreService:GetDataStore("VTR25_TransferListings_v2"),Index=DataStoreService:GetOrderedDataStore("VTR25_TransferIndex_v2"),Mail=DataStoreService:GetDataStore("VTR25_TransferMail_v2"),Local={},Token=game.JobId~=""and game.JobId or HttpService:GenerateGUID(false)},Service)
end
function Service:_queueMail(userId:number,entry:any)
	pcall(function()self.Mail:UpdateAsync(tostring(userId),function(current:any)local mail=type(current)=="table"and current or{};table.insert(mail,entry);return mail end)end)
end
function Service:_removeCard(profile:any,id:string)
	for index,reference in profile.TransferList or{}do if reference==id then table.remove(profile.TransferList,index);break end end
	if profile.SquadState and profile.SquadState.transferList then for index,reference in profile.SquadState.transferList do if reference==id then table.remove(profile.SquadState.transferList,index);break end end end
	for index,card in profile.PlayerCardInventory or{}do if card.Id==id or card.cardInstanceId==id then table.remove(profile.PlayerCardInventory,index);break end end;profile.PlayerCardMeta[id]=nil
end
function Service:_applyMail(player:Player)
	task.wait(1);local profile=self.Profiles:GetProfile(player);if not profile then return end;local ok,mail=pcall(function()return self.Mail:GetAsync(tostring(player.UserId))end);if not ok or type(mail)~="table"then return end
	for _,entry in mail do if entry.Type=="Coins"then profile.Currency.Coins=math.min(EconomyConfig.MaximumCoins,profile.Currency.Coins+(entry.Amount or 0))elseif entry.Type=="RemoveCard"then self:_removeCard(profile,entry.CardId)elseif entry.Type=="ReturnCard"then self.Squad:MovePlayer(player,entry.CardId,"Club",nil)elseif entry.Type=="Player"then local definition=PlayerDatabase.Get(entry.PlayerId);if definition then self.Inventory:AddCard(player,definition)end end end
	pcall(function()self.Mail:RemoveAsync(tostring(player.UserId))end)
end
function Service:_settle(listing:any)
	if not listing or listing.Status~="Active"or listing.EndsAt>os.time()then return end
	local claimed=false;local ok,updated=pcall(function()return self.Listings:UpdateAsync(listing.ListingId,function(current:any)if type(current)~="table"or current.Status~="Active"or current.EndsAt>os.time()then return current end;current.Status="Settling";current.SettlementToken=self.Token;claimed=true;return current end)end)
	if ok then if not claimed or not updated or updated.SettlementToken~=self.Token then return end;listing=updated elseif self.Local[listing.ListingId]then listing.Status="Settling"else return end
	listing.Status=listing.CurrentBidderUserId>0 and"Sold"or"Expired";listing.SettlementToken=self.Token;self:_write(listing.ListingId,listing)
	local seller=Players:GetPlayerByUserId(listing.SellerUserId);local sellerProfile=seller and self.Profiles:GetProfile(seller)
	if listing.Status=="Sold"then
		if sellerProfile then self:_removeCard(sellerProfile,listing.CardInstanceId);sellerProfile.Currency.Coins=math.min(EconomyConfig.MaximumCoins,sellerProfile.Currency.Coins+listing.CurrentBid)else self:_queueMail(listing.SellerUserId,{Type="RemoveCard",CardId=listing.CardInstanceId});self:_queueMail(listing.SellerUserId,{Type="Coins",Amount=listing.CurrentBid})end
		local winner=Players:GetPlayerByUserId(listing.CurrentBidderUserId);local definition=PlayerDatabase.Get(listing.PlayerId);if winner and definition then self.Inventory:AddCard(winner,definition)else self:_queueMail(listing.CurrentBidderUserId,{Type="Player",PlayerId=listing.PlayerId})end
	elseif sellerProfile then self.Squad:MovePlayer(seller,listing.CardInstanceId,"Club",nil)else self:_queueMail(listing.SellerUserId,{Type="ReturnCard",CardId=listing.CardInstanceId})end
	if hasBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)then pcall(function()self.Index:RemoveAsync(listing.ListingId)end)end;self.Local[listing.ListingId]=nil
end
function Service:Start()
	Players.PlayerAdded:Connect(function(player)task.spawn(function()self:_applyMail(player)end)end);for _,player in Players:GetPlayers()do task.spawn(function()self:_applyMail(player)end)end
	task.spawn(function()while task.wait(5)do for _,listing in self.Local do self:_settle(listing)end;if hasBudget(Enum.DataStoreRequestType.GetSortedAsync)then local ok,pages=pcall(function()return self.Index:GetSortedAsync(true,40,nil,os.time())end);if ok and pages then for _,entry in pages:GetCurrentPage()do if hasBudget(Enum.DataStoreRequestType.GetAsync)then local loaded,value=pcall(function()return self.Listings:GetAsync(entry.key)end);if loaded then self:_settle(value)end end end end end end end)
end
function Service:_write(id:string,listing:any):boolean local listingOk=false;if hasBudget(Enum.DataStoreRequestType.SetIncrementAsync)then listingOk=pcall(function()self.Listings:SetAsync(id,listing)end)end;local indexOk=false;if listingOk and hasBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)then indexOk=pcall(function()self.Index:SetAsync(id,listing.EndsAt)end)end;if not listingOk or not indexOk then self.Local[id]=listing end;return true end
function Service:CreateListing(player:Player,cardId:string,startPrice:number,duration:number):(boolean,string,any?)
	startPrice=math.floor(tonumber(startPrice)or 0);duration=math.floor(tonumber(duration)or 0);if startPrice<1000 or startPrice>EconomyConfig.MaximumCoins or not VALID_DURATIONS[duration]then return false,"Use a price of at least 1,000 and a valid auction duration.",nil end
	local profile=self.Profiles:GetProfile(player);local card=profile and findCard(profile,cardId);if not profile or not card then return false,"Player card is not owned.",nil end;local meta=profile.PlayerCardMeta[card.Id]or{};if meta.Locked or meta.Loan then return false,"Locked and loan cards cannot enter the market.",nil end;if card.location=="transfer_list"then return false,"Card is already transfer listed.",nil end
	local moved,message=self.Squad:MovePlayer(player,card.Id,"TransferList",nil);if not moved then return false,message,nil end
	local id="listing_"..HttpService:GenerateGUID(false);local listing={ListingId=id,SellerUserId=player.UserId,SellerName=player.Name,CardInstanceId=card.Id,PlayerId=card.playerId or card.PlayerId,Name=card.Name,Rating=card.Rating,Position=card.Position,Rarity=card.Rarity,CardType=card.CardType,StartPrice=startPrice,CurrentBid=0,CurrentBidderUserId=0,CurrentBidderName="",CreatedAt=os.time(),EndsAt=os.time()+duration,Status="Active"};self:_write(id,listing);return true,"Player listed on the global market.",listing
end
function Service:GetListings(_player:Player):any
	local result={};local seen={};local ok,pages=pcall(function()return self.Index:GetSortedAsync(true,60,os.time()-86400,os.time()+86400)end)
	if ok and pages then for _,entry in pages:GetCurrentPage()do local loadedOk,listing=pcall(function()return self.Listings:GetAsync(entry.key)end);if loadedOk and listing and listing.Status=="Active"and listing.EndsAt>os.time()then seen[listing.ListingId]=true;table.insert(result,listing)end end end
	for id,listing in self.Local do if not seen[id]and listing.Status=="Active"and listing.EndsAt>os.time()then table.insert(result,listing)end end
	table.sort(result,function(a,b)if a.EndsAt~=b.EndsAt then return a.EndsAt<b.EndsAt end;return(a.CurrentBid>0 and a.CurrentBid or a.StartPrice)<(b.CurrentBid>0 and b.CurrentBid or b.StartPrice)end);return result
end
function Service:PlaceBid(player:Player,listingId:string,amount:number):(boolean,string,any?)
	amount=math.floor(tonumber(amount)or 0);if amount<1000 then return false,"Invalid bid.",nil end;local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local listing=self.Local[listingId];if not listing then local ok,value=pcall(function()return self.Listings:GetAsync(listingId)end);if ok then listing=value end end;if not listing or listing.Status~="Active"or listing.EndsAt<=os.time()then return false,"Auction is no longer active.",nil end;if listing.SellerUserId==player.UserId then return false,"You cannot bid on your own player.",nil end
	local minimum=listing.CurrentBid>0 and listing.CurrentBid+250 or listing.StartPrice;if amount<minimum then return false,"Minimum bid is "..minimum.." coins.",nil end;if not DeveloperConfig.InfiniteCoinsEveryone and profile.Currency.Coins<amount then return false,"Insufficient coins.",nil end
	local previousUser=listing.CurrentBidderUserId;local previousAmount=listing.CurrentBid;local accepted=false
	local updateOk,updated=pcall(function()return self.Listings:UpdateAsync(listingId,function(current:any)if type(current)~="table"or current.Status~="Active"or current.EndsAt<=os.time()then return current end;local currentMinimum=current.CurrentBid>0 and current.CurrentBid+250 or current.StartPrice;if amount<currentMinimum then return current end;previousUser=current.CurrentBidderUserId;previousAmount=current.CurrentBid;current.CurrentBid=amount;current.CurrentBidderUserId=player.UserId;current.CurrentBidderName=player.Name;if current.EndsAt-os.time()<10 then current.EndsAt=os.time()+10 end;accepted=true;return current end)end)
	if updateOk then if not accepted or not updated or updated.CurrentBidderUserId~=player.UserId or updated.CurrentBid~=amount then return false,"Another bid arrived first. Refresh the auction.",nil end;listing=updated else listing.CurrentBid=amount;listing.CurrentBidderUserId=player.UserId;listing.CurrentBidderName=player.Name;if listing.EndsAt-os.time()<10 then listing.EndsAt=os.time()+10 end;self.Local[listingId]=listing;accepted=true end
	if not DeveloperConfig.InfiniteCoinsEveryone then profile.Currency.Coins-=amount end;if hasBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)then pcall(function()self.Index:SetAsync(listingId,listing.EndsAt)end)else self.Local[listingId]=listing end
	if previousUser and previousUser>0 and previousAmount>0 and not DeveloperConfig.InfiniteCoinsEveryone then local previous=Players:GetPlayerByUserId(previousUser);local previousProfile=previous and self.Profiles:GetProfile(previous);if previousProfile then previousProfile.Currency.Coins=math.min(EconomyConfig.MaximumCoins,previousProfile.Currency.Coins+previousAmount)else self:_queueMail(previousUser,{Type="Coins",Amount=previousAmount})end end
	return true,"Bid placed. Auction synchronized globally.",listing
end
return Service
