from pathlib import Path

path = Path("src/server/Gameplay/AIAssignmentService.lua")
text = path.read_text(encoding="utf-8")

if 'local Workspace = game:GetService("Workspace")' not in text:
    text = text.replace(
        'local PenaltyBoxService = require(script.Parent.PenaltyBoxService)',
        'local PenaltyBoxService = require(script.Parent.PenaltyBoxService)\nlocal Workspace = game:GetService("Workspace")',
        1
    )

old = '''local function inFrontOfDefensiveDangerZone(context: any, defendingSide: string, attacker: any): boolean
\tlocal zone = PitchConfig.Zones.OwnBox
\tlocal threatPitch = PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
\tlocal xMargin = 24
\treturn threatPitch.X >= zone.XMin - xMargin
\t\tand threatPitch.X <= zone.XMax + xMargin
\t\tand threatPitch.Z >= zone.ZMax
\t\tand threatPitch.Z <= zone.ZMax + 60
end'''

new = '''local function stadiumAnalysisFolder(): Instance?
\treturn Workspace:FindFirstChild("VTRStadiumAnalysis", true)
end

local function defensiveBoxPart(defendingSide: string): BasePart?
\tlocal analysis = stadiumAnalysisFolder()
\tlocal name = defendingSide == "Home" and "HomeBox" or "AwayBox"
\tlocal found = analysis and analysis:FindFirstChild(name, true) or Workspace:FindFirstChild(name, true)
\treturn found and found:IsA("BasePart") and found or nil
end

local function inFrontOfDefensiveDangerZone(context: any, defendingSide: string, attacker: any): boolean
\tlocal box = defensiveBoxPart(defendingSide)
\tif box then
\t\tlocal boxLocal = context.PitchCFrame:PointToObjectSpace(box.Position)
\t\tlocal threatLocal = context.PitchCFrame:PointToObjectSpace(attacker.World)
\t\tlocal halfWidth = math.max(box.Size.X, box.Size.Z) * 0.5
\t\tlocal halfDepth = math.min(box.Size.X, box.Size.Z) * 0.5
\t\tlocal xMargin = 32
\t\tlocal zMargin = 60
\t\tlocal xInside = threatLocal.X >= boxLocal.X - halfWidth - xMargin and threatLocal.X <= boxLocal.X + halfWidth + xMargin
\t\tlocal zInside
\t\tif boxLocal.Z >= 0 then
\t\t\tzInside = threatLocal.Z <= boxLocal.Z - halfDepth and threatLocal.Z >= boxLocal.Z - halfDepth - zMargin
\t\telse
\t\t\tzInside = threatLocal.Z >= boxLocal.Z + halfDepth and threatLocal.Z <= boxLocal.Z + halfDepth + zMargin
\t\tend
\t\treturn xInside and zInside
\tend
\tlocal zone = PitchConfig.Zones.OwnBox
\tlocal threatPitch = PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
\tlocal xMargin = 24
\treturn threatPitch.X >= zone.XMin - xMargin
\t\tand threatPitch.X <= zone.XMax + xMargin
\t\tand threatPitch.Z >= zone.ZMax
\t\tand threatPitch.Z <= zone.ZMax + 60
end'''

if old not in text:
    raise RuntimeError("Could not find old inFrontOfDefensiveDangerZone block")

text = text.replace(old, new, 1)

old2 = '''\tlocal ballNearDefensiveBox = PenaltyBoxService.IsNearDefensiveBox(info.Side, context.BallWorld, context.Options, 36)'''
new2 = '''\tlocal ballNearDefensiveBox = PenaltyBoxService.IsNearDefensiveBox(info.Side, context.BallWorld, context.Options, 60)'''

if old2 in text:
    text = text.replace(old2, new2, 1)

old3 = '''\tif ownerInfo and not pressPaused and not boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then'''
new3 = '''\tif ownerInfo and not pressPaused and boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
\t\tlocal rank = midfieldPressRank(context, info, ownerInfo)
\t\tif rank == 1 then
\t\t\treturn "MidfieldBoxPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\telseif rank == 2 then
\t\t\treturn "SecondMidfielderBoxCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, faceModel
\t\tend
\tend
\tif ownerInfo and not pressPaused and not boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then'''

if "MidfieldBoxPress" not in text:
    if old3 not in text:
        raise RuntimeError("Could not find midfielder press block")
    text = text.replace(old3, new3, 1)

old4 = '''\t\tif boxThreat and ballNearDefensiveBox then'''
new4 = '''\t\tif boxThreat and (ballNearDefensiveBox or context.Owner == boxThreat.Model) then'''

if old4 in text:
    text = text.replace(old4, new4, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("updated", path)