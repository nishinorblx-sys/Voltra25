--!strict
local TweenService=game:GetService("TweenService")
local Service={}
local function color(value:any,fallback:Color3):Color3 local ok,result=pcall(Color3.fromHex,tostring(value or""));return ok and result or fallback end
local function textSurface(part:BasePart,face:Enum.NormalId,value:string,textColor:Color3,size:number,name:string)local gui=Instance.new("SurfaceGui");gui.Name=name;gui.Face=face;gui.LightInfluence=0;gui.PixelsPerStud=70;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.Parent=part;local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1);label.Text=value;label.TextColor3=textColor;label.TextScaled=true;label.Font=Enum.Font.GothamBlack;label.Parent=gui;local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(.18,0);padding.PaddingRight=UDim.new(.18,0);padding.PaddingTop=UDim.new(size,0);padding.PaddingBottom=UDim.new(size,0);padding.Parent=label end
local function frontBadgePlate(torso:BasePart,value:string,textColor:Color3)
	local plate=Instance.new("Part");plate.Name="ChestBadgePlate";plate.Anchored=false;plate.CanCollide=false;plate.CanTouch=false;plate.CanQuery=false;plate.CastShadow=false;plate.Massless=true;plate.Material=Enum.Material.SmoothPlastic;plate.Transparency=1;plate.Size=Vector3.new(math.max(.8,torso.Size.X*.62),math.max(.18,torso.Size.Y*.16),.025);plate.CFrame=torso.CFrame*CFrame.new(0,torso.Size.Y*.12,-torso.Size.Z*.5-.045);plate.Parent=torso.Parent
	local weld=Instance.new("WeldConstraint");weld.Part0=torso;weld.Part1=plate;weld.Parent=plate
	textSurface(plate,Enum.NormalId.Front,value,textColor,.10,"ChestBadge")
end
local function backPrintSurface(part:BasePart,playerName:string,number:string,textColor:Color3)
	local gui=Instance.new("SurfaceGui");gui.Name="BackPrint";gui.Face=Enum.NormalId.Back;gui.LightInfluence=0;gui.PixelsPerStud=90;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.Parent=part
	local nameLabel=Instance.new("TextLabel");nameLabel.Name="PlayerName";nameLabel.BackgroundTransparency=1;nameLabel.Position=UDim2.fromScale(.08,.10);nameLabel.Size=UDim2.fromScale(.84,.18);nameLabel.Text=string.upper(playerName);nameLabel.TextColor3=textColor;nameLabel.TextScaled=true;nameLabel.Font=Enum.Font.GothamBlack;nameLabel.TextXAlignment=Enum.TextXAlignment.Center;nameLabel.TextYAlignment=Enum.TextYAlignment.Center;nameLabel.Parent=gui
	local numberLabel=Instance.new("TextLabel");numberLabel.Name="ShirtNumber";numberLabel.BackgroundTransparency=1;numberLabel.Position=UDim2.fromScale(.16,.27);numberLabel.Size=UDim2.fromScale(.68,.50);numberLabel.Text=number;numberLabel.TextColor3=textColor;numberLabel.TextScaled=true;numberLabel.Font=Enum.Font.GothamBlack;numberLabel.TextXAlignment=Enum.TextXAlignment.Center;numberLabel.TextYAlignment=Enum.TextYAlignment.Center;numberLabel.Parent=gui
