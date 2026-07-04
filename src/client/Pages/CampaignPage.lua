local MATCHUP_PANEL_DELAY = 0.85
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local LiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local ClubIdentityConfig=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local PageBase=require(script.Parent.PageBase)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local ProgressBar=require(script.Parent.Parent.Components.ProgressBar)
local MatchSetupService=require(script.Parent.Parent.Services.MatchSetupService)
local MatchPresentation=require(script.Parent.Parent.Components.MatchPresentation)

local Page={}

local FORMATIONS={"4-3-3","4-2-3-1","4-4-2","3-5-2","5-3-2"}
local TACTICS={"Balanced","Possession","Counter Attack","High Press","Wing Play","Direct Long Ball","Low Block"}

local function label(parent:Instance,value:string,pos:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel
	local item=Instance.new("TextLabel");item.BackgroundTransparency=1;item.Position=pos;item.Size=size;item.Text=value;item.TextColor3=color;item.TextSize=textSize;item.Font=font;item.TextXAlignment=Enum.TextXAlignment.Left;item.Parent=parent;return item
end

function Page.new(context:any):CanvasGroup
	local group,scroll=PageBase.new("Campaign",900)
	PageBase.heading(scroll,"OFFLINE CAMPAIGN","CAMPAIGN","Pick an AI opponent. Your saved Ultimate Team plays as the home side with your club badge, kit and tactics.")
	local progress=context.Data.Progression.CampaignProgress or {UnlockedDifficulty=1,CompletedTeams={}}
	local configResponse=MatchSetupService:GetConfig()
	local matchConfig=configResponse.Success and configResponse.Data or nil
	if not matchConfig then
		label(scroll,"MATCH CONFIG UNAVAILABLE\n"..(configResponse.Message or"Restart Play mode and try again."),UDim2.fromOffset(0,150),UDim2.new(1,0,0,100),18,Theme.Colors.Danger,Theme.Fonts.Display).TextXAlignment=Enum.TextXAlignment.Center
		return group
	end
	local countries=matchConfig.Countries or{}
	local englandLeague=""
	for _,country in countries do
		if country.Country=="England"then englandLeague=(country.Leagues and country.Leagues[1])or"";break end
	end
	local teamResponse=MatchSetupService:GetTeams("England",englandLeague)
	local campaignTeams=teamResponse.Success and teamResponse.Data or matchConfig.Teams or{}
	if #campaignTeams<2 then campaignTeams=matchConfig.Teams or campaignTeams end
	local function teamByIndex(index:number):any
		return campaignTeams[((index-1)%math.max(1,#campaignTeams))+1] or (matchConfig.Teams and matchConfig.Teams[1])
	end
	local function teamById(id:string):any?
		for _,team in campaignTeams do if team.teamId==id then return team end end
		for _,team in matchConfig.Teams or{}do if team.teamId==id then return team end end
		return nil
	end
	local homeTeam=teamById(matchConfig.Setup.HomeTeamId) or (matchConfig.Teams and matchConfig.Teams[1]) or teamByIndex(1)
	local identity=(context.Data.PlayerProfile and context.Data.PlayerProfile.ClubIdentity) or (context.Data.Progression and context.Data.Progression.ClubMembership) or {}
	local primary=ClubIdentityConfig.ResolveColor(identity.PrimaryColor)
	local secondary=ClubIdentityConfig.ResolveColor(identity.SecondaryColor)
	local accent=ClubIdentityConfig.ResolveColor(identity.AccentColor)
	local clubName=identity.Name;if type(clubName)~="string"or clubName==""or clubName=="NO CLUB"then clubName=(context.Data.PlayerProfile and context.Data.PlayerProfile.DisplayName or"YOUR").." XI"end
	local abbreviation=identity.Abbreviation;if type(abbreviation)~="string"or#abbreviation<2 then abbreviation=string.upper(string.sub(tostring(clubName):gsub("[^%a]",""),1,3));if abbreviation==""then abbreviation="VTR"end end
	local displayHome=table.clone(homeTeam or{})
	displayHome.teamId="ultimate_team_preview";displayHome.teamName=clubName;displayHome.country="VTR UNIVERSE";displayHome.league="SQUAD BUILDER";displayHome.logo=string.upper(abbreviation);displayHome.colors={Primary=primary,Secondary=secondary,Accent=accent};displayHome.BadgeIdentity={PrimaryColor=primary,SecondaryColor=secondary,AccentColor=accent,BadgePreset=identity.BadgePreset or"Modern",BadgeShape=identity.BadgeShape or"Shield",BadgeSymbol=identity.BadgeSymbol or"Lightning Bolt",BadgeColorBehavior=identity.BadgeColorBehavior or"Tri Color"};displayHome.badgeIdentity=displayHome.BadgeIdentity;displayHome.kits={Home={Name="Home",Primary=primary,Secondary=secondary,Accent=accent,Style=ClubIdentityConfig.ResolveStyle(identity.KitStyle),NumberColor=accent},Away={Name="Away",Primary=secondary,Secondary=primary,Accent=accent,Style=ClubIdentityConfig.ResolveStyle(identity.KitStyle),NumberColor=accent}};displayHome.badgePreset=identity.BadgeShape or identity.BadgePreset or"Shield"
	local savedTactics=context.Data.Progression.TeamTactics or LiteConfig.DefaultTactics()
	local unlocked=tonumber(progress.UnlockedDifficulty)or 1
	local ladder=Panel.new({Name="DifficultyLadder",Position=UDim2.fromOffset(0,96),Size=UDim2.new(.25,-8,0,640)});ladder.Parent=scroll
	label(ladder,"DIFFICULTY LADDER",UDim2.fromOffset(18,14),UDim2.new(1,-36,0,24),13,Theme.Colors.Electric,Theme.Fonts.Strong)
	local selectedIndex=math.clamp(unlocked,1,#LiteConfig.CampaignDifficulties)
	local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.new(.25,8,0,96);body.Size=UDim2.new(.75,-8,0,640);body.Parent=scroll
	local function render()
		for _,child in ladder:GetChildren()do if child:IsA("GuiObject")and child.Name=="TierButton"then child:Destroy()end end
		for _,child in body:GetChildren()do child:Destroy()end
		local tierStartY=58
		local tierRowHeight=76
		local tierButtonHeight=52
		for index,tier in LiteConfig.CampaignDifficulties do
			local locked=index>unlocked
			local tierY=tierStartY+(index-1)*tierRowHeight
			local button=Button.new({Text=string.upper(tier.Name),Variant=index==selectedIndex and"Primary"or"Secondary",Size=UDim2.new(1,-36,0,tierButtonHeight),OnActivated=function()if not locked then selectedIndex=index;render()end end})
			button.Name="TierButton";button.Position=UDim2.fromOffset(18,tierY);button.Parent=ladder
			if locked then button.Text=string.upper(tier.Name).."  LOCKED"end
			local rewardMeta=label(ladder,tier.Range[1].."-"..tier.Range[2].." OVR  /  "..tier.Reward,UDim2.fromOffset(24,tierY+tierButtonHeight+6),UDim2.new(1,-48,0,14),8,locked and Theme.Colors.Muted or Theme.Colors.Silver,Theme.Fonts.Strong)
			rewardMeta.Name="TierButton"
			rewardMeta.TextYAlignment=Enum.TextYAlignment.Center
		end
		local tier=LiteConfig.CampaignDifficulties[selectedIndex]
		local header=Panel.new({Name="CampaignTier",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,118)});header.Parent=body
		label(header,string.upper(tier.Name),UDim2.fromOffset(20,14),UDim2.new(.48,0,0,34),25,Theme.Colors.White,Theme.Fonts.Display)
		label(header,"AI SQUAD OVR "..tier.Range[1].." - "..tier.Range[2].."  /  REWARD "..string.upper(tier.Reward),UDim2.fromOffset(22,55),UDim2.new(.7,0,0,20),10,Theme.Colors.Electric,Theme.Fonts.Strong)
		local completed=0;for teamId,done in progress.CompletedTeams or{}do if done and string.find(tostring(teamId),tier.Id,1,true)then completed+=1 end end
		local bar=ProgressBar.new(completed/5);bar.Position=UDim2.new(.68,0,0,48);bar.Size=UDim2.new(.27,0,0,7);bar.Parent=header
		label(header,completed.." / 5 SQUADS BEATEN",UDim2.new(.68,0,0,62),UDim2.new(.27,0,0,18),8,Theme.Colors.Silver,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Right
		local squadGrid=Instance.new("Frame");squadGrid.BackgroundTransparency=1;squadGrid.Position=UDim2.fromOffset(0,132);squadGrid.Size=UDim2.new(1,0,1,-132);squadGrid.Parent=body
		local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(.5,-8,0,154);grid.CellPadding=UDim2.fromOffset(12,12);grid.Parent=squadGrid
		for squad=1,5 do
			local card=Panel.new({Name="AISquad"..squad});card.Parent=squadGrid
			local opponent=teamByIndex((selectedIndex-1)*5+squad)
			if opponent and homeTeam and opponent.teamId==homeTeam.teamId then opponent=teamByIndex((selectedIndex-1)*5+squad+1)end
			local overall=math.clamp(tier.Range[1]+((squad*7)%math.max(1,tier.Range[2]-tier.Range[1]+1)),tier.Range[1],tier.Range[2])
			local formation=FORMATIONS[((selectedIndex+squad-2)%#FORMATIONS)+1]
			local tactic=TACTICS[((selectedIndex*2+squad-2)%#TACTICS)+1]
			local teamId=tier.Id.."_"..squad
			local beaten=progress.CompletedTeams and progress.CompletedTeams[teamId]==true
			if beaten then
				card.BackgroundColor3=Color3.fromHex("16351A")
				local stroke=card:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color=Theme.Colors.Electric;stroke.Transparency=.22 end
			end
			label(card,(beaten and"CLEARED  "or"")..(opponent and string.upper(opponent.teamName) or("AI SQUAD "..squad)),UDim2.fromOffset(16,14),UDim2.new(1,-32,0,26),17,Theme.Colors.White,Theme.Fonts.Display)
			label(card,"OVR "..(opponent and opponent.overall or overall).."  /  "..formation.."  /  "..string.upper(tactic),UDim2.fromOffset(16,44),UDim2.new(1,-32,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong)
			label(card,(beaten and"REPLAY RUN  NO REWARDS\n"or"YOUR TEAM VS AI\n").."SAVED PLAN  "..string.upper(tostring(savedTactics.Identity or"Balanced")).."\nOPPONENT  "..(opponent and string.upper(opponent.country or"ENGLAND")or"ENGLAND"),UDim2.fromOffset(16,70),UDim2.new(1,-32,0,42),8,Theme.Colors.Silver,Theme.Fonts.Body).TextWrapped=true
			local play=Button.new({Text=beaten and"REPLAY"or"WATCH",Variant="Primary",Size=UDim2.fromOffset(118,34),OnActivated=function()
				if not opponent or not homeTeam then context.Toast({Title="CAMPAIGN",Message="Campaign teams unavailable.",Kind="Error"});return end
				local setup=table.clone(matchConfig.Setup)
				setup.HomeTeamId=homeTeam.teamId;setup.AwayTeamId=opponent.teamId;setup.HomeKit="Home";setup.AwayKit=setup.HomeTeamId==setup.AwayTeamId and"Away"or"Away";setup.MatchType=setup.HomeTeamId==setup.AwayTeamId and"Friendly"or"Objective Match";setup.Difficulty=tier.Name=="Street Level"and"Amateur"or tier.Name=="Local League"and"Semi Pro"or tier.Name=="Regional Pro"and"Professional"or tier.Name=="National Class"and"World Class"or"Legendary"
				setup.CampaignTeamId=teamId;setup.CampaignTier=selectedIndex;setup.CampaignReplay=beaten
				local saved=MatchSetupService:Save(setup)
				if not saved.Success then context.Toast({Title="CAMPAIGN",Message=saved.Message or"Could not save match setup.",Kind="Error"});return end
				setup=saved.Data;setup.StadiumName="VOLTRA CAMPAIGN"
				context.Toast({Title="CAMPAIGN",Message=(beaten and"Replay starting vs "or"Watch match starting vs ")..opponent.teamName..".",Kind="Info"})
				MatchPresentation.play(context.Root or group,setup,displayHome,opponent,function()context.Navigate("Home")end,function(message:string,kind:string)context.Toast({Title="CAMPAIGN",Message=message,Kind=kind})end,true)
			end})
			play.Position=UDim2.fromOffset(16,112);play.Parent=card
		end
	end
	render()
	return group
end

return Page
