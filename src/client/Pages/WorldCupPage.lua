--!strict

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local MarketplaceService=game:GetService("MarketplaceService")
local RunService=game:GetService("RunService")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local WorldCupConfig=require(ReplicatedStorage.VTR.Shared.WorldCupConfig)
local PageBase=require(script.Parent.PageBase)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local MatchSetupService=require(script.Parent.Parent.Services.MatchSetupService)

local Page={}
local seenKnockoutIntroByRun:{[string]:boolean}={}
local seenTournamentCompleteByRun:{[string]:boolean}={}
local WORLD_CUP_ICON="rbxassetid://104590993555982"
local SIM_KICKOFF_SOUND="rbxassetid://99361731737732"
local SIM_FINAL_WHISTLE_SOUND="rbxassetid://116302042443605"
local SIM_AMBIENCE_SOUND="rbxassetid://114836843250240"
local SIM_GOAL_SOUND="rbxassetid://75642333208760"

local function wcCode(country:string):string
	return string.upper(string.sub((country or""):gsub("[^%a]",""),1,3))
end

local function text(parent:Instance,value:string,pos:UDim2,size:UDim2,textSize:number,color:Color3?,font:Enum.Font?):TextLabel
	local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=pos;label.Size=size;label.Text=value;label.TextColor3=color or Theme.Colors.White;label.TextSize=textSize;label.Font=font or Theme.Fonts.Body;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Center;label.TextWrapped=true;label.Parent=parent;return label
end

local function corner(parent:Instance,radius:number)
	local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,radius);c.Parent=parent
end

local function flag(parent:Instance,country:string,pos:UDim2,size:UDim2)
	local image=Instance.new("ImageLabel");image.BackgroundColor3=Theme.Colors.Gunmetal;image.BorderSizePixel=0;image.Image=WorldCupConfig.Flag(country);image.Position=pos;image.Size=size;image.ScaleType=Enum.ScaleType.Crop;image.Parent=parent;corner(image,4);return image
end

local function setDangerButton(button:TextButton,danger:boolean)
	button:SetAttribute("VTRDanger",danger)
	button:SetAttribute("VTRPrimary",false)
	button.BackgroundColor3=danger and Theme.Colors.Danger or Theme.Colors.Gunmetal
	button.TextColor3=Theme.Colors.White
	local stroke=button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color=danger and Theme.Colors.Danger or Theme.Colors.Border
		stroke.Transparency=danger and .18 or 0
	end
end

local function circleFlag(parent:Instance,country:string,pos:UDim2,size:number,selected:boolean?):ImageLabel
	local image=flag(parent,country,pos,UDim2.fromOffset(size,size))
	image.Name="Flag_"..country:gsub("%W","")
	image.BackgroundColor3=selected and Theme.Colors.Electric or Theme.Colors.White
	image.ZIndex=5
	local existing=image:FindFirstChildOfClass("UICorner");if existing then existing.CornerRadius=UDim.new(1,0)end
	local stroke=Instance.new("UIStroke");stroke.Color=selected and Theme.Colors.Electric or Theme.Colors.Border;stroke.Thickness=selected and 3 or 1;stroke.Transparency=selected and 0 or .25;stroke.Parent=image
	return image
end

local function line(parent:Instance,pos:UDim2,size:UDim2)
	local item=Instance.new("Frame");item.BackgroundColor3=Theme.Colors.Silver;item.BackgroundTransparency=.15;item.BorderSizePixel=0;item.Position=pos;item.Size=size;item.ZIndex=2;item.Parent=parent;return item
end

local function statLine(parent:Instance,index:number,country:string,standing:any,selected:string?)
	local row=Instance.new("Frame");row.BackgroundColor3=country==selected and Theme.Colors.Electric or Theme.Colors.Raised;row.BackgroundTransparency=country==selected and 0 or .18;row.BorderSizePixel=0;row.Position=UDim2.fromOffset(10,72+(index-1)*35);row.Size=UDim2.new(1,-20,0,30);row.Parent=parent;corner(row,5)
	text(row,tostring(index),UDim2.fromOffset(8,0),UDim2.fromOffset(18,30),9,country==selected and Theme.Colors.Black or Theme.Colors.Muted,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Center
	flag(row,country,UDim2.fromOffset(30,5),UDim2.fromOffset(28,20))
	text(row,string.upper(country),UDim2.fromOffset(64,0),UDim2.new(1,-268,1,0),9,country==selected and Theme.Colors.Black or Theme.Colors.White,Theme.Fonts.Strong)
	local values={
		standing and standing.P or 0,
		standing and standing.W or 0,
		standing and standing.D or 0,
		standing and standing.L or 0,
		standing and standing.GD or 0,
		standing and standing.PTS or 0,
	}
	local startX=1
	local widths={24,24,24,24,34,34}
	local offset=0
	for valueIndex,value in ipairs(values)do
		local w=widths[valueIndex]
		local stats=text(row,tostring(value),UDim2.new(startX,-188+offset,0,0),UDim2.fromOffset(w,30),9,country==selected and Theme.Colors.Black or Theme.Colors.Silver,Theme.Fonts.Strong)
		stats.TextXAlignment=Enum.TextXAlignment.Center
		offset+=w+4
	end
end

local function rankedGroup(teams:any,standings:any):{string}
	local ranked=table.clone(teams or{})
	table.sort(ranked,function(a:string,b:string)
		local sa=standings and standings[a]or{}
		local sb=standings and standings[b]or{}
		if (sa.PTS or 0)~=(sb.PTS or 0)then return(sa.PTS or 0)>(sb.PTS or 0)end
		if (sa.GD or 0)~=(sb.GD or 0)then return(sa.GD or 0)>(sb.GD or 0)end
		if (sa.GF or 0)~=(sb.GF or 0)then return(sa.GF or 0)>(sb.GF or 0)end
		return tostring(a)<tostring(b)
	end)
	return ranked
end

local function renderGroupLeaderboard(parent:Instance,state:any,selected:string?)
	for _,child in parent:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
	text(parent,"YOUR GROUP LEADERBOARD",UDim2.fromOffset(12,8),UDim2.new(1,-24,0,22),14,Theme.Colors.White,Theme.Fonts.Display)
	local legend=text(parent,"P PLAYED   W WINS   D DRAWS   L LOSSES   GD GOAL DIFFERENCE   PTS POINTS",UDim2.fromOffset(12,31),UDim2.new(1,-24,0,18),7,Theme.Colors.Muted,Theme.Fonts.Strong)
	legend.TextWrapped=false
	local headers={{"#",8,18},{"NATION",64,92},{"P",-188,24},{"W",-160,24},{"D",-132,24},{"L",-104,24},{"GD",-76,34},{"PTS",-38,34}}
	for _,header in ipairs(headers)do
		local pos=type(header[2])=="number"and(header[2]>=0 and UDim2.fromOffset(header[2],52)or UDim2.new(1,header[2],0,52))or UDim2.fromOffset(0,52)
		local item=text(parent,tostring(header[1]),pos,UDim2.fromOffset(tonumber(header[3])or 24,16),7,Theme.Colors.Electric,Theme.Fonts.Strong)
		item.TextXAlignment=header[1]=="NATION"and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	end
	if state and state.UserGroup then
		local teams=rankedGroup(state.Groups and state.Groups[state.UserGroup]or{},state.Standings)
		for index,country in ipairs(teams)do statLine(parent,index,country,state.Standings and state.Standings[country],selected)end
	else
		local empty=text(parent,"NO DRAW YET",UDim2.fromOffset(12,82),UDim2.new(1,-24,0,32),16,Theme.Colors.Muted,Theme.Fonts.Display)
		empty.TextXAlignment=Enum.TextXAlignment.Center
	end
end

local function renderWorldCupTicker(parent:Instance,state:any)
	local old=parent:FindFirstChild("TournamentTickerOverlay")
	if old then old:Destroy()end
	if not state then return end
	local overlay=Panel.new({Name="TournamentTickerOverlay",Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,1)})
	overlay.ZIndex=30
	overlay.Parent=parent
	local title=text(overlay,"WORLD CUP LIVE",UDim2.fromOffset(18,14),UDim2.new(1,-36,0,30),22,Theme.Colors.White,Theme.Fonts.Display);title.ZIndex=31
	local day=tonumber(state.GroupMatchIndex)or 1
	local stage=tostring(state.Stage or"GROUP")
	local sub=text(overlay,string.format("GAMEDAY %d  /  %s SIMULATION FEED",math.clamp(day,1,3),string.upper(stage)),UDim2.fromOffset(20,46),UDim2.new(1,-40,0,20),9,Theme.Colors.Electric,Theme.Fonts.Strong);sub.ZIndex=31
	local ticker=Instance.new("Frame");ticker.Name="TickerStrip";ticker.BackgroundColor3=Theme.Colors.Black;ticker.BackgroundTransparency=.08;ticker.BorderSizePixel=0;ticker.Position=UDim2.fromOffset(18,78);ticker.Size=UDim2.new(1,-36,0,42);ticker.ZIndex=31;ticker.Parent=overlay;corner(ticker,6)
	local latest=type(state.News)=="table"and state.News[1]or nil
	local function newsHeadline(item:any):string
		if type(item)=="table"then return tostring(item.Headline or item.Title or"World Cup update")end
		return tostring(item or"World Cup update")
	end
	local function newsSummary(item:any):string
		if type(item)=="table"then return tostring(item.Description or item.Summary or item.Headline or item.Title or"Match details are still coming in.")end
		return tostring(item or"Match details are still coming in.")
	end
	local function showNewsModal(item:any)
		local playerGui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then return end
		local old=playerGui:FindFirstChild("VTRWorldCupNewsModal")
		if old then old:Destroy()end
		local gui=Instance.new("ScreenGui");gui.Name="VTRWorldCupNewsModal";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=990;gui.Parent=playerGui
		local shade=Instance.new("CanvasGroup");shade.Name="Shade";shade.BackgroundColor3=Theme.Colors.Black;shade.BackgroundTransparency=.18;shade.BorderSizePixel=0;shade.Size=UDim2.fromScale(1,1);shade.ZIndex=990;shade.Parent=gui
		local panel=Panel.new({Name="NewsStory",Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.62,.58)});panel.AnchorPoint=Vector2.new(.5,.5);panel.ZIndex=991;panel.Parent=shade
		local home=type(item)=="table"and tostring(item.Home or item.TeamA or"")or""
		local away=type(item)=="table"and tostring(item.Away or item.TeamB or"")or""
		if home~=""then local f=flag(panel,home,UDim2.fromScale(.05,.12),UDim2.fromScale(.16,.22));f.ZIndex=992 end
		if away~=""then local f=flag(panel,away,UDim2.fromScale(.79,.12),UDim2.fromScale(.16,.22));f.ZIndex=992 end
		local headline=text(panel,string.upper(newsHeadline(item)),UDim2.fromScale(.22,.08),UDim2.fromScale(.56,.11),14,Theme.Colors.Silver,Theme.Fonts.Strong);headline.TextXAlignment=Enum.TextXAlignment.Center;headline.ZIndex=992
		local storyTitle=text(panel,string.upper(type(item)=="table"and tostring(item.Title or"MATCH STORY")or"MATCH STORY"),UDim2.fromScale(.12,.28),UDim2.fromScale(.76,.09),30,Theme.Colors.Electric,Theme.Fonts.Display);storyTitle.TextXAlignment=Enum.TextXAlignment.Center;storyTitle.ZIndex=992
		local body=text(panel,"",UDim2.fromScale(.10,.42),UDim2.fromScale(.80,.28),15,Theme.Colors.White,Theme.Fonts.Body);body.TextXAlignment=Enum.TextXAlignment.Center;body.TextYAlignment=Enum.TextYAlignment.Top;body.TextWrapped=true;body.ZIndex=992
		local close=Button.new({Text="CLOSE",Variant="Primary",Size=UDim2.fromOffset(180,42),OnActivated=function()
			if gui.Parent then gui:Destroy()end
		end})
		close.AnchorPoint=Vector2.new(.5,1);close.Position=UDim2.fromScale(.5,.92);close.ZIndex=993;close.Parent=panel
		local story=newsSummary(item)
		task.spawn(function()
			for index=1,#story do
				if not body.Parent then return end
				body.Text=string.sub(story,1,index)
				task.wait(index%3==0 and .012 or .006)
			end
		end)
	end
	local tickerText=text(ticker,string.upper(newsHeadline(latest or"GROUP DRAW COMPLETE  /  NEWS WILL UPDATE AFTER YOUR NEXT MATCH")),UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),10,Theme.Colors.Electric,Theme.Fonts.Strong);tickerText.ZIndex=32;tickerText.TextWrapped=false;tickerText.TextTruncate=Enum.TextTruncate.AtEnd
	local feed=Instance.new("ScrollingFrame");feed.Name="NewsFeed";feed.BackgroundTransparency=1;feed.BorderSizePixel=0;feed.Position=UDim2.fromOffset(18,136);feed.Size=UDim2.new(1,-36,1,-154);feed.AutomaticCanvasSize=Enum.AutomaticSize.Y;feed.CanvasSize=UDim2.new();feed.ScrollBarThickness=4;feed.ScrollBarImageColor3=Theme.Colors.Electric;feed.ZIndex=31;feed.Parent=overlay
	feed.Position=UDim2.fromOffset(18,136);feed.Size=UDim2.new(1,-36,1,-154)
	local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=feed
	local news=type(state.News)=="table"and state.News or{}
	if #news==0 then
		local row=Instance.new("Frame");row.BackgroundColor3=Theme.Colors.Raised;row.BackgroundTransparency=.12;row.BorderSizePixel=0;row.Size=UDim2.new(1,-4,0,66);row.ZIndex=32;row.Parent=feed;corner(row,6)
		local label=text(row,"SIMULATION NEWS WILL APPEAR AFTER GAMEDAY 1",UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),12,Theme.Colors.Silver,Theme.Fonts.Strong);label.ZIndex=33;label.TextXAlignment=Enum.TextXAlignment.Center
	else
		local selectedRow:TextButton?=nil
		for index,item in ipairs(news)do
			if index>10 then break end
			local row=Instance.new("TextButton");row.Text="";row.AutoButtonColor=true;row.BackgroundColor3=Theme.Colors.Raised;row.BackgroundTransparency=.14;row.BorderSizePixel=0;row.Size=UDim2.new(1,-4,0,62);row.ZIndex=32;row.Parent=feed;corner(row,6)
			local label=text(row,string.upper(newsHeadline(item)),UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),9,Theme.Colors.White,Theme.Fonts.Strong);label.ZIndex=33;label.TextWrapped=true
			row.Activated:Connect(function()
				if selectedRow and selectedRow.Parent then selectedRow.BackgroundColor3=Theme.Colors.Raised;selectedRow.BackgroundTransparency=.14;local old=selectedRow:FindFirstChildWhichIsA("TextLabel");if old then old.TextColor3=Theme.Colors.White end end
				selectedRow=row;row.BackgroundColor3=Theme.Colors.Electric;row.BackgroundTransparency=.02;label.TextColor3=Theme.Colors.Black
				tickerText.Text=string.upper(newsHeadline(item))
				showNewsModal(item)
			end)
		end
	end
end

local QUALIFY_ORANGE=Color3.fromHex("FF8A22")
local CUTOFF_RED=Color3.fromHex("E02020")