end
local function pattern(torso:BasePart,style:string,primary:Color3,secondary:Color3,accent:Color3)
	local gui=Instance.new("SurfaceGui");gui.Name="VTRKitPattern";gui.Face=Enum.NormalId.Front;gui.LightInfluence=0;gui.PixelsPerStud=80;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.Parent=torso;local root=Instance.new("Frame");root.BackgroundColor3=primary;root.BorderSizePixel=0;root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true;root.Parent=gui
	local function bar(name:string,pos:UDim2,size:UDim2,c:Color3,rotation:number?)local f=Instance.new("Frame");f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.Position=pos;f.Size=size;f.BackgroundColor3=c;f.BorderSizePixel=0;f.Rotation=rotation or 0;f.Parent=root;return f end
	local function label(name:string,value:string,pos:UDim2,size:UDim2,c:Color3,maxSize:number)local t=Instance.new("TextLabel");t.Name=name;t.AnchorPoint=Vector2.new(.5,.5);t.BackgroundTransparency=1;t.Position=pos;t.Size=size;t.Text=value;t.TextColor3=c;t.TextScaled=true;t.Font=Enum.Font.GothamBlack;t.Parent=root;local constraint=Instance.new("UITextSizeConstraint");constraint.MaxTextSize=maxSize;constraint.MinTextSize=4;constraint.Parent=t;return t end
	local function voltraMarks(showWordmark:boolean)label("VoltraV","V",UDim2.fromScale(.79,.18),UDim2.fromScale(.14,.14),accent,20);label("VoltraBolt","Z",UDim2.fromScale(.21,.2),UDim2.fromScale(.1,.1),accent,12);if showWordmark then label("VoltraWordmark","VOLTRA",UDim2.fromScale(.5,.37),UDim2.fromScale(.54,.12),accent,15)end end
	if style=="Vertical Stripes"then for i=1,5 do if i%2==0 then bar("Stripe",UDim2.fromScale((i-.5)/5,.5),UDim2.fromScale(.2,1.1),secondary)end end elseif style=="Horizontal Stripes"or style=="Hoops"then for i=1,5 do bar("Hoop",UDim2.fromScale(.5,i/6),UDim2.fromScale(1.1,.09),secondary)end elseif style=="Diagonal Sash"then bar("Sash",UDim2.fromScale(.5,.5),UDim2.fromScale(.18,1.55),secondary,-34);bar("SashAccent",UDim2.fromScale(.54,.5),UDim2.fromScale(.035,1.45),accent,-34)elseif style=="Split"then bar("Split",UDim2.fromScale(.75,.5),UDim2.fromScale(.5,1),secondary)elseif style=="Gradient"then local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new(primary,secondary);gradient.Rotation=90;gradient.Parent=root elseif style=="Lightning Trim"then bar("Bolt1",UDim2.fromScale(.4,.3),UDim2.fromScale(.08,.55),accent,25);bar("Bolt2",UDim2.fromScale(.52,.62),UDim2.fromScale(.08,.55),accent,-28)elseif style=="Volt Pattern"then for i=1,3 do bar("Volt",UDim2.fromScale(.25*i,.5),UDim2.fromScale(.05,1.4),i==2 and accent or secondary,i%2==0 and -22 or 22)end elseif style=="Checker Accent"then for y=1,5 do for x=1,4 do if(x+y)%2==0 then bar("Check",UDim2.fromScale((x-.5)/4,(y-.5)/5),UDim2.fromScale(.25,.2),secondary)end end end elseif style=="Chevron"then bar("ChevronLeft",UDim2.fromScale(.39,.5),UDim2.fromScale(.075,1),secondary,-43);bar("ChevronRight",UDim2.fromScale(.61,.5),UDim2.fromScale(.075,1),secondary,43);bar("ChevronAccentLeft",UDim2.fromScale(.39,.55),UDim2.fromScale(.024,.86),accent,-43);bar("ChevronAccentRight",UDim2.fromScale(.61,.55),UDim2.fromScale(.024,.86),accent,43)elseif style=="Racing Stripe"then bar("CenterStripe",UDim2.fromScale(.5,.5),UDim2.fromScale(.16,1.08),secondary);bar("LeftPin",UDim2.fromScale(.39,.5),UDim2.fromScale(.025,1.08),accent);bar("RightPin",UDim2.fromScale(.61,.5),UDim2.fromScale(.025,1.08),accent)elseif style=="Volt Halves"then bar("HalfPanel",UDim2.fromScale(.25,.5),UDim2.fromScale(.5,1.08),secondary);bar("HalfSlash",UDim2.fromScale(.5,.5),UDim2.fromScale(.032,.96),accent,-18)elseif style=="Voltra Founder"then bar("FounderChevronLeft",UDim2.fromScale(.34,.36),UDim2.fromScale(.055,.72),Color3.fromRGB(18,18,18),-48);bar("FounderChevronRight",UDim2.fromScale(.66,.36),UDim2.fromScale(.055,.72),Color3.fromRGB(18,18,18),48);bar("FounderCoreLeft",UDim2.fromScale(.37,.48),UDim2.fromScale(.045,.66),Color3.fromRGB(35,35,35),-48);bar("FounderCoreRight",UDim2.fromScale(.63,.48),UDim2.fromScale(.045,.66),Color3.fromRGB(35,35,35),48);bar("FounderSideLeft",UDim2.fromScale(.18,.56),UDim2.fromScale(.025,.72),accent);bar("FounderSideRight",UDim2.fromScale(.82,.56),UDim2.fromScale(.025,.72),accent);bar("FounderHem",UDim2.fromScale(.5,.92),UDim2.fromScale(1.05,.055),accent);voltraMarks(true)elseif style=="Voltra Limited"then bar("LimitedTextureA",UDim2.fromScale(.47,.58),UDim2.fromScale(.028,.98),Color3.fromRGB(15,15,15),-26);bar("LimitedTextureB",UDim2.fromScale(.57,.54),UDim2.fromScale(.022,.9),Color3.fromRGB(20,20,20),-26);bar("LimitedSideLeft",UDim2.fromScale(.16,.56),UDim2.fromScale(.022,.72),accent);bar("LimitedSideRight",UDim2.fromScale(.84,.56),UDim2.fromScale(.022,.72),accent);bar("LimitedHem",UDim2.fromScale(.5,.93),UDim2.fromScale(1.05,.045),accent);voltraMarks(false)elseif style=="Voltra Lightning"then for i=0,4 do local y=.18+i*.17;bar("DarkCrack",UDim2.fromScale(.5,y),UDim2.fromScale(.028,1.18),Color3.fromRGB(22,22,22),-64);bar("LightningCrack",UDim2.fromScale(.32+(i%2)*.22,y+.04),UDim2.fromScale(.026,.72),accent,-42+i*8)end;bar("MainLightning",UDim2.fromScale(.48,.55),UDim2.fromScale(.055,1.24),accent,-36);bar("LightningCore",UDim2.fromScale(.48,.55),UDim2.fromScale(.018,1.2),Color3.fromRGB(230,255,120),-36);voltraMarks(false)elseif style=="Voltra Gradient"then local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,primary),ColorSequenceKeypoint.new(.48,Color3.fromRGB(9,9,9)),ColorSequenceKeypoint.new(1,secondary)});gradient.Rotation=90;gradient.Parent=root;for i=1,6 do local shade=bar("GradientTexture",UDim2.fromScale(i/7,.62),UDim2.fromScale(.012,.95),Color3.fromRGB(18,18,18),-18);shade.BackgroundTransparency=.25 end;bar("GradientSideLeft",UDim2.fromScale(.16,.58),UDim2.fromScale(.022,.74),accent);bar("GradientSideRight",UDim2.fromScale(.84,.58),UDim2.fromScale(.022,.74),accent);local glow=bar("GradientBottomGlow",UDim2.fromScale(.5,.91),UDim2.fromScale(1.1,.08),accent);glow.BackgroundTransparency=.2;voltraMarks(false)end
	if style=="Voltra Gradient"then
		root.BackgroundColor3=Color3.fromRGB(5,5,5)
		local bloom=bar("GradientLowerBloomStrong",UDim2.fromScale(.5,.76),UDim2.fromScale(1.18,.48),accent)
		bloom.BackgroundTransparency=.34
		local fade=Instance.new("UIGradient")
		fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.45,.68),NumberSequenceKeypoint.new(1,0)})
		fade.Rotation=90
		fade.Parent=bloom
		for i=1,4 do
			local lift=bar("GradientFadeLift",UDim2.fromScale(.5,.58+i*.075),UDim2.fromScale(1.08,.08),accent)
			lift.BackgroundTransparency=.86-(i*.1)
		end
	end
	return root
