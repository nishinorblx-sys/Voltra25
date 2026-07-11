local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local function vtrClientRoot()
	local current = script

	while current do
		if current.Name == "VTRClient" or current.Name == "Client" then
			return current
		end

		current = current.Parent
	end

	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChild("PlayerScripts")
	local found = playerScripts and (playerScripts:FindFirstChild("VTRClient") or playerScripts:FindFirstChild("Client"))

	return found or script.Parent
end
--!strict
local PackRouletteAlignmentService = require(vtrClientRoot():WaitForChild("Services"):WaitForChild("PackRouletteAlignmentService"))
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local Modal=require(script.Parent.Parent.Components.Modal)
local LoadingScreen=require(script.Parent.Parent.Components.LoadingScreen)
local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local UISoundService=require(script.Parent.Parent.Services.UISoundService)
local WidePlayerCard=require(script.Parent.Parent.Components.WidePlayerCard)
local CardSurface=require(script.Parent.Parent.Components.CardSurface)
local PlayerDetailsModal=require(script.Parent.Parent.Components.PlayerDetailsModal)
local PackOpeningSequence=require(script.Parent.Parent.Components.PackOpeningSequence)
local PackService=require(script.Parent.Parent.Services.PackService)
local FlowController={};FlowController.__index=FlowController

local function cosmeticName(id:string):string
	for _,cosmetic in Catalog.Cosmetics do
		if cosmetic.Id==id then return tostring(cosmetic.Name or id)end
	end
	return string.upper((id:gsub("_"," ")))
end

function FlowController.new(root:Frame,toast:(any)->())
	local self=setmetatable({Root=root,Toast=toast,Busy=false,ProductPurchaseLocks={}},FlowController)
	task.spawn(function()
		local vtr=ReplicatedStorage:WaitForChild("VTR",10)
		local remotes=vtr and vtr:WaitForChild("Remotes",10)
		local remote=remotes and remotes:WaitForChild("CelebrationPackReveal",10)
		if remote and remote:IsA("RemoteEvent")then
			remote.OnClientEvent:Connect(function(payload)self:CelebrationPackReveal(payload)end)
		end
	end)
	return self
end
function FlowController:SetPlayerDetailsHandler(handler:(string)->()) self.PlayerDetailsHandler=handler end
function FlowController:SetNavigator(handler:(string)->()) self.Navigator=handler end
function FlowController:SetInventoryNavigator(handler:()->()) self.InventoryNavigator=handler end
local packOverlayNames={PackResults=true,PremiumPackOpening=true}
local function clearPackOverlays(root:Instance)
	for name in packOverlayNames do
		local existing=root:FindFirstChild(name)
		if existing then existing:Destroy()end
	end
end

function FlowController:ModeTransition(title:string,callback:()->(),compact:boolean?)
	if self.Busy then return end;self.Busy=true;UISoundService.PlayTransition();UISoundService.PlayTransition()
	local reduced=workspace:GetAttribute("VTRReducedMotion")==true
	local overlay=Instance.new("CanvasGroup");overlay.Name="ModeTransition";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=80;overlay.Active=true;overlay.Selectable=false;overlay.Parent=self.Root
	local shield=Instance.new("TextButton");shield.Name="ModeTransitionShield";shield.BackgroundTransparency=1;shield.BorderSizePixel=0;shield.Size=UDim2.fromScale(1,1);shield.Text="";shield.AutoButtonColor=false;shield.Selectable=false;shield.Modal=true;shield.Active=true;shield.ZIndex=80;shield.Parent=overlay
	local slash=Instance.new("Frame");slash.AnchorPoint=Vector2.new(.5,.5);slash.BackgroundColor3=Theme.Colors.Electric;slash.BorderSizePixel=0;slash.Position=UDim2.fromScale(-.25,.5);slash.Rotation=-16;slash.Size=UDim2.fromScale(.55,1.7);slash.ZIndex=81;slash.Parent=overlay
	local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(.5,.5);label.BackgroundTransparency=1;label.Position=UDim2.fromScale(.5,.5);label.Size=UDim2.fromOffset(700,80);label.Text=string.upper(title);label.TextColor3=Theme.Colors.White;label.TextSize=compact and 22 or 34;label.Font=Theme.Fonts.Display;label.ZIndex=82;label.Parent=overlay
	TweenService:Create(overlay,TweenInfo.new(reduced and .06 or .16),{GroupTransparency=0}):Play();TweenService:Create(slash,TweenInfo.new(reduced and .14 or .36,Theme.Animation.EasingStyle,Theme.Animation.EasingDirection),{Position=UDim2.fromScale(1.22,.5)}):Play()
	task.delay(reduced and .07 or .18,callback);task.delay(reduced and .15 or(compact and .3 or .42),function() TweenService:Create(overlay,TweenInfo.new(reduced and .06 or .16),{GroupTransparency=1}):Play();task.delay(reduced and .07 or .17,function() overlay:Destroy();self.Busy=false end) end)
