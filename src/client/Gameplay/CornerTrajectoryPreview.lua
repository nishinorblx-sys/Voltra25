--!strict
local Preview={};Preview.__index=Preview
local SEGMENTS=22
local function segment(parent:Instance):Part local p=Instance.new("Part");p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=Color3.fromHex("77F7E5");p.Transparency=.22;p.Size=Vector3.new(.12,.12,1);p.Parent=parent;return p end
function Preview.new()
	local folder=Instance.new("Folder");folder.Name="VTRCornerTrajectory";folder.Parent=workspace
	local parts={};for _=1,SEGMENTS do table.insert(parts,segment(folder))end
	local marker=Instance.new("Part");marker.Name="CornerLandingCircle";marker.Shape=Enum.PartType.Cylinder;marker.Anchored=true;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false;marker.Material=Enum.Material.Neon;marker.Color=Color3.fromHex("FFFFFF");marker.Transparency=.42;marker.Size=Vector3.new(.08,4.2,4.2);marker.Parent=folder
	return setmetatable({Folder=folder,Parts=parts,Marker=marker},Preview)
end
function Preview:Update(origin:Vector3,target:Vector3,delivery:string,power:number,up:Vector3)
	local direct=target-origin;local flat=direct-up*direct:Dot(up);local right=flat.Magnitude>.1 and flat.Unit:Cross(up)or Vector3.xAxis
	local distance=flat.Magnitude;local height=delivery=="Lob"and math.max(20,6+distance*.22+power*10)or delivery=="Driven"and math.max(5,2+distance*.08+power*3.5)or math.max(10,4+distance*.14+power*6)
	local bendBase=delivery=="Driven"and 4.2 or delivery=="Lob"and 8.2 or 6.6;local bend=bendBase*math.clamp(distance/55,.6,1.45)*(1-power*.12)
	local control=origin:Lerp(target,.5)+up*height+right*bend
	local previous=origin
	for index,part in self.Parts do local t=index/SEGMENTS;local inv=1-t;local point=origin*(inv*inv)+control*(2*inv*t)+target*(t*t);local length=(point-previous).Magnitude;part.Size=Vector3.new(.11,.11,math.max(.05,length));part.CFrame=CFrame.lookAt(previous:Lerp(point,.5),point);part.Transparency=.18+t*.2;previous=point end
	self.Marker.Size=Vector3.new(.08,3.1,3.1);self.Marker.CFrame=CFrame.new(target+up*.08)*CFrame.Angles(0,0,math.pi/2)
end
function Preview:Destroy()if self.Folder then self.Folder:Destroy()end end
return Preview
