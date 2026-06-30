--!strict

local Library = {}

Library.Symbols = {
	"Lightning Bolt", "Football", "Crown", "Star", "Wings", "Flame", "Wolf Head", "Dragon Head", "Falcon", "Lion Head",
	"Shark", "Tiger", "Phoenix", "Shield Sword", "Mountain", "Tornado", "Viper", "Eagle", "Panther", "Meteor",
	"Skull", "Knight Helmet", "Rocket", "Volt V", "Spartan Helmet",
}

export type Palette = { Primary: Color3, Secondary: Color3, Accent: Color3 }

local function part(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: Color3, rotation: number?, round: number?): Frame
	local item = Instance.new("Frame")
	item.Name = name; item.AnchorPoint = Vector2.new(.5,.5); item.Position = UDim2.fromScale(x,y); item.Size = UDim2.fromScale(w,h)
	item.BackgroundColor3 = color; item.BorderSizePixel = 0; item.Rotation = rotation or 0; item.Parent = parent
	if round then local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(round,0);corner.Parent=item end
	return item
end

local function dot(parent: Instance, name: string, x: number, y: number, d: number, color: Color3): Frame return part(parent,name,x,y,d,d,color,0,1) end
local function outline(item: GuiObject, color: Color3, width: number) local s=Instance.new("UIStroke");s.Color=color;s.Thickness=width;s.Parent=item end
local function pair(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: Color3, rotation: number, round: number?)
	part(parent,"Left"..name,.5-x,y,w,h,color,-rotation,round);part(parent,"Right"..name,.5+x,y,w,h,color,rotation,round)
end
local function eyes(parent: Instance, color: Color3, y: number, spread: number) dot(parent,"LeftEye",.5-spread,y,.065,color);dot(parent,"RightEye",.5+spread,y,.065,color) end

local function wings(r: Frame, p: Palette)
	for side=-1,1,2 do for i=1,4 do part(r,(side<0 and"L"or"R")..i,.5+side*(.13+i*.055),.42+i*.055,.34,.105,i==4 and p.Primary or p.Accent,side*(-20-i*7),.45) end end
	dot(r,"WingCore",.5,.47,.2,p.Primary)
end

local function animal(r: Frame, p: Palette, ears: number, muzzle: number)
	part(r,"Head",.5,.52,.55,.58,p.Primary,0,.34);pair(r,"Ear",.2,.27,.21,.35,p.Accent,ears,.12)
	part(r,"Muzzle",.5,.67,muzzle,.22,p.Accent,0,.45);eyes(r,p.Secondary,.47,.13);part(r,"Nose",.5,.62,.14,.09,p.Secondary,0,.5)
end