end
local function addAnimatedKit(model:Model,torso:BasePart,root:Frame,accent:Color3)
	for _,old in model:GetChildren()do if old.Name=="VTRAnimatedKitBolt"then old:Destroy()end end
	local sweep=Instance.new("Frame");sweep.Name="AnimatedKitSweep";sweep.AnchorPoint=Vector2.new(.5,.5);sweep.BackgroundColor3=accent;sweep.BackgroundTransparency=.45;sweep.BorderSizePixel=0;sweep.Position=UDim2.fromScale(-.2,.5);sweep.Rotation=-18;sweep.Size=UDim2.fromScale(.08,1.45);sweep.Parent=root
	local bolts={}
	local function bolt(x:number,y:number,w:number,h:number,rotation:number,transparency:number)
		local p=Instance.new("Part");p.Name="VTRAnimatedKitBolt";p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Massless=true;p.Material=Enum.Material.Neon;p.Color=accent;p.Transparency=transparency;p.Size=Vector3.new(torso.Size.X*w,torso.Size.Y*h,.018);p.CFrame=torso.CFrame*CFrame.new(torso.Size.X*x,torso.Size.Y*y,-torso.Size.Z*.5-.035)*CFrame.Angles(0,0,math.rad(rotation));p.Parent=model
		local weld=Instance.new("WeldConstraint");weld.Part0=torso;weld.Part1=p;weld.Parent=p
		table.insert(bolts,p)
		return p
	end
	bolt(0,-.03,.075,1.18,-36,.16)
	bolt(0,-.03,.026,1.10,-36,0)
	bolt(-.22,.17,.026,.58,-64,.04)
	bolt(.20,-.23,.024,.52,-60,.08)
	task.spawn(function()
		local pulse=false
		while sweep.Parent do
			pulse=not pulse
			sweep.Position=UDim2.fromScale(-.2,.5)
			TweenService:Create(sweep,TweenInfo.new(1.15,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Position=UDim2.fromScale(1.2,.5),BackgroundTransparency=.22}):Play()
			for index,p in bolts do
				if p.Parent then
					TweenService:Create(p,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=pulse and(index==1 and .08 or 0)or(index==1 and .28 or .12)}):Play()
				end
			end
			task.wait(.42)
			for index,p in bolts do
				if p.Parent then
					TweenService:Create(p,TweenInfo.new(.28,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=index==1 and .18 or .04}):Play()
				end
			end
			task.wait(.5)
		end
	end)