end

function FlowController:_safe(action:any,perform:()->any,refresh:()->()):any
	local ok,result=pcall(perform)
	if not ok then self:Error("ACTION FAILED","The mock service rejected this action. Please try again.");return end
	if type(result)=="table"and result.Success==false then
		self.Toast({Title=action.Item or"VTR 25",Message=result.Message or result.Error or"Action blocked by server.",Kind="Error"})
		return result
	end
	local message=type(result)=="table" and (result.Message or "Action completed.") or tostring(result)
	self.Toast({Title=action.Item or "VTR 25",Message=message,Kind=(action.Operation=="Purchase" or action.Operation=="Claim") and "Reward" or "Info"});refresh();return result
end

function FlowController:Confirmation(title:string,description:string,label:string,callback:()->(),onCancel:(()->())?) Modal.open(self.Root,{Kicker="CONFIRMATION",Title=title,Description=description,ConfirmLabel=label,OnConfirm=callback,OnCancel=onCancel}) end
function FlowController:ItemDetail(card:any,action:any,callback:(()->())?) Modal.open(self.Root,{Kicker="ITEM DETAIL",Title=card.Title,Meta=card.Subtitle.."  •  "..card.Meta,Description=card.Detail or action.Message or "Premium VTR 25 item. Live item data connects here later.",ConfirmLabel=callback and action.Label or "CLOSE",OnConfirm=callback}) end
function FlowController:PlayerCardDetail(card:any,action:any,callback:()->()) if self.PlayerDetailsHandler and (card.cardInstanceId or card.Id) then self.PlayerDetailsHandler(card.cardInstanceId or card.Id);return end;Modal.open(self.Root,{Kicker="PLAYER CARD DETAIL",Title=card.Title,Meta=card.Subtitle.."  •  "..card.Meta,Description=card.Detail or "Player attributes, chemistry links and club status.",ConfirmLabel=action.Label,OnConfirm=callback}) end
function FlowController:PackPreview(card:any,action:any,callback:()->())
	if self.PackOpeningActive==true or self.Root:FindFirstChild("PremiumPackOpening")then
		self.Toast({Title="PACK CONTENTS",Message="Finish the current pack opening first.",Kind="Info"})
		return
	end
	clearPackOverlays(self.Root)
	Modal.open(self.Root,{Kicker="PACK PREVIEW",Title=card.Title,Meta=card.Subtitle,Description=card.Detail or "Cards are generated from the 5,000-player VTR database using this pack tier's server-owned rarity weights.",ConfirmLabel=action.Label=="OPEN PACK" and "OPEN PACK" or "VIEW CONTENTS",OnConfirm=function()
		if action.Label=="OPEN PACK" then
			self.LastPackOpenClickedAt=os.clock()
		end
		callback()
	end,OnCancel=action.OnCancel})
end

