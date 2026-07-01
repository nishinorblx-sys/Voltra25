local MATCHUP_PANEL_DELAY = 0.85
--!strict

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local PageBase=require(script.Parent.PageBase)
local SquadService=require(script.Parent.Parent.Services.SquadService)
local ProgressionService=require(script.Parent.Parent.Services.ProgressionService)
local BadgePreview=require(script.Parent.Parent.Components.BadgePreview)
local PlayerDatabaseService=require(script.Parent.Parent.Services.PlayerDatabaseService)
local AvatarPortraitGenerator=require(script.Parent.Parent.Services.PlayerPortraitService)
local DragController=require(script.Parent.Parent.Controllers.DragController)
local CompactPlayerCard=require(script.Parent.Parent.Components.CompactPlayerCard)
local WidePlayerCard=require(script.Parent.Parent.Components.WidePlayerCard)
local PackService=require(script.Parent.Parent.Services.PackService)
local LaunchService=require(script.Parent.Parent.Services.LaunchService)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local Modal=require(script.Parent.Parent.Components.Modal)
local FormationConfig=require(ReplicatedStorage.VTR.Shared.FormationConfig)
local LiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)

local UltimateTeamPage={}
local TABS={"Starting XI","Bench","Reserves","Club"}
local POSITIONS={"ALL","GK","LB","CB","RB","CDM","CM","CAM","LW","ST","RW"}
local RARITIES={"ALL","STARTER","COMMON","BRONZE","SILVER","GOLD","RARE","ELITE","LEGENDARY","ICON","MYTHIC"}
local TACTIC_PRESETS={"Balanced","Possession","Counter Attack","High Press","Wing Play","Direct Long Ball","Low Block"}
local FORMATION_DOTS={
	["4-3-3"]={{.5,.9},{.18,.68},{.38,.7},{.62,.7},{.82,.68},{.28,.48},{.5,.52},{.72,.48},{.2,.24},{.5,.18},{.8,.24}},
	["4-2-3-1"]={{.5,.9},{.18,.68},{.38,.7},{.62,.7},{.82,.68},{.38,.52},{.62,.52},{.24,.32},{.5,.3},{.76,.32},{.5,.15}},
	["4-4-2"]={{.5,.9},{.18,.68},{.38,.7},{.62,.7},{.82,.68},{.2,.45},{.4,.48},{.6,.48},{.8,.45},{.38,.18},{.62,.18}},
	["3-5-2"]={{.5,.9},{.28,.7},{.5,.72},{.72,.7},{.12,.48},{.34,.5},{.5,.46},{.66,.5},{.88,.48},{.38,.18},{.62,.18}},
	["5-3-2"]={{.5,.9},{.12,.68},{.32,.72},{.5,.74},{.68,.72},{.88,.68},{.3,.45},{.5,.48},{.7,.45},{.38,.18},{.62,.18}},
}

