--!strict
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Modal=require(script.Parent.Parent.Components.Modal)
local LoadingScreen=require(script.Parent.Parent.Components.LoadingScreen)
local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local UISoundService=require(script.Parent.Parent.Services.UISoundService)
local WidePlayerCard=require(script.Parent.Parent.Components.WidePlayerCard)
local CardSurface=require(script.Parent.Parent.Components.CardSurface)
local PackOpeningSequence=require(script.Parent.Parent.Components.PackOpeningSequence)
local PackService=require(script.Parent.Parent.Services.PackService)
local FlowController={};FlowController.__index=FlowController

function FlowController.new(root:Frame,toast:(any)->()) return setmetatable({Root=root,Toast=toast,Busy=false},FlowController) end
function FlowController:SetPlayerDetailsHandler(handler:(string)->()) self.PlayerDetailsHandler=handler end
function FlowController:SetNavigator(handler:(string)->()) self.Navigator=handler end
function FlowController:SetInventoryNavigator(handler:()->()) self.InventoryNavigator=handler end

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
	local message=type(result)=="table" and (result.Message or "Action completed.") or tostring(result)
	self.Toast({Title=action.Item or "VTR 25",Message=message,Kind=(action.Operation=="Purchase" or action.Operation=="Claim") and "Reward" or "Info"});refresh();return result
end

function FlowController:Confirmation(title:string,description:string,label:string,callback:()->()) Modal.open(self.Root,{Kicker="CONFIRMATION",Title=title,Description=description,ConfirmLabel=label,OnConfirm=callback}) end
function FlowController:ItemDetail(card:any,action:any,callback:(()->())?) Modal.open(self.Root,{Kicker="ITEM DETAIL",Title=card.Title,Meta=card.Subtitle.."  •  "..card.Meta,Description=card.Detail or action.Message or "Premium VTR 25 item. Live item data connects here later.",ConfirmLabel=callback and action.Label or "CLOSE",OnConfirm=callback}) end
function FlowController:PlayerCardDetail(card:any,action:any,callback:()->()) if self.PlayerDetailsHandler and (card.cardInstanceId or card.Id) then self.PlayerDetailsHandler(card.cardInstanceId or card.Id);return end;Modal.open(self.Root,{Kicker="PLAYER CARD DETAIL",Title=card.Title,Meta=card.Subtitle.."  •  "..card.Meta,Description=card.Detail or "Player attributes, chemistry links and club status.",ConfirmLabel=action.Label,OnConfirm=callback}) end
function FlowController:PackPreview(card:any,action:any,callback:()->()) Modal.open(self.Root,{Kicker="PACK PREVIEW",Title=card.Title,Meta=card.Subtitle,Description=card.Detail or "Cards are generated from the 5,000-player VTR database using this pack tier's server-owned rarity weights.",ConfirmLabel=action.Label=="OPEN PACK" and "OPEN PACK" or "VIEW CONTENTS",OnConfirm=callback}) end