function FlowController:_packResults(title:string,reveals:any,complete:()->())
	local existing=self.Root:FindFirstChild("PackResults")
	if existing then existing:Destroy() end
	local overlay=Instance.new("CanvasGroup");overlay.Name="PackResults";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.08;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=105;overlay.Active=true;overlay.Selectable=false;overlay.Parent=self.Root
	local shield=Instance.new("TextButton");shield.Name="PackResultsShield";shield.BackgroundTransparency=1;shield.BorderSizePixel=0;shield.Size=UDim2.fromScale(1,1);shield.Text="";shield.AutoButtonColor=false;shield.Selectable=false;shield.Modal=true;shield.Active=true;shield.ZIndex=105;shield.Parent=overlay
	local panel=Panel.new({Name="PackResultsPanel",Size=UDim2.fromOffset(880,500)});panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.ZIndex=106;panel.Parent=overlay
	local titleLabel=Instance.new("TextLabel");titleLabel.BackgroundTransparency=1;titleLabel.Position=UDim2.fromOffset(24,18);titleLabel.Size=UDim2.new(1,-48,0,42);titleLabel.Text=string.upper(title).."  /  PLAYER REVEAL";titleLabel.TextColor3=Theme.Colors.White;titleLabel.TextSize=22;titleLabel.Font=Theme.Fonts.Display;titleLabel.TextXAlignment=Enum.TextXAlignment.Left;titleLabel.ZIndex=107;titleLabel.Parent=panel
	local hint=titleLabel:Clone();hint.Position=UDim2.fromOffset(24,58);hint.Size=UDim2.new(1,-48,0,22);hint.Text="SELECT ANY CARD TO OPEN THE FULL PLAYER DATABASE PROFILE";hint.TextColor3=Theme.Colors.Electric;hint.TextSize=8;hint.Font=Theme.Fonts.Strong;hint.Parent=panel
	local grid=Instance.new("ScrollingFrame");grid.BackgroundTransparency=1;grid.BorderSizePixel=0;grid.Position=UDim2.fromOffset(24,92);grid.Size=UDim2.new(1,-48,1,-162);grid.AutomaticCanvasSize=Enum.AutomaticSize.Y;grid.CanvasSize=UDim2.new();grid.ScrollBarThickness=3;grid.ScrollBarImageColor3=Theme.Colors.White;grid.ZIndex=107;grid.Parent=panel
	local layout=Instance.new("UIGridLayout");layout.CellSize=UDim2.new(.5,-6,0,112);layout.CellPadding=UDim2.fromOffset(10,10);layout.Parent=grid
	for index,card in reveals do local reveal=WidePlayerCard.new({Parent=grid,Card=card,Size=UDim2.new(1,0,1,0),OnActivated=function() if self.PlayerDetailsHandler then self.PlayerDetailsHandler(card.cardInstanceId or card.Id) end end});reveal.LayoutOrder=index;reveal.ZIndex=108 end
	local continue=Button.new({Text="CONTINUE",Variant="Primary",Size=UDim2.fromOffset(160,40),OnActivated=function() overlay:Destroy();complete() end});continue.Position=UDim2.new(1,-184,1,-54);continue.ZIndex=108;continue.Parent=panel
end

function FlowController:PackOpening(title:string,complete:()->(),reveals:any?)
	if not reveals or #reveals==0 then self:Error("PACK OPENING FAILED","The server returned no player cards.");return end
	if self.PackOpeningActive==true then return end
	self.PackOpeningActive=true
	clearPackOverlays(self.Root)
	local released=false
	local function release()
		if released then return end
		released=true
		self.PackOpeningActive=false
	end
	local packOpenClickedAt=self.LastPackOpenClickedAt
	self.LastPackOpenClickedAt=nil
	local ok,overlay=pcall(function()return PackOpeningSequence.play(self.Root,{Title=title,Reveals=reveals,PackOpenClickedAt=packOpenClickedAt,OnComplete=function()release();complete()end,OnViewPlayer=function(cardInstanceId:string) if self.PlayerDetailsHandler then self.PlayerDetailsHandler(cardInstanceId) end end,Toast=function(message:string,kind:string) self.Toast({Title="PACK CONTENTS",Message=message,Kind=kind}) end})end)
	if not ok or not overlay then
		release()
		self:Error("PACK OPENING FAILED","The pack was opened, but the reveal screen could not start. Re-open Inventory to see the new players.")
		return
	end
	overlay.Destroying:Once(release)
end
function FlowController:OfferPackDelivery(delivered:any,onComplete:(()->())?,beforeOpen:(()->())?)
	local quantity=tonumber(delivered.quantity)or 1
	local localPlayer=Players.LocalPlayer
	if localPlayer then localPlayer:SetAttribute("VTRHoldPackRewardFlyin",true)end
	local function releaseFlyin()
		if localPlayer then localPlayer:SetAttribute("VTRHoldPackRewardFlyin",false)end
	end
	local function dropFlyin()
		if localPlayer then
			localPlayer:SetAttribute("VTRDropPackRewardFlyinUntil",os.clock()+8)
			localPlayer:SetAttribute("VTRHoldPackRewardFlyin",false)
		end
	end
	Modal.open(self.Root,{Kicker="PACK DELIVERED",Title=delivered.name,Meta=quantity>1 and(quantity.." PACKS READY")or"PACK READY",Description=quantity>1 and("Open one now or close this panel to send the sealed packs into your Inventory.")or"Open this pack now or close this panel to send it into your Inventory.",CancelLabel="CLOSE",OnCancel=function()releaseFlyin()end,ConfirmLabel="OPEN PACK",OnConfirm=function()
		self.LastPackOpenClickedAt=os.clock()
		dropFlyin()
		local opened=PackService:Open(delivered.packInstanceId);if not opened.Success then self:Error("PACK OPENING FAILED",opened.Message or "The pack could not be opened.");return end;if beforeOpen then beforeOpen()end
		self:PackOpening(delivered.name,onComplete or function()self.Toast({Title="PACK CONTENTS",Message="Pack contents secured in your Club.",Kind="Reward"})end,opened.Data)
	end})