end
local function bootColor(id:string,accent:Color3):Color3
	if id=="boots_limited_green"then return Color3.fromHex("B7FF1A")end
	if id=="boots_animated_trail"then return Color3.fromHex("1DDCFF")end
	if id=="boots_gradient_premium"then return Color3.fromHex("FF2E4F")end
	return accent
end
local function bootSecondaryColor(id:string):Color3
	if id=="boots_gradient_premium"then return Color3.fromHex("B7FF1A")end
	if id=="boots_animated_trail"then return Color3.fromHex("071016")end
	return Color3.fromHex("050805")
end
local function bootPart(name:string,size:Vector3,cframe:CFrame,c:Color3,material:Enum.Material,parent:Instance):Part
	local part=Instance.new("Part");part.Name=name;part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Massless=true;part.Material=material;part.Color=c;part.Size=size;part.CFrame=cframe;part.Parent=parent;part:SetAttribute("VTRBootAccessory",true);return part
end
local function addBoots(model:Model,bootStyle:string,accent:Color3)
	if bootStyle==""then return end
	local c=bootColor(bootStyle,accent);local secondary=bootSecondaryColor(bootStyle);local material=bootStyle=="boots_animated_trail"and Enum.Material.Neon or Enum.Material.SmoothPlastic
	for _,old in model:GetChildren()do if old.Name=="VTRBoot"then old:Destroy()end end
	for _,legName in{"Left Leg","Right Leg"}do
		local leg=model:FindFirstChild(legName)
		if leg and leg:IsA("BasePart")then
			local boot=Instance.new("Model");boot.Name="VTRBoot";boot:SetAttribute("VTRBootStyle",bootStyle);boot.Parent=model
			local base=leg.CFrame*CFrame.new(0,-leg.Size.Y*.52,-leg.Size.Z*.08)
			local body=bootPart("BootBody",Vector3.new(leg.Size.X*1.08,.18,leg.Size.Z*1.06),base,c,material,boot)
			local toe=bootPart("BootToe",Vector3.new(leg.Size.X*1.12,.16,leg.Size.Z*.48),base*CFrame.new(0,-.01,-leg.Size.Z*.45),bootStyle=="boots_gradient_premium"and secondary or c,material,boot)
			local sole=bootPart("BootSole",Vector3.new(leg.Size.X*1.14,.055,leg.Size.Z*1.16),base*CFrame.new(0,-.12,0),secondary,Enum.Material.SmoothPlastic,boot)
			local collar=bootPart("BootCollar",Vector3.new(leg.Size.X*.92,.12,leg.Size.Z*.38),base*CFrame.new(0,.14,leg.Size.Z*.3),secondary,Enum.Material.SmoothPlastic,boot)
			for _,part in{body,toe,sole,collar}do local weld=Instance.new("WeldConstraint");weld.Part0=leg;weld.Part1=part;weld.Parent=part end
			if bootStyle=="boots_animated_trail"then local a0=Instance.new("Attachment");a0.Position=Vector3.new(0,0,body.Size.Z*.48);a0.Parent=body;local a1=Instance.new("Attachment");a1.Position=Vector3.new(0,0,-body.Size.Z*.56);a1.Parent=toe;local trail=Instance.new("Trail");trail.Attachment0=a0;trail.Attachment1=a1;trail.Color=ColorSequence.new(c);trail.Lifetime=.22;trail.LightEmission=.85;trail.Transparency=NumberSequence.new(.18,1);trail.Parent=body end
		end
	end
