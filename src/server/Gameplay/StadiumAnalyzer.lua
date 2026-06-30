--!strict
local CollectionService=game:GetService("CollectionService")
local Workspace=game:GetService("Workspace")

local Analyzer={}
local formation={Vector2.new(0,.84),Vector2.new(-.35,.61),Vector2.new(-.13,.64),Vector2.new(.13,.64),Vector2.new(.35,.61),Vector2.new(-.24,.25),Vector2.new(0,.34),Vector2.new(.24,.25),Vector2.new(-.32,-.25),Vector2.new(0,-.38),Vector2.new(.32,-.25)}

local function pitchScore(part:BasePart):number
	local name=string.lower(part.Name)
	if name=="baseplate"or not part.Anchored or part.Size.Y>12 or math.min(part.Size.X,part.Size.Z)<30 or math.max(part.Size.X,part.Size.Z)>1000 then return -math.huge end
	local score=part.Size.X*part.Size.Z
	if name:find("pitch")or name:find("field")or name:find("grass")then score*=8 end
	if part:GetAttribute("VTRPitch")==true then score*=100 end
	if part.Material==Enum.Material.Grass then score*=4 end
	if part.Color.G>part.Color.R*1.15 and part.Color.G>part.Color.B*1.15 then score*=2 end
	if part:FindFirstAncestorWhichIsA("Model")and string.lower(part:FindFirstAncestorWhichIsA("Model").Name):find("stadium")then score*=2 end
	return score
end

function Analyzer.FindPitch():BasePart?
	for _,tagged in CollectionService:GetTagged("VTRPitch")do if tagged:IsA("BasePart")then return tagged end end
	local best:BasePart?=nil;local bestScore=-math.huge
	for _,item in Workspace:GetDescendants()do
		if item:IsA("BasePart")and not item:FindFirstAncestor("VTRStadiumAnalysis")and not item:FindFirstAncestor("VTRMatch_")then local score=pitchScore(item);if score>bestScore then best=item;bestScore=score end end
	end
	return best
end

function Analyzer.Analyze(pitch:BasePart?):any?
	pitch=pitch or Analyzer.FindPitch();if not pitch then return nil end
	local width,length,pitchCFrame
	if pitch.Size.Z>=pitch.Size.X then width=pitch.Size.X;length=pitch.Size.Z;pitchCFrame=pitch.CFrame else width=pitch.Size.Z;length=pitch.Size.X;pitchCFrame=CFrame.fromMatrix(pitch.Position,pitch.CFrame.LookVector,pitch.CFrame.UpVector,pitch.CFrame.RightVector)end
	pitchCFrame=CFrame.fromMatrix(pitch.Position+pitch.CFrame.UpVector*(pitch.Size.Y/2),pitchCFrame.RightVector,pitchCFrame.UpVector,pitchCFrame.ZVector)
	local result={Pitch=pitch,PitchCFrame=pitchCFrame,Center=pitchCFrame.Position,Width=width,Length=length,HomeGoal=pitchCFrame:PointToWorldSpace(Vector3.new(0,0,length/2)),AwayGoal=pitchCFrame:PointToWorldSpace(Vector3.new(0,0,-length/2)),HomeSpawns={},AwaySpawns={}}
	for index,point in formation do local x=point.X*width;local z=point.Y*length/2;result.HomeSpawns[index]=pitchCFrame:PointToWorldSpace(Vector3.new(x,3,z));result.AwaySpawns[index]=pitchCFrame:PointToWorldSpace(Vector3.new(x,3,-z))end
	return result
end

local function marker(parent:Instance,name:string,position:Vector3,color:Color3,size:Vector3?)local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Material=Enum.Material.Neon;p.Color=color;p.Transparency=.2;p.Size=size or Vector3.new(2,.25,2);p.Position=position;p.Parent=parent;return p end
function Analyzer.CreateDebugMarkers(result:any):Folder
	local old=Workspace:FindFirstChild("VTRStadiumAnalysis");if old then old:Destroy()end;local folder=Instance.new("Folder");folder.Name="VTRStadiumAnalysis";folder.Parent=Workspace
	marker(folder,"PITCH_CENTER",result.Center,Color3.fromHex("B7FF1A"),Vector3.new(4,.35,4));marker(folder,"HOME_GOAL",result.HomeGoal,Color3.fromHex("39B8FF"));marker(folder,"AWAY_GOAL",result.AwayGoal,Color3.fromHex("FF384D"))
	for index,position in result.HomeSpawns do marker(folder,"HOME_"..index,position,Color3.fromHex("39B8FF"))end;for index,position in result.AwaySpawns do marker(folder,"AWAY_"..index,position,Color3.fromHex("FF384D"))end
	return folder
end
function Analyzer.PrintReport(result:any)print(string.format("[VTR Stadium] Pitch=%s Center=(%.2f, %.2f, %.2f) Width=%.2f Length=%.2f",result.Pitch:GetFullName(),result.Center.X,result.Center.Y,result.Center.Z,result.Width,result.Length));print("[VTR Stadium] Set the pitch part attribute VTRPitch=true or tag it VTRPitch to lock detection.")end
return Analyzer
