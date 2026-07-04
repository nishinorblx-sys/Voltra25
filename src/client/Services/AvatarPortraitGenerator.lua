--!strict

local AvatarPortraitGenerator = {}

local modelCache: { [string]: Model } = {}
local cacheOrder:{string}={};local MAX_CACHED_MODELS=256
local skinColors={Brown="8D5524",DeepBrown="6B3E24",Ebony="3B2417",Fair="E7C4A5",Golden="C98F58",Light="F0CFB2",LightWarm="E8BD96",MediumBrown="A9653F",OliveLight="C6A06E",Porcelain="F3D8C4",Sand="D7AA7B",Tan="B97A56",WarmTan="C88758"}
local hairColors={Black="17130F",Blonde="D5B06A",Brown="4A3020",DarkBrown="2B1A12",LightBrown="765039",Red="8F2F2F"}
local accessoryColors={Black="111111",ClubPrimary="B7FF1A",ClubSecondary="050505",DarkGray="343834",NeonGreen="9FFF00",None="111111",White="F5F7F2"}
local hairMap={Afro="Afro",BowlFade="Short",Braids="Curly",BuzzCut="BuzzCut",CaesarCut="Short",Cornrows="Curly",CrewCut="Short",CurlyMedium="Curly",CurlyShort="Curly",Fade="Fade",FlatTop="LongTop",HighFade="Fade",Locs="LongTop",LongStraight="LongTop",LongTopFade="LongTop",LowFade="Fade",MediumSweep="SidePart",MiniAfro="Afro",MohawkFade="Spiky",Ponytail="LongTop",Shaved="BuzzCut",ShortLocs="Curly",ShortMessy="Messy",SidePart="SidePart",SlickBack="SidePart",Spiky="Spiky",TempleFade="Fade",TexturedTop="Messy",Undercut="LongTop",WavyShort="Messy"}
local function portraitId(playerData:any):string return tostring(playerData.playerId or playerData.PlayerId or playerData.Id or playerData.cardInstanceId or playerData.Name or playerData.displayName or "vtr_player") end
local function cacheKey(playerData:any):string
	local appearance=playerData.appearance or {}
	return portraitId(playerData).."|"..tostring(playerData.portraitSeed or playerData.PortraitSeed or 0).."|"..tostring(appearance.skinTone or "").."|"..tostring(appearance.hairStyle or "").."|"..tostring(appearance.hairColor or "").."|"..tostring(appearance.faceShape or "")
end
local function cameraFor(size:UDim2?,special:boolean):(number,Vector3,Vector3)
	local height=size and math.abs(size.Y.Offset) or 0
	if height>0 and height<=54 then return special and 18 or 19,Vector3.new(0,1.2,special and -7.2 or -7.45),Vector3.new(0,1.22,0)end
	if height>0 and height<=100 then return special and 20 or 21,Vector3.new(0,.98,special and -8.3 or -8.65),Vector3.new(0,1.02,0)end
	return special and 22 or 23,Vector3.new(0,.78,special and -9.4 or -9.7),Vector3.new(0,.86,0)
end

local function bodyPart(model: Model, name: string, size: Vector3, position: Vector3, color: Color3, transparency: number?): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CastShadow = false
	item.Material = Enum.Material.SmoothPlastic
	item.Size = size
	item.Position = position
	item.Color = color
	item.Transparency = transparency or 0
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = model
	return item
end

local function hairPart(model: Model, name: string, size: Vector3, position: Vector3, color: Color3, shape: Enum.PartType?): Part
	local item = bodyPart(model, name, size, position, color)
	if shape then item.Shape = shape end
	return item
end

local function motor(parent: Instance, name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = c0
	joint.C1 = c1
	joint.Parent = parent
end

local function facePart(model: Model, name: string, size: Vector3, position: Vector3, color: Color3, rotation: number?, round: boolean?): Part
	local item = bodyPart(model, name, size, position, color)
	item.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(rotation or 0))
	if round then item.Shape = Enum.PartType.Ball end
	return item
end