local function groupCard(parent:Instance,groupName:string,teams:any,selected:string?,standings:any?)
	local card=Panel.new({Name="Group"..groupName,Size=UDim2.fromScale(1,1)});card.Parent=parent
	local userGroup=table.find(teams or{},selected)~=nil
	local stroke=card:FindFirstChildOfClass("UIStroke")or Instance.new("UIStroke");stroke.Color=userGroup and Theme.Colors.Electric or Theme.Colors.Border;stroke.Thickness=userGroup and 3 or 1;stroke.Transparency=userGroup and 0 or .35;stroke.Parent=card
	text(card,"GROUP "..groupName,UDim2.fromOffset(12,8),UDim2.new(1,-88,0,18),12,userGroup and Theme.Colors.Electric or Theme.Colors.White,Theme.Fonts.Display)
	local ptsHeader=text(card,"PTS",UDim2.new(1,-48,0,8),UDim2.fromOffset(34,18),7,Theme.Colors.Muted,Theme.Fonts.Strong);ptsHeader.TextXAlignment=Enum.TextXAlignment.Center
	local ranked=rankedGroup(teams or{},standings)
	for index,country in ipairs(ranked)do
		local y=32+(index-1)*30
		local qualifies=index<=2
		local selectedRow=country==selected
		local row=Instance.new("Frame");row.BackgroundColor3=selectedRow and Theme.Colors.Electric or qualifies and QUALIFY_ORANGE or Theme.Colors.Black;row.BackgroundTransparency=selectedRow and 0 or qualifies and .06 or .25;row.BorderSizePixel=0;row.Position=UDim2.fromOffset(10,y);row.Size=UDim2.new(1,-20,0,24);row.Parent=card;corner(row,4)
		flag(row,country,UDim2.fromOffset(5,4),UDim2.fromOffset(24,16))
		local color=selectedRow and Theme.Colors.Black or qualifies and Theme.Colors.Black or Theme.Colors.White
		text(row,string.upper(country),UDim2.fromOffset(35,0),UDim2.new(1,-82,1,0),8,color,Theme.Fonts.Strong)
		local pts=standings and standings[country]and standings[country].PTS or 0
		local ptsLabel=text(row,tostring(pts),UDim2.new(1,-40,0,0),UDim2.fromOffset(34,24),9,color,Theme.Fonts.Display);ptsLabel.TextXAlignment=Enum.TextXAlignment.Center
		if index==2 then
			local cutoff=Instance.new("Frame");cutoff.Name="QualificationCutoff";cutoff.BackgroundColor3=CUTOFF_RED;cutoff.BorderSizePixel=0;cutoff.Position=UDim2.fromOffset(10,y+27);cutoff.Size=UDim2.new(1,-20,0,2);cutoff.Parent=card
		end
		row.BackgroundTransparency=1
		task.delay(index*.08,function()if row.Parent then TweenService:Create(row,TweenInfo.new(.28,Enum.EasingStyle.Quad),{BackgroundTransparency=selectedRow and 0 or qualifies and .06 or .25}):Play()end end)
	end
	return card
end

local function renderBracket(parent:Instance,state:any)
	for _,child in parent:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
	text(parent,"KNOCKOUT ROAD",UDim2.fromOffset(12,8),UDim2.new(1,-24,0,22),14,Theme.Colors.White,Theme.Fonts.Display)
	if not state or not state.Knockout then
		local empty=text(parent,"BRACKET UNLOCKS AFTER GROUP STAGE",UDim2.fromOffset(12,82),UDim2.new(1,-24,0,34),16,Theme.Colors.Muted,Theme.Fonts.Display)
		empty.TextXAlignment=Enum.TextXAlignment.Center
		return
	end
	local selected=state.SelectedCountry
	local nextFixture=state.NextFixture
	local roundName=WorldCupConfig.KnockoutRounds[tonumber(state.Knockout.Round)or 1]or"KNOCKOUT"
	local roundLabel=text(parent,string.upper(roundName),UDim2.new(1,-210,0,8),UDim2.fromOffset(190,22),10,Theme.Colors.Electric,Theme.Fonts.Strong)
	roundLabel.TextXAlignment=Enum.TextXAlignment.Right
	local rounds={}
	for _,history in ipairs(state.Knockout.History or{})do
		local round=tonumber(history.Round)
		if round then rounds[round]=history.Fixtures or{}end
	end
	rounds[tonumber(state.Knockout.Round)or 1]=state.Knockout.Fixtures or{}
	local function winnerOf(fixture:any):string?
		if fixture.Winner then return tostring(fixture.Winner)end
		local hg,ag=tonumber(fixture.HomeGoals),tonumber(fixture.AwayGoals)
		if not hg or not ag or hg==ag then return nil end
		return hg>ag and tostring(fixture.Home)or tostring(fixture.Away)
	end
	local function connector(x1:number,y1:number,x2:number,y2:number)
		local item=Instance.new("Frame");item.BackgroundColor3=Theme.Colors.White;item.BackgroundTransparency=.34;item.BorderSizePixel=0;item.ZIndex=1;item.Parent=parent
		if math.abs(x2-x1)>=math.abs(y2-y1)then
			item.Position=UDim2.new(math.min(x1,x2),0,y1,0);item.Size=UDim2.new(math.abs(x2-x1),0,0,2)
		else
			item.Position=UDim2.new(x1,0,math.min(y1,y2),0);item.Size=UDim2.new(0,2,math.abs(y2-y1),0)
		end
		return item
	end
	local function renderMatch(fixture:any,x:number,y:number,w:number,h:number,current:boolean)
		local winner=winnerOf(fixture)
		local box=Instance.new("Frame");box.BackgroundColor3=current and QUALIFY_ORANGE or Theme.Colors.Raised;box.BackgroundTransparency=current and .03 or .12;box.BorderSizePixel=0;box.Position=UDim2.new(x,0,y,0);box.Size=UDim2.new(w,0,0,h);box.ZIndex=5;box.Parent=parent;corner(box,6)
		local stroke=Instance.new("UIStroke");stroke.Color=current and QUALIFY_ORANGE or Theme.Colors.Border;stroke.Thickness=current and 2 or 1;stroke.Transparency=current and 0 or .35;stroke.Parent=box
		local teams={{tostring(fixture.Home or"TBD"),tonumber(fixture.HomeGoals)},{tostring(fixture.Away or"TBD"),tonumber(fixture.AwayGoals)}}
		for index,entry in ipairs(teams)do
			local country=entry[1]
			local score=entry[2]
			local rowY=index==1 and 5 or 26
			local f=flag(box,country,UDim2.fromOffset(6,rowY),UDim2.fromOffset(24,16));f.ZIndex=6
			local color=current and Theme.Colors.Black or country==selected and Theme.Colors.Electric or winner==country and Theme.Colors.White or Theme.Colors.Silver
			local name=text(box,wcCode(country),UDim2.fromOffset(35,rowY-1),UDim2.new(1,-58,0,18),7,color,Theme.Fonts.Strong);name.TextTruncate=Enum.TextTruncate.AtEnd;name.ZIndex=6
			local scoreLabel=text(box,score and tostring(score)or"",UDim2.new(1,-21,0,rowY-1),UDim2.fromOffset(15,18),8,color,Theme.Fonts.Display);scoreLabel.TextXAlignment=Enum.TextXAlignment.Center;scoreLabel.ZIndex=6
		end
		return{x=x,y=y,w=w,h=h,cx=x+w/2,cy=y,mid=y+(h/2)/430}
	end
	local roundLayouts={
		[1]={{.035,.14},{.035,.32},{.035,.50},{.035,.68},{.855,.14},{.855,.32},{.855,.50},{.855,.68}},
		[2]={{.225,.23},{.225,.59},{.660,.23},{.660,.59}},
		[3]={{.385,.41},{.505,.41}},
		[4]={{.445,.57}},
	}
	local cupIcon=Instance.new("ImageLabel");cupIcon.Name="WorldCupIcon";cupIcon.BackgroundTransparency=1;cupIcon.Image=WORLD_CUP_ICON;cupIcon.AnchorPoint=Vector2.new(.5,.5);cupIcon.Position=UDim2.fromScale(.5,.27);cupIcon.Size=UDim2.fromOffset(48,48);cupIcon.ZIndex=7;cupIcon.Parent=parent
	local sideLabels={
		{1,.035,.075,.13},
		{2,.225,.075,.13},
		{3,.385,.075,.12},
		{3,.505,.075,.12},
		{2,.660,.075,.13},
		{1,.855,.075,.13},
		{4,.445,.365,.12},
	}
	for _,item in ipairs(sideLabels)do
		local round=item[1]
		local label=WorldCupConfig.KnockoutRounds[round]or("ROUND "..round)
		local roundText=text(parent,string.upper(label),UDim2.new(item[2],0,item[3],0),UDim2.new(item[4],0,0,16),7,round==4 and Theme.Colors.Electric or Theme.Colors.Muted,Theme.Fonts.Strong)
		roundText.TextXAlignment=Enum.TextXAlignment.Center
	end
	local rendered:{[number]:{any}}={}
	for round=1,4 do
		local fixtures=rounds[round]or{}
		rendered[round]={}
		for index,fixture in ipairs(fixtures)do
			local pos=roundLayouts[round]and roundLayouts[round][index]
			if not pos then continue end
			local current=(nextFixture and fixture.Home==nextFixture.Home and fixture.Away==nextFixture.Away)or false
			local width=round==1 and .105 or round==2 and .115 or round==3 and .112 or .11
			rendered[round][index]=renderMatch(fixture,pos[1],pos[2],width,42,current)
		end
	end
	local function join(left:any,right:any)
		if not left or not right then return end
		local x1=left.x+left.w
		local y1=left.y+.053
		local x2=right.x
		local y2=right.y+.053
		local mid=math.min(x2-.015,math.max(x1+.015,(x1+x2)/2))
		connector(x1,y1,mid,y1);connector(mid,y1,mid,y2);connector(mid,y2,x2,y2)
	end
	local function joinRight(left:any,right:any)
		if not left or not right then return end
		local x1=left.x
		local y1=left.y+.053
		local x2=right.x+right.w
		local y2=right.y+.053
		local mid=math.max(x2+.015,math.min(x1-.015,(x1+x2)/2))
		connector(x1,y1,mid,y1);connector(mid,y1,mid,y2);connector(mid,y2,x2,y2)
	end
	join(rendered[1]and rendered[1][1],rendered[2]and rendered[2][1]);join(rendered[1]and rendered[1][2],rendered[2]and rendered[2][1])
	join(rendered[1]and rendered[1][3],rendered[2]and rendered[2][2]);join(rendered[1]and rendered[1][4],rendered[2]and rendered[2][2])
	joinRight(rendered[1]and rendered[1][5],rendered[2]and rendered[2][3]);joinRight(rendered[1]and rendered[1][6],rendered[2]and rendered[2][3])
	joinRight(rendered[1]and rendered[1][7],rendered[2]and rendered[2][4]);joinRight(rendered[1]and rendered[1][8],rendered[2]and rendered[2][4])
	join(rendered[2]and rendered[2][1],rendered[3]and rendered[3][1]);join(rendered[2]and rendered[2][2],rendered[3]and rendered[3][1])
	joinRight(rendered[2]and rendered[2][3],rendered[3]and rendered[3][2]);joinRight(rendered[2]and rendered[2][4],rendered[3]and rendered[3][2])
	join(rendered[3]and rendered[3][1],rendered[4]and rendered[4][1]);joinRight(rendered[3]and rendered[3][2],rendered[4]and rendered[4][1])
	if nextFixture then
		local hint=text(parent,"ORANGE = CURRENT MATCH",UDim2.new(.5,-95,1,-28),UDim2.fromOffset(190,18),8,QUALIFY_ORANGE,Theme.Fonts.Strong)
		hint.TextXAlignment=Enum.TextXAlignment.Center
	end
	if state.WorldCupWinner then
		local winner=text(parent,"WINNER  /  "..string.upper(tostring(state.WorldCupWinner)),UDim2.new(.5,-160,1,-72),UDim2.fromOffset(320,22),12,Theme.Colors.Electric,Theme.Fonts.Display)
		winner.TextXAlignment=Enum.TextXAlignment.Center
	end
	if state and(state.Stage=="Champion"or state.Stage=="Eliminated")then
		local status=text(parent,state.Stage=="Champion"and"WORLD CUP CHAMPIONS"or"ELIMINATED",UDim2.new(.5,-160,1,-42),UDim2.fromOffset(320,32),18,state.Stage=="Champion"and Theme.Colors.Electric or Theme.Colors.Danger,Theme.Fonts.Display)
		status.TextXAlignment=Enum.TextXAlignment.Center
	end
end

local function showGroupDrawOverlay(root:Instance,state:any,selected:string,done:()->())
	local overlay=Instance.new("Frame");overlay.Name="WorldCupGroupDrawOverlay";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.04;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=220;overlay.Parent=root
	text(overlay,"WORLD CUP GROUP DRAW",UDim2.fromOffset(34,26),UDim2.new(1,-68,0,46),34,Theme.Colors.White,Theme.Fonts.Display).ZIndex=221
	local sub=text(overlay,"DRAWING TEAMS INTO GROUPS A-H",UDim2.fromOffset(38,72),UDim2.new(1,-76,0,22),10,Theme.Colors.Electric,Theme.Fonts.Strong);sub.ZIndex=221
	local stage=Instance.new("Frame");stage.BackgroundTransparency=1;stage.Position=UDim2.fromOffset(34,116);stage.Size=UDim2.new(1,-68,1,-190);stage.ZIndex=221;stage.Parent=overlay
	local layout=Instance.new("UIGridLayout");layout.CellPadding=UDim2.fromOffset(14,14);layout.CellSize=UDim2.new(.25,-11,0,168);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=stage
	local delayTime=0
	for groupIndex,groupName in ipairs(WorldCupConfig.GroupNames)do
		local teams=state.Groups and state.Groups[groupName]or{}
		local userGroup=table.find(teams,selected)~=nil
		local card=Panel.new({Name="DrawGroup"..groupName,Size=UDim2.fromScale(1,1)});card.LayoutOrder=groupIndex;card.ZIndex=222;card.Parent=stage
		card.BackgroundTransparency=userGroup and .02 or .18
		local stroke=card:FindFirstChildOfClass("UIStroke")or Instance.new("UIStroke");stroke.Color=userGroup and Theme.Colors.Electric or Theme.Colors.Border;stroke.Thickness=userGroup and 3 or 1;stroke.Transparency=userGroup and 0 or .3;stroke.Parent=card
		local header=text(card,"GROUP "..groupName,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,22),17,userGroup and Theme.Colors.Electric or Theme.Colors.White,Theme.Fonts.Display);header.ZIndex=223
		for index,country in ipairs(teams)do
			local row=Instance.new("Frame");row.BackgroundColor3=country==selected and Theme.Colors.Electric or Theme.Colors.Raised;row.BackgroundTransparency=1;row.BorderSizePixel=0;row.Position=UDim2.fromOffset(14,16);row.Size=UDim2.new(1,-28,0,28);row.ZIndex=224;row.Parent=card;corner(row,5)
			local f=flag(row,country,UDim2.fromOffset(6,5),UDim2.fromOffset(30,18));f.ZIndex=225
			local label=text(row,string.upper(country),UDim2.fromOffset(44,0),UDim2.new(1,-52,1,0),8,country==selected and Theme.Colors.Black or Theme.Colors.White,Theme.Fonts.Strong);label.ZIndex=225
			local final=UDim2.fromOffset(14,40+(index-1)*31)
			delayTime+=.07
			task.delay(delayTime,function()
				if not row.Parent then return end
				TweenService:Create(row,TweenInfo.new(.34,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=final,BackgroundTransparency=country==selected and 0 or .12}):Play()
			end)
		end
	end
	local continue=Instance.new("TextButton");continue.Name="Continue";continue.AnchorPoint=Vector2.new(1,1);continue.BackgroundColor3=Theme.Colors.Electric;continue.BorderSizePixel=0;continue.Position=UDim2.new(1,-34,1,-28);continue.Size=UDim2.fromOffset(190,44);continue.Text="CONTINUE";continue.TextColor3=Theme.Colors.Black;continue.TextSize=12;continue.Font=Theme.Fonts.Strong;continue.Visible=false;continue.ZIndex=230;continue.Parent=overlay;corner(continue,7)
	local finished=false
	local function finish()
		if finished then return end
		finished=true
		if overlay.Parent then overlay:Destroy()end
		done()
	end
	task.delay(math.max(1.3,delayTime+.45),function()if continue.Parent then continue.Visible=true;TweenService:Create(continue,TweenInfo.new(.2),{BackgroundTransparency=0}):Play()end end)
	continue.Activated:Connect(finish)
end

