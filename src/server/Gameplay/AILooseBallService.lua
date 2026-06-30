--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Service.ProjectBall(context: any, seconds: number?): Vector3
	local velocity = flat(context.BallVelocity or Vector3.zero)
	local projected = context.BallWorld + velocity * (seconds or 0.35)
	local homePitch = PitchConfig.WorldToTeamPitchPosition(projected, "Home", context.Options)
	local clamped = PitchConfig.ClampInsidePitch(homePitch)
	return PitchConfig.TeamPitchPositionToWorld(clamped, "Home", context.Options)
end

function Service.InterceptScore(context: any, info: any): number
	if not info.Root then
		return -math.huge
	end
	local target = Service.ProjectBall(context, 0.45)
	local distance = PitchConfig.GetDistanceStuds(info.World, target)
	local velocity = flat(info.Root.AssemblyLinearVelocity)
	local toBall = flat(target - info.World)
	local angleScore = 0
	if velocity.Magnitude > 0.5 and toBall.Magnitude > 0.1 then
		angleScore = velocity.Unit:Dot(toBall.Unit) * 12
	end
	local roleBias = info.Role == "GK" and -18 or info.Role == "CB" and -8 or info.Role == "CDM" and 8 or info.Role == "CM" and 6 or info.Role == "ST" and 4 or 0
	if PitchConfig.InZone(context.BallTeam[info.Side], "OwnBox") and (info.Role == "GK" or info.Role == "CB") then
		roleBias += 24
	end
	local staminaScore = math.clamp(info.Stamina or 60, 0, 100) * 0.12
	return -distance + angleScore + roleBias + staminaScore + (info.Stats.pace or 60) * 0.08
end

function Service.ChooseChasers(context: any, side: string): (any?, any?)
	if context.PassInFlight then
		for _, info in ipairs(context.Teams[side].List) do
			if info.Model:GetAttribute("VTRPreparingReceive") == true and (tonumber(info.Model:GetAttribute("VTRReceiveUntil")) or 0) > (context.Now or os.clock()) then
				return info, nil
			end
		end
	end
	local scored = {}
	for _, info in ipairs(context.Teams[side].List) do
		if not info.IsUserControlled then
			table.insert(scored, {Info = info, Score = Service.InterceptScore(context, info)})
		end
	end
	table.sort(scored, function(a, b)
		return a.Score > b.Score
	end)
	return scored[1] and scored[1].Info or nil, scored[2] and scored[2].Info or nil
end

return Service