end
function Service.Apply(model:Model,kit:any,number:number,shortName:string,badgeText:string)
	local primary=color(kit.Primary or kit.primaryColor,Color3.fromHex("B7FF1A"));local secondary=color(kit.Secondary or kit.secondaryColor,Color3.fromHex("111111"));local accent=color(kit.Accent or kit.accentColor,Color3.fromHex("D9D9D9"));local style=kit.Style or kit.KitStyle or kit.kitStyle or"Solid";local torso=model:FindFirstChild("Torso")::BasePart?
	if torso then torso.Color=primary;local root=pattern(torso,style,primary,secondary,accent);if kit.Animated==true and root then addAnimatedKit(model,torso,root,accent)end;local printColor=kit.NumberColor and color(kit.NumberColor,accent)or accent;backPrintSurface(torso,shortName,tostring(number),printColor);frontBadgePlate(torso,badgeText,accent)end
	for _,name in{"Left Arm","Right Arm"}do local p=model:FindFirstChild(name);if p and p:IsA("BasePart")then p.Color=primary end end;for _,name in{"Left Leg","Right Leg"}do local p=model:FindFirstChild(name);if p and p:IsA("BasePart")then p.Color=secondary end end
	addBoots(model,tostring(kit.BootStyle or kit.bootStyle or""),accent)
end
return Service