local function createFace(model: Model, _head: Part, appearance: any)
	local ink = Color3.fromHex("1A1514")
	local eyeWidth = appearance.eyeType == "Wide" and 0.29 or appearance.eyeType == "Narrow" and 0.22 or 0.25
	local eyeHeight = (appearance.eyeType == "Narrow" or appearance.eyeType == "Sleepy") and 0.07 or 0.14
	local eyeGap=(appearance.faceShape=="Wide"or appearance.faceShape=="Square")and .43 or appearance.faceShape=="Narrow"and .35 or .4
	local roundEyes = appearance.eyeType == "Bright" or appearance.eyeType == "Wide" or appearance.eyeType=="Calm"
	facePart(model, "LeftEye", Vector3.new(eyeWidth, eyeHeight, 0.035), Vector3.new(-eyeGap, 1.64, -0.515), ink, 0, roundEyes)
	facePart(model, "RightEye", Vector3.new(eyeWidth, eyeHeight, 0.035), Vector3.new(eyeGap, 1.64, -0.515), ink, 0, roundEyes)

	local browHeight = appearance.eyebrowType == "Thick" and 0.09 or appearance.eyebrowType=="Thin"and .04 or 0.055
	local leftRotation = (appearance.eyebrowType == "Angled"or appearance.eyebrowType=="Serious") and -10 or appearance.eyebrowType == "Arched" and -5 or 0
	facePart(model, "LeftBrow", Vector3.new(0.36, browHeight, 0.035), Vector3.new(-eyeGap, 1.86, -0.516), ink, leftRotation)
	facePart(model, "RightBrow", Vector3.new(0.36, browHeight, 0.035), Vector3.new(eyeGap, 1.86, -0.516), ink, -leftRotation)
	local noseWidth=appearance.noseType=="Wide"and .2 or appearance.noseType=="Small"and .09 or .13
	facePart(model,"Nose",Vector3.new(noseWidth,.14,.04),Vector3.new(0,1.48,-.522),Color3.fromHex("8A5A42"),0,appearance.noseType=="Rounded"or appearance.noseType=="Button")

	if appearance.mouthType == "Confident" or appearance.mouthType=="Smirk" then
		facePart(model, "MouthCenter", Vector3.new(0.38, 0.055, 0.035), Vector3.new(0, 1.29, -0.517), ink)
		facePart(model, "MouthLeft", Vector3.new(0.16, 0.05, 0.035), Vector3.new(-0.23, 1.34, -0.517), ink, -22)
		facePart(model, "MouthRight", Vector3.new(0.16, 0.05, 0.035), Vector3.new(0.23, 1.34, -0.517), ink, 22)
	elseif appearance.mouthType == "Focused" or appearance.mouthType=="Serious" then
		facePart(model, "Mouth", Vector3.new(0.34, 0.06, 0.035), Vector3.new(0, 1.3, -0.517), ink, -4)
	else
		facePart(model, "Mouth", Vector3.new(0.34, 0.055, 0.035), Vector3.new(0, 1.3, -0.517), ink)
	end
	local beardColor=hairColors[appearance.facialHairColor]and Color3.fromHex(hairColors[appearance.facialHairColor])or ink
	if appearance.facialHair~="None"then local beardHeight=(appearance.facialHair=="FullBeard"or appearance.facialHair=="ShortBeard")and .28 or .08;facePart(model,"FacialHair",Vector3.new(appearance.facialHair=="Goatee"and .28 or .72,beardHeight,.035),Vector3.new(0,1.16,-.516),beardColor,0,false);if appearance.facialHair=="Mustache"or appearance.facialHair=="FullBeard"then facePart(model,"Mustache",Vector3.new(.48,.07,.035),Vector3.new(0,1.35,-.518),beardColor)end end
end

