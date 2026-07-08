--!strict
local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local PageBase=require(script.Parent.PageBase)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local WidePlayerCard=require(script.Parent.Parent.Components.WidePlayerCard)
local EmptyState=require(script.Parent.Parent.Components.EmptyState)
local InventoryService=require(script.Parent.Parent.Services.InventoryService)
local PackService=require(script.Parent.Parent.Services.PackService)
local SquadService=require(script.Parent.Parent.Services.SquadService)
local VirtualizedList=require(script.Parent.Parent.Components.VirtualizedList)
local Modal=require(script.Parent.Parent.Components.Modal)
local InventoryPreview=require(script.Parent.Parent.Components.InventoryPreview)

local Page={}
local TABS={"Packs","Players","Club Items"}
local POSITIONS={"ALL","GK","LB","CB","RB","CDM","CM","CAM","LW","ST","RW"}
local RARITIES={"ALL","STARTER","COMMON","BRONZE","SILVER","GOLD","RARE","ELITE","LEGENDARY","ICON","MYTHIC"}

local function corner(parent:Instance,radius:number)local item=Instance.new("UICorner");item.CornerRadius=UDim.new(0,radius);item.Parent=parent end
local function label(parent:Instance,value:string,position:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel local item=Instance.new("TextLabel");item.BackgroundTransparency=1;item.Position=position;item.Size=size;item.Text=value;item.TextColor3=color;item.TextSize=textSize;item.Font=font;item.TextXAlignment=Enum.TextXAlignment.Left;item.Parent=parent;return item end

function Page.new(context:any):CanvasGroup
	local group,scroll=PageBase.new("Inventory",820);PageBase.heading(scroll,"YOUR COLLECTION","INVENTORY","Every owned pack, player and club item in one place.")
	group:SetAttribute("VTRPageCleanup",true)
	local cleanupEvent=Instance.new("BindableEvent");cleanupEvent.Name="Cleanup";cleanupEvent.Parent=group
	local function mergedInventoryData(): any
		local response=InventoryService:Get()
		local nextData=response.Success and response.Data or {Summary={},Packs={},Players={},Cosmetics={},Kits={},Stadiums={},Consumables={},History={}}
		local packResponse=PackService:GetInventory()
		local packData=packResponse.Success and packResponse.Data or nil
		if type(packData)=="table"then
			if type(packData.Packs)=="table"and(#(nextData.Packs or{})==0 or #packData.Packs>#(nextData.Packs or{}))then
				nextData.Packs=packData.Packs
			end
			if type(packData.History)=="table"and(#(nextData.History or{})==0 or #packData.History>#(nextData.History or{}))then
				nextData.History=packData.History
			end
		end
		nextData.Summary=nextData.Summary or{}
		nextData.Packs=nextData.Packs or{}
		nextData.Summary.UnopenedPacks=#nextData.Packs
		return nextData
	end
	local data=mergedInventoryData()
	local activeTab=(context.Data.UIState.SelectedTabs and context.Data.UIState.SelectedTabs.Inventory) or "Packs";if not table.find(TABS,activeTab)then activeTab="Packs"end;local search="";local positionIndex=1;local rarityIndex=1;local highFirst=true
	local tabs=Instance.new("Frame");tabs.BackgroundTransparency=1;tabs.Position=UDim2.fromOffset(0,92);tabs.Size=UDim2.new(1,0,0,38);tabs.Parent=scroll;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,6);tabLayout.Parent=tabs
	local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(0,146);body.Size=UDim2.new(1,0,0,640);body.Parent=scroll
	local tabButtons={};local render:()->();local leavingLockedUntil=0;local tabSwitchLocked=false;local packActionDebounce=false
	local pageTransientOverlayNames={ModalOverlay=true,InventoryItemPreview=true,PackResults=true}
	local rootTransientOverlayNames={ModalOverlay=true,InventoryItemPreview=true,PackResults=true}
	local function clearTransientOverlays(includeRoot:boolean?)
		for name in pageTransientOverlayNames do
			local existing=group:FindFirstChild(name)
			if existing then existing:Destroy()end
		end
		for _,descendant in group:GetDescendants()do
			if pageTransientOverlayNames[descendant.Name]then descendant:Destroy()end
		end
		if includeRoot and typeof(context.Root)=="Instance"then
			for name in rootTransientOverlayNames do
				local existing=context.Root:FindFirstChild(name)
				if existing then existing:Destroy()end
			end
		end
	end
	local function cleanup()
		leavingLockedUntil=os.clock()+1.25
		scroll.Visible=false
		scroll.Active=false
		for _,child in body:GetChildren()do child:Destroy()end
		clearTransientOverlays(false)
	end
	cleanupEvent.Event:Connect(cleanup)
	local function isCurrent():boolean
		return not context.IsCurrentPage or context.IsCurrentPage("Inventory")
	end
	local function toast(message:string,kind:string?)context.Toast({Title="INVENTORY",Message=message,Kind=kind or "Info"})end
	local function refresh()data=mergedInventoryData()end
	local function field(pack:any,lower:string,upper:string,default:any):any local value=pack and pack[lower];if value==nil and pack then value=pack[upper]end;if value==nil then return default end;return value end
	local function packName(pack:any):string return tostring(field(pack,"name","Name","VTR PLAYER PACK"))end
	local function packId(pack:any):string return tostring(field(pack,"packId","PackId",""))end
	local function packInstanceId(pack:any):string return tostring(field(pack,"packInstanceId","PackInstanceId",""))end
	local function packDescription(pack:any):string return tostring(field(pack,"description","Description","VTR player pack"))end
	local function packCardCount(pack:any):number return math.max(1,math.floor(tonumber(field(pack,"cardCount","CardCount",1))or 1))end
	local function packBestRarity(pack:any):string return tostring(field(pack,"bestPossibleRarity","BestPossibleRarity","Rare"))end
	local function packOdds(pack:any):any return (pack and (pack.odds or pack.Odds)) or{}end
	local function packGuaranteed(pack:any):any return pack and (pack.guaranteedMinRarity or pack.GuaranteedMinRarity) or nil end
	local function oddsText(pack:any):string local parts={};local odds=packOdds(pack);for _,rarity in RARITIES do if rarity~="ALL" then local key=string.sub(rarity,1,1)..string.lower(string.sub(rarity,2));local value=odds[key]or odds[rarity];if value and value>0 then table.insert(parts,rarity.." "..string.format("%.2g",value).."%")end end end;local guaranteed=packGuaranteed(pack);return table.concat(parts,"   ")..(guaranteed and ("   /   GUARANTEED "..string.upper(tostring(guaranteed)).."+") or "")end
	local function finishOpen(title:string,reveals:any)packActionDebounce=false;context.Flow:PackOpening(title,function()if group.Parent and isCurrent()then refresh();render()end;toast("Pack contents added to Players.","Reward")end,reveals)end
	local function openOne(pack:any)
		if packActionDebounce then return end
		packActionDebounce=true
		if context.Root and context.Root:FindFirstChild("PremiumPackOpening")then packActionDebounce=false;toast("Finish the current pack opening first.");return end
		clearTransientOverlays(true)
		context.Flow:PackPreview({Title=packName(pack),Subtitle=packCardCount(pack).." PLAYER CARDS",Detail=packDescription(pack).."\n\n"..oddsText(pack)},{Label="OPEN PACK",OnCancel=function()packActionDebounce=false end},function()local opened=PackService:Open(packInstanceId(pack));if not opened.Success then packActionDebounce=false;toast(opened.Message or "Pack opening failed.","Error");return end;finishOpen(packName(pack),opened.Data)end)
		task.defer(function()if packActionDebounce and context.Root and not context.Root:FindFirstChild("ModalOverlay")and not context.Root:FindFirstChild("PremiumPackOpening")then packActionDebounce=false end end)
	end
	local function openAll(groupData:any)
		if packActionDebounce then return end
		packActionDebounce=true
		if context.Root and context.Root:FindFirstChild("PremiumPackOpening")then packActionDebounce=false;toast("Finish the current pack opening first.");return end
		clearTransientOverlays(true)
		context.Flow:Confirmation("OPEN ALL "..string.upper(packName(groupData)),"Open all "..groupData.quantity.." sealed packs of this type? Rewards remain server controlled.","OPEN ALL",function()local opened=PackService:OpenAll(packId(groupData));if not opened.Success then packActionDebounce=false;toast(opened.Message or "Open All failed.","Error");return end;finishOpen(packName(groupData).."  x"..opened.OpenedCount,opened.Data)end,function()packActionDebounce=false end)
		task.defer(function()if packActionDebounce and context.Root and not context.Root:FindFirstChild("ModalOverlay")and not context.Root:FindFirstChild("PremiumPackOpening")then packActionDebounce=false end end)
	end
	local function scrolling(parent:Instance,top:number?):ScrollingFrame local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(0,top or 0);list.Size=UDim2.new(1,0,1,-(top or 0));list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=3;list.ScrollBarImageColor3=Theme.Colors.Electric;list.Parent=parent;return list end
	local function empty(parent:Instance,title:string,description:string)local state=EmptyState.new(title,description,"◇");state.Position=UDim2.fromOffset(0,120);state.Size=UDim2.new(1,0,0,150);state.Parent=parent end
	local function renderPacks()
		local header=Panel.new({Name="PackSummary",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,66)});header.Parent=body;label(header,(data.Summary.UnopenedPacks or 0).." UNOPENED PACKS",UDim2.fromOffset(18,10),UDim2.new(.6,0,0,24),15,Theme.Colors.White,Theme.Fonts.Display);label(header,"WIN CAMPAIGN AND RANKED MATCHES TO EARN PACKS",UDim2.fromOffset(18,36),UDim2.new(.6,0,0,16),8,Theme.Colors.Electric,Theme.Fonts.Strong)
		local list=scrolling(body,78);local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(.5,-7,0,218);grid.CellPadding=UDim2.fromOffset(12,12);grid.Parent=list
		local groups={};local order={};for _,pack in data.Packs do local id=packId(pack);local current=groups[id];if not current then current=table.clone(pack);current.packId=id;current.quantity=0;current.instances={};groups[id]=current;table.insert(order,current)end;current.quantity+=1;table.insert(current.instances,pack)end
		if #order==0 then empty(list,"NO UNOPENED PACKS","Visit the Store or complete objectives to earn packs.");return end
		for _,pack in order do local card=Panel.new({Name=packId(pack)});card.Parent=list;local stripe=Instance.new("Frame");stripe.BackgroundColor3=Theme.Colors.Electric;stripe.BorderSizePixel=0;stripe.Size=UDim2.fromOffset(5,218);stripe.Parent=card;label(card,packName(pack),UDim2.fromOffset(20,14),UDim2.new(1,-40,0,28),17,Theme.Colors.White,Theme.Fonts.Display);label(card,"SEALED PLAYER PACK  /  QTY "..pack.quantity,UDim2.fromOffset(20,46),UDim2.new(1,-40,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong);label(card,"BEST POSSIBLE  "..string.upper(packBestRarity(pack)),UDim2.fromOffset(20,70),UDim2.new(1,-40,0,18),9,Theme.Colors.Silver,Theme.Fonts.Strong);label(card,packDescription(pack),UDim2.fromOffset(20,95),UDim2.new(1,-40,0,35),8,Theme.Colors.Muted,Theme.Fonts.Body).TextWrapped=true;local open=Button.new({Text="OPEN",Variant="Primary",Size=UDim2.fromOffset(105,36),OnActivated=function()openOne(pack.instances[1])end});open.Position=UDim2.fromOffset(20,158);open.Parent=card;local odds=Button.new({Text="VIEW ODDS",Variant="Secondary",Size=UDim2.fromOffset(112,36),OnActivated=function()context.Flow:PackPreview({Title=packName(pack),Subtitle=packCardCount(pack).." PLAYER CARDS",Detail=oddsText(pack)},{Label="VIEW CONTENTS"},function()end)end});odds.Position=UDim2.fromOffset(132,158);odds.Parent=card;if pack.quantity>1 then local all=Button.new({Text="OPEN ALL",Variant="Secondary",Size=UDim2.fromOffset(112,36),OnActivated=function()openAll(pack)end});all.Position=UDim2.new(1,-132,0,158);all.Parent=card end end
	end
	local function renderPlayers()
		local controls=Instance.new("Frame");controls.BackgroundTransparency=1;controls.Size=UDim2.new(1,0,0,40);controls.Parent=body
		local input=Instance.new("TextBox");input.BackgroundColor3=Theme.Colors.Gunmetal;input.BorderSizePixel=0;input.Size=UDim2.new(.4,-6,0,36);input.PlaceholderText="SEARCH OWNED PLAYERS";input.Text=search;input.TextColor3=Theme.Colors.White;input.PlaceholderColor3=Theme.Colors.Muted;input.Font=Theme.Fonts.Strong;input.TextSize=9;input.ClearTextOnFocus=false;input.Parent=controls;corner(input,6);input.FocusLost:Connect(function()search=input.Text;render()end)
		local pos=Button.new({Text="POS: "..POSITIONS[positionIndex],Variant="Secondary",Size=UDim2.new(.18,-5,0,36),OnActivated=function()positionIndex=positionIndex%#POSITIONS+1;render()end});pos.Position=UDim2.new(.4,5,0,0);pos.Parent=controls;local rarity=Button.new({Text="RARITY: "..RARITIES[rarityIndex],Variant="Secondary",Size=UDim2.new(.24,-5,0,36),OnActivated=function()rarityIndex=rarityIndex%#RARITIES+1;render()end});rarity.Position=UDim2.new(.58,10,0,0);rarity.Parent=controls;local sort=Button.new({Text=highFirst and "OVR HIGH" or "OVR LOW",Variant="Secondary",Size=UDim2.new(.18,-5,0,36),OnActivated=function()highFirst=not highFirst;render()end});sort.Position=UDim2.new(.82,15,0,0);sort.Parent=controls
		local players={};for _,card in data.Players do local positionMatch=POSITIONS[positionIndex]=="ALL" or card.Position==POSITIONS[positionIndex];local rarityMatch=RARITIES[rarityIndex]=="ALL" or string.upper(card.Rarity)==RARITIES[rarityIndex];local searchMatch=search=="" or string.find(string.lower(card.Name),string.lower(search),1,true);if positionMatch and rarityMatch and searchMatch then table.insert(players,card)end end;table.sort(players,function(a,b)if highFirst then return a.Rating>b.Rating else return a.Rating<b.Rating end end);if #players==0 then empty(body,"NO PLAYERS FOUND","Adjust search or filters to view owned player cards.");return end
		VirtualizedList.new(body,{Position=UDim2.fromOffset(0,50),Size=UDim2.new(1,0,1,-50),Items=players,RowHeight=133,Gap=9,Buffer=10,RenderItem=function(parent:Instance,card:any):GuiObject local row=Panel.new({Name=card.Id});row.Parent=parent;local wide=WidePlayerCard.new({Parent=row,Card=card,Size=UDim2.new(1,-450,0,108),Meta=card.Meta,OnActivated=function()context.OpenPlayerDetails(card.Id)end});wide.Position=UDim2.fromOffset(8,8);local details=Button.new({Text="VIEW DETAILS",Variant="Secondary",Size=UDim2.fromOffset(132,34),OnActivated=function()context.OpenPlayerDetails(card.Id)end});details.Position=UDim2.new(1,-426,0,16);details.Parent=row;local squad=Button.new({Text="SEND TO SQUAD",Variant="Primary",Size=UDim2.fromOffset(132,34),OnActivated=function()local moved=SquadService:MovePlayer(card.Id,"Bench",1);toast(moved.Message or(moved.Success and"Player sent to squad."or"Squad move failed."),moved.Success and"Info"or"Error");refresh();render()end});squad.Position=UDim2.new(1,-286,0,55);squad.Parent=row;local sell=Button.new({Text="QUICK SELL",Variant="Secondary",Size=UDim2.fromOffset(132,34),OnActivated=function()context.Flow:Confirmation("QUICK SELL "..string.upper(tostring(card.Name or"PLAYER")),"This permanently removes the card and adds coins immediately.","QUICK SELL",function()local sold=SquadService:QuickSellCard(card.Id);toast(sold.Message or(sold.Success and"Player quick sold."or"Quick sell failed."),sold.Success and"Reward"or"Error");refresh();render()end)end});sell.Position=UDim2.new(1,-146,0,55);sell.Parent=row;return row end})
	end
	local function renderItems(items:any,titleValue:string,description:string)
		local list=scrolling(body,0);local layout=Instance.new("UIGridLayout");layout.CellSize=UDim2.new(.333,-9,0,150);layout.CellPadding=UDim2.fromOffset(12,12);layout.Parent=list;if #items==0 then empty(list,"NO OWNED "..string.upper(titleValue),description);return end;for _,item in items do local card=Panel.new({Name=item.Id or titleValue});card.Parent=list;label(card,string.upper(item.Name or item.Id),UDim2.fromOffset(16,14),UDim2.new(1,-32,0,30),15,Theme.Colors.White,Theme.Fonts.Display);label(card,string.upper(item.Type or titleValue),UDim2.fromOffset(16,44),UDim2.new(1,-32,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong);label(card,"OWNED  /  QTY "..(item.Quantity or 1),UDim2.fromOffset(16,66),UDim2.new(1,-32,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong);if titleValue=="Kits"or titleValue=="Stadiums"then local preview=Button.new({Text="PREVIEW",Variant="Secondary",Size=UDim2.new(1,-32,0,34),OnActivated=function()InventoryPreview.open(group,item,titleValue)end});preview.Position=UDim2.fromOffset(16,102);preview.Parent=card end end
	end
	local function renderTransferMarket()
		local response=SquadService:GetTransferListings();local listings=response.Success and response.Data or{};local list=scrolling(body,0);local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,9);layout.Parent=list
		if#listings==0 then empty(list,"NO ACTIVE AUCTIONS","Player listings from all live servers will appear here.");return end
		for _,listing in listings do local row=Panel.new({Name=listing.ListingId,Size=UDim2.new(1,-6,0,94)});row.Parent=list;label(row,listing.Rating.."  "..listing.Position.."  "..string.upper(listing.Name),UDim2.fromOffset(18,10),UDim2.new(1,-250,0,24),14,Theme.Colors.White,Theme.Fonts.Display);local price=listing.CurrentBid>0 and listing.CurrentBid or listing.StartPrice;label(row,string.upper(listing.Rarity).."  /  SELLER "..string.upper(listing.SellerName),UDim2.fromOffset(18,38),UDim2.new(1,-250,0,17),8,Theme.Colors.Muted,Theme.Fonts.Strong);label(row,"CURRENT BID  "..price.."  /  ENDS IN "..math.max(0,listing.EndsAt-os.time()).."s",UDim2.fromOffset(18,60),UDim2.new(1,-250,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong);local bid=Button.new({Text="PLACE BID",Variant="Primary",Size=UDim2.fromOffset(170,38),OnActivated=function()Modal.open(group,{Kicker="GLOBAL TRANSFER MARKET",Title="BID ON "..string.upper(listing.Name),Description="Enter at least "..(listing.CurrentBid>0 and listing.CurrentBid+250 or listing.StartPrice).." coins. Late bids extend the auction by ten seconds.",Fields={{Key="Amount",Placeholder="BID AMOUNT",Default=tostring(listing.CurrentBid>0 and listing.CurrentBid+250 or listing.StartPrice)}},ConfirmLabel="PLACE BID",OnConfirm=function(values:any)local result=SquadService:PlaceTransferBid(listing.ListingId,tonumber(values.Amount)or 0);toast(result.Message or"Bid processed.",result.Success and"Reward"or"Error");render()end})end});bid.Position=UDim2.new(1,-190,.5,-19);bid.Parent=row end
	end
	local function renderHistory()local list=scrolling(body,0);local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,9);layout.Parent=list;if #data.History==0 then empty(list,"NO INVENTORY HISTORY","Opened packs and best pulls will appear here.");return end;for _,entry in data.History do local best=entry.bestPull;local row=Panel.new({Name=entry.packInstanceId,Size=UDim2.new(1,-6,0,86)});row.Parent=list;label(row,entry.name,UDim2.fromOffset(18,10),UDim2.new(1,-220,0,24),14,Theme.Colors.White,Theme.Fonts.Display);label(row,"OPENED  "..os.date("!%Y-%m-%d  %H:%M",entry.openedAt or 0),UDim2.fromOffset(18,38),UDim2.new(1,-220,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong);label(row,best and (best.rating.." "..best.position.."  "..best.name.."  /  "..string.upper(best.rarity)) or "BEST PULL UNAVAILABLE",UDim2.fromOffset(330,20),UDim2.new(1,-540,0,34),10,Theme.Colors.Electric,Theme.Fonts.Strong);if best then local view=Button.new({Text="VIEW PLAYER",Variant="Secondary",Size=UDim2.fromOffset(150,38),OnActivated=function()context.OpenPlayerDetails(best.cardInstanceId)end});view.Position=UDim2.new(1,-170,.5,-19);view.Parent=row end end end
	render=function()if os.clock()<leavingLockedUntil or not isCurrent() then scroll.Visible=false;scroll.Active=false;for _,child in body:GetChildren()do child:Destroy()end;return end;scroll.Visible=true;scroll.Active=true;for _,child in body:GetChildren()do child:Destroy()end;for name,button in tabButtons do Button.setPrimary(button,name==activeTab)end;if activeTab=="Packs"then renderPacks()elseif activeTab=="Players"then renderPlayers()else local items={};for _,list in {data.Cosmetics or{},data.Kits or{},data.Stadiums or{}}do for _,item in list do table.insert(items,item)end end;renderItems(items,"Club Items","Kits, badges and stadium cosmetics appear here.")end end
	for _,name in TABS do local tab=Button.new({Text=string.upper(name),Variant=name==activeTab and "Primary"or"Secondary",Size=UDim2.fromOffset(name=="Transfer Market"and 145 or 105,36),OnActivated=function()if activeTab==name or tabSwitchLocked then return end;tabSwitchLocked=true;clearTransientOverlays(true);activeTab=name;context.Data.UIState.SelectedTabs=context.Data.UIState.SelectedTabs or{};context.Data.UIState.SelectedTabs.Inventory=name;context.StateService:SetTab("Inventory",name);render();task.delay(.18,function()tabSwitchLocked=false end)end});tab.Parent=tabs;tabButtons[name]=tab end;render();group:GetPropertyChangedSignal("Visible"):Connect(function()if group.Visible and isCurrent() then leavingLockedUntil=0;refresh();render()else cleanup()end end);return group
end
local function vtrFindRouletteGuiObjects(root)
	local scroller
	local container

	if typeof(root) ~= "Instance" then
		return nil, nil
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ScrollingFrame") then
			local n = string.lower(obj.Name)
			if string.find(n, "roulette") or string.find(n, "spin") or string.find(n, "reward") or string.find(n, "pack") then
				scroller = obj
				break
			end
			scroller = scroller or obj
		end
	end

	if scroller then
		for _, obj in ipairs(scroller:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local hasPack = obj:GetAttribute("PackId") or obj:GetAttribute("PackName")
				local n = string.lower(obj.Name)
				if hasPack or string.find(n, "pack") or string.find(n, "card") or string.find(n, "item") then
					container = obj.Parent
					break
				end
			end
		end
	end

	return scroller, container
end

local function vtrForceRouletteWinningCenter(root, winningPack, winningIndex)
	if not winningPack then
		return
	end

	task.defer(function()
		local scroller, container = vtrFindRouletteGuiObjects(root)
		if scroller and container then
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
			task.wait(0.05)
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
		end
	end)
end

return Page
