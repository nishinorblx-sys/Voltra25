--!strict
local Controller = {}
Controller.__index = Controller

local function makeDisc(name:string,color:Color3,size:number,transparency:number): Part
	local part=Instance.new("Part")
	part.Name=name
	part.Shape=Enum.PartType.Cylinder
	part.Size=Vector3.new(.035,size,size)
	part.Anchored=true
	part.CanCollide=false
	part.CanTouch=false
	part.CanQuery=false
	part.CastShadow=false
	part.Material=Enum.Material.Neon
	part.Color=color
	part.Transparency=transparency
	part.Parent=workspace
	return part
end

local function makeBar(name:string): Part
	local part=Instance.new("Part")
	part.Name=name
	part.Anchored=true
	part.CanCollide=false
	part.CanTouch=false
	part.CanQuery=false
	part.CastShadow=false
	part.Material=Enum.Material.Neon
	part.Color=Color3.fromHex("FFFFFF")
	part.Transparency=.2
	part.Size=Vector3.new(2.4,.035,.12)
	part.Parent=workspace
	return part
end

function Controller.new(ball:BasePart)
	local raycast=RaycastParams.new()
	raycast.FilterType=Enum.RaycastFilterType.Exclude
	raycast.FilterDescendantsInstances={ball}
	local shadow=makeDisc("VTRBallAirShadow",Color3.fromRGB(0,0,0),1.15,.58)
	shadow.Material=Enum.Material.SmoothPlastic
	local landing=makeDisc("VTRBallLandingMarker",Color3.fromHex("FFFFFF"),1.05,.52)
	local crossA=makeBar("VTRLobLandingCrossA")
	local crossB=makeBar("VTRLobLandingCrossB")
	return setmetatable({Ball=ball,Raycast=raycast,Shadow=shadow,Landing=landing,CrossA=crossA,CrossB=crossB,SmoothLanding=nil},Controller)
end

function Controller:Update(_dt:number)
	if not self.Ball or not self.Ball.Parent then return end
	local lobTarget=self.Ball:GetAttribute("VTRLobTarget")
	local lobActive=self.Ball:GetAttribute("VTRLobPassActive")==true and typeof(lobTarget)=="Vector3"
	local passTarget=self.Ball:GetAttribute("VTRPassTarget")
	local passActive=typeof(passTarget)=="Vector3"
	local clearanceActive=self.Ball:GetAttribute("VTRMotionKind")=="Clearance"
	local hit=workspace:Raycast(self.Ball.Position,Vector3.new(0,-220,0),self.Raycast)
	if not hit then
		self.Shadow.Transparency=1
		self.Landing.Transparency=1
		self.CrossA.Transparency=1
		self.CrossB.Transparency=1
		self.SmoothLanding=nil
		return
	end
	local height=math.max(0,self.Ball.Position.Y-hit.Position.Y)
	local airborne=height>2.2 or math.abs(self.Ball.AssemblyLinearVelocity.Y)>8
	local landingVisible=lobActive or passActive or(clearanceActive and airborne)
	if not airborne then
		self.Shadow.Transparency=1
		if not landingVisible then
			self.Landing.Transparency=1
			self.CrossA.Transparency=1
			self.CrossB.Transparency=1
			self.SmoothLanding=nil
			return
		end
	end
	local scale=math.clamp(1+height/28,.85,2.15)
	self.Shadow.Size=Vector3.new(.035,1.05*scale,1.05*scale)
	self.Shadow.CFrame=CFrame.new(hit.Position+Vector3.new(0,.045,0))*CFrame.Angles(0,0,math.pi/2)
	self.Shadow.Transparency=math.clamp(.42+height/80,.48,.82)
	local velocity=self.Ball.AssemblyLinearVelocity
	local gravity=workspace.Gravity
	local y0=self.Ball.Position.Y-hit.Position.Y
	local vy=velocity.Y
	local discriminant=vy*vy+2*gravity*y0
	local timeToGround=discriminant>0 and math.clamp((vy+math.sqrt(discriminant))/gravity,.08,3.2) or .35
	local landingPos=self.Ball.Position+Vector3.new(velocity.X,0,velocity.Z)*timeToGround
	if lobActive then landingPos=lobTarget :: Vector3 elseif passActive then landingPos=passTarget :: Vector3 end
	if self.SmoothLanding then landingPos=self.SmoothLanding:Lerp(landingPos,.35)end
	self.SmoothLanding=landingPos
	local landingHit=workspace:Raycast(landingPos+Vector3.new(0,80,0),Vector3.new(0,-180,0),self.Raycast)
	if landingHit then landingPos=landingHit.Position end
	local markerScale=clearanceActive and math.clamp(1.35+height/32,1.35,2.65)or scale
	self.Landing.Color=clearanceActive and Color3.fromHex("FFCB45")or Color3.fromHex("FFFFFF")
	self.CrossA.Color=self.Landing.Color
	self.CrossB.Color=self.Landing.Color
	self.Landing.Size=Vector3.new(.035,1.05*markerScale,1.05*markerScale)
	local crossLength=clearanceActive and math.clamp(3.2+height/22,3.2,5.2)or 2.4
	self.CrossA.Size=Vector3.new(crossLength,.035,clearanceActive and .16 or .12)
	self.CrossB.Size=self.CrossA.Size
	self.Landing.CFrame=CFrame.new(landingPos+Vector3.new(0,.055,0))*CFrame.Angles(0,0,math.pi/2)
	self.Landing.Transparency=clearanceActive and .16 or lobActive and .34 or passActive and .42 or .46
	self.CrossA.CFrame=CFrame.new(landingPos+Vector3.new(0,.09,0))
	self.CrossB.CFrame=CFrame.new(landingPos+Vector3.new(0,.095,0))*CFrame.Angles(0,math.pi/2,0)
	self.CrossA.Transparency=landingVisible and(clearanceActive and .03 or .08)or 1
	self.CrossB.Transparency=self.CrossA.Transparency
end

function Controller:Destroy()
	if self.Shadow then self.Shadow:Destroy()end
	if self.Landing then self.Landing:Destroy()end
	if self.CrossA then self.CrossA:Destroy()end
	if self.CrossB then self.CrossB:Destroy()end
end

return Controller
