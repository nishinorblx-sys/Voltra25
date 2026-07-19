--!strict

local PitchConfig = require(script.Parent.PitchConfig)

local Util = {}

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.SecondLastOpponentZ(context: any, attackingSide: string, opponents: {any}?): number
	local lines = {}
	for _, opponent in ipairs(opponents or (((context.Teams or {})[attackingSide == "Home" and "Away" or "Home"] or {}).List or {})) do
		local world = nil
		if typeof(opponent) == "Instance" then
			local opponentRoot = root(opponent :: Model)
			world = opponentRoot and opponentRoot.Position or nil
		else
			world = opponent.World
			if not world and opponent.Root then
				world = opponent.Root.Position
			end
		end
		if typeof(world) == "Vector3" then
			local pitch = PitchConfig.WorldToTeamPitchPosition(world, attackingSide, context.Options)
			table.insert(lines, pitch.Z)
		end
	end
	table.sort(lines, function(a: number, b: number) return a > b end)
	return lines[2] or lines[1] or PitchConfig.PITCH_LENGTH
end

function Util.IsReceiverOffside(context: any, attackingSide: string, receiverPitch: Vector3, ballPitch: Vector3, tolerance: number?, secondLastZ: number?): boolean
	local margin = tolerance or .5
	if receiverPitch.Z <= PitchConfig.HALF_LENGTH then return false end
	if receiverPitch.Z <= ballPitch.Z + margin then return false end
	local line = secondLastZ or Util.SecondLastOpponentZ(context, attackingSide)
	return receiverPitch.Z > line + margin
end

function Util.IsModelOffsideAt(context: any, passer: Model?, receiver: Model, ballPosition: Vector3, tolerance: number?): boolean
	local side = tostring((passer and passer:GetAttribute("VTRTeam")) or receiver:GetAttribute("VTRTeam") or "")
	if side ~= "Home" and side ~= "Away" then return false end
	if passer and receiver:GetAttribute("VTRTeam") ~= side then return false end
	local receiverRoot = root(receiver)
	if not receiverRoot then return false end
	local receiverPitch = PitchConfig.WorldToTeamPitchPosition(receiverRoot.Position, side, context.Options)
	local ballPitch = PitchConfig.WorldToTeamPitchPosition(ballPosition, side, context.Options)
	return Util.IsReceiverOffside(context, side, receiverPitch, ballPitch, tolerance)
end

return table.freeze(Util)