local function text(parent:Instance,value:string,position:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel
	local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=position;label.Size=size;label.Text=value;label.TextColor3=color;label.TextSize=textSize;label.Font=font;label.TextXAlignment=Enum.TextXAlignment.Left;label.Parent=parent;return label
end
local function corner(parent:Instance,radius:number) local value=Instance.new("UICorner");value.CornerRadius=UDim.new(0,radius);value.Parent=parent end
local function rosterMeta(snapshot:any,card:any):any return snapshot.CardMeta and snapshot.CardMeta[card.Id] or card.Meta or {} end

function UltimateTeamPage.new(context:any):CanvasGroup
	local group,scroll=PageBase.new("UltimateTeam",930)
	PageBase.heading(scroll,"VOLTRA ULTIMATE TEAM","SQUAD BUILDER","Build, move and manage the complete matchday roster.")
	local response=SquadService:GetSquad();local snapshot=response.Success and response.Data or {Slots={},SlotOrder={},Bench={},Reserves={},Club={},Rating=0,Chemistry=0,Filled=0,Formation="4-3-3",FormationOptions={"4-3-3"},CardMeta={}}
	local tactics=LiteConfig.DefaultTactics()
	for key,value in context.Data.Progression.TeamTactics or{}do tactics[key]=value end
	tactics.Sliders=tactics.Sliders or LiteConfig.DefaultTactics().Sliders
	local selectedCard:any?=nil;local selectedDetails:any?=nil;local pendingCardId:string?=nil;local tapMoveEnabled=false;local activeTab="Bench";local searchText="";local positionIndex=1;local rarityIndex=1;local sortHigh=true;local compareCard:any?=nil
	local targets={}
	local pitchNodes={}

	local summary=Panel.new({Name="TeamSummary",Position=UDim2.fromOffset(0,96),Size=UDim2.new(.19,-8,0,558)});summary.Parent=scroll
	local pitch=Panel.new({Name="FormationPitch",Position=UDim2.new(.19,8,0,96),Size=UDim2.new(.55,-16,0,558),Color=Theme.Colors.Pitch,ClipsDescendants=true});pitch.Parent=scroll
	local preview=Panel.new({Name="PlayerPreview",Position=UDim2.new(.74,8,0,96),Size=UDim2.new(.26,-8,0,558)});preview.Parent=scroll
	local tray=Panel.new({Name="RosterTray",Position=UDim2.fromOffset(0,670),Size=UDim2.new(1,0,0,230),ClipsDescendants=true});tray.Parent=scroll

	-- Clean pitch markings sit behind fixed formation slots.
	local field=Instance.new("Frame");field.BackgroundTransparency=1;field.Position=UDim2.fromOffset(18,18);field.Size=UDim2.new(1,-36,1,-36);field.Parent=pitch
	local fieldStroke=Instance.new("UIStroke");fieldStroke.Color=Color3.fromHex("52634A");fieldStroke.Thickness=2;fieldStroke.Transparency=.18;fieldStroke.Parent=field
	local half=Instance.new("Frame");half.BackgroundColor3=Color3.fromHex("52634A");half.BackgroundTransparency=.22;half.BorderSizePixel=0;half.Position=UDim2.fromScale(0,.5);half.Size=UDim2.new(1,0,0,2);half.Parent=field
	local circle=Instance.new("Frame");circle.AnchorPoint=Vector2.new(.5,.5);circle.BackgroundTransparency=1;circle.Position=UDim2.fromScale(.5,.5);circle.Size=UDim2.fromOffset(94,94);circle.Parent=field;corner(circle,47);local circleStroke=Instance.new("UIStroke");circleStroke.Color=Color3.fromHex("52634A");circleStroke.Thickness=2;circleStroke.Transparency=.2;circleStroke.Parent=circle
	local cardsLayer=Instance.new("Frame");cardsLayer.BackgroundTransparency=1;cardsLayer.Size=UDim2.fromScale(1,1);cardsLayer.Parent=field

	local teamContent=Instance.new("Frame");teamContent.BackgroundTransparency=1;teamContent.Position=UDim2.fromOffset(14,12);teamContent.Size=UDim2.new(1,-28,1,-24);teamContent.Parent=summary
	local previewContent=Instance.new("Frame");previewContent.BackgroundTransparency=1;previewContent.Position=UDim2.fromOffset(14,12);previewContent.Size=UDim2.new(1,-28,1,-24);previewContent.Parent=preview
	local tabBar=Instance.new("Frame");tabBar.BackgroundTransparency=1;tabBar.Position=UDim2.fromOffset(12,10);tabBar.Size=UDim2.new(1,-24,0,34);tabBar.Parent=tray
	local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,7);tabLayout.Parent=tabBar
	local trayContent=Instance.new("Frame");trayContent.BackgroundTransparency=1;trayContent.Position=UDim2.fromOffset(12,52);trayContent.Size=UDim2.new(1,-24,1,-62);trayContent.Parent=tray
	local tabButtons={}

	local renderAll:()->();local renderTray:()->();local renderPitch:()->();local renderSummary:()->();local renderPreview:()->();local repositionPitchOnly:()->();local selectCard:(any)->();local requestMove:(string,string,any?)->();local openCardMenu:(any)->();local destinationTap:(any?,string,any?)->()
	local function toast(message:string,kind:string?) context.Toast({Title="SQUAD BUILDER",Message=message,Kind=kind or "Info"}) end
	local function apply(result:any)
		if not result.Success then toast(result.Message or "Roster action rejected.","Error");return end
		snapshot=result.Data or snapshot;toast(result.Message or "Squad saved.");if result.CompletedNow then toast("BUILD FIRST XI COMPLETE - reward ready.","Reward") end;renderAll()
	end
	requestMove=function(cardId:string,destinationType:string,destinationSlot:any?) apply(SquadService:MovePlayer(cardId,destinationType,destinationSlot)) end
	local formationSaveToken=0
	local formationOpen=false
	local function applyFormationLocally(name:string)
		local formation=FormationConfig.Formations[name]
		if not formation then return end
		snapshot.Formation=name
		snapshot.FormationOptions=snapshot.FormationOptions or {"4-3-3","4-4-2","4-2-3-1","3-5-2","5-3-2"}
		for slot,data in snapshot.Slots or {} do
			local definition=formation[slot]
			if definition then
				data.Coordinate=Vector2.new(definition.X,definition.Y)
				data.Label=definition.Label
				data.Expected=definition.Expected
				if data.Card then
					local position=tostring(data.Card.Position or data.Card.bestPosition or "")
					data.OutOfPosition=position~="" and definition.Expected~="" and position~=definition.Expected and not string.find(definition.Expected,position,1,true)
				end
			end
		end
	end
	local function setFormationInstant(name:string)
		if name==snapshot.Formation then formationOpen=false;renderSummary();return end
		formationSaveToken+=1
		local token=formationSaveToken
		formationOpen=false
		applyFormationLocally(name)
		renderSummary()
		repositionPitchOnly()
		task.spawn(function()
			local result=SquadService:SetFormation(name)
			if token~=formationSaveToken then return end
			if result.Success then
				if result.Data then
					snapshot=result.Data
					renderSummary()
					repositionPitchOnly()
					if selectedCard then renderPreview()end
				end
			else
				toast(result.Message or "Formation change rejected.","Error")
				local refresh=SquadService:GetSquad()
				if refresh.Success and token==formationSaveToken then snapshot=refresh.Data;renderAll()end
			end
		end)
	end

	local function registerTarget(instance:GuiObject,kind:string,slot:any?) table.insert(targets,{Instance=instance,Kind=kind,Slot=slot}) end
	local function targetAt(screenPosition:Vector2):any?
		for _,target in targets do local instance=target.Instance;if instance.Parent then local p,s=instance.AbsolutePosition,instance.AbsoluteSize;if screenPosition.X>=p.X and screenPosition.X<=p.X+s.X and screenPosition.Y>=p.Y and screenPosition.Y<=p.Y+s.Y then return target end end end;return nil
	end
	local dragController=DragController.new(group,{Threshold=8,HitTest=targetAt,OnDrop=function(card:any,destination:any) pendingCardId=nil;tapMoveEnabled=false;requestMove(card.Id,destination.Kind,destination.Slot) end,OnCancel=function() toast("Move cancelled - the complete card returned to its original location.") end})
	group.Destroying:Connect(function() dragController:Destroy() end)
	local function addDrag(button:GuiButton,card:any,kind:string,slot:any?) dragController:Attach(button,card,function() destinationTap(card,kind,slot) end) end
	destinationTap=function(card:any?,kind:string,slot:any?)
		if tapMoveEnabled and pendingCardId and (not card or card.Id~=pendingCardId) then local id=pendingCardId;context.Flow:Confirmation("CONFIRM PLAYER MOVE","Move the selected player to this "..kind.." destination?","MOVE PLAYER",function() pendingCardId=nil;tapMoveEnabled=false;requestMove(id,kind,slot) end);return end
		if card then openCardMenu(card) end
	end

	repositionPitchOnly=function()
		local preservedTargets={}
		for _,target in targets do
			if target.Kind~="StartingXI" then table.insert(preservedTargets,target) end
		end
		targets=preservedTargets
		for _,slot in snapshot.SlotOrder or{}do
			local data=snapshot.Slots[slot]
			local node=pitchNodes[slot]
			if node and node.Parent and data then
				node.Position=UDim2.fromScale(data.Coordinate.X,data.Coordinate.Y)
				registerTarget(node,"StartingXI",slot)
				if not data.Card then
					local label=node:FindFirstChildWhichIsA("TextLabel")
					if label then label.Text="+\n"..(data.Label or tostring(slot))end
				end
			end
		end
	end

	local function makeCard(parent:Instance,card:any?,size:UDim2,kind:string,slot:any?,compact:boolean?):TextButton
		local selected=card~=nil and selectedCard~=nil and selectedCard.Id==card.Id
		local button:TextButton
		if card then
			local outOfPosition=kind=="StartingXI" and snapshot.Slots[slot] and snapshot.Slots[slot].OutOfPosition
			button=CompactPlayerCard.new({Parent=parent,Card=card,Size=size,Horizontal=compact==true,Selected=selected,Meta=rosterMeta(snapshot,card),ChemistryColor=compact and nil or (outOfPosition and Theme.Colors.Warning or Theme.Colors.Electric)})
			button.Name="Card_"..card.Id;addDrag(button,card,kind,slot)
		else
			button=Instance.new("TextButton");button.Name=kind.."Empty";button.AutoButtonColor=false;button.BackgroundColor3=Color3.fromHex("13200F");button.BackgroundTransparency=.28;button.BorderSizePixel=0;button.Size=size;button.Text="";button.Selectable=false;button.Parent=parent;corner(button,7)
			local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Border;stroke.Thickness=1;stroke.Transparency=.2;stroke.Parent=button
			local label=kind=="StartingXI" and (snapshot.Slots[slot] and snapshot.Slots[slot].Label or tostring(slot)) or kind=="Bench" and ("B"..slot) or "+";local empty=text(button,"+\n"..label,UDim2.new(),UDim2.fromScale(1,1),compact and 9 or 11,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center;empty.TextYAlignment=Enum.TextYAlignment.Center
		end
		button.AnchorPoint=compact and Vector2.zero or Vector2.new(.5,.5)
		if pendingCardId and (kind=="StartingXI" or kind=="Bench" or kind=="Reserves") then local targetGlow=Instance.new("UIStroke");targetGlow.Name="MoveDestinationGlow";targetGlow.Color=Theme.Colors.Electric;targetGlow.Thickness=1;targetGlow.Transparency=.38;targetGlow.Parent=button end
		if not card then button.Activated:Connect(function() destinationTap(nil,kind,slot) end) end;registerTarget(button,kind,slot);return button
	end

	local function closeMenu(menu:Instance) menu:Destroy() end
	local function actionMenu()
		if not selectedCard then return end;local card=selectedCard;local meta=rosterMeta(snapshot,card)
		local overlay=Instance.new("TextButton");overlay.Name="PlayerActionOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.3;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=60;overlay.Parent=group
		local menu=Panel.new({Name="PlayerActions",Size=UDim2.fromOffset(310,540),ClipsDescendants=false});menu.AnchorPoint=Vector2.new(.5,.5);menu.Position=UDim2.fromScale(.5,.5);menu.ZIndex=61;menu.Parent=overlay
		text(menu,"PLAYER ACTIONS",UDim2.fromOffset(20,16),UDim2.new(1,-40,0,24),9,Theme.Colors.Electric,Theme.Fonts.Strong);text(menu,card.Rating.."  "..card.Name.."  /  "..card.Position,UDim2.fromOffset(20,41),UDim2.new(1,-40,0,30),15,Theme.Colors.White,Theme.Fonts.Display)
		local holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Position=UDim2.fromOffset(18,82);holder.Size=UDim2.new(1,-36,1,-100);holder.ZIndex=62;holder.Parent=menu;local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,5);layout.Parent=holder
		local function item(label:string,callback:()->()) local action=Button.new({Text=label,Variant="Secondary",Size=UDim2.new(1,0,0,35),OnActivated=function() closeMenu(overlay);callback() end});action.ZIndex=63;action.Parent=holder end
		item("VIEW DETAILS",function() context.OpenPlayerDetails(card.Id) end)
		item("COMPARE PLAYER",function() compareCard=card;toast("Select another player to compare against "..card.Name..".") end)
		item("MOVE PLAYER",function() pendingCardId=card.Id;tapMoveEnabled=UserInputService:GetLastInputType()==Enum.UserInputType.Touch;if tapMoveEnabled then toast("Tap a highlighted destination, then confirm the move.") else toast("Valid destinations are highlighted. Drag the card to move it.") end;renderAll() end)
		item("SEND TO BENCH",function() local destination=1;for index=1,7 do if not snapshot.Bench[index] or not snapshot.Bench[index].Card then destination=index;break end end;requestMove(card.Id,"Bench",destination) end)
		item("SEND TO RESERVES",function() requestMove(card.Id,"Reserves",nil) end)
		item("REMOVE FROM SQUAD",function() requestMove(card.Id,"Club",nil) end)
		item("ADD TO TRANSFER LIST",function()Modal.open(group,{Kicker="GLOBAL TRANSFER MARKET",Title="LIST "..string.upper(card.Name),Description="Choose a starter bid and duration in hours (1, 3, 6, 12 or 24). The card cannot be used while listed.",Fields={{Key="Price",Placeholder="STARTER BID",Default="1000"},{Key="Hours",Placeholder="HOURS",Default="1"}},ConfirmLabel="LIST PLAYER",OnConfirm=function(values:any)local hours=tonumber(values.Hours)or 0;local result=SquadService:CreateTransferListing(card.Id,tonumber(values.Price)or 0,hours*3600);if not result.Success then toast(result.Message or"Listing failed.","Error")else toast(result.Message or"Player listed.","Reward");local refreshed=SquadService:GetSquad();if refreshed.Success then snapshot=refreshed.Data;renderAll()end end end})end)
		item("QUICK SELL",function()if meta.Locked then toast("Unlock this player before quick selling.","Error")else context.Flow:Confirmation("QUICK SELL "..string.upper(card.Name),"This permanently removes the card. Value scales from 1,000 to 24,000 coins by card quality.","QUICK SELL",function()apply(SquadService:QuickSellCard(card.Id))end)end end)
		item(meta.Locked and "UNLOCK PLAYER" or "LOCK PLAYER",function() apply(SquadService:SetCardFlag(card.Id,"Locked",not meta.Locked)) end)
		item(meta.Favorite and "REMOVE FAVORITE" or "FAVORITE PLAYER",function() apply(SquadService:SetCardFlag(card.Id,"Favorite",not meta.Favorite)) end)
		overlay.Activated:Connect(function() closeMenu(overlay) end)
	end

	selectCard=function(card:any)
		if compareCard and compareCard.Id~=card.Id then toast(card.Name.." is "..math.abs(card.Rating-compareCard.Rating).." OVR "..(card.Rating>=compareCard.Rating and "higher" or "lower").." than "..compareCard.Name..".");compareCard=nil end
		selectedCard=card;selectedDetails=nil;local details=PlayerDatabaseService:GetDetails(card.Id);if details.Success then selectedDetails=details.Data end;renderAll()
	end
	openCardMenu=function(card:any) pendingCardId=nil;tapMoveEnabled=false;selectCard(card);task.defer(actionMenu) end

	renderSummary=function()
		for _,child in teamContent:GetChildren() do child:Destroy() end
		text(teamContent,string.upper(snapshot.TeamName or "YOUR CLUB"),UDim2.fromOffset(0,0),UDim2.new(1,0,0,30),14,Theme.Colors.White,Theme.Fonts.Display)
		if snapshot.ClubIdentity then local badge=BadgePreview.new(teamContent,snapshot.ClubIdentity,UDim2.fromOffset(48,48));badge.AnchorPoint=Vector2.new(1,0);badge.Position=UDim2.new(1,0,0,0)end
		text(teamContent,"TEAM OVERALL",UDim2.fromOffset(0,44),UDim2.new(1,0,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong);text(teamContent,tostring(snapshot.Rating),UDim2.fromOffset(0,62),UDim2.new(1,0,0,36),25,Theme.Colors.Electric,Theme.Fonts.Display)
		text(teamContent,"CHEMISTRY",UDim2.fromOffset(0,108),UDim2.new(1,0,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong);text(teamContent,snapshot.Chemistry.." / 33",UDim2.fromOffset(0,126),UDim2.new(1,0,0,28),17,Theme.Colors.White,Theme.Fonts.Display)
		text(teamContent,"FORMATION",UDim2.fromOffset(0,168),UDim2.new(1,0,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong)
		local formation=Button.new({Text=snapshot.Formation.."  V",Variant="Secondary",Size=UDim2.new(1,0,0,34),OnActivated=function() formationOpen=not formationOpen;renderSummary() end});formation.Position=UDim2.fromOffset(0,190);formation.Parent=teamContent
		local nextY=232;if formationOpen then for _,name in snapshot.FormationOptions do local option=Button.new({Text=name,Variant=name==snapshot.Formation and "Primary" or "Secondary",Size=UDim2.new(1,0,0,28),OnActivated=function() setFormationInstant(name) end});option.Position=UDim2.fromOffset(0,nextY);option.Parent=teamContent;nextY+=31 end end
		local objective=snapshot.Objective;if not formationOpen then local objectiveY=246;text(teamContent,"STARTER OBJECTIVE",UDim2.fromOffset(0,objectiveY),UDim2.new(1,0,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong);text(teamContent,objective and (objective.title.."\n"..objective.progress.." / "..objective.target) or "JOURNEY COMPLETE",UDim2.fromOffset(0,objectiveY+20),UDim2.new(1,0,0,43),8,Theme.Colors.Silver,Theme.Fonts.Strong);if objective and (objective.status=="claimable" or objective.status=="completed") then local claim=Button.new({Text="CLAIM REWARD",Variant="Primary",Size=UDim2.new(1,0,0,32),OnActivated=function() local result=ProgressionService:Claim("Objective",objective.objectiveId);if result.Success then toast(result.Message or "Reward claimed.","Reward");local refresh=SquadService:GetSquad();if refresh.Success then snapshot=refresh.Data;renderAll() end else toast(result.Message or "Claim failed.","Error") end end});claim.Position=UDim2.fromOffset(0,316);claim.Parent=teamContent end end
		local auto=Button.new({Text="AUTO BUILD",Variant="Primary",Size=UDim2.new(1,0,0,36),OnActivated=function() apply(SquadService:AutoBuildSquad()) end});auto.Position=UDim2.new(0,0,1,-120);auto.Parent=teamContent
		local clear=Button.new({Text="CLEAR XI",Variant="Secondary",Size=UDim2.new(1,0,0,36),OnActivated=function() context.Flow:Confirmation("CLEAR STARTING XI","Move all starters to reserves?","CLEAR XI",function() apply(SquadService:ClearSquad()) end) end});clear.Position=UDim2.new(0,0,1,-78);clear.Parent=teamContent
		text(teamContent,"SAVED  "..os.date("!%H:%M:%S",snapshot.SavedAt or os.time()),UDim2.new(0,0,1,-28),UDim2.new(1,0,0,20),7,Theme.Colors.Electric,Theme.Fonts.Strong)
	end

	renderPitch=function()
		targets={};pitchNodes={};for _,child in cardsLayer:GetChildren() do child:Destroy() end
		for _,slot in snapshot.SlotOrder or {} do local data=snapshot.Slots[slot];local card=data and data.Card;local node=makeCard(cardsLayer,card,UDim2.fromOffset(76,94),"StartingXI",slot,false);node.Position=UDim2.fromScale(data.Coordinate.X,data.Coordinate.Y);pitchNodes[slot]=node end
	end

	renderPreview=function()
		for _,child in previewContent:GetChildren() do child:Destroy() end
		if not selectedCard then text(previewContent,"SELECT A PLAYER",UDim2.fromOffset(0,210),UDim2.new(1,0,0,30),15,Theme.Colors.Muted,Theme.Fonts.Display).TextXAlignment=Enum.TextXAlignment.Center;return end
		local card=selectedCard;local portrait=AvatarPortraitGenerator.new(previewContent,card,UDim2.new(1,0,0,156),false);portrait.Position=UDim2.fromOffset(0,0)
		text(previewContent,card.Rating.."  "..card.Position,UDim2.fromOffset(10,10),UDim2.new(1,-20,0,27),18,Theme.Colors.White,Theme.Fonts.Display).ZIndex=4;text(previewContent,card.Name,UDim2.fromOffset(0,164),UDim2.new(1,0,0,28),14,Theme.Colors.White,Theme.Fonts.Display)
		local stats=selectedDetails and selectedDetails.mainStats or {PAC="-",SHO="-",PAS="-",DRI="-",DEF="-",PHY="-"};local details=selectedDetails and (selectedDetails.detailedStats or selectedDetails.DetailedStats) or {};local isGoalkeeper=string.upper(tostring(card.Position or card.bestPosition or ""))=="GK";local statHolder=Instance.new("Frame");statHolder.BackgroundTransparency=1;statHolder.Position=UDim2.fromOffset(0,202);statHolder.Size=UDim2.new(1,0,0,94);statHolder.Parent=previewContent;local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(1/3,-5,0,43);grid.CellPadding=UDim2.fromOffset(6,6);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=statHolder;local displayStats=isGoalkeeper and {{Key="gkDiving",Label="DIV",Value=details.gkDiving or details.GKDiving or 0},{Key="gkHandling",Label="HAN",Value=details.gkHandling or details.GKHandling or 0},{Key="gkKicking",Label="KIC",Value=details.gkKicking or details.GKKicking or 0},{Key="gkPositioning",Label="POS",Value=details.gkPositioning or details.GKPositioning or 0},{Key="gkReflexes",Label="REF",Value=details.gkReflexes or details.GKReflexes or 0}} or {{Key="PAC",Label="PAC",Value=stats.PAC},{Key="SHO",Label="SHO",Value=stats.SHO},{Key="PAS",Label="PAS",Value=stats.PAS},{Key="DRI",Label="DRI",Value=stats.DRI},{Key="DEF",Label="DEF",Value=stats.DEF},{Key="PHY",Label="PHY",Value=stats.PHY}};for index,item in displayStats do local chip=Panel.new({Name=item.Label});chip.LayoutOrder=index;chip.Parent=statHolder;text(chip,tostring(item.Value or "-"),UDim2.fromOffset(0,4),UDim2.new(1,0,0,20),13,Theme.Colors.Electric,Theme.Fonts.Display).TextXAlignment=Enum.TextXAlignment.Center;text(chip,item.Label,UDim2.fromOffset(0,24),UDim2.new(1,0,0,14),7,Theme.Colors.Muted,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Center end
		local location,locationSlot="Club",nil;for _,clubCard in snapshot.Club do if clubCard.Id==card.Id then location=clubCard.RosterLocation;locationSlot=clubCard.RosterSlot;break end end;local impact=location=="StartingXI" and snapshot.Slots[locationSlot] and snapshot.Slots[locationSlot].OutOfPosition and "OUT OF POSITION  /  -2 BASE CHEM" or location=="StartingXI" and "NATURAL ROLE  /  +2 BASE CHEM" or "NOT IN STARTING XI";text(previewContent,"CHEMISTRY IMPACT",UDim2.fromOffset(0,318),UDim2.new(1,0,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong);text(previewContent,impact,UDim2.fromOffset(0,338),UDim2.new(1,0,0,32),8,location=="StartingXI" and Theme.Colors.Electric or Theme.Colors.Silver,Theme.Fonts.Strong)
		local actions=Button.new({Text="PLAYER ACTIONS",Variant="Primary",Size=UDim2.new(1,0,0,40),OnActivated=actionMenu});actions.Position=UDim2.new(0,0,1,-50);actions.Parent=previewContent
	end

	renderTray=function()
		for _,child in trayContent:GetChildren() do child:Destroy() end;for name,button in tabButtons do Button.setPrimary(button,name==activeTab) end
		local controlsHeight=activeTab=="Club" and 36 or 0
		if activeTab=="Club" then
			local search=Instance.new("TextBox");search.BackgroundColor3=Theme.Colors.Gunmetal;search.BorderSizePixel=0;search.Position=UDim2.fromOffset(0,0);search.Size=UDim2.new(.42,-6,0,32);search.PlaceholderText="SEARCH CLUB PLAYERS";search.Text=searchText;search.TextColor3=Theme.Colors.White;search.PlaceholderColor3=Theme.Colors.Muted;search.TextSize=9;search.Font=Theme.Fonts.Strong;search.ClearTextOnFocus=false;search.Parent=trayContent;corner(search,5);search.FocusLost:Connect(function() searchText=search.Text;renderTray() end)
			local pos=Button.new({Text="POS: "..POSITIONS[positionIndex],Variant="Secondary",Size=UDim2.new(.18,-4,0,32),OnActivated=function() positionIndex=positionIndex%#POSITIONS+1;renderTray() end});pos.Position=UDim2.new(.42,4,0,0);pos.Parent=trayContent
			local rarity=Button.new({Text="RARITY: "..RARITIES[rarityIndex],Variant="Secondary",Size=UDim2.new(.22,-4,0,32),OnActivated=function() rarityIndex=rarityIndex%#RARITIES+1;renderTray() end});rarity.Position=UDim2.new(.60,6,0,0);rarity.Parent=trayContent
			local sort=Button.new({Text=sortHigh and "OVR HIGH" or "OVR LOW",Variant="Secondary",Size=UDim2.new(.18,-4,0,32),OnActivated=function() sortHigh=not sortHigh;renderTray() end});sort.Position=UDim2.new(.82,8,0,0);sort.Parent=trayContent
		end
		local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(0,controlsHeight+6);list.Size=UDim2.new(1,0,1,-controlsHeight-6);list.CanvasSize=UDim2.new();list.ScrollingDirection=Enum.ScrollingDirection.X;list.ScrollingEnabled=true;list.Active=true;list.Selectable=false;list.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable;list.ScrollBarThickness=5;list.ScrollBarImageColor3=Theme.Colors.Electric;list.Parent=trayContent;local layout=Instance.new("UIListLayout");layout.FillDirection=Enum.FillDirection.Horizontal;layout.Padding=UDim.new(0,8);layout.Parent=list
		local function updateCanvas()if not list.Parent then return end;list.CanvasSize=UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X+8,list.AbsoluteSize.X),0)end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas);list:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
		list.InputChanged:Connect(function(input)if input.UserInputType~=Enum.UserInputType.MouseWheel then return end;local maxX=math.max(0,list.AbsoluteCanvasSize.X-list.AbsoluteWindowSize.X);list.CanvasPosition=Vector2.new(math.clamp(list.CanvasPosition.X-input.Position.Z*72,0,maxX),0)end)
		local entries={};if activeTab=="Bench" then for index=1,7 do table.insert(entries,{Card=snapshot.Bench[index] and snapshot.Bench[index].Card or nil,Kind="Bench",Slot=index}) end elseif activeTab=="Reserves" then for index,card in snapshot.Reserves do table.insert(entries,{Card=card,Kind="Reserves",Slot=index}) end elseif activeTab=="Starting XI" then for _,slot in snapshot.SlotOrder do table.insert(entries,{Card=snapshot.Slots[slot].Card,Kind="StartingXI",Slot=slot}) end else for _,card in snapshot.Club do local match=(POSITIONS[positionIndex]=="ALL" or card.Position==POSITIONS[positionIndex]) and (RARITIES[rarityIndex]=="ALL" or string.upper(card.Rarity)==RARITIES[rarityIndex]) and (searchText=="" or string.find(string.lower(card.Name),string.lower(searchText),1,true));if match then table.insert(entries,{Card=card,Kind="Club",Slot=nil}) end end;table.sort(entries,function(a,b)
			local ratingA=tonumber(a.Card and a.Card.Rating)or 0;local ratingB=tonumber(b.Card and b.Card.Rating)or 0
			if ratingA~=ratingB then if sortHigh then return ratingA>ratingB else return ratingA<ratingB end end
			local nameA=string.lower(tostring(a.Card and a.Card.Name or""));local nameB=string.lower(tostring(b.Card and b.Card.Name or""))
			if nameA~=nameB then return nameA<nameB end
			local idA=tostring(a.Card and(a.Card.Id or a.Card.cardInstanceId)or"");local idB=tostring(b.Card and(b.Card.Id or b.Card.cardInstanceId)or"")
			return idA<idB
		end) end
		for order,entry in entries do
			local card:TextButton
			if activeTab=="Club" and entry.Card then card=WidePlayerCard.new({Parent=list,Card=entry.Card,Size=UDim2.fromOffset(390,112),Selected=selectedCard and selectedCard.Id==entry.Card.Id,Meta=rosterMeta(snapshot,entry.Card)});addDrag(card,entry.Card,entry.Kind,entry.Slot);registerTarget(card,entry.Kind,entry.Slot)
			else card=makeCard(list,entry.Card,UDim2.fromOffset(150,68),entry.Kind,entry.Slot,true) end
			card.LayoutOrder=order
		end
		if activeTab=="Reserves" then registerTarget(list,"Reserves",nil) elseif activeTab=="Club" then registerTarget(list,"Club",nil) end
		task.defer(updateCanvas)
	end

	renderAll=function()
		if selectedCard then local replacement=nil;for _,card in snapshot.Club do if card.Id==selectedCard.Id then replacement=card;break end end;selectedCard=replacement end
		renderSummary();renderPitch();renderPreview();renderTray()
	end

	local openPackHub:(()->())
	openPackHub=function()
		local response=PackService:GetInventory();if not response.Success then toast(response.Message or "Pack inventory unavailable.","Error");return end
		local packData=response.Data or {Packs={},History={}};local selectedTab="My Packs";local packTabs={"My Packs","Store Packs","Pack Odds","History"};local storeOrder={"starter_pack","bronze_pack","silver_pack","gold_pack","elite_pack","voltra_pack"}
		local overlay=Instance.new("TextButton");overlay.Name="PackHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.12;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="PackHub",Size=UDim2.fromOffset(900,580),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		text(hub,"ULTIMATE TEAM PACKS",UDim2.fromOffset(24,16),UDim2.new(1,-150,0,34),21,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73
		text(hub,"UNOPENED INVENTORY  /  STORE  /  TRANSPARENT ODDS  /  OPEN HISTORY",UDim2.fromOffset(24,50),UDim2.new(1,-48,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(96,34),OnActivated=function() overlay:Destroy() end});close.Position=UDim2.new(1,-120,0,20);close.ZIndex=74;close.Parent=hub
		local tabBar=Instance.new("Frame");tabBar.BackgroundTransparency=1;tabBar.Position=UDim2.fromOffset(24,78);tabBar.Size=UDim2.new(1,-48,0,36);tabBar.ZIndex=73;tabBar.Parent=hub;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,8);tabLayout.Parent=tabBar
		local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,124);body.Size=UDim2.new(1,-48,1,-148);body.ZIndex=72;body.Parent=hub
		local tabButtons={};local renderTab:()->()
		local function oddsFor(definition:any):string local values={};for _,rarity in {"Starter","Common","Bronze","Silver","Gold","Rare","Elite","Legendary","Icon","Mythic"} do local chance=definition.Odds and definition.Odds[rarity];if chance and chance>0 then table.insert(values,string.format("%s %.2g%%",string.upper(rarity),chance)) end end;return table.concat(values,"   ")..(definition.GuaranteedMinRarity and ("   /   GUARANTEED "..string.upper(definition.GuaranteedMinRarity).."+") or "") end
		local function refreshData() local fresh=PackService:GetInventory();if fresh.Success then packData=fresh.Data end end
		local function openOwned(pack:any)
			local oddsText=oddsFor(pack);context.Flow:PackPreview({Title=pack.name,Subtitle=pack.CardCount.." PLAYER CARDS",Detail=(pack.description or "VTR player pack").."\n\n"..oddsText},{Label="OPEN PACK"},function()
				local opened=PackService:Open(pack.packInstanceId);if not opened.Success then toast(opened.Message or "Pack opening failed.","Error");return end
				overlay:Destroy();context.Flow:PackOpening(pack.name,function() local refreshed=SquadService:GetSquad();if refreshed.Success then snapshot=refreshed.Data;renderAll() end;toast("Pack contents secured in your Club.","Reward") end,opened.Data)
			end)
		end
		local function offerOpenNow(delivered:any)
			context.Flow:OfferPackDelivery(delivered,function()toast("Pack contents secured in your Club.","Reward")end,function()overlay:Destroy()end)
		end
		renderTab=function()
			for _,child in body:GetChildren() do child:Destroy() end;for name,button in tabButtons do Button.setPrimary(button,name==selectedTab) end
			local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Size=UDim2.fromScale(1,1);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=3;list.ScrollBarImageColor3=Theme.Colors.Electric;list.ZIndex=73;list.Parent=body;local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,9);layout.Parent=list
			local function row(titleValue:string,subtitle:string,meta:string,buttonText:string?,callback:(()->())?) local item=Panel.new({Name=titleValue,Size=UDim2.new(1,-6,0,92)});item.ZIndex=74;item.Parent=list;text(item,titleValue,UDim2.fromOffset(18,10),UDim2.new(1,-230,0,24),14,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75;text(item,subtitle,UDim2.fromOffset(18,37),UDim2.new(1,-230,0,17),8,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=75;text(item,meta,UDim2.fromOffset(18,58),UDim2.new(1,-230,0,18),7,Theme.Colors.Muted,Theme.Fonts.Body).ZIndex=75;if buttonText and callback then local action=Button.new({Text=buttonText,Variant="Primary",Size=UDim2.fromOffset(170,38),OnActivated=callback});action.Position=UDim2.new(1,-190,.5,-19);action.ZIndex=75;action.Parent=item end end
			if selectedTab=="My Packs" then local packs=packData.Packs or {};if #packs==0 then local empty=text(list,"NO UNOPENED PACKS\n\nPurchase a pack in Store Packs or earn one from objectives.",UDim2.fromOffset(0,140),UDim2.new(1,0,0,90),13,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center else for _,pack in packs do row(pack.name,pack.CardCount.." PLAYERS  /  UNOPENED",pack.description or "VTR player pack","OPEN PACK",function() openOwned(pack) end) end end
			elseif selectedTab=="Store Packs" then for _,id in storeOrder do local definition=Catalog.Packs[id];row(definition.Name,definition.CardCount.." PLAYER CARDS",oddsFor(definition).."  /  ◈ "..definition.PriceCoins,"BUY PACK",function() context.Flow:Confirmation("BUY "..definition.Name,"The server will validate your coins and deliver a unique unopened pack instance.","BUY PACK",function() local purchased=LaunchService:Request("Purchase",{ItemType="Pack",Id=id});if not purchased.Success then toast(purchased.Message or "Purchase failed.","Error");return end;toast("Pack added to inventory.","Reward");refreshData();renderTab();if purchased.Data and purchased.Data.Pack then offerOpenNow(purchased.Data.Pack) end end) end) end
			elseif selectedTab=="Pack Odds" then for _,id in storeOrder do local definition=Catalog.Packs[id];row(definition.Name,definition.Description,oddsFor(definition),nil,nil) end
			else local history=packData.History or {};if #history==0 then local empty=text(list,"NO PACK HISTORY\n\nYour opened packs and best pulls will appear here.",UDim2.fromOffset(0,140),UDim2.new(1,0,0,90),13,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center else for _,entry in history do local best=entry.bestPull;local bestText=best and (best.rating.." "..best.position.."  "..best.name.."  /  "..string.upper(best.rarity)) or "BEST PULL UNAVAILABLE";row(entry.name,"OPENED  "..os.date("!%Y-%m-%d  %H:%M",entry.openedAt or 0),bestText,best and "VIEW PLAYER" or nil,best and function() context.OpenPlayerDetails(best.cardInstanceId) end or nil) end end end
		end
		for _,name in packTabs do local tab=Button.new({Text=string.upper(name),Variant=name==selectedTab and "Primary" or "Secondary",Size=UDim2.fromOffset(160,34),OnActivated=function() selectedTab=name;renderTab() end});tab.ZIndex=74;tab.Parent=tabBar;tabButtons[name]=tab end;renderTab()
	end

	local function openObjectivesHub()
		local progression=ProgressionService:Get()or context.Data.Progression;local selectedGroup="starter_journey";local groups={{"starter_journey","STARTER"},{"daily","DAILY"},{"weekly","WEEKLY"},{"milestone","MILESTONES"},{"loan_trials","LOAN PLAYERS"}}
		local overlay=Instance.new("TextButton");overlay.Name="ObjectivesHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.12;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="ObjectivesHub",Size=UDim2.fromOffset(900,580),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		text(hub,"OBJECTIVES",UDim2.fromOffset(24,16),UDim2.new(1,-150,0,34),22,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73;text(hub,"LIVE SERVER PROGRESS  /  REWARDS  /  LIMITED LOAN PLAYERS",UDim2.fromOffset(24,50),UDim2.new(1,-48,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(96,34),OnActivated=function()overlay:Destroy()end});close.Position=UDim2.new(1,-120,0,20);close.ZIndex=74;close.Parent=hub
		local tabBar=Instance.new("Frame");tabBar.BackgroundTransparency=1;tabBar.Position=UDim2.fromOffset(24,78);tabBar.Size=UDim2.new(1,-48,0,36);tabBar.ZIndex=73;tabBar.Parent=hub;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,7);tabLayout.Parent=tabBar
		local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,124);body.Size=UDim2.new(1,-48,1,-148);body.ZIndex=72;body.Parent=hub;local buttons={};local renderObjectives:()->()
		renderObjectives=function()
			for _,child in body:GetChildren()do child:Destroy()end;for id,button in buttons do Button.setPrimary(button,id==selectedGroup)end
			local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Size=UDim2.fromScale(1,1);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=3;list.ScrollBarImageColor3=Theme.Colors.Electric;list.ZIndex=73;list.Parent=body;local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,9);layout.Parent=list
			local count=0;for _,objective in progression.Objectives or{}do if objective.groupId==selectedGroup then count+=1;local row=Panel.new({Name=objective.objectiveId,Size=UDim2.new(1,-6,0,102)});row.ZIndex=74;row.Parent=list;text(row,objective.title,UDim2.fromOffset(18,10),UDim2.new(1,-230,0,24),14,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75;text(row,objective.description,UDim2.fromOffset(18,37),UDim2.new(1,-230,0,17),8,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=75;local reward=objective.reward or{};text(row,string.upper(objective.status).."  /  "..objective.progress.." / "..objective.target.."  /  REWARD "..(reward.Amount or 1).." "..(reward.Type or"ITEM"),UDim2.fromOffset(18,62),UDim2.new(1,-230,0,18),8,objective.status=="claimable"and Theme.Colors.Electric or Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
				if objective.status=="claimable"then local claim=Button.new({Text="CLAIM REWARD",Variant="Primary",Size=UDim2.fromOffset(170,38),OnActivated=function()local result=ProgressionService:Claim("Objective",objective.objectiveId);if result.Success then toast(result.Message or"Reward claimed.","Reward");progression=ProgressionService:Get()or progression;renderObjectives()else toast(result.Message or"Claim rejected.","Error")end end});claim.Position=UDim2.new(1,-190,.5,-19);claim.ZIndex=76;claim.Parent=row end
			end end
			if count==0 then local empty=text(list,"NO OBJECTIVES IN THIS GROUP",UDim2.fromOffset(0,140),UDim2.new(1,0,0,40),14,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center end
		end
		for _,entry in groups do local id,labelValue=entry[1],entry[2];local tab=Button.new({Text=labelValue,Variant=id==selectedGroup and"Primary"or"Secondary",Size=UDim2.fromOffset(145,34),OnActivated=function()selectedGroup=id;renderObjectives()end});tab.ZIndex=74;tab.Parent=tabBar;buttons[id]=tab end;renderObjectives()
	end

	local function openTacticsHub()
		local overlay=Instance.new("TextButton");overlay.Name="TacticsHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.1;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="TacticsHub",Size=UDim2.fromOffset(1120,650),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		text(hub,"TACTICS",UDim2.fromOffset(24,16),UDim2.new(1,-150,0,34),22,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73
		text(hub,"SQUAD FORMATION  /  AI IDENTITY  /  MATCH BEHAVIOR",UDim2.fromOffset(24,50),UDim2.new(1,-48,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(96,34),OnActivated=function()overlay:Destroy()end});close.Position=UDim2.new(1,-120,0,20);close.ZIndex=74;close.Parent=hub
		local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,88);body.Size=UDim2.new(1,-48,1,-112);body.ZIndex=72;body.Parent=hub
		local pitch=Panel.new({Name="TacticsPitch",Position=UDim2.fromOffset(0,0),Size=UDim2.new(.32,-8,1,0),Color=Theme.Colors.Pitch,ClipsDescendants=true});pitch.ZIndex=73;pitch.Parent=body
		local controls=Panel.new({Name="TacticsControls",Position=UDim2.new(.32,8,0,0),Size=UDim2.new(.68,-8,1,0),ClipsDescendants=true});controls.ZIndex=73;controls.Parent=body
		local function saveTactics():boolean
			local result=LaunchService:Request("SaveTeamTactics",tactics)
			if not result.Success then toast(result.Message or"Could not save AI tactics.","Error");return false end
			if result.Data and result.Data.TeamTactics then tactics=result.Data.TeamTactics end
			toast(result.Message or"AI tactics saved.","Reward")
			return true
		end
		local function renderHub()
			for _,child in pitch:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
			for _,child in controls:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
			text(pitch,string.upper(snapshot.Formation or"4-3-3"),UDim2.fromOffset(20,18),UDim2.new(1,-40,0,36),24,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75
			text(pitch,"STARTING XI SHAPE",UDim2.fromOffset(22,55),UDim2.new(1,-44,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=75
			local field=Instance.new("Frame");field.BackgroundTransparency=1;field.Position=UDim2.fromOffset(42,92);field.Size=UDim2.new(1,-84,1,-132);field.ZIndex=74;field.Parent=pitch
			local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Border;stroke.Thickness=2;stroke.Transparency=.18;stroke.Parent=field
			local half=Instance.new("Frame");half.BackgroundColor3=Theme.Colors.Border;half.BackgroundTransparency=.28;half.BorderSizePixel=0;half.Position=UDim2.fromScale(0,.5);half.Size=UDim2.new(1,0,0,2);half.ZIndex=75;half.Parent=field
			local dots=FORMATION_DOTS[snapshot.Formation or"4-3-3"] or FORMATION_DOTS["4-3-3"]
			for index,dot in dots do
				local node=Instance.new("Frame");node.AnchorPoint=Vector2.new(.5,.5);node.Position=UDim2.fromScale(dot[1],dot[2]);node.Size=UDim2.fromOffset(index==1 and 24 or 18,index==1 and 24 or 18);node.BackgroundColor3=index==1 and Theme.Colors.Electric or Theme.Colors.White;node.BorderSizePixel=0;node.ZIndex=76;node.Parent=field
				local round=Instance.new("UICorner");round.CornerRadius=UDim.new(1,0);round.Parent=node
			end
			text(controls,"FORMATION",UDim2.fromOffset(22,18),UDim2.new(1,-44,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
			local formationRow=Instance.new("Frame");formationRow.BackgroundTransparency=1;formationRow.Position=UDim2.fromOffset(22,42);formationRow.Size=UDim2.new(1,-44,0,82);formationRow.ZIndex=74;formationRow.Parent=controls
			local formationGrid=Instance.new("UIGridLayout");formationGrid.CellSize=UDim2.new(.25,-7,0,34);formationGrid.CellPadding=UDim2.fromOffset(9,9);formationGrid.Parent=formationRow
			for _,name in snapshot.FormationOptions or{"4-3-3","4-4-2","4-2-3-1","3-5-2","5-3-2"}do
				local option=Button.new({Text=name,Variant=name==snapshot.Formation and"Primary"or"Secondary",Size=UDim2.new(1,0,1,0),OnActivated=function()setFormationInstant(name);task.defer(renderHub)end});option.ZIndex=76;option.Parent=formationRow
			end
			text(controls,"AI IDENTITY",UDim2.fromOffset(22,142),UDim2.new(1,-44,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
			local presetRow=Instance.new("Frame");presetRow.BackgroundTransparency=1;presetRow.Position=UDim2.fromOffset(22,166);presetRow.Size=UDim2.new(1,-44,0,96);presetRow.ZIndex=74;presetRow.Parent=controls
			local presetGrid=Instance.new("UIGridLayout");presetGrid.CellSize=UDim2.new(1/3,-8,0,34);presetGrid.CellPadding=UDim2.fromOffset(10,9);presetGrid.Parent=presetRow
			for _,preset in TACTIC_PRESETS do
				local option=Button.new({Text=string.upper(preset),Variant=tactics.Identity==preset and"Primary"or"Secondary",Size=UDim2.new(1,0,1,0),OnActivated=function()
					tactics.Identity=preset
					local values=LiteConfig.TacticPresets[preset]or LiteConfig.TacticPresets.Balanced
					for index,name in LiteConfig.TacticSliderNames do tactics.Sliders[name]=values[index]end
					renderHub()
				end});option.ZIndex=76;option.Parent=presetRow
			end
			text(controls,"BEHAVIOR SETTINGS",UDim2.fromOffset(22,284),UDim2.new(1,-44,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
			local sliderList=Instance.new("ScrollingFrame");sliderList.BackgroundTransparency=1;sliderList.BorderSizePixel=0;sliderList.Position=UDim2.fromOffset(22,310);sliderList.Size=UDim2.new(1,-44,1,-370);sliderList.AutomaticCanvasSize=Enum.AutomaticSize.Y;sliderList.CanvasSize=UDim2.new();sliderList.ScrollBarThickness=4;sliderList.ScrollBarImageColor3=Theme.Colors.Electric;sliderList.ZIndex=74;sliderList.Parent=controls
			local categories:any={
				{"BUILD UP",{"BuildUpSpeed","PassTempo","PassingDirectness","SupportDistance","ForwardPassPriority","BackPassSafety","SwitchPlayFrequency","ThroughBallFrequency","PassRisk","OneTouchPassing","FirstTouchDirectness","ReceiverTrapAggression"}},
				{"ATTACK",{"AttackingWidth","WidthDiscipline","RunsInBehind","OverlapFrequency","UnderlapFrequency","FullbackAttack","MidfieldRotation","BoxRuns","CrossingFrequency","CutbackFrequency","FinalThirdPatience","ShotPatience","LongShotFrequency","DribblingFreedom","CreativeFreedom","CounterAttackFrequency"}},
				{"DEFENSE",{"DefensiveWidth","DefensiveDepth","DefensiveLineStepUp","PressingIntensity","PressTriggerDistance","CounterPress","TackleAggression","InterceptionRisk","MarkingTightness","LaneBlocking","BackLineCompactness","BoxProtection","ZoneDiscipline","LooseBallAggression","RecoveryRuns","SprintConservation","StaminaPressLimit"}},
				{"GOALKEEPER + SET PIECES",{"KeeperAggression","KeeperDistributionRisk","ShortGKDistribution","LongGKDistribution","FreeKickShortPass","FreeKickLongPass","CornerNearPost","CornerFarPost","SetPiecePatience","ClearanceHeight","RiskLevel"}},
			}
			local y=0
			local function drawSlider(name:string,row:number,column:number)
				local value=tonumber(tactics.Sliders[name])or 50
				local xScale=column==1 and 0 or .5
				local xPad=column==1 and 0 or 10
				local rowFrame=Instance.new("Frame");rowFrame.BackgroundTransparency=1;rowFrame.Position=UDim2.new(xScale,xPad,0,row);rowFrame.Size=UDim2.new(.5,-10,0,34);rowFrame.ZIndex=75;rowFrame.Parent=sliderList
				text(rowFrame,string.upper(name:gsub("(%u)"," %1")),UDim2.fromOffset(0,0),UDim2.new(1,-92,0,16),7,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=76
				local bar=Instance.new("Frame");bar.BackgroundColor3=Theme.Colors.Gunmetal;bar.BorderSizePixel=0;bar.Position=UDim2.new(0,0,0,22);bar.Size=UDim2.new(1,-104,0,7);bar.ZIndex=76;bar.Parent=rowFrame
				local fill=Instance.new("Frame");fill.BackgroundColor3=Theme.Colors.Electric;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(value/100,1);fill.ZIndex=77;fill.Parent=bar
				local minus=Button.new({Text="-",Variant="Secondary",Size=UDim2.fromOffset(24,23),OnActivated=function()tactics.Sliders[name]=math.max(0,value-5);renderHub()end});minus.Position=UDim2.new(1,-98,0,9);minus.ZIndex=77;minus.Parent=rowFrame
				local valueText=text(rowFrame,tostring(value),UDim2.new(1,-68,0,10),UDim2.fromOffset(32,20),8,Theme.Colors.Electric,Theme.Fonts.Display);valueText.TextXAlignment=Enum.TextXAlignment.Center;valueText.ZIndex=77
				local plus=Button.new({Text="+",Variant="Secondary",Size=UDim2.fromOffset(24,23),OnActivated=function()tactics.Sliders[name]=math.min(100,value+5);renderHub()end});plus.Position=UDim2.new(1,-26,0,9);plus.ZIndex=77;plus.Parent=rowFrame
			end
			for _,category in categories do
				text(sliderList,category[1],UDim2.fromOffset(0,y),UDim2.new(1,0,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=76
				y+=24
				for index,name in category[2]do
					local row=y+math.floor((index-1)/2)*40
					drawSlider(name,row,((index-1)%2)+1)
				end
				y+=math.ceil(#category[2]/2)*40+16
			end
			local bottomPad=Instance.new("Frame");bottomPad.BackgroundTransparency=1;bottomPad.Position=UDim2.fromOffset(0,y);bottomPad.Size=UDim2.new(1,0,0,8);bottomPad.Parent=sliderList
			local save=Button.new({Text="SAVE TACTICS",Variant="Primary",Size=UDim2.fromOffset(180,40),OnActivated=saveTactics});save.Position=UDim2.new(1,-202,1,-58);save.ZIndex=76;save.Parent=controls
		end
		renderHub()
	end

	for _,name in TABS do local tab=Button.new({Text=string.upper(name),Variant=name==activeTab and "Primary" or "Secondary",Size=UDim2.fromOffset(126,32),OnActivated=function() activeTab=name;renderTray() end});tab.Parent=tabBar;tabButtons[name]=tab end
	local shortcuts=Instance.new("Frame");shortcuts.BackgroundTransparency=1;shortcuts.Position=UDim2.new(1,-626,0,18);shortcuts.Size=UDim2.fromOffset(626,34);shortcuts.Parent=scroll;local shortcutLayout=Instance.new("UIListLayout");shortcutLayout.FillDirection=Enum.FillDirection.Horizontal;shortcutLayout.Padding=UDim.new(0,6);shortcutLayout.Parent=shortcuts
	local squadShortcut=Button.new({Text="SQUAD BUILDER",Variant="Primary",Size=UDim2.fromOffset(116,34),OnActivated=function()toast("Squad Builder is active.")end});squadShortcut.Parent=shortcuts
	local tacticsButton=Button.new({Text="TACTICS",Variant="Secondary",Size=UDim2.fromOffset(116,34),OnActivated=openTacticsHub});tacticsButton.Parent=shortcuts
	local packsButton=Button.new({Text="PACKS",Variant="Secondary",Size=UDim2.fromOffset(116,34),OnActivated=openPackHub});packsButton.Parent=shortcuts
	local playersButton=Button.new({Text="PLAYER INVENTORY",Variant="Secondary",Size=UDim2.fromOffset(132,34),OnActivated=function()context.Data.UIState.SelectedTabs.Inventory="Players";context.StateService:SetTab("Inventory","Players");context.Navigate("Inventory")end});playersButton.Parent=shortcuts
	local objectivesButton=Button.new({Text="OBJECTIVES",Variant="Secondary",Size=UDim2.fromOffset(116,34),OnActivated=openObjectivesHub});objectivesButton.Parent=shortcuts
	renderAll()
	return group
end

return UltimateTeamPage