local function showQualifiedOverlay(root:Instance,state:any,done:()->())
	local selected=tostring(state and state.SelectedCountry or"")
	local rank=tonumber(state and state.GroupRank)or 2
	local overlay=Instance.new("Frame");overlay.Name="WorldCupQualifiedOverlay";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.02;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=235;overlay.Parent=root
	local flagImage=circleFlag(overlay,selected,UDim2.fromScale(.5,.24),124,true);flagImage.AnchorPoint=Vector2.new(.5,.5);flagImage.ZIndex=236
	local title=text(overlay,"QUALIFIED",UDim2.fromScale(.15,.38),UDim2.fromScale(.7,.09),52,Theme.Colors.Electric,Theme.Fonts.Display);title.TextXAlignment=Enum.TextXAlignment.Center;title.ZIndex=236
	local sub=text(overlay,string.format("%s  /  GROUP %s  /  %s PLACE",string.upper(selected),tostring(state.UserGroup or""),rank==1 and"1ST"or"2ND"),UDim2.fromScale(.18,.49),UDim2.fromScale(.64,.04),13,Theme.Colors.White,Theme.Fonts.Strong);sub.TextXAlignment=Enum.TextXAlignment.Center;sub.ZIndex=236
	local continue=Button.new({Text="ENTER KNOCKOUTS",Variant="Primary",Size=UDim2.fromOffset(210,44),OnActivated=function()
		if overlay.Parent then overlay:Destroy()end
		done()
	end})
	continue.Position=UDim2.fromScale(.5,.64);continue.AnchorPoint=Vector2.new(.5,.5);continue.ZIndex=238;continue.Parent=overlay
	overlay.BackgroundTransparency=1;title.TextTransparency=1;sub.TextTransparency=1;flagImage.ImageTransparency=1
	TweenService:Create(overlay,TweenInfo.new(.28),{BackgroundTransparency=.02}):Play()
	TweenService:Create(flagImage,TweenInfo.new(.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{ImageTransparency=0,Size=UDim2.fromOffset(138,138)}):Play()
	TweenService:Create(title,TweenInfo.new(.32),{TextTransparency=0}):Play()
	TweenService:Create(sub,TweenInfo.new(.32),{TextTransparency=0}):Play()
end

local function worldCupRunKey(state:any):string
	if type(state)~="table"then return""end
	return tostring(state.SelectedCountry or"")..":"..tostring(state.CreatedAt or"")..":"..tostring(state.GroupRank or"")
end

local function isTerminalWorldCup(state:any):boolean
	return type(state)=="table"and(state.Stage=="Champion"or state.Stage=="Eliminated")
end

local function showWorldCupMatchLoading(message:string?):ScreenGui
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	local old=playerGui:FindFirstChild("VTRWorldCupMatchLoading")
	if old then old:Destroy()end
	local gui=Instance.new("ScreenGui")
	gui.Name="VTRWorldCupMatchLoading"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=980
	gui.Parent=playerGui
	local overlay=Instance.new("CanvasGroup")
	overlay.Name="Overlay"
	overlay.Active=true
	overlay.BackgroundColor3=Color3.fromHex("020402")
	overlay.BorderSizePixel=0
	overlay.Size=UDim2.fromScale(1,1)
	overlay.ZIndex=980
	overlay.Parent=gui
	local title=text(overlay,"LOADING WORLD CUP MATCH",UDim2.fromScale(.1,.38),UDim2.fromScale(.8,.08),38,Theme.Colors.White,Theme.Fonts.Display)
	title.TextXAlignment=Enum.TextXAlignment.Center
	title.ZIndex=981
	local subtitle=text(overlay,string.upper(message or"LOCKING TOURNAMENT AND PREPARING MATCH"),UDim2.fromScale(.16,.48),UDim2.fromScale(.68,.04),11,Theme.Colors.Electric,Theme.Fonts.Strong)
	subtitle.TextXAlignment=Enum.TextXAlignment.Center
	subtitle.ZIndex=981
	local bar=Instance.new("Frame")
	bar.AnchorPoint=Vector2.new(.5,.5)
	bar.BackgroundColor3=Theme.Colors.Gunmetal
	bar.BorderSizePixel=0
	bar.Position=UDim2.fromScale(.5,.57)
	bar.Size=UDim2.fromScale(.38,.008)
	bar.ZIndex=981
	bar.Parent=overlay
	local fill=Instance.new("Frame")
	fill.BackgroundColor3=Theme.Colors.Electric
	fill.BorderSizePixel=0
	fill.Size=UDim2.fromScale(.18,1)
	fill.ZIndex=982
	fill.Parent=bar
	TweenService:Create(fill,TweenInfo.new(.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.fromScale(.82,0)}):Play()
	return gui
end

local function completeWorldCupLoading(gui:ScreenGui?)
	if not gui or not gui.Parent then return end
	local overlay=gui:FindFirstChild("Overlay")
	if overlay and overlay:IsA("CanvasGroup")then
		TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=1}):Play()
	end
	task.delay(.18,function()if gui and gui.Parent then gui:Destroy()end end)
end

local function showWorldCupRewardOverlay(reward:any,granted:any,done:()->())
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	local old=playerGui:FindFirstChild("VTRWorldCupRewardOverlay")
	if old then old:Destroy()end
	reward=type(reward)=="table"and reward or{}
	granted=type(granted)=="table"and granted or{}
	local packs=type(reward.Packs)=="table"and reward.Packs or{}
	local gui=Instance.new("ScreenGui")
	gui.Name="VTRWorldCupRewardOverlay"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=999
	gui.Parent=playerGui
	local overlay=Instance.new("CanvasGroup")
	overlay.Name="Overlay"
	overlay.Active=true
	overlay.BackgroundColor3=Color3.fromHex("030503")
	overlay.BorderSizePixel=0
	overlay.GroupTransparency=1
	overlay.Size=UDim2.fromScale(1,1)
	overlay.Parent=gui
	local title=text(overlay,"WORLD CUP REWARDS",UDim2.fromScale(.08,.07),UDim2.fromScale(.84,.07),38,Theme.Colors.White,Theme.Fonts.Display)
	title.TextXAlignment=Enum.TextXAlignment.Center;title.ZIndex=1001
	local reached=text(overlay,string.upper("FINISH  /  "..tostring(reward.Reached or"TOURNAMENT COMPLETE")),UDim2.fromScale(.18,.15),UDim2.fromScale(.64,.04),11,Theme.Colors.Electric,Theme.Fonts.Strong)
	reached.TextXAlignment=Enum.TextXAlignment.Center;reached.ZIndex=1001
	local panel=Instance.new("Frame");panel.BackgroundColor3=Theme.Colors.Black;panel.BackgroundTransparency=.08;panel.BorderSizePixel=0;panel.Position=UDim2.fromScale(.17,.23);panel.Size=UDim2.fromScale(.66,.25);panel.ZIndex=1000;panel.Parent=overlay;corner(panel,8)
	local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Electric;stroke.Transparency=.1;stroke.Thickness=2;stroke.Parent=panel
	local analysis=text(panel,"",UDim2.fromScale(.06,.12),UDim2.fromScale(.88,.72),20,Theme.Colors.White,Theme.Fonts.Body)
	analysis.TextXAlignment=Enum.TextXAlignment.Center;analysis.TextYAlignment=Enum.TextYAlignment.Center;analysis.ZIndex=1001
	local packTitle=text(overlay,"PACKS EARNED",UDim2.fromScale(.18,.53),UDim2.fromScale(.64,.035),13,Theme.Colors.Electric,Theme.Fonts.Display)
	packTitle.TextXAlignment=Enum.TextXAlignment.Center;packTitle.ZIndex=1001;packTitle.TextTransparency=1
	local packRow=Instance.new("Frame");packRow.BackgroundTransparency=1;packRow.Position=UDim2.fromScale(.12,.59);packRow.Size=UDim2.fromScale(.76,.22);packRow.ZIndex=1000;packRow.Parent=overlay
	local layout=Instance.new("UIListLayout");layout.FillDirection=Enum.FillDirection.Horizontal;layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.VerticalAlignment=Enum.VerticalAlignment.Center;layout.Padding=UDim.new(0,16);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=packRow
	local revealCards={}
	for index,pack in ipairs(packs)do
		local packId=tostring(pack.PackId or pack.Id or"")
		local definition=Catalog.Packs[packId]or{}
		local count=math.max(1,tonumber(pack.Quantity or pack.Count)or 1)
		local card=Instance.new("Frame");card.Name="RewardPack";card.BackgroundColor3=Theme.Colors.Raised;card.BackgroundTransparency=1;card.BorderSizePixel=0;card.Size=UDim2.fromOffset(170,130);card.ZIndex=1001;card.LayoutOrder=index;card.Parent=packRow;corner(card,8)
		local cardStroke=Instance.new("UIStroke");cardStroke.Color=Theme.Colors.Electric;cardStroke.Transparency=1;cardStroke.Thickness=2;cardStroke.Parent=card
		local top=Instance.new("Frame");top.BackgroundColor3=Theme.Colors.Electric;top.BackgroundTransparency=1;top.BorderSizePixel=0;top.Position=UDim2.fromScale(.08,.1);top.Size=UDim2.fromScale(.84,.14);top.ZIndex=1002;top.Parent=card;corner(top,99)
		local name=text(card,string.upper(tostring(definition.Name or pack.Name or packId)),UDim2.fromScale(.08,.3),UDim2.fromScale(.84,.32),13,Theme.Colors.White,Theme.Fonts.Display);name.TextXAlignment=Enum.TextXAlignment.Center;name.ZIndex=1002;name.TextTransparency=1
		local qty=text(card,"x"..tostring(count),UDim2.fromScale(.18,.68),UDim2.fromScale(.64,.18),18,Theme.Colors.Electric,Theme.Fonts.Display);qty.TextXAlignment=Enum.TextXAlignment.Center;qty.ZIndex=1002;qty.TextTransparency=1
		table.insert(revealCards,{Frame=card,Stroke=cardStroke,Top=top,Name=name,Qty=qty})
	end
	if #revealCards==0 then
		local card=Instance.new("Frame");card.BackgroundColor3=Theme.Colors.Raised;card.BackgroundTransparency=1;card.BorderSizePixel=0;card.Size=UDim2.fromOffset(260,98);card.ZIndex=1001;card.Parent=packRow;corner(card,8)
		local label=text(card,"NO PACKS GRANTED",UDim2.fromScale(.08,.2),UDim2.fromScale(.84,.6),18,Theme.Colors.Muted,Theme.Fonts.Display);label.TextXAlignment=Enum.TextXAlignment.Center;label.ZIndex=1002;label.TextTransparency=1
		table.insert(revealCards,{Frame=card,Name=label})
	end
	local claim=Button.new({Text="CONTINUE",Variant="Primary",Size=UDim2.fromOffset(190,46),OnActivated=function()
		if overlay.Parent then TweenService:Create(overlay,TweenInfo.new(.18),{GroupTransparency=1}):Play()end
		task.delay(.2,function()
			if gui.Parent then gui:Destroy()end
			done()
		end)
	end})
	claim.AnchorPoint=Vector2.new(.5,.5);claim.Position=UDim2.fromScale(.5,.88);claim.ZIndex=1003;claim.Parent=overlay;claim.Visible=false
	TweenService:Create(overlay,TweenInfo.new(.25),{GroupTransparency=0}):Play()
	local story=tostring(reward.Analysis or"Your World Cup run has been reviewed. Rewards are ready.")
	task.spawn(function()
		for index=1,#story do
			if not analysis.Parent then return end
			analysis.Text=string.sub(story,1,index)
			task.wait(index%4==0 and .018 or .009)
		end
		task.wait(.25)
		TweenService:Create(packTitle,TweenInfo.new(.18),{TextTransparency=0}):Play()
		for _,card in ipairs(revealCards)do
			if not card.Frame.Parent then return end
			card.Frame.Size=UDim2.fromOffset(120,88)
			TweenService:Create(card.Frame,TweenInfo.new(.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundTransparency=.12,Size=UDim2.fromOffset(170,130)}):Play()
			if card.Stroke then TweenService:Create(card.Stroke,TweenInfo.new(.2),{Transparency=.05}):Play()end
			if card.Top then TweenService:Create(card.Top,TweenInfo.new(.2),{BackgroundTransparency=0}):Play()end
			if card.Name then TweenService:Create(card.Name,TweenInfo.new(.18),{TextTransparency=0}):Play()end
			if card.Qty then TweenService:Create(card.Qty,TweenInfo.new(.18),{TextTransparency=0}):Play()end
			task.wait(.22)
		end
		claim.Visible=true
	end)
end

local function showWorldCupCompleteOverlay(root:Instance,state:any,done:()->())
	local winner=tostring(state and state.WorldCupWinner or state and state.SelectedCountry or"World Cup Winner")
	local boards=type(state)=="table"and type(state.Leaderboards)=="table"and state.Leaderboards or{}
	local function topEntries(board:any):{any}
		local result={}
		if type(board)=="table"then
			for _,entry in pairs(board)do
				if type(entry)=="table"then table.insert(result,{Name=tostring(entry.Name or"PLAYER"),Team=tostring(entry.Team or""),Count=tonumber(entry.Count)or 0})end
			end
		end
		table.sort(result,function(a,b)if a.Count==b.Count then return a.Name<b.Name end;return a.Count>b.Count end)
		while #result<5 do table.insert(result,{Name="-",Team="",Count=0})end
		return result
	end
	local overlay=Instance.new("CanvasGroup");overlay.Name="WorldCupCompleteOverlay";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.03;overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=240;overlay.Parent=root
	local cup=Instance.new("ImageLabel");cup.BackgroundTransparency=1;cup.Image=WORLD_CUP_ICON;cup.AnchorPoint=Vector2.new(.5,.5);cup.Position=UDim2.fromScale(.5,.13);cup.Size=UDim2.fromOffset(88,88);cup.ZIndex=241;cup.Parent=overlay
	local winnerFlag=circleFlag(overlay,winner,UDim2.fromScale(.5,.30),142,true);winnerFlag.AnchorPoint=Vector2.new(.5,.5);winnerFlag.ZIndex=241
	local title=text(overlay,"WORLD CUP CHAMPIONS",UDim2.fromScale(.12,.43),UDim2.fromScale(.76,.06),40,Theme.Colors.White,Theme.Fonts.Display);title.TextXAlignment=Enum.TextXAlignment.Center;title.ZIndex=241
	local winnerName=text(overlay,string.upper(winner),UDim2.fromScale(.18,.50),UDim2.fromScale(.64,.05),28,Theme.Colors.Electric,Theme.Fonts.Display);winnerName.TextXAlignment=Enum.TextXAlignment.Center;winnerName.ZIndex=241
	local columns=Instance.new("Frame");columns.BackgroundTransparency=1;columns.Position=UDim2.fromScale(.08,.61);columns.Size=UDim2.fromScale(.84,.24);columns.ZIndex=241;columns.Parent=overlay
	local layout=Instance.new("UIListLayout");layout.FillDirection=Enum.FillDirection.Horizontal;layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.VerticalAlignment=Enum.VerticalAlignment.Center;layout.Padding=UDim.new(0,14);layout.Parent=columns
	local specs={{"TOP GOALS",boards.Goals},{"TOP ASSISTS",boards.Assists},{"TOP MOTM",boards.MOTM}}
	for specIndex,spec in ipairs(specs)do
		local panel=Panel.new({Name="Leaderboard"..specIndex,Size=UDim2.new(.333,-10,1,0)});panel.ZIndex=242;panel.Parent=columns
		text(panel,tostring(spec[1]),UDim2.fromOffset(14,10),UDim2.new(1,-28,0,22),13,Theme.Colors.Electric,Theme.Fonts.Display).ZIndex=243
		for index,entry in ipairs(topEntries(spec[2]))do
			local row=Instance.new("Frame");row.BackgroundColor3=Theme.Colors.Raised;row.BackgroundTransparency=.18;row.BorderSizePixel=0;row.Position=UDim2.fromOffset(12,40+(index-1)*30);row.Size=UDim2.new(1,-24,0,24);row.ZIndex=243;row.Parent=panel;corner(row,5)
			local rank=text(row,tostring(index),UDim2.fromOffset(8,0),UDim2.fromOffset(18,24),8,Theme.Colors.Muted,Theme.Fonts.Strong);rank.TextXAlignment=Enum.TextXAlignment.Center;rank.ZIndex=244
			if entry.Team~=""then local f=flag(row,entry.Team,UDim2.fromOffset(30,5),UDim2.fromOffset(24,14));f.ZIndex=244 end
			local name=text(row,string.upper(tostring(entry.Name)),UDim2.fromOffset(60,0),UDim2.new(1,-98,1,0),8,Theme.Colors.White,Theme.Fonts.Strong);name.TextTruncate=Enum.TextTruncate.AtEnd;name.ZIndex=244
			local count=text(row,tostring(entry.Count),UDim2.new(1,-30,0,0),UDim2.fromOffset(22,24),10,Theme.Colors.Electric,Theme.Fonts.Display);count.TextXAlignment=Enum.TextXAlignment.Center;count.ZIndex=244
		end
	end
	local continue=Button.new({Text="CONTINUE",Variant="Primary",Size=UDim2.fromOffset(190,44),OnActivated=function()
		TweenService:Create(overlay,TweenInfo.new(.18),{GroupTransparency=1}):Play()
		task.delay(.2,function()if overlay.Parent then overlay:Destroy()end;done()end)
	end})
	continue.AnchorPoint=Vector2.new(.5,.5);continue.Position=UDim2.fromScale(.5,.92);continue.ZIndex=245;continue.Parent=overlay
	winnerFlag.Size=UDim2.fromOffset(104,104);cup.Size=UDim2.fromOffset(54,54)
	TweenService:Create(overlay,TweenInfo.new(.25),{GroupTransparency=0}):Play()
	TweenService:Create(cup,TweenInfo.new(.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(88,88)}):Play()
	TweenService:Create(winnerFlag,TweenInfo.new(.44,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(142,142)}):Play()