end

function FlowController:RewardClaim(card:any,action:any,callback:()->()) Modal.open(self.Root,{Kicker="REWARD CLAIM",Title=action.Item or card.Title,Meta="READY TO CLAIM",Description="The server validates eligibility before the reward reveal.",ConfirmLabel="CLAIM REWARD",OnConfirm=function() local loading=LoadingScreen.new(self.Root,"UNLOCKING REWARD");task.delay(.65,function() LoadingScreen.complete(loading,callback) end) end}) end
function FlowController:CreateClubForm(callback:(any)->()) Modal.open(self.Root,{Kicker="CREATE CLUB",Title="NEW CLUB IDENTITY",Meta="CLUB SETUP",Description="Choose a club name and 2–4 letter tag. The server validates and stores this identity.",Fields={{Key="Name",Placeholder="CLUB NAME",Default="VOLTAGE UNITED"},{Key="Tag",Placeholder="TAG",Default="VTR"}},ConfirmLabel="CREATE CLUB",OnConfirm=callback}) end
function FlowController:CareerSetup(callback:()->()) Modal.open(self.Root,{Kicker="CAREER SETUP",Title="NEW CAREER SAVE",Meta="LOCAL MOCK SLOT",Description="Choose the career type to continue into the full setup hub.",ConfirmLabel="CHOOSE CAREER",OnConfirm=callback}) end
function FlowController:ComingSoon(title:string,message:string,callback:(()->())?) Modal.open(self.Root,{Kicker="COMING SOON",Title=title,Meta="FRAMEWORK READY",Description=message,ConfirmLabel="UNDERSTOOD",OnConfirm=callback}) end
function FlowController:Error(title:string,message:string) Modal.open(self.Root,{Kicker="ERROR",Title=title,Meta="PLEASE TRY AGAIN",Description=message,ConfirmLabel="CLOSE"}) end

function FlowController:PromptDeveloperProduct(card:any,action:any)
	local productId=tonumber(action.ProductId)
	if not productId or productId<=0 then self:Error("PRODUCT UNAVAILABLE","This developer product is missing its Roblox product id.");return end
	local player=Players.LocalPlayer
	local grantItemId=tostring(action.GrantItemId or action.Item or "")
	if (action.ProductKind=="Kit" or action.ProductKind=="Cosmetic") and grantItemId~="" then
		local ownedAttribute=action.ProductKind=="Kit" and ("VTROwnedKit_"..grantItemId) or ("VTROwnedCosmetic_"..grantItemId)
		local itemType=action.ProductKind=="Kit" and "kit" or "item"
		if player and player:GetAttribute(ownedAttribute)==true then
			self.Toast({Title="STORE",Message="You already own this "..itemType..". Equip it from Customize.",Kind="Info"})
			return
		end
		if self.ProductPurchaseLocks[grantItemId]==true then
			self.Toast({Title="STORE",Message="This purchase is already being processed.",Kind="Info"})
			return
		end
		self.ProductPurchaseLocks[grantItemId]=true
		task.delay(8,function()
			if not player or player:GetAttribute(ownedAttribute)~=true then
				self.ProductPurchaseLocks[grantItemId]=nil
			end
		end)
	end
	if player then MarketplaceService:PromptProductPurchase(player,productId)end
	self.Toast({Title="STORE",Message="Roblox purchase prompt opened.",Kind="Info"})
end