function FlowController:_packResults(title:string,reveals:any,complete:()->())
	local overlay=Instance.new("CanvasGroup");overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.08;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=105;overlay.Active=true;overlay.Selectable=false;overlay.Parent=self.Root
	local shield=Instance.new("TextButton");shield.Name="PackResultsShield";shield.BackgroundTransparency=1;shield.BorderSizePixel=0;shield.Size=UDim2.fromScale(1,1);shield.Text="";shield.AutoButtonColor=false;shield.Selectable=false;shield.Modal=true;shield.Active=true;shield.ZIndex=105;shield.Parent=overlay
	local panel=Panel.new({Name="PackResults",Size=UDim2.fromOffset(880,500)});panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.ZIndex=106;panel.Parent=overlay
	local titleLabel=Instance.new("TextLabel");titleLabel.BackgroundTransparency=1;titleLabel.Position=UDim2.fromOffset(24,18);titleLabel.Size=UDim2.new(1,-48,0,42);titleLabel.Text=string.upper(title).."  /  PLAYER REVEAL";titleLabel.TextColor3=Theme.Colors.White;titleLabel.TextSize=22;titleLabel.Font=Theme.Fonts.Display;titleLabel.TextXAlignment=Enum.TextXAlignment.Left;titleLabel.ZIndex=107;titleLabel.Parent=panel
	local hint=titleLabel:Clone();hint.Position=UDim2.fromOffset(24,58);hint.Size=UDim2.new(1,-48,0,22);hint.Text="SELECT ANY CARD TO OPEN THE FULL PLAYER DATABASE PROFILE";hint.TextColor3=Theme.Colors.Electric;hint.TextSize=8;hint.Font=Theme.Fonts.Strong;hint.Parent=panel
	local grid=Instance.new("ScrollingFrame");grid.BackgroundTransparency=1;grid.BorderSizePixel=0;grid.Position=UDim2.fromOffset(24,92);grid.Size=UDim2.new(1,-48,1,-162);grid.AutomaticCanvasSize=Enum.AutomaticSize.Y;grid.CanvasSize=UDim2.new();grid.ScrollBarThickness=3;grid.ScrollBarImageColor3=Theme.Colors.Electric;grid.ZIndex=107;grid.Parent=panel
	local layout=Instance.new("UIGridLayout");layout.CellSize=UDim2.new(.5,-6,0,112);layout.CellPadding=UDim2.fromOffset(10,10);layout.Parent=grid
	for index,card in reveals do local reveal=WidePlayerCard.new({Parent=grid,Card=card,Size=UDim2.new(1,0,1,0),OnActivated=function() if self.PlayerDetailsHandler then self.PlayerDetailsHandler(card.cardInstanceId or card.Id) end end});reveal.LayoutOrder=index;reveal.ZIndex=108 end
	local continue=Button.new({Text="CONTINUE",Variant="Primary",Size=UDim2.fromOffset(160,40),OnActivated=function() overlay:Destroy();complete() end});continue.Position=UDim2.new(1,-184,1,-54);continue.ZIndex=108;continue.Parent=panel
end

function FlowController:PackOpening(title:string,complete:()->(),reveals:any?)
	if not reveals or #reveals==0 then self:Error("PACK OPENING FAILED","The server returned no player cards.");return end
	PackOpeningSequence.play(self.Root,{Title=title,Reveals=reveals,OnComplete=complete,OnViewPlayer=function(cardInstanceId:string) if self.PlayerDetailsHandler then self.PlayerDetailsHandler(cardInstanceId) end end,Toast=function(message:string,kind:string) self.Toast({Title="PACK CONTENTS",Message=message,Kind=kind}) end})
end
function FlowController:OfferPackDelivery(delivered:any,onComplete:(()->())?,beforeOpen:(()->())?)
	local quantity=tonumber(delivered.quantity)or 1
	Modal.open(self.Root,{Kicker="PACK DELIVERED",Title=delivered.name,Meta=quantity>1 and(quantity.." PACKS ADDED TO INVENTORY")or"PACK ADDED TO INVENTORY",Description=quantity>1 and("Open one now or go to Inventory to see all "..quantity.." unopened packs.")or"Open this pack now or go directly to your Inventory hub.",CancelLabel="GO TO INVENTORY",OnCancel=function()if self.InventoryNavigator then self.InventoryNavigator()elseif self.Navigator then self.Navigator("Inventory")end end,ConfirmLabel="OPEN NOW",OnConfirm=function()
		local opened=PackService:Open(delivered.packInstanceId);if not opened.Success then self:Error("PACK OPENING FAILED",opened.Message or "The pack could not be opened.");return end;if beforeOpen then beforeOpen()end
		self:PackOpening(delivered.name,onComplete or function()self.Toast({Title="PACK CONTENTS",Message="Pack contents secured in your Club.",Kind="Reward"})end,opened.Data)
	end})
end

