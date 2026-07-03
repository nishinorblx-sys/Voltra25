--!strict
local Service={}
local skin={Fair=Color3.fromRGB(255,219,185),Light=Color3.fromRGB(241,194,156),LightWarm=Color3.fromRGB(224,172,125),Porcelain=Color3.fromRGB(255,224,199),Golden=Color3.fromRGB(198,134,82),Sand=Color3.fromRGB(210,156,112),Tan=Color3.fromRGB(181,119,76),WarmTan=Color3.fromRGB(168,108,72),OliveLight=Color3.fromRGB(190,145,103),MediumBrown=Color3.fromRGB(137,82,55),Brown=Color3.fromRGB(112,66,44),DeepBrown=Color3.fromRGB(78,43,31),Ebony=Color3.fromRGB(53,31,25)}
local hair={Black=Color3.fromRGB(22,18,16),Brown=Color3.fromRGB(83,53,34),DarkBrown=Color3.fromRGB(52,34,25),LightBrown=Color3.fromRGB(130,86,52),Blonde=Color3.fromRGB(221,184,105),Red=Color3.fromRGB(140,54,34)}
local function weld(part:BasePart,target:BasePart)local joint=Instance.new("WeldConstraint");joint.Part0=part;joint.Part1=target;joint.Parent=part end
local function hairBlock(head:BasePart,name:string,size:Vector3,offset:CFrame,color:Color3,shape:Enum.PartType?):Part local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=head.CFrame*offset;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.CanCollide=false;p.CanTouch=false;p.Massless=true;p:SetAttribute("VTRHair",true);if shape then p.Shape=shape end;p.Parent=head.Parent;weld(p,head);return p end
local function clearHair(model:Model)for _,child in model:GetChildren()do if child:IsA("BasePart")and child:GetAttribute("VTRHair")==true then child:Destroy()end end end
local function hairTop(head:BasePart,name:string,height:number,color:Color3,width:number?,depth:number?,x:number?,z:number?)hairBlock(head,name,Vector3.new(width or 2.04,height,depth or 1.05),CFrame.new(x or 0,.54+height*.5,z or 0),color)end
local function hairBack(head:BasePart,name:string,height:number,color:Color3,z:number?)hairBlock(head,name,Vector3.new(1.9,height,.22),CFrame.new(0,.16,z or .55),color)end
local function hairSide(head:BasePart,name:string,x:number,height:number,color:Color3)hairBlock(head,name,Vector3.new(.14,height,1.02),CFrame.new(x,.06,0),color)end
local function createHair(head:BasePart,style:string,color:Color3)
	if style=="Shaved"then return end
	if style=="BuzzCut"then hairTop(head,"BuzzCut",.12,color);return end
	if style=="Afro"or style=="MiniAfro"then
		local scale=style=="MiniAfro"and .82 or 1
		for x=-1,1 do for z=-1,1 do
			if not(x~=0 and z==1)then hairBlock(head,"Afro"..x.."_"..z,Vector3.new(.62*scale,.62*scale,.54*scale),CFrame.new(x*.52*scale,.78+(x==0 and .12 or 0)*scale,z*.34*scale),color,Enum.PartType.Ball)end
		end end
		return
	end
	if style=="CurlyShort"or style=="CurlyMedium"or style=="Cornrows"or style=="ShortLocs"then
		for i=-2,2 do hairBlock(head,style.."Curl"..i,Vector3.new(.42,.42,.42),CFrame.new(i*.34,.74+(i%2)*.06,-.02),color,Enum.PartType.Ball)end
		if style=="CurlyMedium"or style=="ShortLocs"then hairBack(head,style.."Back",.48,color,.5)end
		if style=="Cornrows"then for i=-2,2 do hairBlock(head,"Cornrow"..i,Vector3.new(.11,.2,1.08),CFrame.new(i*.23,.72,0),color)end end
		return
	end
	if style=="Braids"or style=="Locs"then
		hairTop(head,style.."Top",.24,color,1.9,1.03)
		for i=-3,3 do hairBlock(head,style.."Strand"..i,Vector3.new(.12,.78,.12),CFrame.new(i*.27,.08,.56),color,Enum.PartType.Cylinder)end
		return
	end
	if style=="LongStraight"or style=="Ponytail"then
		hairTop(head,style.."Top",.34,color,1.92,1.05)
		hairBack(head,style.."Back",1.05,color,.55)
		if style=="Ponytail"then hairBlock(head,"PonytailTie",Vector3.new(.38,.38,.38),CFrame.new(0,.18,.82),color,Enum.PartType.Ball);hairBlock(head,"PonytailTail",Vector3.new(.32,.92,.32),CFrame.new(0,-.22,1.02),color,Enum.PartType.Cylinder)end
		return
	end
	if style=="MohawkFade"or style=="Spiky"then
		hairTop(head,style.."Base",.14,color,1.85,1.0)
		local count=style=="MohawkFade"and 3 or 5
		for i=-(count//2),count//2 do hairBlock(head,style.."Spike"..i,Vector3.new(.25,.48,.32),CFrame.new(i*.34,.92+(i%2)*.05,0)*CFrame.Angles(0,0,i*.08),color)end
		if style=="MohawkFade"then hairSide(head,"MohawkFadeLeft",-1.03,.35,color);hairSide(head,"MohawkFadeRight",1.03,.35,color)end
		return
	end
	if style=="Fade"or style=="HighFade"or style=="LowFade"or style=="TempleFade"then
		local sideHeight=style=="HighFade"and .26 or style=="LowFade"and .56 or .42
		hairTop(head,style.."Top",style=="HighFade"and .3 or .22,color,style=="TempleFade"and 1.62 or 1.8,.98)
		hairSide(head,style.."Left",-1.03,sideHeight,color);hairSide(head,style.."Right",1.03,sideHeight,color)
		return
	end
	if style=="SidePart"or style=="MediumSweep"or style=="SlickBack"then
		hairTop(head,style.."Base",.18,color,2.02,1.04)
		hairBlock(head,style.."Sweep",Vector3.new(style=="SlickBack"and 1.75 or 1.18,.3,1.0),CFrame.new(style=="MediumSweep"and -.22 or -.38,.86,style=="SlickBack"and .08 or 0),color)
		if style~="SlickBack"then hairBlock(head,"PartLine",Vector3.new(.07,.32,1.04),CFrame.new(.24,.82,0),Color3.fromRGB(42,33,27))else hairBack(head,"SlickBackBack",.42,color,.5)end
		return
	end
	if style=="ShortMessy"or style=="TexturedTop"or style=="WavyShort"then
		hairTop(head,style.."Base",.18,color,2.02,1.04)
		for i=-2,2 do hairBlock(head,style.."Tuft"..i,Vector3.new(.34,.24+math.abs(i)*.03,.38),CFrame.new(i*.34,.84+(i%2)*.05,-.04),color)end
		return
	end
	if style=="FlatTop"then hairTop(head,"FlatTop",.38,color,1.84,.95);hairBlock(head,"FlatFace",Vector3.new(1.82,.08,.95),CFrame.new(0,.98,0),color);return end
	if style=="BowlFade"then hairTop(head,"BowlCap",.28,color,2.08,1.06);hairBlock(head,"BowlFringe",Vector3.new(1.88,.2,.12),CFrame.new(0,.66,-.55),color);return end
	if style=="LongTopFade"or style=="Undercut"then hairTop(head,style.."Top",.4,color,1.74,1.0);hairSide(head,style.."Left",-1.04,.25,color);hairSide(head,style.."Right",1.04,.25,color);return end
	hairTop(head,style.."Top",style=="CrewCut"and .18 or .22,color,2.0,1.02);if style=="CaesarCut"then hairBlock(head,"CaesarFringe",Vector3.new(1.6,.14,.12),CFrame.new(0,.66,-.55),color)else hairBack(head,style.."Back",.38,color,.53)end
end
local function face(head:BasePart,appearance:any,skinColor:Color3,hairColor:Color3)
	local gui=Instance.new("SurfaceGui");gui.Name="VTRFace";gui.Face=Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=80;gui.LightInfluence=0;gui.Parent=head
	local canvas=Instance.new("Frame");canvas.BackgroundTransparency=1;canvas.Size=UDim2.fromScale(1,1);canvas.Parent=gui
	local function shape(name:string,pos:UDim2,size:UDim2,color:Color3,rotation:number?)local f=Instance.new("Frame");f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.Position=pos;f.Size=size;f.BackgroundColor3=color;f.BorderSizePixel=0;f.Rotation=rotation or 0;f.Parent=canvas;local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=f;return f end
	local eyeY=appearance.eyeType=="Sleepy"and .45 or .42;shape("LeftEye",UDim2.fromScale(.35,eyeY),UDim2.fromScale(.11,.065),Color3.fromRGB(20,18,17));shape("RightEye",UDim2.fromScale(.65,eyeY),UDim2.fromScale(.11,.065),Color3.fromRGB(20,18,17));shape("LeftBrow",UDim2.fromScale(.35,.32),UDim2.fromScale(.22,.035),hairColor,appearance.eyebrowType=="Angled"and -8 or 0);shape("RightBrow",UDim2.fromScale(.65,.32),UDim2.fromScale(.22,.035),hairColor,appearance.eyebrowType=="Angled"and 8 or 0)
	shape("Nose",UDim2.fromScale(.5,.57),UDim2.fromScale(appearance.noseType=="Wide"and .15 or .09,.055),skinColor:Lerp(Color3.new(0,0,0),.22))
	local mouth=shape("Mouth",UDim2.fromScale(.5,.72),UDim2.fromScale(.25,.035),Color3.fromRGB(91,39,38),appearance.mouthType=="Smirk"and -7 or 0);if appearance.mouthType=="Serious"then mouth.Size=UDim2.fromScale(.2,.025)end
	if appearance.facialHair and appearance.facialHair~="None"then shape("FacialHair",UDim2.fromScale(.5,.8),UDim2.fromScale(appearance.facialHair=="Mustache"and .28 or .42,appearance.facialHair=="FullBeard"and .22 or .1),hairColor).BackgroundTransparency=.18 end
end
function Service.Apply(model:Model,appearance:any)
	local humanoid=model:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff;humanoid.NameDisplayDistance=0;humanoid.HealthDisplayDistance=0;humanoid.DisplayName=""end
	appearance=appearance or{};local skinColor=skin[appearance.skinTone]or skin.Tan;local hairColor=hair[appearance.hairColor]or hair.Black
	for _,name in{"Head","Left Arm","Right Arm","Left Leg","Right Leg"}do local p=model:FindFirstChild(name);if p and p:IsA("BasePart")then p.Color=skinColor end end
	local head=model:FindFirstChild("Head")::BasePart?;if not head then return end;for _,child in head:GetChildren()do if child:IsA("Decal")then child:Destroy()end end;face(head,appearance,skinColor,hairColor)
	clearHair(model)
	createHair(head,appearance.hairStyle or"BuzzCut",hairColor)
end
return Service