local function createHair(model: Model, style: string, color: Color3)
	if style == "Short" then
		hairPart(model, "ShortTop", Vector3.new(2.04, 0.24, 1.04), Vector3.new(0, 2.12, 0), color)
		hairPart(model, "ShortBack", Vector3.new(2.02, 0.62, 0.16), Vector3.new(0, 1.79, 0.52), color)
	elseif style == "Messy" then
		hairPart(model, "MessyBase", Vector3.new(2.04, 0.2, 1.04), Vector3.new(0, 2.1, 0), color)
		for index = -2, 2 do hairPart(model, "MessyTuft" .. index, Vector3.new(0.38, 0.3 + math.abs(index) * 0.03, 0.42), Vector3.new(index * 0.36, 2.31 + (index % 2) * 0.05, -0.05), color) end
	elseif style == "Spiky" then
		hairPart(model, "SpikyBase", Vector3.new(2.03, 0.18, 1.04), Vector3.new(0, 2.08, 0), color)
		for index = -2, 2 do hairPart(model, "Spike" .. index, Vector3.new(0.28, 0.42, 0.34), Vector3.new(index * 0.4, 2.35 + (index % 2) * 0.07, 0), color) end
	elseif style == "Curly" then
		for index = -2, 2 do hairPart(model, "Curl" .. index, Vector3.new(0.48, 0.48, 0.48), Vector3.new(index * 0.4, 2.23 + (index % 2) * 0.12, 0), color, Enum.PartType.Ball) end
		hairPart(model, "CurlBack", Vector3.new(1.9, 0.42, 0.38), Vector3.new(0, 2.12, 0.38), color)
	elseif style == "Fade" then
		hairPart(model, "FadeTop", Vector3.new(1.8, 0.22, 0.98), Vector3.new(0, 2.1, 0), color)
		hairPart(model, "FadeLeft", Vector3.new(0.12, 0.46, 1.01), Vector3.new(-1.02, 1.83, 0), color)
		hairPart(model, "FadeRight", Vector3.new(0.12, 0.46, 1.01), Vector3.new(1.02, 1.83, 0), color)
	elseif style == "SidePart" then
		hairPart(model, "SidePartBase", Vector3.new(2.03, 0.2, 1.04), Vector3.new(0, 2.1, 0), color)
		hairPart(model, "SidePartTop", Vector3.new(1.18, 0.3, 1.0), Vector3.new(-0.38, 2.31, 0), color)
		hairPart(model, "PartLine", Vector3.new(0.07, 0.34, 1.02), Vector3.new(0.24, 2.25, 0), Color3.fromHex("2A211B"))
	elseif style == "BuzzCut" then
		hairPart(model, "BuzzCut", Vector3.new(2.02, 0.12, 1.03), Vector3.new(0, 2.06, 0), color)
	elseif style == "LongTop" then
		hairPart(model, "LongTop", Vector3.new(1.86, 0.46, 1.02), Vector3.new(0, 2.28, 0), color)
		hairPart(model, "LongTopBack", Vector3.new(2.02, 0.52, 0.18), Vector3.new(0, 1.87, 0.52), color)
	else
		for x = -1, 1 do for z = -1, 1 do
			if not (x ~= 0 and z == 1) then hairPart(model, "AfroBlock" .. x .. z, Vector3.new(0.68, 0.68, 0.58), Vector3.new(x * 0.58, 2.24 + (x == 0 and 0.22 or 0), z * 0.38), color) end
		end end
	end
end

