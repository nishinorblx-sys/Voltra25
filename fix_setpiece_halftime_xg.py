from pathlib import Path
import re

root = Path.cwd()

def p(path):
    return root / path

def read(path):
    f = p(path)
    if not f.exists():
        return None
    return f.read_text(encoding="utf-8")

def write(path, text):
    f = p(path)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text, encoding="utf-8")

def patch(path, fn):
    text = read(path)
    if text is None:
        print("missing", path)
        return
    new = fn(text)
    if new != text:
        write(path, new)
        print("patched", path)
    else:
        print("unchanged", path)

def add_before_return(text, block):
    if block.strip() in text:
        return text
    m = re.search(r"\nreturn\s+\w+\s*$", text)
    if not m:
        return text + "\n" + block.strip() + "\n"
    return text[:m.start()] + "\n" + block.strip() + "\n" + text[m.start():]

def patch_goalkeeper(text):
    text = text.replace("SaveChanceBank = {},", "GoalChanceBank = {},")
    text = text.replace("SaveChanceBank={},", "GoalChanceBank={},")
    text = re.sub(r"local function percentChance\(service:any,keeper:Model,chance:number\):boolean.*?end\s*\n\s*function Service\.new", """local function goalPercentChance(service:any,keeper:Model,chance:number):boolean
	chance=math.clamp(chance,0,1)
	if chance<=0 then
		return false
	end
	if chance>=1 then
		return true
	end
	local roll=(service.Random and service.Random:NextNumber() or math.random())
	return roll<=chance
end

function Service.new""", text, flags=re.S)
    text = re.sub(r"local function goalPercentChance\(service:any,keeper:Model,chance:number\):boolean.*?end\s*\n\s*function Service\.new", """local function goalPercentChance(service:any,keeper:Model,chance:number):boolean
	chance=math.clamp(chance,0,1)
	if chance<=0 then
		return false
	end
	if chance>=1 then
		return true
	end
	local roll=(service.Random and service.Random:NextNumber() or math.random())
	return roll<=chance
end

function Service.new""", text, flags=re.S)
    text = re.sub(r"local chance=saveProbability\((.*?)\)", r"local chance,goalChance=saveProbability(\1)", text)
    text = re.sub(r"local chance,goalChance=saveProbability\((.*?)\)", r"local chance,goalChance=saveProbability(\1)", text)
    text = text.replace("willSave=percentChance(self,keeper,chance)", "willSave=not goalPercentChance(self,keeper,goalChance or (1-chance))")
    text = text.replace("willSave=self.Random:NextNumber()<=chance", "willSave=not goalPercentChance(self,keeper,goalChance or (1-chance))")
    text = text.replace("willSave=not goalPercentChance(self,keeper,goalChance)", "willSave=not goalPercentChance(self,keeper,goalChance)")
    text = re.sub(r"local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number(.*?)\nend", lambda m: m.group(0).replace("return saveChance", "return saveChance,goalChance"), text, flags=re.S)
    text = text.replace("keeper:SetAttribute(\"VTRLastSaveChance\",math.floor(chance*100+.5))", "keeper:SetAttribute(\"VTRLastSaveChance\",math.floor((chance or 0)*100+.5))")
    text = text.replace("GoalChanceBank = {},", "GoalChanceBank = {},\n		Random = Random.new(),")
    text = text.replace("GoalChanceBank={},", "GoalChanceBank={},Random=Random.new(),")
    text = text.replace("Random = Random.new(),\n		Random = Random.new(),", "Random = Random.new(),")
    return text

def patch_setpiece(text):
    helper = r'''
local function vtrClearSetPiecePreview(self, player)
	if self.Remote then
		self.Remote:FireAllClients({Type="ClearSetPiecePreview", Player=player})
	end
	if self.Event then
		self.Event:FireAllClients({Type="ClearSetPiecePreview", Player=player})
	end
	if self.ClientRemote then
		self.ClientRemote:FireAllClients({Type="ClearSetPiecePreview", Player=player})
	end
end

local function vtrGoalSideName(goalSide)
	local s=tostring(goalSide or "")
	if string.find(s,"Home") then
		return "Home"
	end
	if string.find(s,"Away") then
		return "Away"
	end
	return s
end

local function vtrFixHomeGoalLateral(goalSide, lateral)
	if vtrGoalSideName(goalSide)=="Home" then
		return -lateral
	end
	return lateral
end
'''
    if "vtrFixHomeGoalLateral" not in text:
        first_function = re.search(r"\nlocal function|\nfunction", text)
        if first_function:
            text = text[:first_function.start()] + "\n" + helper.strip() + "\n" + text[first_function.start():]
        else:
            text = helper.strip() + "\n" + text
    text = re.sub(r"(local\s+lateral\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrFixHomeGoalLateral(targetGoalSide or goalSide or defendingSide or attackingGoal or GoalSide, \2)", text)
    text = re.sub(r"(local\s+aimX\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrFixHomeGoalLateral(targetGoalSide or goalSide or defendingSide or attackingGoal or GoalSide, \2)", text)
    text = re.sub(r"(local\s+xOffset\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrFixHomeGoalLateral(targetGoalSide or goalSide or defendingSide or attackingGoal or GoalSide, \2)", text)
    text = re.sub(r"(local\s+targetX\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrFixHomeGoalLateral(targetGoalSide or goalSide or defendingSide or attackingGoal or GoalSide, \2)", text)
    text = re.sub(r"(function\s+[%w_:\.]*Auto[%w_]*Decision[^\n]*\n)", r"\1	vtrClearSetPiecePreview(self, player or taker or shooter)\n", text)
    text = re.sub(r"(function\s+[%w_:\.]*Resolve[%w_]*Decision[^\n]*\n)", r"\1	vtrClearSetPiecePreview(self, player or taker or shooter)\n", text)
    text = re.sub(r"(function\s+[%w_:\.]*Execute[%w_]*FreeKick[^\n]*\n)", r"\1	vtrClearSetPiecePreview(self, player or taker or shooter)\n", text)
    text = re.sub(r"(function\s+[%w_:\.]*Take[%w_]*FreeKick[^\n]*\n)", r"\1	vtrClearSetPiecePreview(self, player or taker or shooter)\n", text)
    text = text.replace("vtrClearSetPiecePreview(self, player or taker or shooter)\n\tvtrClearSetPiecePreview(self, player or taker or shooter)", "vtrClearSetPiecePreview(self, player or taker or shooter)")
    return text