end

local WORLD_CUP_SIM_2X_PASS=Catalog.GamePasses and Catalog.GamePasses.world_cup_sim_2x or nil
local WORLD_CUP_SIM_2X_PASS_ID=tonumber(WORLD_CUP_SIM_2X_PASS and WORLD_CUP_SIM_2X_PASS.GamePassId)or 0

local function ownsWorldCupSim2x():boolean
	if WORLD_CUP_SIM_2X_PASS_ID<=0 then
		return true
	end
	local ok,owns=pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Players.LocalPlayer.UserId,WORLD_CUP_SIM_2X_PASS_ID)
	end)
	return ok and owns==true
end

local COMMENTARY_TEMPLATES={
	{Kind="Chance",Text="{team} work the ball into the box, but the final shot is blocked before it can trouble the keeper."},
	{Kind="Shot",Text="{team} force a save with a low drive from the edge of the area."},
	{Kind="Miss",Text="Big chance for {team}. The forward gets free, but drags the finish wide."},
	{Kind="Crossbar",Text="{team} hit the crossbar. The stadium thought that was in."},
	{Kind="FreeKick",Text="Dangerous free kick for {team}. It bends over the wall and flashes just past the post."},
	{Kind="YellowCard",Text="Yellow card for {team} after a late challenge stops the break."},
	{Kind="RedCard",Text="Red card. {team} are down to ten after a reckless tackle."},
	{Kind="PenaltyMiss",Text="Penalty for {team}. The taker goes for power, but the keeper guesses right and saves it."},
	{Kind="Corner",Text="{team} win a corner and load the six-yard box, but the header goes over."},
	{Kind="Counter",Text="{team} break quickly through midfield and nearly turn it into a clean one-on-one."},
	{Kind="Keeper",Text="Huge goalkeeper moment. {team} look certain to score, but the keeper spreads himself and saves."},
	{Kind="Pressure",Text="{team} are building pressure now, pinning the opponent back for a long spell."},
}
local GOAL_BUILDUP_TEMPLATES={
	"{team} move it quickly through midfield and find space between the lines.",
	"{team} switch play with purpose, stretching the back line before the final pass.",
	"{team} win the second ball high up the pitch and suddenly have numbers forward.",
	"{team} break into the box after a sharp one-two on the edge of the area.",
	"{team} keep the attack alive after the first cross is cleared only halfway.",
	"{team} draw defenders toward the ball, then slip a runner through the channel.",
	"{team} turn a loose touch into danger and attack before the defense can reset.",
	"{team} recycle possession patiently, waiting for the opening to appear.",
}

local function fillCommentary(template:string,team:string):string
	return template:gsub("{team}",string.upper(team))
end