local draw: {[string]: (Frame, Palette)->()} = {}
draw["Lightning Bolt"]=function(r,p) part(r,"Top",.57,.31,.18,.48,p.Accent,24,.08);part(r,"Joint",.5,.49,.38,.16,p.Primary,-12,.08);part(r,"Bottom",.43,.67,.18,.48,p.Accent,24,.08) end
draw.Football=function(r,p) local b=dot(r,"Ball",.5,.5,.7,p.Accent);outline(b,p.Primary,2);part(r,"Core",.5,.5,.22,.22,p.Secondary,45,.12);for i,a in{0,72,144,216,288}do local q=math.rad(a);local x,y=.5+math.sin(q)*.24,.5-math.cos(q)*.24;part(r,"Panel"..i,x,y,.15,.1,p.Primary,a,.3);part(r,"Seam"..i,(.5+x)/2,(.5+y)/2,.035,.22,p.Secondary,-a,.3)end end
draw.Crown=function(r,p) part(r,"Base",.5,.69,.68,.16,p.Accent,0,.15);for i,x in{.25,.5,.75}do part(r,"Point"..i,x,.46,.18,.5,i==2 and p.Primary or p.Accent,(i-2)*18,.08);dot(r,"Gem"..i,x,.24+math.abs(x-.5)*.24,.1,p.Secondary)end end
draw.Star=function(r,p) for i=1,5 do part(r,"Ray"..i,.5,.5,.17,.78,i%2==0 and p.Primary or p.Accent,(i-1)*72,.12)end;dot(r,"Core",.5,.5,.3,p.Accent)end
draw.Wings=wings
draw.Flame=function(r,p) part(r,"OuterL",.42,.55,.3,.68,p.Primary,24,.45);part(r,"OuterR",.58,.52,.28,.72,p.Accent,-18,.45);part(r,"Inner",.5,.64,.18,.38,p.Secondary,8,.5)end
draw["Wolf Head"]=function(r,p) animal(r,p,18,.34);pair(r,"Cheek",.23,.6,.17,.36,p.Primary,32,.15)end
draw["Dragon Head"]=function(r,p) part(r,"Snout",.55,.57,.58,.38,p.Primary,-8,.24);for i=1,3 do part(r,"Horn"..i,.28+i*.14,.28-math.abs(i-2)*.04,.11,.38,p.Accent,-30+i*14,.12)end;eyes(r,p.Secondary,.46,.13);part(r,"Jaw",.58,.7,.48,.12,p.Accent,-5,.3)end
draw.Falcon=function(r,p) part(r,"Head",.47,.43,.5,.48,p.Accent,-15,.4);part(r,"Beak",.69,.55,.34,.15,p.Primary,-20,.12);dot(r,"Eye",.51,.4,.09,p.Secondary);for i=1,3 do part(r,"Feather"..i,.35+i*.03,.63+i*.045,.35,.1,p.Primary,18+i*7,.3)end end
draw["Lion Head"]=function(r,p) for i=1,8 do part(r,"Mane"..i,.5,.5,.31,.84,p.Accent,(i-1)*45,.32)end;animal(r,p,8,.32)end
draw.Shark=function(r,p) part(r,"Body",.5,.52,.72,.34,p.Primary,-8,.5);part(r,"Fin",.48,.3,.16,.37,p.Accent,-16,.08);pair(r,"Tail",.32,.52,.2,.34,p.Accent,32,.1);dot(r,"Eye",.7,.47,.065,p.Secondary);part(r,"Mouth",.71,.61,.24,.035,p.Secondary,-8,.4)end
draw.Tiger=function(r,p) animal(r,p,10,.36);for i,x in{.37,.5,.63}do part(r,"Stripe"..i,x,.36,.065,.28,p.Secondary,(i-2)*20,.4)end end
draw.Phoenix=function(r,p) wings(r,p);part(r,"Neck",.5,.52,.16,.52,p.Primary,-8,.5);part(r,"Head",.56,.31,.25,.2,p.Accent,-10,.5);for i=1,3 do part(r,"Tail"..i,.5+(i-2)*.13,.76,.09,.42,i==2 and p.Accent or p.Primary,(i-2)*16,.4)end end
draw["Shield Sword"]=function(r,p) local s=part(r,"Shield",.5,.53,.57,.68,p.Primary,0,.22);outline(s,p.Accent,2);part(r,"Blade",.5,.46,.095,.7,p.Accent,0,.2);part(r,"Guard",.5,.63,.4,.08,p.Secondary,0,.35);dot(r,"Pommel",.5,.78,.12,p.Secondary)end
draw.Mountain=function(r,p) part(r,"LeftPeak",.35,.56,.36,.62,p.Primary,-34,.08);part(r,"MainPeak",.6,.52,.43,.72,p.Accent,31,.08);part(r,"RightPeak",.72,.64,.25,.43,p.Primary,34,.08);part(r,"Snow",.57,.32,.16,.16,p.Secondary,45,.08)end
draw.Tornado=function(r,p) for i=1,6 do part(r,"Wind"..i,.5,.25+i*.09,.82-i*.1,.075,i%2==0 and p.Primary or p.Accent,i%2==0 and 6 or-6,.5)end end
draw.Viper=function(r,p) for i=1,5 do dot(r,"Body"..i,.31+i*.09,.7-math.sin(i*1.25)*.18,.19-i*.012,i%2==0 and p.Accent or p.Primary)end;part(r,"Head",.7,.35,.32,.24,p.Primary,-12,.35);eyes(r,p.Secondary,.31,.08);part(r,"Tongue",.82,.42,.2,.025,p.Accent,12,.5)end
draw.Eagle=function(r,p) wings(r,p);part(r,"Head",.5,.42,.26,.28,p.Accent,0,.5);part(r,"Beak",.59,.5,.2,.1,p.Primary,-18,.2);dot(r,"Eye",.52,.39,.055,p.Secondary)end
draw.Panther=function(r,p) animal(r,{Primary=p.Secondary,Secondary=p.Accent,Accent=p.Primary},12,.38);pair(r,"Whisker",.25,.66,.3,.025,p.Accent,12,.5)end
draw.Meteor=function(r,p) for i=1,3 do part(r,"Trail"..i,.35,.35+(i-2)*.13,.63-i*.08,.1,i==2 and p.Accent or p.Primary,42,.5)end;dot(r,"Rock",.66,.59,.4,p.Accent);dot(r,"Crater1",.6,.54,.07,p.Secondary);dot(r,"Crater2",.72,.63,.07,p.Secondary)end
draw.Skull=function(r,p) local h=part(r,"Skull",.5,.45,.56,.52,p.Accent,0,.4);outline(h,p.Primary,1);pair(r,"Socket",.11,.44,.16,.16,p.Secondary,0,1);part(r,"Nose",.5,.57,.1,.12,p.Secondary,45,.12);for i=1,4 do part(r,"Tooth"..i,.38+i*.05,.72,.045,.18,p.Accent,0,.15)end end
draw["Knight Helmet"]=function(r,p) part(r,"Helmet",.5,.48,.62,.65,p.Accent,0,.32);part(r,"Opening",.55,.51,.52,.25,p.Secondary,0,.18);for i=1,4 do part(r,"Bar"..i,.35+i*.1,.51,.035,.27,p.Primary,0,.4)end;part(r,"Plume",.48,.17,.18,.35,p.Primary,-18,.5)end
draw.Rocket=function(r,p) part(r,"Body",.53,.45,.29,.62,p.Accent,35,.48);dot(r,"Window",.59,.37,.13,p.Secondary);pair(r,"Fin",.13,.67,.2,.28,p.Primary,18,.15);for i=1,3 do part(r,"Flame"..i,.27+i*.06,.74+i*.03,.08,.3,i==2 and p.Accent or p.Primary,35,.5)end end
draw["Volt V"]=function(r,p) local t=Instance.new("TextLabel");t.Name="VoltV";t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Text="V";t.TextScaled=true;t.Font=Enum.Font.GothamBlack;t.TextColor3=p.Accent;t.Parent=r;local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(.19,0);pad.PaddingRight=UDim.new(.19,0);pad.PaddingTop=UDim.new(.08,0);pad.PaddingBottom=UDim.new(.08,0);pad.Parent=t end
draw["Spartan Helmet"]=function(r,p) part(r,"Dome",.5,.43,.58,.55,p.Accent,0,.5);part(r,"Face",.42,.59,.2,.48,p.Accent,0,.16);part(r,"Cheek",.62,.68,.3,.12,p.Primary,-24,.2);part(r,"Opening",.58,.48,.28,.2,p.Secondary,-8,.14);for i=1,4 do part(r,"Crest"..i,.32+i*.09,.17,.07,.35,p.Primary,(i-2)*8,.4)end end

function Library.render(parent: Instance, symbolName: string, palette: Palette, size: UDim2?): Frame
	local root=Instance.new("Frame");root.Name="BadgeSymbol_"..symbolName:gsub("%s","");root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.5);root.Size=size or UDim2.fromScale(.78,.78);root.BackgroundTransparency=1;root.ClipsDescendants=true;root.Parent=parent
	local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Height;aspect.Parent=root
	local renderer = draw[symbolName] or draw["Lightning Bolt"]
	renderer(root, palette)
	return root
end

return table.freeze(Library)