def patch_penalty_client(text):
    helper = r'''
local function vtrGoalName(goalSide)
	local s=tostring(goalSide or "")
	if string.find(s,"Home") then
		return "Home"
	end
	if string.find(s,"Away") then
		return "Away"
	end
	return s
end

local function vtrPenaltyShotLateral(goalSide, lateral)
	if vtrGoalName(goalSide)=="Home" then
		return -lateral
	end
	return lateral
end
'''
    if "vtrPenaltyShotLateral" not in text:
        first_function = re.search(r"\nlocal function|\nfunction", text)
        if first_function:
            text = text[:first_function.start()] + "\n" + helper.strip() + "\n" + text[first_function.start():]
        else:
            text = helper.strip() + "\n" + text
    text = re.sub(r"(local\s+shotX\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrPenaltyShotLateral(targetGoalSide or goalSide or attackingGoal or defendingGoal or GoalSide, \2)", text)
    text = re.sub(r"(local\s+aimX\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrPenaltyShotLateral(targetGoalSide or goalSide or attackingGoal or defendingGoal or GoalSide, \2)", text)
    text = re.sub(r"(local\s+lateral\s*=\s*)(math\.clamp\([^,\n]+,\s*-?[\d\.]+,\s*[\d\.]+\))", r"\1vtrPenaltyShotLateral(targetGoalSide or goalSide or attackingGoal or defendingGoal or GoalSide, \2)", text)
    text = text.replace("vtrPenaltyShotLateral(targetGoalSide or goalSide or attackingGoal or defendingGoal or GoalSide, vtrPenaltyShotLateral", "vtrPenaltyShotLateral")
    return text

def patch_runtime(text):
    text = text.replace("SecondHalfReadyRequired = 1", "SecondHalfReadyRequired = 2")
    text = text.replace("HalftimeReadyRequired = 1", "HalftimeReadyRequired = 2")
    text = text.replace("secondHalfReadyRequired = 1", "secondHalfReadyRequired = 2")
    text = text.replace("halftimeReadyRequired = 1", "halftimeReadyRequired = 2")
    text = re.sub(r"(secondHalfReadyCount\s*>=\s*)1", r"\g<1>2", text, flags=re.I)
    text = re.sub(r"(halftimeReadyCount\s*>=\s*)1", r"\g<1>2", text, flags=re.I)
    text = re.sub(r"(readyCount\s*>=\s*)1([^\d])", r"\g<1>2\2", text)
    text = re.sub(r"(#readyPlayers\s*>=\s*)1", r"\g<1>2", text)
    text = re.sub(r"(readyPlayersCount\s*>=\s*)1", r"\g<1>2", text)
    helper = r'''
function VTRSecondHalfNeedsBothReady(readyCount, playerCount, timerExpired)
	if timerExpired then
		return true
	end
	return readyCount>=math.min(2, math.max(1, playerCount or 2))
end
'''
    if "VTRSecondHalfNeedsBothReady" not in text:
        text = helper.strip() + "\n" + text
    return text

def patch_preview_client(text):
    handler = r'''
local function vtrClearSetPiecePreviewObjects()
	for _,container in ipairs({workspace, game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")}) do
		for _,obj in ipairs(container:GetDescendants()) do
			local n=string.lower(obj.Name)
			local isPath=(string.find(n,"preview") or string.find(n,"trajectory") or string.find(n,"pathway") or string.find(n,"aimpath"))
			local isSetPiece=(string.find(n,"free") or string.find(n,"setpiece") or string.find(n,"penalty") or string.find(n,"vtr"))
			if isPath and isSetPiece then
				obj:Destroy()
			end
		end
	end
end

local function vtrBindSetPiecePreviewClear(remote)
	if not remote:IsA("RemoteEvent") then
		return
	end
	local n=string.lower(remote.Name)
	if string.find(n,"setpiece") or string.find(n,"free") or string.find(n,"penalty") or string.find(n,"decision") then
		remote.OnClientEvent:Connect(function(payload)
			if typeof(payload)=="table" then
				local t=tostring(payload.Type or payload.type or "")
				if string.find(t,"ClearSetPiecePreview") or string.find(t,"Auto") or string.find(t,"Decision") or string.find(t,"Resolved") or string.find(t,"KickTaken") then
					task.defer(vtrClearSetPiecePreviewObjects)
					task.delay(.35,vtrClearSetPiecePreviewObjects)
				end
			end
		end)
	end
end

for _,remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
	vtrBindSetPiecePreviewClear(remote)
end

game:GetService("ReplicatedStorage").DescendantAdded:Connect(vtrBindSetPiecePreviewClear)
'''
    return add_before_return(text, handler)

patch("src/server/Gameplay/GoalkeeperService.lua", patch_goalkeeper)
patch("src/server/Gameplay/SetPieceService.lua", patch_setpiece)
patch("src/server/Gameplay/MatchRuntimeService.lua", patch_runtime)
patch("src/client/Gameplay/PenaltyAimController.lua", patch_penalty_client)
patch("src/client/Gameplay/GameplayController.lua", patch_preview_client)