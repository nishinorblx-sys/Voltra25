--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)

local Config = {}

Config.Slots = table.freeze({
	"LEFT_DOWN",
	"LEFT_UP",
	"MIDDLE",
	"RIGHT_DOWN",
	"RIGHT_UP",
})

function Config.NormalizeSlot(slot: any): string?
	if type(slot) ~= "string" then return nil end
	local value = string.upper(slot)
	value = string.gsub(value, "CENTER", "MIDDLE")
	value = string.gsub(value, "%s+", "_")
	if value == "MIDDLE_DOWN" or value == "MIDDLE_UP" then
		value = "MIDDLE"
	end
	return table.find(Config.Slots, value) and value or nil
end

local function goalAxes(pitchCFrame: CFrame, length: number, goalSign: number)
	local planePoint = pitchCFrame:PointToWorldSpace(Vector3.new(0, 0, goalSign * length * 0.5))
	return planePoint, pitchCFrame.RightVector, pitchCFrame.UpVector
end

local function rectangleForGoal(pitchCFrame: CFrame, width: number?, length: number, goalSign: number): any?
	local scoringSide = goalSign < 0 and "Home" or "Away"
	local ok, rectangle = pcall(function()
		return GoalModelResolver.ResolveSide(scoringSide, pitchCFrame, width or 76, length)
	end)
	return ok and rectangle or nil
end

function Config.SlotFromGoalPoint(pitchCFrame: CFrame, length: number, goalSign: number, point: Vector3, width: number?): string
	local rectangle = rectangleForGoal(pitchCFrame, width, length, goalSign)
	if rectangle then
		local offset = point - rectangle.PlanePoint
		local horizontal = offset:Dot(rectangle.Right)
		local vertical = offset:Dot(rectangle.Up)
		local goalWidth = math.max(1, rectangle.RightBound - rectangle.Left)
		local goalHeight = math.max(1, rectangle.Top - rectangle.Bottom)
		local center = rectangle.Left + goalWidth * 0.5
		local side = "MIDDLE"
		if horizontal < center - goalWidth * 0.18 then
			side = "LEFT"
		elseif horizontal > center + goalWidth * 0.18 then
			side = "RIGHT"
		end
		if side == "MIDDLE" then
			return "MIDDLE"
		end
		local height = vertical >= rectangle.Bottom + goalHeight * 0.5 and "UP" or "DOWN"
		return side .. "_" .. height
	end
	local planePoint, right, up = goalAxes(pitchCFrame, length, goalSign)
	local offset = point - planePoint
	local horizontal = offset:Dot(right)
	local vertical = offset:Dot(up)
	local side = "MIDDLE"
	if horizontal < -3.8 then
		side = "LEFT"
	elseif horizontal > 3.8 then
		side = "RIGHT"
	end
	if side == "MIDDLE" then
		return "MIDDLE"
	end
	local height = vertical >= 4.8 and "UP" or "DOWN"
	return side .. "_" .. height
end

function Config.PointForSlot(pitchCFrame: CFrame, length: number, goalSign: number, slot: string, width: number?): Vector3
	slot = Config.NormalizeSlot(slot) or "MIDDLE"
	local rectangle = rectangleForGoal(pitchCFrame, width, length, goalSign)
	if rectangle then
		local goalWidth = math.max(1, rectangle.RightBound - rectangle.Left)
		local goalHeight = math.max(1, rectangle.Top - rectangle.Bottom)
		local ballPadding = math.clamp(goalWidth * 0.035, 0.45, 0.9)
		local x = rectangle.Left + goalWidth * 0.5
		if string.find(slot, "LEFT", 1, true) then
			x = rectangle.Left + ballPadding
		elseif string.find(slot, "RIGHT", 1, true) then
			x = rectangle.RightBound - ballPadding
		end
		local y = rectangle.Bottom + goalHeight * 0.46
		if slot ~= "MIDDLE" then
			y = string.find(slot, "UP", 1, true) and (rectangle.Top - math.clamp(goalHeight * 0.06, 0.35, 0.75)) or (rectangle.Bottom + math.clamp(goalHeight * 0.14, 0.75, 1.35))
		end
		return GoalModelResolver.Point(rectangle, x, y)
	end
	local planePoint, right, up = goalAxes(pitchCFrame, length, goalSign)
	local x = 0
	if string.find(slot, "LEFT", 1, true) then
		x = -10.65
	elseif string.find(slot, "RIGHT", 1, true) then
		x = 10.65
	end
	local y = slot == "MIDDLE" and 4.6 or string.find(slot, "UP", 1, true) and 8.6 or 1.25
	return planePoint + right * x + up * y
end

function Config.IsValidSlot(slot: any): boolean
	return Config.NormalizeSlot(slot) ~= nil
end

function Config.RandomSlot(random: Random?): string
	local rng = random or Random.new()
	return Config.Slots[rng:NextInteger(1, #Config.Slots)]
end

return table.freeze(Config)
