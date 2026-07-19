--!strict

local Director = {}
Director.__index = Director

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local MIN_COMMIT = .55
local HIGH_PRESS_COMMIT = 1.05

function Director.new(): any
	return setmetatable({State = {Home = nil, Away = nil}}, Director)
end

local function possessionIntent(context: any, side: string, style: any, spatial: any): string
	local ball = context.BallTeam[side]
	local stage = ball.Z < 185 and "BuildOut" or ball.Z < 360 and "Consolidate" or ball.Z < 560 and "Progress" or "CreateChance"
	local pressure = context.DefensivePress and context.DefensivePress[side == "Home" and "Away" or "Home"]
	local direct = style and style:Ratio("PassingDirectness") or .5
	local counter = style and style:Ratio("CounterAttackFrequency") or .45
	local width = style and style:Ratio("AttackingWidth") or .5
	if context.OwnerSide == side and context.Now - (tonumber(context.Owner and context.Owner:GetAttribute("VTRReceivedAt")) or context.Now) < 2.8 and counter > .72 then
		return "CounterAttack"
	end
	if ball.Z < 235 and pressure and pressure.Active then
		return "EscapePressure"
	end
	if stage == "BuildOut" and direct < .68 then
		return pressure and pressure.Active and "AttractPress" or "BuildOut"
	end
	if stage == "Progress" and width > .7 then
		return "OverloadWide"
	end
	if stage == "Progress" and direct > .72 then
		return "DirectRelease"
	end
	if stage == "CreateChance" and spatial and spatial:BestCell(side, 540, true) then
		return "SwitchPlay"
	end
	return stage
end

local function defenseIntent(context: any, side: string, style: any): string
	local ball = context.BallTeam[side]
	local press = style and style:Ratio("PressingIntensity") or .5
	local depth = style and style:Ratio("DefensiveDepth") or .5
	local trigger = style and style:Ratio("PressTriggerDistance") or .5
	local counter = style and style:Ratio("CounterPress") or .5
	if context.LooseBall then return "AttackLooseBall" end
	if ball.Z < 185 then return "ProtectBox" end
	if depth < .34 then return "LowBlock" end
	local pressCommit = press * .72 + trigger * .28
	if ball.Z >= 520 and pressCommit >= .56 then return "HighPressBuildUp" end
	if ball.Z >= 470 and press >= .58 then return "HighPressBuildUp" end
	if ball.Z >= PitchConfig.HALF_LENGTH and pressCommit >= .68 then return "HighPressLocked" end
	if ball.Z >= 250 and counter >= .58 and press >= .54 then return "Counterpress" end
	return "MidBlock"
end

function Director:Update(context: any, styles: any, spatial: any, memory: any): any
	local now = context.Now or os.clock()
	local result = {}
	for _, side in ipairs({"Home", "Away"}) do
		local previous = self.State[side]
		local nextIntent
		if context.OwnerSide == side then
			nextIntent = possessionIntent(context, side, styles[side], spatial)
		elseif context.LooseBall then
			nextIntent = "AttackLooseBall"
		else
			nextIntent = defenseIntent(context, side, styles[side])
		end
		local minimumCommit = previous and tostring(previous.Intent or ""):find("HighPress") and HIGH_PRESS_COMMIT or MIN_COMMIT
		if previous and previous.Intent ~= nextIntent and now - previous.StartedAt < minimumCommit then
			nextIntent = previous.Intent
		end
		local state = previous and previous.Intent == nextIntent and previous or {Intent = nextIntent, StartedAt = now, Reason = context.MatchState}
		state.UpdatedAt = now
		self.State[side] = state
		result[side] = state
		if memory then memory:CommitIntent(side, nextIntent, now) end
	end
	context.TeamIntent = result
	return result
end

function Director:Reset(side: string?)
	if side then self.State[side] = nil else self.State = {Home = nil, Away = nil} end
end

return Director
