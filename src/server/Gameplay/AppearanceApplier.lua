--!strict
local Service={}
local skin={Fair=Color3.fromRGB(255,219,185),Light=Color3.fromRGB(241,194,156),LightWarm=Color3.fromRGB(224,172,125),Porcelain=Color3.fromRGB(255,224,199),Golden=Color3.fromRGB(198,134,82),Sand=Color3.fromRGB(210,156,112),Tan=Color3.fromRGB(181,119,76),WarmTan=Color3.fromRGB(168,108,72),OliveLight=Color3.fromRGB(190,145,103),MediumBrown=Color3.fromRGB(137,82,55),Brown=Color3.fromRGB(112,66,44),DeepBrown=Color3.fromRGB(78,43,31),Ebony=Color3.fromRGB(53,31,25)}
local hair={Black=Color3.fromRGB(22,18,16),Brown=Color3.fromRGB(83,53,34),DarkBrown=Color3.fromRGB(52,34,25),LightBrown=Color3.fromRGB(130,86,52),Blonde=Color3.fromRGB(221,184,105),Red=Color3.fromRGB(140,54,34)}
local function weld(part:BasePart,target:BasePart)local joint=Instance.new("WeldConstraint");joint.Part0=part;joint.Part1=target;joint.Parent=part end
local function hairBlock(head:BasePart,name:string,size:Vector3,offset:CFrame,color:Color3):Part local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=head.CFrame*offset;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.CanCollide=false;p.CanTouch=false;p.Massless=true;p.Parent=head.Parent;weld(p,head);return p end
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
	local style=appearance.hairStyle or"BuzzCut";if style~="Shaved"then hairBlock(head,"HairTop",Vector3.new(2.05,style:find("Afro")and .9 or .35,2.05),CFrame.new(0,style:find("Afro")and .75 or .58,0),hairColor);if style:find("Long")or style=="Locs"or style=="Braids"then hairBlock(head,"HairBack",Vector3.new(1.8,1.15,.35),CFrame.new(0,.05,.95),hairColor)end;if style=="MohawkFade"or style=="Spiky"then for i=-2,2 do hairBlock(head,"Spike"..i,Vector3.new(.28,.55,.38),CFrame.new(i*.32,.9,0)*CFrame.Angles(0,0,i*.08),hairColor)end end end
end
return Service