function FlowController:RewardClaim(card:any,action:any,callback:()->()) Modal.open(self.Root,{Kicker="REWARD CLAIM",Title=action.Item or card.Title,Meta="READY TO CLAIM",Description="The server validates eligibility before the reward reveal.",ConfirmLabel="CLAIM REWARD",OnConfirm=function() local loading=LoadingScreen.new(self.Root,"UNLOCKING REWARD");task.delay(.65,function() LoadingScreen.complete(loading,callback) end) end}) end
function FlowController:CreateClubForm(callback:(any)->()) Modal.open(self.Root,{Kicker="CREATE CLUB",Title="NEW CLUB IDENTITY",Meta="CLUB SETUP",Description="Choose a club name and 2–4 letter tag. The server validates and stores this identity.",Fields={{Key="Name",Placeholder="CLUB NAME",Default="VOLTAGE UNITED"},{Key="Tag",Placeholder="TAG",Default="VTR"}},ConfirmLabel="CREATE CLUB",OnConfirm=callback}) end
function FlowController:CareerSetup(callback:()->()) Modal.open(self.Root,{Kicker="CAREER SETUP",Title="NEW CAREER SAVE",Meta="LOCAL MOCK SLOT",Description="Choose the career type to continue into the full setup hub.",ConfirmLabel="CHOOSE CAREER",OnConfirm=callback}) end
function FlowController:ComingSoon(title:string,message:string,callback:(()->())?) Modal.open(self.Root,{Kicker="COMING SOON",Title=title,Meta="FRAMEWORK READY",Description=message,ConfirmLabel="UNDERSTOOD",OnConfirm=callback}) end
function FlowController:Error(title:string,message:string) Modal.open(self.Root,{Kicker="ERROR",Title=title,Meta="PLEASE TRY AGAIN",Description=message,ConfirmLabel="CLOSE"}) end

function FlowController:Handle(card:any,action:any,perform:()->any,refresh:()->(),navigateTab:(string)->())
	local run=function() return self:_safe(action,perform,refresh) end
	if action.TargetTab then
		if action.Operation=="CareerSetup" then self:CareerSetup(function() navigateTab(action.TargetTab) end) else self:ModeTransition(action.TargetTab,function() navigateTab(action.TargetTab) end,true) end
	elseif action.Operation=="EquipToggle" then self:PlayerCardDetail(card,action,run)
	elseif action.Operation=="Purchase" and action.ItemType=="Pack" then Modal.open(self.Root,{Kicker="PACK PURCHASE",Title="BUY "..string.upper(card.Title),Meta=card.Meta,Description="Choose how many sealed packs to buy. The server validates currency and grants each pack as its own unopened inventory item.",Fields={{Key="Quantity",Placeholder="1 - 25",Default="1"}},ConfirmLabel="BUY PACKS",OnConfirm=function(values:any)
		local quantity=math.clamp(math.floor(tonumber(values.Quantity)or 1),1,25)
		action.Quantity=quantity
		local result=run();local delivered=type(result)=="table" and result.Success and result.Data and result.Data.Pack
		if delivered then
			delivered.quantity=quantity
			self:OfferPackDelivery(delivered)
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
	elseif action.Operation=="Create" and action.Key=="ClubCreated" then self:CreateClubForm(function(values:any) action.FormValues=values;run() end)
	elseif action.Label=="OPEN PACK" then self:PackPreview(card,action,function() local result=run();if type(result)=="table" and result.Success and result.Data then self:PackOpening(card.Title,function() end,result.Data) end end)
	elseif action.Label=="FIND MATCH" then local result=run();if type(result)=="table"and result.Success then RankedQueuePresentation.StartSearching(self.Root);self.Toast({Title="RANKED QUEUE",Message=result.Message or"Searching for opponent…",Kind="Info"})end
	elseif action.Label=="CANCEL QUEUE"then self:Confirmation("LEAVE RANKED QUEUE","Stop searching for another player?","LEAVE QUEUE",function()local result=run();if type(result)=="table"and result.Success then RankedQueuePresentation.Cancel(self.Root);self.Toast({Title="RANKED QUEUE",Message=result.Message or"Search cancelled.",Kind="Info"})end end)
	elseif string.find(string.upper(card.Title),"PACK") and action.Operation=="ComingSoon" then self:PackPreview(card,action,function() self:ComingSoon("PACK CONTENTS","Pack probability and item tables connect here later.") end)
	elseif action.Operation=="ComingSoon" then self:ComingSoon(card.Title,action.Message or "This feature connects in a future milestone.")
	elseif action.Confirm then self:Confirmation(card.Title,action.Description or "Confirm this action.",action.Label,run)
	elseif action.Operation=="Save" then run()
	else self:ItemDetail(card,action,run) end
end
return FlowController