local function buildSimulationCommentary(home:string,away:string,goals:{any},maxMinute:number?):{any}
	maxMinute=math.max(90,tonumber(maxMinute)or 90)
	local events={}
	for _,goal in ipairs(goals)do
		local leadMinute=math.max(1,(tonumber(goal.Minute)or 2)-1)
		local leadTemplate=goal.Method=="Penalty"and"Penalty for {team}. The referee points straight to the spot after a clumsy challenge."or GOAL_BUILDUP_TEMPLATES[((#tostring(goal.Team)+leadMinute)%#GOAL_BUILDUP_TEMPLATES)+1]
		table.insert(events,{Kind=goal.Method=="Penalty"and"Penalty"or"Attack",Minute=leadMinute,Team=goal.Team,Text=fillCommentary(leadTemplate,tostring(goal.Team or"")),GoalLeadup=true})
		table.insert(events,{Kind="Goal",Minute=goal.Minute,Team=goal.Team,Goal=goal})
	end
	local usedMinutes:{[number]:boolean}={}
	for _,event in ipairs(events)do usedMinutes[math.floor(tonumber(event.Minute)or 0)]=true end
	local random=Random.new(#home*97+#away*131+#goals*19+37)
	local count=math.clamp((maxMinute>90 and 24 or 18)+#goals*2,18,34)
	for index=1,count do
		local minute=math.clamp(4+math.floor(index*((maxMinute-8)/(count+1)))+random:NextInteger(-3,4),2,maxMinute-1)
		for _=1,8 do
			if not usedMinutes[minute]then break end
			minute=math.clamp(minute+random:NextInteger(1,4),2,maxMinute-1)
		end
		local tooCloseToGoal=false
		for _,goal in ipairs(goals)do
			if math.abs(minute-(tonumber(goal.Minute)or 0))<=1 then tooCloseToGoal=true;break end
		end
		if tooCloseToGoal then
			minute=math.clamp(minute+3,2,maxMinute-1)
		end
		usedMinutes[minute]=true
		local template=COMMENTARY_TEMPLATES[random:NextInteger(1,#COMMENTARY_TEMPLATES)]
		if (template.Kind=="RedCard"and random:NextNumber()>.015)or(template.Kind=="PenaltyMiss"and random:NextNumber()>.04)then
			for _=1,8 do
				template=COMMENTARY_TEMPLATES[random:NextInteger(1,#COMMENTARY_TEMPLATES)]
				if template.Kind~="RedCard"and template.Kind~="PenaltyMiss"then break end
			end
		end
		local team=random:NextNumber()<.5 and home or away
		table.insert(events,{Kind=template.Kind,Minute=minute,Team=team,Text=fillCommentary(template.Text,team)})
	end
	table.sort(events,function(a:any,b:any)
		if a.Minute==b.Minute then return tostring(a.Kind)<tostring(b.Kind)end
		return a.Minute<b.Minute
	end)
	return events
end

local function buildSimulationStats(home:string,away:string,homeGoals:number,awayGoals:number,goals:{any}):any
	local seed=#home*83+#away*107+homeGoals*31+awayGoals*47+#goals*13
	local random=Random.new(seed)
	local totalGoals=homeGoals+awayGoals
	local homeShots=math.clamp(homeGoals*3+random:NextInteger(5,11),homeGoals,22)
	local awayShots=math.clamp(awayGoals*3+random:NextInteger(5,11),awayGoals,22)
	local homeSot=math.clamp(homeGoals+random:NextInteger(2,math.max(3,math.floor(homeShots*.58))),homeGoals,homeShots)
	local awaySot=math.clamp(awayGoals+random:NextInteger(2,math.max(3,math.floor(awayShots*.58))),awayGoals,awayShots)
	local possession=math.clamp(50+(homeShots-awayShots)*2+random:NextInteger(-7,7),38,62)
	local homeXg=math.max(.2,homeGoals*.72+homeSot*.18+random:NextNumber(-.25,.35))
	local awayXg=math.max(.2,awayGoals*.72+awaySot*.18+random:NextNumber(-.25,.35))
	local cardsBase=totalGoals>4 and 1 or 0
	local potmGoal:any=nil
	for _,goal in ipairs(goals)do
		if not potmGoal or (goal.Team==(homeGoals>=awayGoals and home or away) and potmGoal.Team~=(homeGoals>=awayGoals and home or away))then
			potmGoal=goal
		end
	end
	local potmName=potmGoal and tostring(potmGoal.Scorer or"PLAYER")or(homeGoals>=awayGoals and home or away).." CAPTAIN"
	local potmTeam=potmGoal and tostring(potmGoal.Team or(homeGoals>=awayGoals and home or away))or(homeGoals>=awayGoals and home or away)
	local potmRating=math.clamp(7.3+(potmGoal and 1.0 or .4)+(potmGoal and potmGoal.Assister and .2 or 0)+math.max(homeGoals,awayGoals)*.12,7.2,9.8)
	return{
		Home={Possession=possession,Shots=homeShots,OnTarget=homeSot,XG=homeXg,Corners=random:NextInteger(2,8),Fouls=random:NextInteger(6,14),Yellow=cardsBase+random:NextInteger(0,3),Red=random:NextNumber()<.002 and 1 or 0},
		Away={Possession=100-possession,Shots=awayShots,OnTarget=awaySot,XG=awayXg,Corners=random:NextInteger(2,8),Fouls=random:NextInteger(6,14),Yellow=cardsBase+random:NextInteger(0,3),Red=random:NextNumber()<.002 and 1 or 0},
		POTM={Name=potmName,Team=potmTeam,Rating=potmRating},
	}
end

local function showSimulatedMatchOverlay(score:any,done:()->())
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	local old=playerGui:FindFirstChild("VTRWorldCupSimOverlay")
	if old then old:Destroy()end
	local home=tostring(score and score.Home or"HOME")
	local away=tostring(score and score.Away or"AWAY")
	local homeGoals=math.max(0,tonumber(score and score.HomeGoals)or 0)
	local awayGoals=math.max(0,tonumber(score and score.AwayGoals)or 0)
	local matchLabel=string.upper(tostring(score and score.MatchLabel or"SIMULATED MATCH"))
	local hasExtraTime=score and score.ExtraTime==true
	local hasPenalties=score and score.Penalties==true and type(score.Shootout)=="table"
	local maxMinute=hasExtraTime and 120 or 90
	local gui=Instance.new("ScreenGui")
	gui.Name="VTRWorldCupSimOverlay"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=998
	gui.Parent=playerGui
	local simSoundFolder=Instance.new("Folder")
	simSoundFolder.Name="WorldCupSimulationAudio"
	simSoundFolder.Parent=gui
	local function makeSimSound(name:string,soundId:string,volume:number,looped:boolean?):Sound
		local sound=Instance.new("Sound")
		sound.Name=name
		sound.SoundId=soundId
		sound.Volume=volume
		sound.Looped=looped==true
		sound.RollOffMode=Enum.RollOffMode.InverseTapered
		sound.Parent=simSoundFolder
		return sound
	end
	local kickoffSound=makeSimSound("KickoffWhistle",SIM_KICKOFF_SOUND,.72,false)
	local finalWhistleSound=makeSimSound("FinalWhistle",SIM_FINAL_WHISTLE_SOUND,.78,false)
	local goalSound=makeSimSound("GoalSting",SIM_GOAL_SOUND,.62,false)
	local ambienceSound=makeSimSound("MatchAmbience",SIM_AMBIENCE_SOUND,0,true)
	local finalWhistlePlayed=false
	local function playSimOneShot(sound:Sound?)
		if not sound or not sound.Parent then return end
		sound.TimePosition=0
		sound:Play()
	end
	local function startSimulationAudio()
		playSimOneShot(kickoffSound)
		if ambienceSound.Parent then
			ambienceSound.Volume=0
			ambienceSound:Play()
			TweenService:Create(ambienceSound,TweenInfo.new(.7,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=.22}):Play()
		end
	end
	local function playFinalSimulationWhistle()
		if finalWhistlePlayed then return end
		finalWhistlePlayed=true
		if ambienceSound.Parent then
			TweenService:Create(ambienceSound,TweenInfo.new(.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Volume=0}):Play()
			task.delay(.32,function()if ambienceSound.Parent then ambienceSound:Stop()end end)
		end
		playSimOneShot(finalWhistleSound)
	end
	local overlay=Instance.new("CanvasGroup")
	overlay.Name="Overlay"
	overlay.Active=true
	overlay.BackgroundColor3=Color3.fromHex("050705")
	overlay.GroupTransparency=1
	overlay.Size=UDim2.fromScale(1,1)
	overlay.Parent=gui
	local title=text(overlay,matchLabel,UDim2.fromScale(.05,.055),UDim2.fromScale(.9,.055),30,Theme.Colors.White,Theme.Fonts.Display)
	title.TextXAlignment=Enum.TextXAlignment.Center;title.ZIndex=1000
	local clock=text(overlay,"00'",UDim2.fromScale(.43,.145),UDim2.fromScale(.14,.07),42,Theme.Colors.Electric,Theme.Fonts.Display)
	clock.TextXAlignment=Enum.TextXAlignment.Center;clock.ZIndex=1000
	local scoreLabel=text(overlay,"0  -  0",UDim2.fromScale(.38,.255),UDim2.fromScale(.24,.12),58,Theme.Colors.White,Theme.Fonts.Display)
	scoreLabel.TextXAlignment=Enum.TextXAlignment.Center;scoreLabel.ZIndex=1000
	local homePanel=Instance.new("Frame");homePanel.BackgroundColor3=Theme.Colors.Raised;homePanel.BackgroundTransparency=.08;homePanel.BorderSizePixel=0;homePanel.Position=UDim2.fromScale(.06,.2);homePanel.Size=UDim2.fromScale(.28,.25);homePanel.ZIndex=999;homePanel.Parent=overlay;corner(homePanel,8)
	local awayPanel=Instance.new("Frame");awayPanel.BackgroundColor3=Theme.Colors.Raised;awayPanel.BackgroundTransparency=.08;awayPanel.BorderSizePixel=0;awayPanel.Position=UDim2.fromScale(.66,.2);awayPanel.Size=UDim2.fromScale(.28,.25);awayPanel.ZIndex=999;awayPanel.Parent=overlay;corner(awayPanel,8)
	local hf=flag(homePanel,home,UDim2.fromScale(.08,.17),UDim2.fromScale(.3,.5));hf.ZIndex=1000
	local af=flag(awayPanel,away,UDim2.fromScale(.62,.17),UDim2.fromScale(.3,.5));af.ZIndex=1000
	local homeName=text(homePanel,string.upper(home),UDim2.fromScale(.42,.13),UDim2.fromScale(.52,.32),18,Theme.Colors.White,Theme.Fonts.Display);homeName.ZIndex=1000
	local awayName=text(awayPanel,string.upper(away),UDim2.fromScale(.06,.13),UDim2.fromScale(.52,.32),18,Theme.Colors.White,Theme.Fonts.Display);awayName.TextXAlignment=Enum.TextXAlignment.Right;awayName.ZIndex=1000
	local homeStat=text(homePanel,"SIM HOME",UDim2.fromScale(.42,.5),UDim2.fromScale(.5,.18),9,Theme.Colors.Electric,Theme.Fonts.Strong);homeStat.ZIndex=1000
	local awayStat=text(awayPanel,"SIM AWAY",UDim2.fromScale(.08,.5),UDim2.fromScale(.5,.18),9,Theme.Colors.Electric,Theme.Fonts.Strong);awayStat.TextXAlignment=Enum.TextXAlignment.Right;awayStat.ZIndex=1000
	local function addRedCardMarker(team:string)
		local panel=team==home and homePanel or team==away and awayPanel or nil
		if not panel or panel:FindFirstChild("RedCardMarker")then return end
		local marker=Instance.new("TextLabel");marker.Name="RedCardMarker";marker.AnchorPoint=Vector2.new(.5,.5);marker.BackgroundColor3=Theme.Colors.Danger;marker.BorderSizePixel=0;marker.Position=UDim2.fromScale(.5,.08);marker.Size=UDim2.fromOffset(20,28);marker.Text="";marker.ZIndex=1003;marker.Parent=panel;corner(marker,3)
	end
	local timeline=Instance.new("Frame");timeline.BackgroundColor3=Theme.Colors.Gunmetal;timeline.BorderSizePixel=0;timeline.Position=UDim2.fromScale(.08,.68);timeline.Size=UDim2.fromScale(.84,.018);timeline.ZIndex=999;timeline.Parent=overlay;corner(timeline,99)
	local fill=Instance.new("Frame");fill.BackgroundColor3=Theme.Colors.Electric;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(0,1);fill.ZIndex=1000;fill.Parent=timeline;corner(fill,99)
	if hasExtraTime then
		local normalTimeMarker=Instance.new("Frame");normalTimeMarker.Name="NormalTimeMarker";normalTimeMarker.AnchorPoint=Vector2.new(.5,.5);normalTimeMarker.BackgroundColor3=Theme.Colors.White;normalTimeMarker.BorderSizePixel=0;normalTimeMarker.Position=UDim2.fromScale(90/maxMinute,.5);normalTimeMarker.Size=UDim2.fromOffset(4,30);normalTimeMarker.ZIndex=1002;normalTimeMarker.Parent=timeline;corner(normalTimeMarker,99)
		local normalTimeLabel=text(overlay,"90'",UDim2.fromScale(.08+.84*(90/maxMinute)-.02,.695),UDim2.fromScale(.04,.025),8,Theme.Colors.Muted,Theme.Fonts.Strong);normalTimeLabel.TextXAlignment=Enum.TextXAlignment.Center;normalTimeLabel.ZIndex=1001
	end
	local eventText=text(overlay,"",UDim2.fromScale(.18,.53),UDim2.fromScale(.64,.08),28,Theme.Colors.Silver,Theme.Fonts.Display)
	eventText.TextXAlignment=Enum.TextXAlignment.Center;eventText.Visible=false;eventText.ZIndex=1000
	local sub=text(overlay,"WATCHING THE MATCH ENGINE PLAY OUT",UDim2.fromScale(.22,.61),UDim2.fromScale(.56,.035),10,Theme.Colors.Muted,Theme.Fonts.Strong)
	sub.TextXAlignment=Enum.TextXAlignment.Center;sub.ZIndex=1000
	local speedMultiplier=1
	local commentaryCallout=Instance.new("CanvasGroup");commentaryCallout.Name="LiveCommentaryCallout";commentaryCallout.AnchorPoint=Vector2.new(.5,.5);commentaryCallout.BackgroundColor3=Theme.Colors.Black;commentaryCallout.BackgroundTransparency=.18;commentaryCallout.BorderSizePixel=0;commentaryCallout.GroupTransparency=0;commentaryCallout.Position=UDim2.fromScale(.5,.585);commentaryCallout.Size=UDim2.fromScale(.60,.13);commentaryCallout.Visible=true;commentaryCallout.ZIndex=1001;commentaryCallout.Parent=overlay;corner(commentaryCallout,8)
	local commentaryHeader=text(commentaryCallout,"LIVE COMMENTARY",UDim2.fromScale(.04,.08),UDim2.fromScale(.92,.22),11,Theme.Colors.Electric,Theme.Fonts.Strong);commentaryHeader.TextXAlignment=Enum.TextXAlignment.Center;commentaryHeader.ZIndex=1002
	local commentaryBody=text(commentaryCallout,"The teams are walking into the rhythm of the match.",UDim2.fromScale(.06,.33),UDim2.fromScale(.88,.58),15,Theme.Colors.White,Theme.Fonts.Body);commentaryBody.TextXAlignment=Enum.TextXAlignment.Center;commentaryBody.TextYAlignment=Enum.TextYAlignment.Center;commentaryBody.TextWrapped=true;commentaryBody.ZIndex=1002
	local commentarySequence=0
	local function showCommentaryEvent(event:any)
		commentarySequence+=1
		commentaryHeader.Text=string.format("%02d'  /  %s",tonumber(event.Minute)or 0,string.upper(tostring(event.Kind or"MATCH EVENT")))
		local body=tostring(event.Text or"")
		commentaryBody.Text=body
		commentaryCallout.BackgroundTransparency=.12
		TweenService:Create(commentaryCallout,TweenInfo.new(.12),{BackgroundTransparency=.18}):Play()
	end
	local function showFullTimeStats(stats:any)
		local result=Instance.new("CanvasGroup");result.Name="SimulationFullTimeStats";result.BackgroundColor3=Theme.Colors.Black;result.BackgroundTransparency=.12;result.BorderSizePixel=0;result.GroupTransparency=1;result.Size=UDim2.fromScale(1,1);result.ZIndex=1010;result.Parent=overlay
		local panel=Instance.new("Frame");panel.AnchorPoint=Vector2.new(.5,.5);panel.BackgroundColor3=Color3.fromHex("080B08");panel.BackgroundTransparency=.02;panel.BorderSizePixel=0;panel.Position=UDim2.fromScale(.5,.52);panel.Size=UDim2.fromScale(.64,.68);panel.ZIndex=1011;panel.Parent=result;corner(panel,10)
		local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Electric;stroke.Transparency=.25;stroke.Thickness=1;stroke.Parent=panel
		local finalTitle=text(panel,hasPenalties and"AFTER PENALTIES"or hasExtraTime and"AFTER EXTRA TIME"or"FULL TIME",UDim2.fromScale(.08,.05),UDim2.fromScale(.84,.07),32,Theme.Colors.White,Theme.Fonts.Display);finalTitle.TextXAlignment=Enum.TextXAlignment.Center;finalTitle.ZIndex=1012
		local shootout=score and score.Shootout or nil
		local scoreSuffix=hasPenalties and string.format("  (%d-%d pens)",tonumber(shootout and shootout.HomePens)or 0,tonumber(shootout and shootout.AwayPens)or 0)or""
		local finalScore=text(panel,string.format("%s  %d  -  %d  %s%s",string.upper(home),homeGoals,awayGoals,string.upper(away),scoreSuffix),UDim2.fromScale(.08,.13),UDim2.fromScale(.84,.07),20,Theme.Colors.Electric,Theme.Fonts.Display);finalScore.TextXAlignment=Enum.TextXAlignment.Center;finalScore.ZIndex=1012
		local potm=stats.POTM or{}
		local spotlight=Instance.new("Frame");spotlight.BackgroundColor3=Theme.Colors.Raised;spotlight.BackgroundTransparency=.07;spotlight.BorderSizePixel=0;spotlight.Position=UDim2.fromScale(.08,.23);spotlight.Size=UDim2.fromScale(.84,.15);spotlight.ZIndex=1012;spotlight.Parent=panel;corner(spotlight,8)
		text(spotlight,"PLAYER OF THE MATCH",UDim2.fromScale(.04,.12),UDim2.fromScale(.50,.22),10,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=1013
		text(spotlight,string.upper(tostring(potm.Name or"PLAYER")),UDim2.fromScale(.04,.38),UDim2.fromScale(.58,.38),24,Theme.Colors.White,Theme.Fonts.Display).ZIndex=1013
		local meta=text(spotlight,string.upper(tostring(potm.Team or"")).."  /  MR "..string.format("%.1f",tonumber(potm.Rating)or 7.5),UDim2.fromScale(.66,.26),UDim2.fromScale(.28,.46),16,Theme.Colors.Electric,Theme.Fonts.Display);meta.TextXAlignment=Enum.TextXAlignment.Right;meta.ZIndex=1013
		local statsPanel=Instance.new("Frame");statsPanel.BackgroundTransparency=1;statsPanel.Position=UDim2.fromScale(.08,.43);statsPanel.Size=UDim2.fromScale(.84,.34);statsPanel.ZIndex=1012;statsPanel.Parent=panel
		local rows={{"POSSESSION","Possession","%"},{"SHOTS","Shots",""},{"ON TARGET","OnTarget",""},{"EXPECTED GOALS","XG","xg"},{"CORNERS","Corners",""},{"FOULS","Fouls",""},{"YELLOW CARDS","Yellow",""},{"RED CARDS","Red",""}}
		for index,row in ipairs(rows)do
			local y=(index-1)*.12
			local leftValue=stats.Home and stats.Home[row[2]]or 0
			local rightValue=stats.Away and stats.Away[row[2]]or 0
			local function format(value:any):string
				if row[2]=="XG"then return string.format("%.2f",tonumber(value)or 0)end
				if row[3]=="%"then return tostring(math.floor(tonumber(value)or 0)).."%"end
				return tostring(value)
			end
			local left=text(statsPanel,format(leftValue),UDim2.new(0,0,y,0),UDim2.fromScale(.18,.105),13,Theme.Colors.White,Theme.Fonts.Display);left.TextXAlignment=Enum.TextXAlignment.Left;left.ZIndex=1013
			local label=text(statsPanel,row[1],UDim2.new(.22,0,y,0),UDim2.fromScale(.56,.105),9,Theme.Colors.Silver,Theme.Fonts.Strong);label.TextXAlignment=Enum.TextXAlignment.Center;label.ZIndex=1013
			local right=text(statsPanel,format(rightValue),UDim2.new(.82,0,y,0),UDim2.fromScale(.18,.105),13,Theme.Colors.White,Theme.Fonts.Display);right.TextXAlignment=Enum.TextXAlignment.Right;right.ZIndex=1013
		end
		local continue=Instance.new("TextButton");continue.Name="Continue";continue.AnchorPoint=Vector2.new(.5,1);continue.BackgroundColor3=Theme.Colors.Electric;continue.BorderSizePixel=0;continue.Position=UDim2.fromScale(.5,.93);continue.Size=UDim2.fromOffset(210,44);continue.Text="CONTINUE";continue.TextColor3=Theme.Colors.Black;continue.TextSize=13;continue.Font=Theme.Fonts.Strong;continue.ZIndex=1014;continue.Parent=panel;corner(continue,7)
		TweenService:Create(result,TweenInfo.new(.22),{GroupTransparency=0}):Play()
		continue.Activated:Connect(function()
			continue.Active=false
			TweenService:Create(result,TweenInfo.new(.22),{GroupTransparency=1}):Play()
			task.delay(.24,function()
				if gui.Parent then gui:Destroy()end
				done()
			end)
		end)
	end
	local function playPenaltyShootout(finished:()->())
		local shootout=score and score.Shootout or{}
		local rounds=type(shootout.Rounds)=="table"and shootout.Rounds or{}
		if #rounds==0 then finished();return end
		local box=Instance.new("CanvasGroup");box.Name="PenaltyShootout";box.AnchorPoint=Vector2.new(.5,.5);box.BackgroundColor3=Theme.Colors.Black;box.BackgroundTransparency=.08;box.BorderSizePixel=0;box.GroupTransparency=1;box.Position=UDim2.fromScale(.5,.47);box.Size=UDim2.fromScale(.88,.34);box.ZIndex=1005;box.Parent=overlay;corner(box,10)
		local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Silver;stroke.Transparency=.35;stroke.Thickness=2;stroke.Parent=box
		local header=text(box,"PENALTY SHOOTOUT",UDim2.fromScale(.04,.07),UDim2.fromScale(.54,.12),24,Theme.Colors.White,Theme.Fonts.Display);header.TextXAlignment=Enum.TextXAlignment.Left;header.ZIndex=1006
		local taker=text(box,"",UDim2.fromScale(.04,.80),UDim2.fromScale(.54,.10),13,Theme.Colors.Electric,Theme.Fonts.Display);taker.TextXAlignment=Enum.TextXAlignment.Left;taker.ZIndex=1006
		local pens=text(box,string.format("0 - 0"),UDim2.fromScale(.43,.07),UDim2.fromScale(.14,.12),25,Theme.Colors.White,Theme.Fonts.Display);pens.TextXAlignment=Enum.TextXAlignment.Center;pens.ZIndex=1006
		local rowsFrame=Instance.new("Frame");rowsFrame.BackgroundTransparency=1;rowsFrame.Position=UDim2.fromScale(.04,.25);rowsFrame.Size=UDim2.fromScale(.53,.46);rowsFrame.ZIndex=1006;rowsFrame.Parent=box
		local maxSlots=math.max(5,#rounds)
		local homeSlots={}
		local awaySlots={}
		local function makeShootoutRow(teamName:string,y:number,slots:any)
			local teamFlag=flag(rowsFrame,teamName,UDim2.fromScale(0,y),UDim2.fromScale(.095,.32));teamFlag.ZIndex=1007
			local code=text(rowsFrame,wcCode(teamName),UDim2.fromScale(.105,y+.08),UDim2.fromScale(.12,.16),13,Theme.Colors.White,Theme.Fonts.Display);code.ZIndex=1007
			for index=1,maxSlots do
				local marker=Instance.new("TextLabel");marker.Name="Kick"..index;marker.AnchorPoint=Vector2.new(.5,.5);marker.BackgroundColor3=Color3.fromRGB(54,54,54);marker.BackgroundTransparency=.1;marker.BorderSizePixel=0;marker.Position=UDim2.fromScale(.24+(index-1)*(.69/math.max(1,maxSlots)),y+.16);marker.Size=UDim2.fromScale(.065,.22);marker.Text="";marker.TextColor3=Theme.Colors.White;marker.TextSize=20;marker.Font=Theme.Fonts.Display;marker.ZIndex=1007;marker.Parent=rowsFrame;corner(marker,99)
				slots[index]=marker
			end
		end
		makeShootoutRow(home,.02,homeSlots)
		makeShootoutRow(away,.55,awaySlots)
		local goal=Instance.new("Frame");goal.Name="ShootoutGoal";goal.BackgroundTransparency=1;goal.Position=UDim2.fromScale(.62,.19);goal.Size=UDim2.fromScale(.32,.50);goal.ZIndex=1006;goal.Parent=box
		local postColor=Theme.Colors.White
		local leftPost=Instance.new("Frame");leftPost.BackgroundColor3=postColor;leftPost.BorderSizePixel=0;leftPost.Position=UDim2.fromScale(.02,.04);leftPost.Size=UDim2.fromScale(.025,.82);leftPost.ZIndex=1007;leftPost.Parent=goal
		local rightPost=leftPost:Clone();rightPost.Position=UDim2.fromScale(.955,.04);rightPost.Parent=goal
		local crossbar=Instance.new("Frame");crossbar.BackgroundColor3=postColor;crossbar.BorderSizePixel=0;crossbar.Position=UDim2.fromScale(.02,.04);crossbar.Size=UDim2.fromScale(.96,.055);crossbar.ZIndex=1007;crossbar.Parent=goal;corner(crossbar,6)
		for index=1,5 do
			local line=Instance.new("Frame");line.BackgroundColor3=Color3.fromRGB(78,78,78);line.BorderSizePixel=0;line.BackgroundTransparency=.15;line.Position=UDim2.fromScale(.14+index*.14,.10);line.Size=UDim2.fromScale(.012,.76);line.ZIndex=1006;line.Parent=goal
		end
		for index=1,4 do
			local line=Instance.new("Frame");line.BackgroundColor3=Color3.fromRGB(78,78,78);line.BorderSizePixel=0;line.BackgroundTransparency=.15;line.Position=UDim2.fromScale(.04,.18+index*.14);line.Size=UDim2.fromScale(.92,.012);line.ZIndex=1006;line.Parent=goal
		end
		local ball=Instance.new("TextLabel");ball.Name="ShootoutBall";ball.AnchorPoint=Vector2.new(.5,.5);ball.BackgroundColor3=Theme.Colors.White;ball.BorderSizePixel=0;ball.Position=UDim2.fromScale(.5,.55);ball.Size=UDim2.fromScale(.12,.18);ball.Text="";ball.TextColor3=Theme.Colors.Black;ball.TextSize=14;ball.Font=Theme.Fonts.Display;ball.ZIndex=1008;ball.Parent=goal;corner(ball,99)
		local ballCore=Instance.new("Frame");ballCore.AnchorPoint=Vector2.new(.5,.5);ballCore.BackgroundColor3=Theme.Colors.Black;ballCore.BorderSizePixel=0;ballCore.Position=UDim2.fromScale(.5,.5);ballCore.Size=UDim2.fromScale(.32,.32);ballCore.ZIndex=1009;ballCore.Parent=ball;corner(ballCore,99)
		local goalResult=text(box,"",UDim2.fromScale(.62,.72),UDim2.fromScale(.32,.10),18,Theme.Colors.White,Theme.Fonts.Display);goalResult.TextXAlignment=Enum.TextXAlignment.Center;goalResult.ZIndex=1007
		local function setKickMarker(marker:TextLabel?,scored:boolean)
			if not marker then return end
			marker.BackgroundColor3=scored and Theme.Colors.White or Theme.Colors.Black
			marker.Text=scored and""or"X"
			marker.TextColor3=Theme.Colors.Danger
			if scored then
				local core=Instance.new("Frame");core.AnchorPoint=Vector2.new(.5,.5);core.BackgroundColor3=Theme.Colors.Black;core.BorderSizePixel=0;core.Position=UDim2.fromScale(.5,.5);core.Size=UDim2.fromScale(.34,.34);core.ZIndex=1008;core.Parent=marker;corner(core,99)
			end
		end
		local function showKick(teamName:string,scored:boolean,roundNumber:number,scoreHome:number,scoreAway:number)
			taker.Text=string.format("ROUND %d  /  %s",roundNumber,string.upper(teamName))
			goalResult.Text=scored and"GOAL"or"SAVED"
			goalResult.TextColor3=scored and Theme.Colors.Electric or Theme.Colors.Danger
			pens.Text=string.format("%d - %d",scoreHome,scoreAway)
			ball.Position=scored and UDim2.fromScale(.28+((roundNumber%4)*.14),.40+((roundNumber%3)*.08))or UDim2.fromScale(.5,.78)
			if scored then playSimOneShot(goalSound)end
		end
		TweenService:Create(box,TweenInfo.new(.22),{GroupTransparency=0}):Play()
		task.spawn(function()
			task.wait(.45/math.max(1,speedMultiplier))
			for _,round in ipairs(rounds)do
				if not box.Parent then return end
				local roundNumber=tonumber(round.Round)or 1
				taker.Text=string.format("ROUND %d  /  %s",roundNumber,string.upper(home))
				goalResult.Text=""
				task.wait(.55/math.max(1,speedMultiplier))
				setKickMarker(homeSlots[roundNumber],round.HomeScored==true)
				showKick(home,round.HomeScored==true,roundNumber,tonumber(round.HomeScore)or 0,tonumber(round.AwayScore)or 0)
				task.wait(.5/math.max(1,speedMultiplier))
				taker.Text=string.format("ROUND %d  /  %s",roundNumber,string.upper(away))
				goalResult.Text=""
				task.wait(.55/math.max(1,speedMultiplier))
				setKickMarker(awaySlots[roundNumber],round.AwayScored==true)
				showKick(away,round.AwayScored==true,roundNumber,tonumber(round.HomeScore)or 0,tonumber(round.AwayScore)or 0)
				task.wait(.62/math.max(1,speedMultiplier))
			end
			taker.Text="SHOOTOUT WINNER"
			goalResult.Text=string.upper(tostring(shootout.Winner or score.Winner or"WINNER"))
			goalResult.TextColor3=Theme.Colors.Electric
			task.wait(1/math.max(1,speedMultiplier))
			TweenService:Create(box,TweenInfo.new(.22),{GroupTransparency=1}):Play()
			task.delay(.24,function()
				if box.Parent then box:Destroy()end
				finished()
			end)
		end)
	end
	local goalLog=Instance.new("Frame");goalLog.BackgroundColor3=Theme.Colors.Black;goalLog.BackgroundTransparency=.18;goalLog.BorderSizePixel=0;goalLog.Position=UDim2.fromScale(.28,.73);goalLog.Size=UDim2.fromScale(.44,.19);goalLog.ZIndex=999;goalLog.Parent=overlay;corner(goalLog,8)
	local goalLogTitle=text(goalLog,"GOALS + ASSISTS",UDim2.fromScale(.05,.04),UDim2.fromScale(.9,.15),10,Theme.Colors.Electric,Theme.Fonts.Strong);goalLogTitle.ZIndex=1000
	local goalList=Instance.new("ScrollingFrame");goalList.BackgroundTransparency=1;goalList.BorderSizePixel=0;goalList.Position=UDim2.fromScale(.05,.22);goalList.Size=UDim2.fromScale(.9,.72);goalList.AutomaticCanvasSize=Enum.AutomaticSize.Y;goalList.CanvasSize=UDim2.new();goalList.ScrollBarThickness=3;goalList.ScrollBarImageColor3=Theme.Colors.Electric;goalList.ZIndex=1000;goalList.Parent=goalLog
	local goalLayout=Instance.new("UIListLayout");goalLayout.SortOrder=Enum.SortOrder.LayoutOrder;goalLayout.Padding=UDim.new(0,5);goalLayout.Parent=goalList
	local noGoals=text(goalList,"NO GOALS YET",UDim2.new(),UDim2.new(1,0,0,22),9,Theme.Colors.Muted,Theme.Fonts.Strong);noGoals.ZIndex=1001
	local has2xAccess=ownsWorldCupSim2x()
	local speedButton=Instance.new("TextButton");speedButton.Name="SimulationSpeed2x";speedButton.AnchorPoint=Vector2.new(1,0);speedButton.AutoButtonColor=true;speedButton.BackgroundColor3=Theme.Colors.Raised;speedButton.BackgroundTransparency=.08;speedButton.BorderSizePixel=0;speedButton.Position=UDim2.fromScale(.95,.07);speedButton.Size=UDim2.fromOffset(164,36);speedButton.Text=has2xAccess and"2X SPEED OFF"or"UNLOCK 2X SPEED";speedButton.TextColor3=Theme.Colors.White;speedButton.TextSize=10;speedButton.Font=Theme.Fonts.Strong;speedButton.ZIndex=1002;speedButton.Parent=overlay;corner(speedButton,6)
	local purchaseConnection:RBXScriptConnection?=nil
	local function refresh2xButton()
		local enabled=speedMultiplier>=2
		speedButton.Text=has2xAccess and(enabled and"2X SPEED ON"or"2X SPEED OFF")or"UNLOCK 2X SPEED"
		speedButton.BackgroundColor3=enabled and Theme.Colors.Electric or Theme.Colors.Raised
		speedButton.BackgroundTransparency=enabled and 0 or .08
		speedButton.TextColor3=enabled and Theme.Colors.Black or Theme.Colors.White
	end
	local function enable2x()
		has2xAccess=true
		speedMultiplier=2
		refresh2xButton()
	end
	speedButton.Activated:Connect(function()
		if has2xAccess or ownsWorldCupSim2x()then
			has2xAccess=true
			speedMultiplier=speedMultiplier>=2 and 1 or 2
			refresh2xButton()
		elseif WORLD_CUP_SIM_2X_PASS_ID>0 then
			speedButton.Text="OPENING STORE"
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer,WORLD_CUP_SIM_2X_PASS_ID)
		else
			speedButton.Text="PASS ID NEEDED"
			task.delay(1.2,function()if speedButton.Parent then refresh2xButton()end end)
		end
	end)
	if WORLD_CUP_SIM_2X_PASS_ID>0 then
		purchaseConnection=MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player:Player,gamePassId:number,purchased:boolean)
			if player==Players.LocalPlayer and gamePassId==WORLD_CUP_SIM_2X_PASS_ID then
				if purchased then enable2x()elseif speedButton.Parent then refresh2xButton()end
			end
		end)
	end
	local detail=Instance.new("Frame");detail.AnchorPoint=Vector2.new(.5,.5);detail.BackgroundColor3=Theme.Colors.Black;detail.BackgroundTransparency=.28;detail.BorderSizePixel=0;detail.Position=UDim2.fromScale(.5,.47);detail.Size=UDim2.fromScale(.58,.07);detail.ZIndex=1001;detail.Parent=overlay;corner(detail,8)
	local goalIcon=Instance.new("ImageLabel");goalIcon.BackgroundTransparency=1;goalIcon.Image="rbxassetid://135771264315819";goalIcon.Position=UDim2.fromScale(.04,.2);goalIcon.Size=UDim2.fromScale(.055,.6);goalIcon.ScaleType=Enum.ScaleType.Fit;goalIcon.ZIndex=1002;goalIcon.Parent=detail
	local scorerLabel=text(detail,"",UDim2.fromScale(.11,0),UDim2.fromScale(.34,1),14,Theme.Colors.White,Theme.Fonts.Display);scorerLabel.ZIndex=1002
	local assistIcon=Instance.new("ImageLabel");assistIcon.BackgroundTransparency=1;assistIcon.Image="rbxassetid://93968131485797";assistIcon.Position=UDim2.fromScale(.49,.2);assistIcon.Size=UDim2.fromScale(.055,.6);assistIcon.ScaleType=Enum.ScaleType.Fit;assistIcon.ZIndex=1002;assistIcon.Parent=detail
	local assistLabel=text(detail,"",UDim2.fromScale(.56,0),UDim2.fromScale(.38,1),13,Theme.Colors.Silver,Theme.Fonts.Strong);assistLabel.ZIndex=1002
	detail.Visible=false
	local goals={}
	if type(score and score.Events)=="table"then
		for _,event in ipairs(score.Events)do
			table.insert(goals,{Team=tostring(event.Team or""),Side=tostring(event.Side or""),Minute=math.clamp(tonumber(event.Minute)or 1,1,maxMinute),Scorer=tostring(event.Scorer or"SCORER"),Assister=event.Assister and tostring(event.Assister)or nil})
		end
	end
	if #goals==0 then
		for index=1,homeGoals do table.insert(goals,{Team=home,Side="Home",Minute=math.clamp(8+index*math.floor((maxMinute-18)/(homeGoals+1))+#home%9,3,maxMinute-1),Scorer="SCORER"})end
		for index=1,awayGoals do table.insert(goals,{Team=away,Side="Away",Minute=math.clamp(10+index*math.floor((maxMinute-20)/(awayGoals+1))+#away%11,4,maxMinute),Scorer="SCORER"})end
	end
	table.sort(goals,function(a,b)if a.Minute==b.Minute then return tostring(a.Team)<tostring(b.Team)end;return a.Minute<b.Minute end)
	local usedGoalMinutes:{[number]:boolean}={}
	local function uniqueGoalMinute(preferred:number):number
		local minute=math.clamp(math.floor(preferred),1,maxMinute)
		if not usedGoalMinutes[minute]then usedGoalMinutes[minute]=true;return minute end
		for offset=1,16 do
			local later=math.clamp(minute+offset,1,maxMinute)
			if not usedGoalMinutes[later]then usedGoalMinutes[later]=true;return later end
			local earlier=math.clamp(minute-offset,1,maxMinute)
			if not usedGoalMinutes[earlier]then usedGoalMinutes[earlier]=true;return earlier end
		end
		for fallback=1,maxMinute do
			if not usedGoalMinutes[fallback]then usedGoalMinutes[fallback]=true;return fallback end
		end
		return minute
	end
	for _,goal in ipairs(goals)do
		goal.Minute=uniqueGoalMinute(tonumber(goal.Minute)or 1)
	end
	for index,goal in ipairs(goals)do
		if ((#tostring(goal.Team)+goal.Minute+index)%17)==0 then goal.Method="Penalty"end
	end
	table.sort(goals,function(a,b)if a.Minute==b.Minute then return a.Team<b.Team end;return a.Minute<b.Minute end)
	local commentaryEvents=buildSimulationCommentary(home,away,goals,maxMinute)
	local simulationStats=buildSimulationStats(home,away,homeGoals,awayGoals,goals)
	local homeNow,awayNow=0,0
	local triggered={}
	local triggeredCommentary={}
	local duration=hasPenalties and 82 or hasExtraTime and 75 or 60
	local lastStep=os.clock()
	local elapsed=0
	TweenService:Create(overlay,TweenInfo.new(.28),{GroupTransparency=0}):Play()
	task.delay(.18,startSimulationAudio)
	task.spawn(function()
		while gui.Parent do
			local now=os.clock()
			elapsed+=math.max(0,now-lastStep)*speedMultiplier
			lastStep=now
			local alpha=math.clamp(elapsed/duration,0,1)
			fill.Size=UDim2.fromScale(alpha,1)
			local minute=math.floor(alpha*maxMinute+.5)
			clock.Text=string.format("%02d'",minute)
			for index,event in ipairs(commentaryEvents)do
				if not triggeredCommentary[index]and minute>=event.Minute then
					triggeredCommentary[index]=true
					if event.Kind~="Goal"then
						showCommentaryEvent(event)
						if event.Kind=="RedCard"then addRedCardMarker(tostring(event.Team or""))end
						local sequence=commentarySequence
						task.delay(1.9/math.max(1,speedMultiplier),function()
							if sequence==commentarySequence and eventText.Parent then eventText.TextColor3=Theme.Colors.Silver end
						end)
					end
				end
			end
			for index,goal in ipairs(goals)do
				if not triggered[index]and minute>=goal.Minute then
					triggered[index]=true
					if goal.Side=="Home"then homeNow+=1 else awayNow+=1 end
					scoreLabel.Text=string.format("%d  -  %d",homeNow,awayNow)
					playSimOneShot(goalSound)
					showCommentaryEvent({Minute=goal.Minute,Kind=goal.Method=="Penalty"and"Penalty Scored"or"Goal",Text=string.format("%s score through %s%s.",string.upper(tostring(goal.Team or"")),tostring(goal.Scorer or"SCORER"),goal.Assister and(" after the pass from "..tostring(goal.Assister))or"")})
					detail.Visible=true
					detail.BackgroundTransparency=.28
					scorerLabel.Text=tostring(goal.Scorer or"SCORER")
					assistIcon.Visible=goal.Assister~=nil
					assistLabel.Visible=goal.Assister~=nil
					assistLabel.Text=goal.Assister and tostring(goal.Assister)or""
					if noGoals and noGoals.Parent then noGoals:Destroy()end
					local goalRow=Instance.new("Frame");goalRow.BackgroundTransparency=1;goalRow.Size=UDim2.new(1,-6,0,34);goalRow.LayoutOrder=index;goalRow.ZIndex=1001;goalRow.Parent=goalList
					local rowGoalIcon=Instance.new("ImageLabel");rowGoalIcon.BackgroundTransparency=1;rowGoalIcon.Image="rbxassetid://135771264315819";rowGoalIcon.Position=UDim2.fromOffset(0,6);rowGoalIcon.Size=UDim2.fromOffset(18,18);rowGoalIcon.ScaleType=Enum.ScaleType.Fit;rowGoalIcon.ZIndex=1002;rowGoalIcon.Parent=goalRow
					local rowText=string.format("%02d'  %s  /  %s",goal.Minute,tostring(goal.Scorer or"SCORER"),string.upper(tostring(goal.Team or"")))
					local scorer=text(goalRow,rowText,UDim2.fromOffset(24,0),UDim2.new(1,-24,0,17),8,Theme.Colors.White,Theme.Fonts.Strong);scorer.ZIndex=1002;scorer.TextTruncate=Enum.TextTruncate.AtEnd
					if goal.Assister then
						local rowAssistIcon=Instance.new("ImageLabel");rowAssistIcon.BackgroundTransparency=1;rowAssistIcon.Image="rbxassetid://93968131485797";rowAssistIcon.Position=UDim2.fromOffset(24,18);rowAssistIcon.Size=UDim2.fromOffset(14,14);rowAssistIcon.ScaleType=Enum.ScaleType.Fit;rowAssistIcon.ZIndex=1002;rowAssistIcon.Parent=goalRow
						local assist=text(goalRow,tostring(goal.Assister),UDim2.fromOffset(42,17),UDim2.new(1,-42,0,16),8,Theme.Colors.Silver,Theme.Fonts.Strong);assist.ZIndex=1002;assist.TextTruncate=Enum.TextTruncate.AtEnd
					end
					goalList.CanvasPosition=Vector2.new(0,math.max(0,goalLayout.AbsoluteContentSize.Y-goalList.AbsoluteWindowSize.Y))
					detail.Size=UDim2.fromScale(.46,.07)
					TweenService:Create(detail,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromScale(.58,.07)}):Play()
					local marker=Instance.new("Frame");marker.AnchorPoint=Vector2.new(.5,.5);marker.BackgroundColor3=Theme.Colors.White;marker.BorderSizePixel=0;marker.Position=UDim2.fromScale(math.clamp(goal.Minute/maxMinute,0,1),.5);marker.Size=UDim2.fromOffset(10,28);marker.ZIndex=1002;marker.Parent=timeline;corner(marker,99)
					TweenService:Create(scoreLabel,TweenInfo.new(.16,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextSize=74}):Play()
					task.delay(.18,function()if scoreLabel.Parent then TweenService:Create(scoreLabel,TweenInfo.new(.2),{TextSize=58}):Play()end end)
					task.delay(2.2/math.max(1,speedMultiplier),function()
						if detail.Parent then
							TweenService:Create(detail,TweenInfo.new(.22),{BackgroundTransparency=1,Size=UDim2.fromScale(.50,.06)}):Play()
							task.delay(.24,function()if detail.Parent then detail.Visible=false;detail.BackgroundTransparency=.28 end end)
						end
					end)
				end
			end
			if alpha>=1 then break end
			task.wait(.08)
		end
		if gui.Parent then
			if purchaseConnection then purchaseConnection:Disconnect();purchaseConnection=nil end
			clock.Text=string.format("%02d'",maxMinute)
			fill.Size=UDim2.fromScale(1,1)
			scoreLabel.Text=string.format("%d  -  %d",homeGoals,awayGoals)
			detail.Visible=false
			task.wait(1.25/math.max(1,speedMultiplier))
			if hasPenalties then
				playPenaltyShootout(function()
					playFinalSimulationWhistle()
					showFullTimeStats(simulationStats)
				end)
			else
				playFinalSimulationWhistle()
				showFullTimeStats(simulationStats)
			end
		elseif purchaseConnection then
			purchaseConnection:Disconnect()
		end
	end)
end

function Page.new(context:any):CanvasGroup
	local group,scroll=PageBase.new("WorldCup",1800)
	PageBase.heading(scroll,"NATIONAL STAGE","WORLD CUP","Select a nation, reveal groups A-H, play your fixtures, and chase the trophy.")
	local response=MatchSetupService:GetWorldCup()
	local data=response and response.Data or{}
	local state=data.State
	local history=type(data.History)=="table"and data.History or{}
	local selected=state and state.SelectedCountry or WorldCupConfig.Countries[1]
	local terminalState=isTerminalWorldCup(state)
	local knockoutIntroSeen=state and state.Stage=="Knockout" and seenKnockoutIntroByRun[worldCupRunKey(state)]==true or false
	local countryButtons:{[string]:TextButton}={}
	local applyReturnedState:(any)->()=function(_newState:any)end
	local applyEmptyWorldCupState:(any?)->()=function(_newHistory:any?)end
	local function maybeShowTournamentComplete(currentState:any)
		if context.IsCurrentPage and not context.IsCurrentPage("WorldCup")then return end
		if type(currentState)~="table"or not currentState.WorldCupWinner then return end
		if currentState.RestSimulated~=true and currentState.Stage~="Champion"then return end
		local key=worldCupRunKey(currentState)..":complete:"..tostring(currentState.WorldCupWinner)
		if seenTournamentCompleteByRun[key]then return end
		seenTournamentCompleteByRun[key]=true
		task.defer(function()
			if group.Parent and (not context.IsCurrentPage or context.IsCurrentPage("WorldCup"))then showWorldCupCompleteOverlay(context.Root,currentState,function()end)end
		end)
	end
	local dashboard=Instance.new("Frame");dashboard.Name="WorldCupDashboard";dashboard.BackgroundTransparency=1;dashboard.Position=UDim2.fromOffset(0,96);dashboard.Size=UDim2.new(1,0,0,430);dashboard.Parent=scroll
	local selector=Panel.new({Name="NationSelector",Position=UDim2.fromOffset(0,0),Size=UDim2.new(.5,-8,1,0)});selector.Parent=dashboard
	text(selector,"SELECT NATION",UDim2.fromOffset(18,14),UDim2.new(1,-36,0,28),20,Theme.Colors.White,Theme.Fonts.Display)
	text(selector,state and(terminalState and"RUN COMPLETE  /  START AGAIN TO CHOOSE AGAIN"or"TOURNAMENT LOCKED  /  CANCEL TO CHOOSE AGAIN")or"Choose the country you want to take through the tournament.",UDim2.fromOffset(20,44),UDim2.new(1,-40,0,24),9,Theme.Colors.Muted,Theme.Fonts.Strong)
	local searchBox=Instance.new("TextBox");searchBox.Name="NationSearch";searchBox.BackgroundColor3=Theme.Colors.Gunmetal;searchBox.BorderSizePixel=0;searchBox.Position=UDim2.fromOffset(18,76);searchBox.Size=UDim2.new(1,-36,0,34);searchBox.PlaceholderText="SEARCH COUNTRY";searchBox.Text="";searchBox.TextColor3=Theme.Colors.White;searchBox.PlaceholderColor3=Theme.Colors.Muted;searchBox.TextSize=10;searchBox.Font=Theme.Fonts.Strong;searchBox.ClearTextOnFocus=false;searchBox.TextXAlignment=Enum.TextXAlignment.Left;searchBox.Parent=selector;corner(searchBox,6)
	local searchPadding=Instance.new("UIPadding");searchPadding.PaddingLeft=UDim.new(0,12);searchPadding.PaddingRight=UDim.new(0,10);searchPadding.Parent=searchBox
	local searchStroke=Instance.new("UIStroke");searchStroke.Color=Theme.Colors.Border;searchStroke.Transparency=.15;searchStroke.Parent=searchBox
	local nationList=Instance.new("ScrollingFrame");nationList.Name="NationList";nationList.BackgroundTransparency=1;nationList.BorderSizePixel=0;nationList.Position=UDim2.fromOffset(18,124);nationList.Size=UDim2.new(1,-36,1,-142);nationList.AutomaticCanvasSize=Enum.AutomaticSize.Y;nationList.CanvasSize=UDim2.new();nationList.ScrollBarThickness=4;nationList.ScrollBarImageColor3=Theme.Colors.Electric;nationList.Parent=selector
	local layout=Instance.new("UIGridLayout");layout.CellSize=UDim2.new(.5,-8,0,56);layout.CellPadding=UDim2.fromOffset(12,12);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=nationList
	local root=Panel.new({Name="WorldCupHero",Position=UDim2.new(.5,8,0,0),Size=UDim2.new(.5,-8,1,0)});root.Parent=dashboard
	local selectedFlag=flag(root,selected,UDim2.fromOffset(26,72),UDim2.fromOffset(170,116))
	local title=text(root,state and(terminalState and"WORLD CUP COMPLETE"or"TOURNAMENT ACTIVE")or"READY FOR THE DRAW",UDim2.fromOffset(26,24),UDim2.new(1,-52,0,42),30,Theme.Colors.White,Theme.Fonts.Display)
	local nextOpponent=state and state.NextFixture and ((state.NextFixture.Home==selected and state.NextFixture.Away)or state.NextFixture.Home)or nil
	local subtitle=text(root,"",UDim2.fromOffset(26,70),UDim2.new(1,-52,0,24),12,Theme.Colors.Electric,Theme.Fonts.Strong)
	local fixturePanel=Instance.new("Frame");fixturePanel.Name="NextFixturePanel";fixturePanel.BackgroundColor3=Theme.Colors.Black;fixturePanel.BackgroundTransparency=.16;fixturePanel.BorderSizePixel=0;fixturePanel.Position=UDim2.fromOffset(26,96);fixturePanel.Size=UDim2.new(1,-52,0,128);fixturePanel.Parent=root;corner(fixturePanel,8)
	local fixtureStroke=Instance.new("UIStroke");fixtureStroke.Color=Theme.Colors.Border;fixtureStroke.Transparency=.25;fixtureStroke.Thickness=1;fixtureStroke.Parent=fixturePanel
	local homeFixtureFlag=flag(fixturePanel,selected,UDim2.fromOffset(22,24),UDim2.fromOffset(78,52));homeFixtureFlag.ZIndex=2
	local awayFixtureFlag=flag(fixturePanel,nextOpponent or selected,UDim2.new(1,-100,0,24),UDim2.fromOffset(78,52));awayFixtureFlag.ZIndex=2
	local homeFixtureName=text(fixturePanel,string.upper(selected),UDim2.fromOffset(18,82),UDim2.new(.42,-18,0,30),14,Theme.Colors.White,Theme.Fonts.Display);homeFixtureName.TextXAlignment=Enum.TextXAlignment.Left;homeFixtureName.TextWrapped=false;homeFixtureName.TextScaled=true;homeFixtureName.TextTruncate=Enum.TextTruncate.AtEnd;homeFixtureName.ZIndex=2
	local homeNameLimit=Instance.new("UITextSizeConstraint");homeNameLimit.MinTextSize=7;homeNameLimit.MaxTextSize=14;homeNameLimit.Parent=homeFixtureName
	local awayFixtureName=text(fixturePanel,string.upper(nextOpponent or selected),UDim2.new(.58,0,0,82),UDim2.new(.42,-18,0,30),14,Theme.Colors.White,Theme.Fonts.Display);awayFixtureName.TextXAlignment=Enum.TextXAlignment.Right;awayFixtureName.TextWrapped=false;awayFixtureName.TextScaled=true;awayFixtureName.TextTruncate=Enum.TextTruncate.AtEnd;awayFixtureName.ZIndex=2
	local awayNameLimit=Instance.new("UITextSizeConstraint");awayNameLimit.MinTextSize=7;awayNameLimit.MaxTextSize=14;awayNameLimit.Parent=awayFixtureName
	local versusLabel=text(fixturePanel,"VS",UDim2.fromScale(.43,.27),UDim2.fromScale(.14,.38),31,Theme.Colors.Electric,Theme.Fonts.Display);versusLabel.TextXAlignment=Enum.TextXAlignment.Center;versusLabel.ZIndex=2
	local fixtureHint=text(fixturePanel,"",UDim2.fromScale(.05,.78),UDim2.fromScale(.9,.15),9,Theme.Colors.Muted,Theme.Fonts.Strong);fixtureHint.TextXAlignment=Enum.TextXAlignment.Center;fixtureHint.Visible=false;fixtureHint.ZIndex=2
	local function worldCupRoundLabel(currentState:any?):string
		if type(currentState)~="table"then return"SELECTED NATION"end
		if currentState.Stage=="Group"then return"GAMEDAY "..tostring(currentState.GroupMatchIndex or(currentState.NextFixture and currentState.NextFixture.Matchday)or 1)
		elseif currentState.Stage=="Knockout"then return string.upper(tostring(WorldCupConfig.KnockoutRounds[tonumber(currentState.Knockout and currentState.Knockout.Round)or 1]or"KNOCKOUT"))
		elseif currentState.Stage=="Champion"then return"WORLD CUP FINAL"
		elseif currentState.Stage=="Eliminated"then return"RUN COMPLETE"
		end
		return string.upper(tostring(currentState.Stage or"WORLD CUP"))
	end
	local function updateNextFixtureDisplay(currentState:any?)
		local currentSelected=tostring(currentState and currentState.SelectedCountry or selected)
		local fixture=currentState and currentState.NextFixture
		local complete=type(currentState)=="table"and(currentState.Stage=="Champion"or currentState.Stage=="Eliminated"or currentState.WorldCupWinner~=nil)
		local home=tostring(fixture and fixture.Home or currentSelected)
		local away=tostring(fixture and fixture.Away or currentSelected)
		if not fixture then
			home=currentSelected
			away=currentSelected
		end
		subtitle.Text=worldCupRoundLabel(currentState)
		homeFixtureFlag.Image=WorldCupConfig.Flag(home)
		awayFixtureFlag.Image=WorldCupConfig.Flag(away)
		homeFixtureName.Text=string.upper(home)
		awayFixtureName.Text=string.upper(away)
		versusLabel.Text=fixture and"VS"or""
		fixtureHint.Text=""
		fixturePanel.Visible=currentState~=nil and not complete and fixture~=nil
		selectedFlag.Visible=currentState==nil
	end
	updateNextFixtureDisplay(state)
	text(root,"GROUPS A-H  /  TOP TWO ADVANCE  /  SINGLE-LEG KNOCKOUTS",UDim2.fromOffset(26,238),UDim2.new(1,-52,0,18),9,Theme.Colors.Silver,Theme.Fonts.Strong)
	local launchBusy=false
	local endCup:TextButton
	local startButton:TextButton
	local simulateButton:TextButton
	local function startButtonText():string
		if not state then return"START WORLD CUP"end
		if terminalState and state.PendingRewards and state.RewardsClaimed~=true then return"CLAIM REWARDS"end
		if terminalState then return"START AGAIN"end
		return"PLAY NEXT MATCH"
	end
	local function simulateButtonText():string
		if state and state.Stage=="Eliminated"then return"SIMULATE REST OF WORLD CUP"end
		return"SIMULATE MATCH"
	end
	local function simulateButtonVisible():boolean
		if not state then return false end
		if state.Stage=="Eliminated"then return state.RestSimulated~=true end
		return not terminalState
	end
	startButton=Button.new({Text=startButtonText(),Variant="Primary",Size=UDim2.fromOffset(230,46),OnActivated=function()
		if launchBusy then return end
		launchBusy=true
		local matchLoading:ScreenGui?=nil
		local result=nil
		if terminalState and state and state.PendingRewards and state.RewardsClaimed~=true then
			if startButton then startButton.Text="CLAIMING..."end
			result=MatchSetupService:ClaimWorldCupRewards()
		elseif isTerminalWorldCup(state)then
			result=MatchSetupService:EndWorldCup()
		elseif state then
			matchLoading=showWorldCupMatchLoading("LOADING "..string.upper(tostring(nextOpponent or"NEXT OPPONENT")))
			if startButton then startButton.Text="LOADING MATCH..."end
			if endCup then endCup.Active=false;endCup.AutoButtonColor=false end
			result=MatchSetupService:StartWorldCupMatch()
		else
			result=MatchSetupService:BeginWorldCup(selected)
		end
		if result and result.Success then
			context.Toast({Title="WORLD CUP",Message=result.Message or"World Cup updated.",Kind="Info"})
			if terminalState and state and state.PendingRewards and state.RewardsClaimed~=true then
				local newState=result.Data and result.Data.WorldCup and result.Data.WorldCup.State
				local reward=result.Data and result.Data.Reward
				local granted=result.Data and result.Data.Granted
				showWorldCupRewardOverlay(reward,granted,function()
					launchBusy=false
					if newState then applyReturnedState(newState)else context.Navigate("WorldCup")end
				end)
				if startButton then
					startButton.Text="REWARDS CLAIMED"
				end
			elseif isTerminalWorldCup(state)then
				launchBusy=false
				applyEmptyWorldCupState(result.Data and result.Data.History)
			elseif state then
				local data=result.Data or{}
				if data.Teleporting==true or data.AIMatchTeleport==true or data.AlreadyQueued==true or data.AlreadyStarting==true or data.AlreadyStarted==true then
					task.spawn(function()
						local playerGui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
						local started=os.clock()
						while matchLoading and matchLoading.Parent and os.clock()-started<20 do
							if playerGui and playerGui:FindFirstChild("VTRPrematchBroadcast")then
								completeWorldCupLoading(matchLoading)
								break
							end
							task.wait(.12)
						end
					end)
				else
					completeWorldCupLoading(matchLoading)
					launchBusy=false
					if startButton then startButton.Text=startButtonText()end
					if endCup then endCup.Active=true;endCup.AutoButtonColor=true end
				end
			elseif not state then
				launchBusy=false
				local newState=result.Data and result.Data.State
				if newState then applyReturnedState(newState);showGroupDrawOverlay(context.Root,newState,newState.SelectedCountry or selected,function()context.Navigate("WorldCup")end)else context.Navigate("WorldCup")end
			end
		else
			completeWorldCupLoading(matchLoading)
			launchBusy=false
			if startButton then startButton.Text=startButtonText()end
			if simulateButton then simulateButton.Text=simulateButtonText();simulateButton.Visible=simulateButtonVisible()end
			if endCup then endCup.Active=true;endCup.AutoButtonColor=true end
			context.Toast({Title="WORLD CUP",Message=result and(result.Message or result.Error)or"World Cup unavailable.",Kind="Error"})
		end
	end})
	startButton.Position=UDim2.fromOffset(26,222);startButton.Parent=root
	simulateButton=Button.new({Text=simulateButtonText(),Variant="Secondary",Size=UDim2.fromOffset(220,46),OnActivated=function()
		if launchBusy or not state then return end
		if state.Stage=="Eliminated"then
			launchBusy=true
			simulateButton.Text="SIMULATING..."
			local result=MatchSetupService:SimulateRestOfWorldCup()
			launchBusy=false
			if result and result.Success then
				context.Toast({Title="WORLD CUP",Message=result.Message or"World Cup simulated.",Kind="Info"})
				local newState=result.Data and result.Data.WorldCup and result.Data.WorldCup.State
				if newState then applyReturnedState(newState)else context.Navigate("WorldCup")end
			else
				simulateButton.Text=simulateButtonText()
				context.Toast({Title="WORLD CUP",Message=result and(result.Message or result.Error)or"Simulation failed.",Kind="Error"})
			end
			return
		end
		if terminalState then return end
		launchBusy=true
		simulateButton.Text="SIMULATING..."
		if startButton then startButton.Active=false;startButton.AutoButtonColor=false end
		local result=MatchSetupService:SimulateWorldCupMatch()
		if result and result.Success then
			local score=result.Data and result.Data.Score
			local scoreText=score and(string.format("%s %d - %d %s",tostring(score.Home),tonumber(score.HomeGoals)or 0,tonumber(score.AwayGoals)or 0,tostring(score.Away)))or(result.Message or"Match simulated.")
			local newState=result.Data and result.Data.WorldCup and result.Data.WorldCup.State
			if score then
				showSimulatedMatchOverlay(score,function()
					launchBusy=false
					if startButton then startButton.Active=true;startButton.AutoButtonColor=true end
					context.Toast({Title="SIMULATED RESULT",Message=scoreText,Kind="Info"})
					if newState then
						local shouldShowQualified=state and state.Stage=="Group"and newState.Stage=="Knockout"
						applyReturnedState(newState)
						if shouldShowQualified then
							local key=worldCupRunKey(newState);seenKnockoutIntroByRun[key]=true;knockoutIntroSeen=true
							if startButton then startButton.Text=startButtonText()end
							showQualifiedOverlay(context.Root,newState,function()end)
						end
					else context.Navigate("WorldCup")end
				end)
			else
				launchBusy=false
				if startButton then startButton.Active=true;startButton.AutoButtonColor=true end
				context.Toast({Title="SIMULATED RESULT",Message=scoreText,Kind="Info"})
				if newState then
					local shouldShowQualified=state and state.Stage=="Group"and newState.Stage=="Knockout"
					applyReturnedState(newState)
					if shouldShowQualified then
						local key=worldCupRunKey(newState);seenKnockoutIntroByRun[key]=true;knockoutIntroSeen=true
						if startButton then startButton.Text=startButtonText()end
						showQualifiedOverlay(context.Root,newState,function()end)
					end
				else context.Navigate("WorldCup")end
			end
		else
			launchBusy=false
			if startButton then startButton.Active=true;startButton.AutoButtonColor=true end
			simulateButton.Text="SIMULATE MATCH"
			context.Toast({Title="WORLD CUP",Message=result and(result.Message or result.Error)or"Simulation failed.",Kind="Error"})
		end
	end})
	simulateButton.Position=UDim2.fromOffset(270,222);simulateButton.Parent=root;simulateButton.Visible=simulateButtonVisible()
	local cancelBusy=false
	endCup=Button.new({Text=state and(terminalState and"START AGAIN"or"CANCEL WORLD CUP")or"RESET",Variant=state and not terminalState and"Danger"or"Secondary",Size=UDim2.fromOffset(state and 190 or 112,46),OnActivated=function()
		if cancelBusy then return end
		cancelBusy=true
		local cancellingActive=state~=nil and not terminalState
		endCup.Text=cancellingActive and"CANCELING..."or"RESETTING..."
		local result=state and(terminalState and MatchSetupService:EndWorldCup()or MatchSetupService:ResetWorldCup())or MatchSetupService:ResetWorldCup()
		cancelBusy=false
		if result and result.Success then
			context.Toast({Title="WORLD CUP",Message=result.Message or"World Cup reset.",Kind="Info"})
			if cancellingActive then applyEmptyWorldCupState()else context.Navigate("WorldCup")end
		else
			endCup.Text=cancellingActive and"CANCEL WORLD CUP"or"RESET"
			context.Toast({Title="WORLD CUP",Message=result and(result.Message or result.Error)or"World Cup reset failed.",Kind="Error"})
		end
	end})
	endCup.AnchorPoint=Vector2.new(.5,1);endCup.Position=UDim2.new(.5,0,1,-22);endCup.Parent=root
	endCup.Visible=not terminalState
	local stage=text(root,string.upper(state and(state.Stage or"GROUP")or"DRAW PENDING"),UDim2.fromOffset(26,298),UDim2.new(1,-52,0,54),36,state and Theme.Colors.Electric or Theme.Colors.Muted,Theme.Fonts.Display);stage.TextXAlignment=Enum.TextXAlignment.Left
	local function applyCountrySearch()
		local query=string.lower(searchBox.Text or"")
		local visibleOrder=0
		for index,country in ipairs(WorldCupConfig.Countries)do
			local button=countryButtons[country]
			if button then
				local searchable=string.lower(country)
				local visible=query==""or string.find(searchable,query,1,true)~=nil
				button.Visible=visible
				if visible then
					visibleOrder+=1
					button.LayoutOrder=visibleOrder
				else
					button.LayoutOrder=10000+index
				end
			end
		end
		nationList.CanvasPosition=Vector2.new(0,0)
	end
	for index,country in ipairs(WorldCupConfig.Countries)do
		local b=Instance.new("TextButton");b.BorderSizePixel=0;b.AutoButtonColor=not state;b.BackgroundColor3=country==selected and Theme.Colors.Electric or Theme.Colors.Raised;b.TextColor3=country==selected and Theme.Colors.Black or Theme.Colors.White;b.Text="";b.LayoutOrder=index;b.Parent=nationList;corner(b,6);countryButtons[country]=b
		flag(b,country,UDim2.fromOffset(8,10),UDim2.fromOffset(48,34))
		local countryLabel=text(b,string.upper(country),UDim2.fromOffset(64,0),UDim2.new(1,-72,1,0),10,country==selected and Theme.Colors.Black or Theme.Colors.White,Theme.Fonts.Strong)
		b.Activated:Connect(function()
			if state then return end
			selected=country;title.Text="READY FOR THE DRAW";selectedFlag.Image=WorldCupConfig.Flag(country);selectedFlag.ImageTransparency=0;selectedFlag.BackgroundColor3=Theme.Colors.Electric;updateNextFixtureDisplay(nil)
			for c,button in countryButtons do
				local chosen=c==country;button.BackgroundColor3=chosen and Theme.Colors.Electric or Theme.Colors.Raised;button.TextColor3=chosen and Theme.Colors.Black or Theme.Colors.White
				local label=button:FindFirstChildWhichIsA("TextLabel");if label then label.TextColor3=chosen and Theme.Colors.Black or Theme.Colors.White end
			end
		end)
		countryLabel.TextTruncate=Enum.TextTruncate.AtEnd
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(applyCountrySearch)
	applyCountrySearch()
	local function setSelectorMode(activeState:any?)
		local active=type(activeState)=="table"
		searchBox.Visible=not active
		nationList.Visible=not active
		if active then
			renderWorldCupTicker(selector,activeState)
		else
			local old=selector:FindFirstChild("TournamentTickerOverlay")
			if old then old:Destroy()end
		end
	end
	setSelectorMode(state)
	local groups=Instance.new("Frame");groups.Name="Groups";groups.BackgroundTransparency=1;groups.Position=UDim2.fromOffset(0,548);groups.Size=UDim2.new(1,0,0,318);groups.Parent=scroll
	local groupLayout=Instance.new("UIGridLayout");groupLayout.CellPadding=UDim2.fromOffset(12,12);groupLayout.CellSize=UDim2.new(.25,-9,0,146);groupLayout.SortOrder=Enum.SortOrder.LayoutOrder;groupLayout.Parent=groups
	if state and state.Groups then
		for _,groupName in ipairs(WorldCupConfig.GroupNames)do groupCard(groups,groupName,state.Groups[groupName],state.SelectedCountry,state.Standings)end
	else
		local drawPreview=Panel.new({Name="DrawPreview",Size=UDim2.new(1,0,0,146)});drawPreview.Parent=groups
		text(drawPreview,"GROUP DRAW PREVIEW",UDim2.fromOffset(18,16),UDim2.new(1,-36,0,32),22,Theme.Colors.White,Theme.Fonts.Display)
		text(drawPreview,"Press START WORLD CUP to animate and reveal eight groups of four teams. Your nation is placed into the tournament and the road updates after every match.",UDim2.fromOffset(20,58),UDim2.new(1,-40,0,54),12,Theme.Colors.Silver,Theme.Fonts.Strong)
	end
	local tablePanel=Panel.new({Name="GroupTable",Position=UDim2.fromOffset(0,888),Size=UDim2.new(1,0,0,224)});tablePanel.Parent=scroll
	renderGroupLeaderboard(tablePanel,state,state and state.SelectedCountry or selected)
	local bracket=Panel.new({Name="Bracket",Position=UDim2.fromOffset(0,1132),Size=UDim2.new(1,0,0,430)});bracket.Parent=scroll
	renderBracket(bracket,state)
	local historyPanel=Panel.new({Name="WorldCupHistory",Position=UDim2.fromOffset(0,1588),Size=UDim2.new(1,0,0,170)});historyPanel.Parent=scroll
	local function renderHistoryPanel()
		for _,child in historyPanel:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
		text(historyPanel,"WORLD CUP HISTORY",UDim2.fromOffset(18,12),UDim2.new(1,-36,0,28),20,Theme.Colors.White,Theme.Fonts.Display)
		text(historyPanel,"Completed attempts only. Manually ended tournaments are not counted.",UDim2.fromOffset(20,44),UDim2.new(1,-40,0,20),9,Theme.Colors.Muted,Theme.Fonts.Strong)
		if #history==0 then
			local empty=text(historyPanel,"NO COMPLETED WORLD CUP RUNS YET",UDim2.fromOffset(20,86),UDim2.new(1,-40,0,34),18,Theme.Colors.Muted,Theme.Fonts.Display)
			empty.TextXAlignment=Enum.TextXAlignment.Center
			return
		end
		for index,entry in ipairs(history)do
			if index>4 then break end
			local row=Instance.new("Frame");row.BackgroundColor3=Theme.Colors.Raised;row.BackgroundTransparency=.14;row.BorderSizePixel=0;row.Position=UDim2.new((index-1)/4,18,0,76);row.Size=UDim2.new(.25,-26,0,72);row.Parent=historyPanel;corner(row,6)
			local country=tostring(entry.Country or"")
			flag(row,country,UDim2.fromOffset(10,12),UDim2.fromOffset(54,36))
			text(row,string.upper(country),UDim2.fromOffset(74,10),UDim2.new(1,-84,0,20),9,Theme.Colors.White,Theme.Fonts.Strong)
			text(row,string.upper(tostring(entry.Reached or"UNKNOWN")),UDim2.fromOffset(74,34),UDim2.new(1,-84,0,20),12,entry.Stage=="Champion"and Theme.Colors.Electric or Theme.Colors.Silver,Theme.Fonts.Display)
			if entry.Winner then text(row,"WINNER: "..string.upper(tostring(entry.Winner)),UDim2.fromOffset(74,54),UDim2.new(1,-84,0,14),7,Theme.Colors.Muted,Theme.Fonts.Strong)end
		end
	end
	renderHistoryPanel()
	historyPanel.Visible=not state
	applyEmptyWorldCupState=function(newHistory:any?)
		if type(newHistory)=="table"then history=newHistory end
		state=nil
		terminalState=false
		knockoutIntroSeen=false
		selected=WorldCupConfig.Countries[1]
		searchBox.Text=""
		applyCountrySearch()
		setSelectorMode(nil)
		title.Text="READY FOR THE DRAW"
		updateNextFixtureDisplay(nil)
		selectedFlag.Image=WorldCupConfig.Flag(selected)
		selectedFlag.ImageTransparency=0
		selectedFlag.BackgroundColor3=Theme.Colors.Electric
		stage.Text="DRAW PENDING"
		stage.TextColor3=Theme.Colors.Muted
		startButton.Text="START WORLD CUP"
		if simulateButton then simulateButton.Text=simulateButtonText();simulateButton.Visible=false end
		endCup.Text="RESET"
		endCup.Size=UDim2.fromOffset(112,46)
		endCup.Visible=true
		setDangerButton(endCup,false)
		for _,child in groups:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
		local drawPreview=Panel.new({Name="DrawPreview",Size=UDim2.new(1,0,0,146)});drawPreview.Parent=groups
		text(drawPreview,"GROUP DRAW PREVIEW",UDim2.fromOffset(18,16),UDim2.new(1,-36,0,32),22,Theme.Colors.White,Theme.Fonts.Display)
		text(drawPreview,"Press START WORLD CUP to animate and reveal eight groups of four teams. Your nation is placed into the tournament and the road updates after every match.",UDim2.fromOffset(20,58),UDim2.new(1,-40,0,54),12,Theme.Colors.Silver,Theme.Fonts.Strong)
		renderGroupLeaderboard(tablePanel,nil,selected)
		renderBracket(bracket,nil)
		historyPanel.Visible=true
		renderHistoryPanel()
		for country,button in countryButtons do
			local chosen=country==selected
			button.AutoButtonColor=true
			button.BackgroundColor3=chosen and Theme.Colors.Electric or Theme.Colors.Raised
			local label=button:FindFirstChildWhichIsA("TextLabel")
			if label then label.TextColor3=chosen and Theme.Colors.Black or Theme.Colors.White end
		end
	end
	applyReturnedState=function(newState:any)
		if type(newState)~="table"then return end
		state=newState
		terminalState=isTerminalWorldCup(newState)
		knockoutIntroSeen=newState.Stage=="Knockout"and seenKnockoutIntroByRun[worldCupRunKey(newState)]==true or false
		selected=tostring(newState.SelectedCountry or selected)
		setSelectorMode(newState)
		title.Text=terminalState and"WORLD CUP COMPLETE"or"TOURNAMENT ACTIVE"
		local nextFixture=newState.NextFixture
		local opponent=nextFixture and ((nextFixture.Home==selected and nextFixture.Away)or nextFixture.Home)or nil
		nextOpponent=opponent
		updateNextFixtureDisplay(newState)
		selectedFlag.Image=WorldCupConfig.Flag(selected)
		stage.Text=string.upper(tostring(newState.Stage or"GROUP"))
		stage.TextColor3=Theme.Colors.Electric
		startButton.Text=startButtonText()
		if simulateButton then simulateButton.Text=simulateButtonText();simulateButton.Visible=simulateButtonVisible() end
		endCup.Text=terminalState and"START AGAIN"or"CANCEL WORLD CUP"
		endCup.Size=UDim2.fromOffset(190,46)
		endCup.Visible=not terminalState
		setDangerButton(endCup,not terminalState)
		for _,child in groups:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
		for _,groupName in ipairs(WorldCupConfig.GroupNames)do groupCard(groups,groupName,newState.Groups and newState.Groups[groupName],selected,newState.Standings)end
		renderGroupLeaderboard(tablePanel,newState,selected)
		renderBracket(bracket,newState)
		historyPanel.Visible=false
		for country,button in countryButtons do
			local chosen=country==selected
			button.AutoButtonColor=false
			button.BackgroundColor3=chosen and Theme.Colors.Electric or Theme.Colors.Raised
			local label=button:FindFirstChildWhichIsA("TextLabel")
			if label then label.TextColor3=chosen and Theme.Colors.Black or Theme.Colors.White end
		end
		maybeShowTournamentComplete(newState)
	end
	maybeShowTournamentComplete(state)
	if state and state.Stage=="Knockout"and not knockoutIntroSeen then
		task.defer(function()
			if not group.Parent then return end
			local key=worldCupRunKey(state)
			seenKnockoutIntroByRun[key]=true
			knockoutIntroSeen=true
			if startButton then startButton.Text=startButtonText()end
			showQualifiedOverlay(context.Root,state,function()end)
		end)
	end
	return group
end

return Page