function FlowController:PromptGamePass(card:any,action:any)
	local gamePassId=tonumber(action.GamePassId)
	if not gamePassId or gamePassId<=0 then self:Error("PASS UNAVAILABLE","This gamepass is missing its Roblox pass id.");return end
	local player=Players.LocalPlayer
	if player then MarketplaceService:PromptGamePassPurchase(player,gamePassId)end
	self.Toast({Title="STORE",Message="Roblox gamepass prompt opened.",Kind="Info"})
end

function FlowController:ShowStarCardOffer(card:any,action:any)
	local playerData=action.PlayerData or card.PlayerData
	local productId=tonumber(action.ProductId)
	if type(playerData)~="table" then self:Error("STAR CARD UNAVAILABLE","Today's Star Card could not be loaded.");return end
	if not productId or productId<=0 then self:Error("PRODUCT UNAVAILABLE","The Star Card product id is missing.");return end
	local existing=self.Root:FindFirstChild("StarCardOfferOverlay")
	if existing then existing:Destroy()end
	local overlay=Instance.new("CanvasGroup")
	overlay.Name="StarCardOfferOverlay"
	overlay.BackgroundColor3=Theme.Colors.Black
	overlay.BackgroundTransparency=.1
	overlay.BorderSizePixel=0
	overlay.Size=UDim2.fromScale(1,1)
	overlay.GroupTransparency=1
	overlay.ZIndex=180
	overlay.Active=true
	overlay.Selectable=false
	overlay.Parent=self.Root
	local shield=Instance.new("TextButton")
	shield.BackgroundTransparency=1
	shield.BorderSizePixel=0
	shield.Size=UDim2.fromScale(1,1)
	shield.Text=""
	shield.Modal=true
	shield.ZIndex=180
	shield.Parent=overlay
	local panel=Panel.new({Name="StarCardOfferPanel",Size=UDim2.fromOffset(760,430),ClipsDescendants=true})
	panel.AnchorPoint=Vector2.new(.5,.5)
	panel.Position=UDim2.fromScale(.5,.5)
	panel.ZIndex=181
	panel.Parent=overlay
	local scale=Instance.new("UIScale")
	scale.Scale=.86
	scale.Parent=panel
	local stroke=Instance.new("UIStroke")
	stroke.Color=Theme.Colors.Electric
	stroke.Thickness=2
	stroke.Transparency=.12
	stroke.Parent=panel
	local function text(value:string,pos:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font,z:number?):TextLabel
		local label=Instance.new("TextLabel")
		label.BackgroundTransparency=1
		label.Position=pos
		label.Size=size
		label.Text=value
		label.TextColor3=color
		label.TextSize=textSize
		label.Font=font
		label.TextXAlignment=Enum.TextXAlignment.Left
		label.TextWrapped=true
		label.ZIndex=z or 183
		label.Parent=panel
		return label
	end
	text("STAR CARD OFFER",UDim2.fromOffset(28,24),UDim2.new(1,-56,0,22),10,Theme.Colors.Electric,Theme.Fonts.Strong)
	text(tostring(playerData.Name or playerData.displayName or"FEATURED PLAYER"),UDim2.fromOffset(28,50),UDim2.new(1,-56,0,44),30,Theme.Colors.White,Theme.Fonts.Display)
	text(tostring(playerData.Rating or playerData.overall or"--").." OVR  /  "..tostring(playerData.Position or playerData.bestPosition or"STAR").."  /  "..string.upper(tostring(playerData.Rarity or playerData.rarity or"RARE")),UDim2.fromOffset(30,94),UDim2.new(1,-60,0,22),10,Theme.Colors.Silver,Theme.Fonts.Strong)
	text(action.Description or "Buy this featured Star Card and add him directly to your club.",UDim2.fromOffset(30,124),UDim2.fromOffset(300,72),10,Theme.Colors.Muted,Theme.Fonts.Body)
	local cardHolder=Instance.new("Frame")
	cardHolder.BackgroundTransparency=1
	cardHolder.Position=UDim2.fromOffset(340,116)
	cardHolder.Size=UDim2.fromOffset(390,112)
	cardHolder.ZIndex=184
	cardHolder.Parent=panel
	local preview=WidePlayerCard.new({Parent=cardHolder,Card=playerData,Size=UDim2.fromScale(1,1),ZIndex=185})
	preview.AutoButtonColor=true
	preview.Activated:Connect(function()PlayerDetailsModal.open(self.Root,playerData)end)
	local attained=text("ATTAINED",UDim2.fromOffset(0,238),UDim2.new(1,0,0,70),48,Theme.Colors.Electric,Theme.Fonts.Display,190)
	attained.TextXAlignment=Enum.TextXAlignment.Center
	attained.TextTransparency=1
	local flash=Instance.new("Frame")
	flash.BackgroundColor3=Theme.Colors.Electric
	flash.BackgroundTransparency=1
	flash.BorderSizePixel=0
	flash.Size=UDim2.fromScale(1,1)
	flash.ZIndex=189
	flash.Parent=panel
	local function close()
		overlay:Destroy()
	end
	local closeButton=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(132,40),OnActivated=close})
	closeButton.Position=UDim2.new(1,-160,1,-64)
	closeButton.ZIndex=190
	closeButton.Parent=panel
	local buying=false
	local purchaseConnection:RBXScriptConnection?=nil
	local function disconnect()
		if purchaseConnection then purchaseConnection:Disconnect();purchaseConnection=nil end
	end
	overlay.Destroying:Connect(disconnect)
	local function playAttained()
		disconnect()
		buying=false
		TweenService:Create(flash,TweenInfo.new(.12),{BackgroundTransparency=.18}):Play()
		task.delay(.14,function()if flash.Parent then TweenService:Create(flash,TweenInfo.new(.35),{BackgroundTransparency=1}):Play()end end)
		TweenService:Create(scale,TweenInfo.new(.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.05}):Play()
		TweenService:Create(stroke,TweenInfo.new(.2),{Thickness=5,Transparency=0}):Play()
		TweenService:Create(attained,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextTransparency=0,TextSize=58}):Play()
		task.delay(.72,function()
			if scale.Parent then TweenService:Create(scale,TweenInfo.new(.22),{Scale=1}):Play()end
			if stroke.Parent then TweenService:Create(stroke,TweenInfo.new(.4),{Thickness=2,Transparency=.12}):Play()end
		end)
		self.Toast({Title="STAR CARD",Message="Star Card attained.",Kind="Reward"})
	end
	local buyButton: TextButton? = nil
	local function buyStarCard()
		if not buyButton then return end
		if buying then return end
		buying=true
		buyButton.Text="WAITING..."
		disconnect()
		purchaseConnection=MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId:any,finishedProductId:any,purchased:any)
			local localPlayer=Players.LocalPlayer
			local finishedUserId=nil
			if typeof(userId)=="Instance" and userId:IsA("Player") then
				finishedUserId=userId.UserId
			else
				finishedUserId=tonumber(userId)
			end
			if localPlayer and finishedUserId==localPlayer.UserId and tonumber(finishedProductId)==productId then
				if purchased==true then
					buyButton.Text="ATTAINED"
					playAttained()
				else
					buying=false
					buyButton.Text="BUY STAR CARD"
					disconnect()
				end
			end
		end)
		local player=Players.LocalPlayer
		if player then MarketplaceService:PromptProductPurchase(player,productId)end
		task.delay(90,function()
			if buying and overlay.Parent then
				buying=false
				buyButton.Text="BUY STAR CARD"
				disconnect()
			end
		end)
	end
	buyButton=Button.new({Text="BUY STAR CARD",Variant="Primary",Size=UDim2.fromOffset(190,40),OnActivated=buyStarCard})
	buyButton.Position=UDim2.new(0,28,1,-64)
	buyButton.ZIndex=190
	buyButton.Parent=panel
	TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=0}):Play()
	TweenService:Create(scale,TweenInfo.new(.24,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end

function FlowController:CelebrationPackReveal(payload:any)
	if type(payload)~="table"then return end
	local pool=type(payload.Pool)=="table"and payload.Pool or{}
	local awarded=tostring(payload.Awarded or pool[1] or"")
	if awarded==""then return end
	local old=self.Root:FindFirstChild("CelebrationPackRevealOverlay")
	if old then old:Destroy()end
	local overlay=Instance.new("TextButton");overlay.Name="CelebrationPackRevealOverlay";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.12;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.AutoButtonColor=false;overlay.Text="";overlay.Modal=true;overlay.ZIndex=210;overlay.Parent=self.Root
	local panel=Panel.new({Name="CelebrationRevealPanel",Size=UDim2.fromOffset(560,330),ClipsDescendants=true});panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.ZIndex=211;panel.Parent=overlay
	local scale=Instance.new("UIScale");scale.Scale=.82;scale.Parent=panel
	local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Electric;stroke.Thickness=2;stroke.Transparency=.05;stroke.Parent=panel
	local glow=Instance.new("Frame");glow.BackgroundColor3=Theme.Colors.Electric;glow.BackgroundTransparency=.86;glow.BorderSizePixel=0;glow.AnchorPoint=Vector2.new(.5,.5);glow.Position=UDim2.fromScale(.5,.5);glow.Size=UDim2.fromScale(1.35,.24);glow.Rotation=-12;glow.ZIndex=212;glow.Parent=panel
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(28,26);title.Size=UDim2.new(1,-56,0,34);title.Text="CELEBRATION PACK";title.TextColor3=Theme.Colors.White;title.TextSize=24;title.Font=Theme.Fonts.Display;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=213;title.Parent=panel
	local sub=Instance.new("TextLabel");sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(30,62);sub.Size=UDim2.new(1,-60,0,18);sub.Text=string.upper(tostring(payload.PackName or"UNLOCKED CELEBRATION"));sub.TextColor3=Theme.Colors.Electric;sub.TextSize=9;sub.Font=Theme.Fonts.Strong;sub.TextXAlignment=Enum.TextXAlignment.Left;sub.ZIndex=213;sub.Parent=panel
	local reel=Instance.new("Frame");reel.BackgroundColor3=Color3.fromHex("050805");reel.BackgroundTransparency=.06;reel.BorderSizePixel=0;reel.Position=UDim2.fromOffset(28,104);reel.Size=UDim2.new(1,-56,0,104);reel.ZIndex=213;reel.Parent=panel;local reelCorner=Instance.new("UICorner");reelCorner.CornerRadius=UDim.new(0,10);reelCorner.Parent=reel;local reelStroke=Instance.new("UIStroke");reelStroke.Color=Theme.Colors.Electric;reelStroke.Transparency=.38;reelStroke.Thickness=1;reelStroke.Parent=reel
	local name=Instance.new("TextLabel");name.BackgroundTransparency=1;name.AnchorPoint=Vector2.new(.5,.5);name.Position=UDim2.fromScale(.5,.5);name.Size=UDim2.new(1,-36,0,52);name.Text="SPINNING...";name.TextColor3=Theme.Colors.White;name.TextSize=24;name.Font=Theme.Fonts.Display;name.TextXAlignment=Enum.TextXAlignment.Center;name.ZIndex=214;name.Parent=reel
	local result=Instance.new("TextLabel");result.BackgroundTransparency=1;result.Position=UDim2.fromOffset(28,226);result.Size=UDim2.new(1,-56,0,34);result.Text="";result.TextColor3=Theme.Colors.Electric;result.TextSize=18;result.Font=Theme.Fonts.Display;result.TextXAlignment=Enum.TextXAlignment.Center;result.ZIndex=214;result.Parent=panel
	local close=Button.new({Text="EQUIP IN CUSTOMIZE",Variant="Primary",Size=UDim2.fromOffset(210,42),OnActivated=function()overlay:Destroy()end});close.AnchorPoint=Vector2.new(.5,1);close.Position=UDim2.new(.5,0,1,-24);close.ZIndex=215;close.Parent=panel
	TweenService:Create(scale,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	task.spawn(function()
		local cycles=math.max(18,#pool*5)
		for index=1,cycles do
			if not overlay.Parent then return end
			local id=tostring(pool[((index-1)%math.max(1,#pool))+1] or awarded)
			name.Text=cosmeticName(id);name.TextColor3=index>cycles-4 and Theme.Colors.Electric or Theme.Colors.White
			task.wait(math.clamp(.035+index*.006,.035,.12))
		end
		name.Text=cosmeticName(awarded);result.Text="UNLOCKED"
		TweenService:Create(glow,TweenInfo.new(.28,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency=.35,Size=UDim2.fromScale(1.5,.42)}):Play()
		TweenService:Create(stroke,TweenInfo.new(.28),{Thickness=4}):Play()
		task.delay(.35,function()if glow.Parent then TweenService:Create(glow,TweenInfo.new(.55),{BackgroundTransparency=.82,Size=UDim2.fromScale(1.35,.24)}):Play()end end)
	end)
end

function FlowController:Handle(card:any,action:any,perform:()->any,refresh:()->(),navigateTab:(string)->())
	local run=function() return self:_safe(action,perform,refresh) end
	if action.TargetTab then
		if action.Operation=="CareerSetup" then self:CareerSetup(function() navigateTab(action.TargetTab) end) else self:ModeTransition(action.TargetTab,function() navigateTab(action.TargetTab) end,true) end
	elseif action.Operation=="DeveloperProduct" then self:PromptDeveloperProduct(card,action)
	elseif action.Operation=="GamePass" then self:PromptGamePass(card,action)
	elseif action.Operation=="ShowStarCard" then
		self:ShowStarCardOffer(card,action)
	elseif action.Operation=="EquipToggle" then self:PlayerCardDetail(card,action,run)
	elseif action.Operation=="Purchase" and action.ItemType=="Pack" then Modal.open(self.Root,{Kicker="PACK PURCHASE",Title="BUY "..string.upper(card.Title),Meta=card.Meta,Description="Choose how many sealed packs to buy. The server validates currency and grants each pack as its own unopened inventory item.",Fields={{Key="Quantity",Placeholder="1 - 25",Default="1"}},ConfirmLabel="BUY PACKS",OnConfirm=function(values:any)
		local quantity=math.clamp(math.floor(tonumber(values.Quantity)or 1),1,25)
		action.Quantity=quantity
		local localPlayer=Players.LocalPlayer
		if localPlayer then localPlayer:SetAttribute("VTRHoldPackRewardFlyin",true)end
		local result=run();local delivered=type(result)=="table" and result.Success and result.Data and result.Data.Pack
		if delivered then
			delivered.quantity=quantity
			self:OfferPackDelivery(delivered)
		elseif localPlayer then
			localPlayer:SetAttribute("VTRHoldPackRewardFlyin",false)
		end
		action.Quantity=nil
	end})
	elseif action.Operation=="Purchase" then self:Confirmation("PURCHASE "..card.Title,card.Meta.."\n\nThe server will validate ownership and currency before granting this item.","PURCHASE",function()
		local result=run();local delivered=type(result)=="table" and result.Success and result.Data and result.Data.Pack
		if action.ItemType=="Pack" and delivered then
			self:OfferPackDelivery(delivered)
		end
	end)
	elseif action.Operation=="Claim" then self:RewardClaim(card,action,function() local result=run();local reward=type(result)=="table" and result.Data or nil;if self.PlayerDetailsHandler and type(reward)=="table" and (reward.cardInstanceId or reward.Id and string.sub(reward.Id,1,5)=="card_") then self.PlayerDetailsHandler(reward.cardInstanceId or reward.Id) end end)
	elseif action.Operation=="Create" and action.Key=="ClubCreated" then self:CreateClubForm(function(values:any) action.FormValues=values;local result=run();action.FormValues=nil;return result end)
	elseif action.Label=="OPEN PACK" then self:PackPreview(card,action,function() local result=run();if type(result)=="table" and result.Success and result.Data then self:PackOpening(card.Title,function() end,result.Data) end end)
	elseif action.Label=="FIND MATCH" then local result=run();if type(result)=="table"and result.Success then if type(result.Data)=="table"and result.Data.Status=="Matched"then RankedQueuePresentation.ShowMatchFound(self.Root,result.Data,function()end)else RankedQueuePresentation.StartSearching(self.Root)end;self.Toast({Title="RANKED QUEUE",Message=result.Message or"Searching for opponent…",Kind="Info"})end
	elseif action.Label=="CANCEL QUEUE"then self:Confirmation("LEAVE RANKED QUEUE","Stop searching for another player?","LEAVE QUEUE",function()local result=run();if type(result)=="table"and result.Success then RankedQueuePresentation.Cancel(self.Root);self.Toast({Title="RANKED QUEUE",Message=result.Message or"Search cancelled.",Kind="Info"})end end)
	elseif string.find(string.upper(card.Title),"PACK") and action.Operation=="ComingSoon" then self:PackPreview(card,action,function() self:ComingSoon("PACK CONTENTS","Pack probability and item tables connect here later.") end)
	elseif action.Operation=="ComingSoon" then self:ComingSoon(card.Title,action.Message or "This feature connects in a future milestone.")
	elseif action.Confirm then self:Confirmation(card.Title,action.Description or "Confirm this action.",action.Label,run)
	elseif action.Operation=="Save" then run()
	else self:ItemDetail(card,action,run) end
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

return FlowController