local function buildR6Model(playerData: any): Model
	local playerId = portraitId(playerData)
	local source=playerData.appearance;assert(type(source)=="table","CSV appearance missing for "..playerId);local appearance=table.clone(source);appearance.hairStyle=hairMap[appearance.hairStyle]or"BuzzCut"
	local skin = Color3.fromHex(assert(skinColors[source.skinTone],"Invalid CSV skin tone"))
	local hair = Color3.fromHex(assert(hairColors[source.hairColor],"Invalid CSV hair color"))
	local shirt = Color3.fromHex("111111");local sleeves=Color3.fromHex("111111");local trim=Color3.fromHex("B7FF1A")
	local accessory = Color3.fromHex(accessoryColors[source.accessoryColor]or"111111")

	local model = Instance.new("Model")
	model.Name = "R6Footballer_" .. playerId
	model:SetAttribute("PortraitSeed",playerData.portraitSeed or 0);model:SetAttribute("CardPose",source.cardPose);model:SetAttribute("CelebrationStyle",source.celebrationStyle);model:SetAttribute("WalkStyle",source.walkStyle);model:SetAttribute("SpecialPortrait",source.specialPortrait==true)
	local root = bodyPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), Color3.new(), 1)
	local torso = bodyPart(model, "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), shirt)
	local head = bodyPart(model, "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), skin)
	local leftArm = bodyPart(model, "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin)
	local rightArm = bodyPart(model, "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin)
	local leftLeg = bodyPart(model, "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), skin)
	local rightLeg = bodyPart(model, "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), skin)
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	motor(root, "RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor(torso, "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor(torso, "Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor(torso, "Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor(torso, "Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	motor(torso, "Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

	-- Football shirt overlays preserve the classic one-piece R6 arms underneath.
	local leftSleeve=bodyPart(model, "Left Sleeve", Vector3.new(1.04, 0.56, 1.04), Vector3.new(-1.5, 0.72, 0), sleeves)
	local rightSleeve=bodyPart(model, "Right Sleeve", Vector3.new(1.04, 0.56, 1.04), Vector3.new(1.5, 0.72, 0), sleeves)
	bodyPart(model, "ChestTrim", Vector3.new(1.84, 0.18, 0.045), Vector3.new(0, 0.34, -0.525), trim)
	bodyPart(model, "Collar", Vector3.new(0.68, 0.14, 0.045), Vector3.new(0, 0.9, -0.525), trim)

	createFace(model, head, appearance)
	createHair(model, appearance.hairStyle, hair)
	if appearance.accessoryType == "Headband" then
		hairPart(model, "Headband", Vector3.new(2.05, 0.16, 1.04), Vector3.new(0, 1.83, 0), accessory)
	elseif appearance.accessoryType == "Glasses" then
		local leftLens = hairPart(model, "LeftLens", Vector3.new(0.62, 0.32, 0.045), Vector3.new(-0.48, 1.58, -0.53), accessory); leftLens.Transparency = 0.45
		local rightLens = hairPart(model, "RightLens", Vector3.new(0.62, 0.32, 0.045), Vector3.new(0.48, 1.58, -0.53), accessory); rightLens.Transparency = 0.45
		hairPart(model, "GlassesBridge", Vector3.new(0.34, 0.08, 0.05), Vector3.new(0, 1.58, -0.535), accessory)
	elseif appearance.accessoryType == "Mask" or appearance.accessoryType == "FaceGuard" then
		local guard = hairPart(model, "FaceGuard", Vector3.new(1.28, 0.28, 0.045), Vector3.new(0, 1.28, -0.53), accessory); guard.Transparency = 0.18
	elseif appearance.accessoryType=="EarTape"then hairPart(model,"EarTape",Vector3.new(.12,.34,.12),Vector3.new(-1.01,1.55,0),accessory)
	elseif appearance.accessoryType=="SportsTape"then hairPart(model,"LeftTape",Vector3.new(1.05,.18,1.05),Vector3.new(-1.5,-.1,0),accessory);hairPart(model,"RightTape",Vector3.new(1.05,.18,1.05),Vector3.new(1.5,-.1,0),accessory)
	elseif appearance.accessoryType=="Wristband"then hairPart(model,"Wristband",Vector3.new(1.05,.16,1.05),Vector3.new(1.5,-.65,0),accessory)
	end
	if source.specialPortrait then
		local pose=source.cardPose
		if pose=="ArmsFolded"then leftArm.CFrame=CFrame.new(-.55,.05,-.58)*CFrame.Angles(0,0,math.rad(-62));rightArm.CFrame=CFrame.new(.55,.05,-.62)*CFrame.Angles(0,0,math.rad(62));leftSleeve.CFrame=CFrame.new(-1.18,.58,-.18)*CFrame.Angles(0,0,math.rad(-28));rightSleeve.CFrame=CFrame.new(1.18,.58,-.18)*CFrame.Angles(0,0,math.rad(28))
		elseif pose=="PowerStance"or pose=="CaptainPose"then leftArm.CFrame=CFrame.new(-1.55,-.05,0)*CFrame.Angles(0,0,math.rad(-12));rightArm.CFrame=CFrame.new(1.55,-.05,0)*CFrame.Angles(0,0,math.rad(12))
		elseif pose=="Pointing"then rightArm.CFrame=CFrame.new(1.75,.55,-.25)*CFrame.Angles(0,0,math.rad(78));rightSleeve.CFrame=CFrame.new(1.25,.65,-.08)*CFrame.Angles(0,0,math.rad(28))end
	end
	return model
end

function AvatarPortraitGenerator.new(parent: Instance, playerData: any, size: UDim2?, circular: boolean?): ViewportFrame
	local playerId = portraitId(playerData)
	local key = cacheKey(playerData)
	assert(type(playerData.portraitSeed)=="number"or type(playerData.PortraitSeed)=="number","CSV portraitSeed missing for "..playerId)
	if not modelCache[key] then modelCache[key] = buildR6Model(playerData);table.insert(cacheOrder,key);if#cacheOrder>MAX_CACHED_MODELS then local expired=table.remove(cacheOrder,1);if modelCache[expired]then modelCache[expired]:Destroy();modelCache[expired]=nil end end end
	local special=playerData.appearance and playerData.appearance.specialPortrait==true
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "R6PlayerPortrait"
	viewport.BackgroundColor3 = special and Color3.fromHex("090C07")or Color3.fromHex("25272A")
	viewport.BorderSizePixel = 0
	viewport.Size = size or UDim2.fromScale(1, 1)
	viewport.Ambient = special and Color3.fromHex("D4E4BE")or Color3.fromHex("B8BCB5")
	viewport.LightColor = special and Color3.fromHex("DFFF9E")or Color3.fromHex("F3F7EE")
	viewport.LightDirection = Vector3.new(-0.7, -1, -0.8)
	viewport.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = circular and UDim.new(1, 0) or UDim.new(0, 7)
	corner.Parent = viewport
	local stroke = Instance.new("UIStroke")
	stroke.Color = special and Color3.fromHex("B7FF1A")or Color3.fromHex("444941")
	stroke.Thickness = special and 2 or 1
	stroke.Transparency = 0.2
	stroke.Parent = viewport
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	modelCache[key]:Clone().Parent = world
	local camera = Instance.new("Camera")
	local fov,position,target=cameraFor(size,special)
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(position,target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return AvatarPortraitGenerator
