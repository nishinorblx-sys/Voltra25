from pathlib import Path
import re

path = Path("src/server/Gameplay/FormationPositionService.lua")
text = path.read_text(encoding="utf-8")

if "local function isKeeper" not in text:
    text = text.replace(
        '''local function root(model: Model): BasePart?
\treturn model:FindFirstChild("HumanoidRootPart") :: BasePart?
end''',
        '''local function root(model: Model): BasePart?
\treturn model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isKeeper(model: Model): boolean
\treturn tostring(model:GetAttribute("position") or "") == "GK"
end''',
        1
    )

old = '''function Service.ThrowIn(teams: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number): Model
\tlocal localExit = pitchCFrame:PointToObjectSpace(location)
\tlocal touchSign = localExit.X >= 0 and 1 or -1
\tlocal x = touchSign * (width / 2 - 1.2)
\tlocal z = math.clamp(localExit.Z, -length / 2 + 8, length / 2 - 8)
\tlocal spot = world(pitchCFrame, x, z)
\tlocal taker = teams[restartTeam][1]
\tlocal nearest = math.huge
\tfor _, model in teams[restartTeam] do
\t\tlocal modelRoot = root(model)
\t\tif modelRoot and (modelRoot.Position - spot).Magnitude < nearest then nearest = (modelRoot.Position - spot).Magnitude; taker = model end
\tend
\tmove(taker, spot, world(pitchCFrame, 0, z))
\tlocal opponent = restartTeam == "Home" and "Away" or "Home"
\tlocal options = {}
\tfor _, model in teams[restartTeam] do if model ~= taker then table.insert(options, model) end end
\ttable.sort(options, function(a, b) return ((root(a) :: BasePart).Position - spot).Magnitude < ((root(b) :: BasePart).Position - spot).Magnitude end)
\tfor index = 1, math.min(4, #options) do
\t\tlocal option = options[index]
\t\tlocal optionPosition = world(pitchCFrame, x - touchSign * (index == 1 and 13 or index == 2 and 20 or 26), z + (index == 1 and 0 or index == 2 and -17 or index == 3 and 18 or 36))
\t\tmove(option, optionPosition, spot)
\t\tlocal marker = teams[opponent][index + 5] or teams[opponent][index]
\t\tmove(marker, world(pitchCFrame, x - touchSign * (index == 1 and 18 or index == 2 and 25 or 30), z + (index == 1 and 2 or index == 2 and -14 or index == 3 and 15 or 32)), optionPosition)
\tend
\tlocal protected: {[Model]: boolean} = {[taker] = true}
\tfor index = 1, math.min(4, #options) do protected[options[index]] = true; protected[teams[opponent][index + 5] or teams[opponent][index]] = true end
\tfor _, side in {restartTeam, opponent} do
\t\tlocal ownSign = side == "Home" and 1 or -1
\t\tfor index, model in teams[side] do
\t\t\tif protected[model] then continue end
\t\t\tlocal lane = ((index - 1) % 5 - 2) * width * 0.17
\t\t\tlocal depth = math.clamp(z + ownSign * (28 + math.floor((index - 1) / 4) * 22), -length / 2 + 16, length / 2 - 16)
\t\t\tlocal fromRestart = Vector2.new(lane - x, depth - z)
\t\t\tif fromRestart.Magnitude < Spacing.ThrowIn.Radius + 4 then
\t\t\t\tlocal direction = fromRestart.Magnitude > 0.1 and fromRestart.Unit or Vector2.new(-touchSign, 0)
\t\t\t\tlane, depth = x + direction.X * (Spacing.ThrowIn.Radius + 4), z + direction.Y * (Spacing.ThrowIn.Radius + 4)
\t\t\tend
\t\t\tmove(model, world(pitchCFrame, lane, depth), spot)
\t\tend
\tend
\treturn taker
end'''

new = '''function Service.ThrowIn(teams: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number): Model
\tlocal localExit = pitchCFrame:PointToObjectSpace(location)
\tlocal touchSign = localExit.X >= 0 and 1 or -1
\tlocal x = touchSign * (width / 2 - 1.2)
\tlocal z = math.clamp(localExit.Z, -length / 2 + 8, length / 2 - 8)
\tlocal spot = world(pitchCFrame, x, z)
\tlocal taker = nil
\tlocal nearest = math.huge
\tfor _, model in teams[restartTeam] do
\t\tlocal modelRoot = root(model)
\t\tif modelRoot and not isKeeper(model) and (modelRoot.Position - spot).Magnitude < nearest then
\t\t\tnearest = (modelRoot.Position - spot).Magnitude
\t\t\ttaker = model
\t\tend
\tend
\ttaker = taker or teams[restartTeam][2] or teams[restartTeam][1]
\tmove(taker, spot, world(pitchCFrame, 0, z))
\tlocal opponent = restartTeam == "Home" and "Away" or "Home"
\tlocal options = {}
\tfor _, model in teams[restartTeam] do
\t\tif model ~= taker and not isKeeper(model) and root(model) then
\t\t\ttable.insert(options, model)
\t\tend
\tend
\ttable.sort(options, function(a, b) return ((root(a) :: BasePart).Position - spot).Magnitude < ((root(b) :: BasePart).Position - spot).Magnitude end)
\tlocal markers = {}
\tfor _, model in teams[opponent] do
\t\tif not isKeeper(model) and root(model) then
\t\t\ttable.insert(markers, model)
\t\tend
\tend
\tfor index = 1, math.min(4, #options) do
\t\tlocal option = options[index]
\t\tlocal optionPosition = world(pitchCFrame, x - touchSign * (index == 1 and 13 or index == 2 and 20 or 26), z + (index == 1 and 0 or index == 2 and -17 or index == 3 and 18 or 36))
\t\tmove(option, optionPosition, spot)
\t\tlocal marker = markers[index + 4] or markers[index]
\t\tif marker then
\t\t\tmove(marker, world(pitchCFrame, x - touchSign * (index == 1 and 18 or index == 2 and 25 or 30), z + (index == 1 and 2 or index == 2 and -14 or index == 3 and 15 or 32)), optionPosition)
\t\tend
\tend
\tlocal protected: {[Model]: boolean} = {[taker] = true}
\tfor _, side in {"Home", "Away"} do
\t\tfor _, model in teams[side] do
\t\t\tif isKeeper(model) then
\t\t\t\tprotected[model] = true
\t\t\t\tmodel:SetAttribute("VTRThrowInKeeperProtected", true)
\t\t\tend
\t\tend
\tend
\tfor index = 1, math.min(4, #options) do
\t\tprotected[options[index]] = true
\t\tlocal marker = markers[index + 4] or markers[index]
\t\tif marker then
\t\t\tprotected[marker] = true
\t\tend
\tend
\tfor _, side in {restartTeam, opponent} do
\t\tlocal ownSign = side == "Home" and 1 or -1
\t\tfor index, model in teams[side] do
\t\t\tif protected[model] or isKeeper(model) then continue end
\t\t\tlocal lane = ((index - 1) % 5 - 2) * width * 0.17
\t\t\tlocal depth = math.clamp(z + ownSign * (28 + math.floor((index - 1) / 4) * 22), -length / 2 + 16, length / 2 - 16)
\t\t\tlocal fromRestart = Vector2.new(lane - x, depth - z)
\t\t\tif fromRestart.Magnitude < Spacing.ThrowIn.Radius + 4 then
\t\t\t\tlocal direction = fromRestart.Magnitude > 0.1 and fromRestart.Unit or Vector2.new(-touchSign, 0)
\t\t\t\tlane, depth = x + direction.X * (Spacing.ThrowIn.Radius + 4), z + direction.Y * (Spacing.ThrowIn.Radius + 4)
\t\t\tend
\t\t\tmove(model, world(pitchCFrame, lane, depth), spot)
\t\tend
\tend
\treturn taker
end'''

if old not in text:
    raise RuntimeError("ThrowIn block not found")

text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("throw ins no longer pull goalkeepers")