--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local AnimatedNumber = {}

local function commas(value: number): string
	local formatted = tostring(math.floor(value + 0.5))
	repeat
		local nextValue, substitutions = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextValue
	until substitutions == 0
	return formatted
end

function AnimatedNumber.play(label: TextLabel, target: number, options: any?)
	options = options or {}
	local driver = Instance.new("NumberValue")
	driver.Value = options.From or 0
	local prefix = options.Prefix or ""
	local suffix = options.Suffix or ""
	local decimals = options.Decimals or 0
	local function render()
		local value = driver.Value
		local text = if decimals > 0 then string.format("%." .. decimals .. "f", value) else commas(value)
		label.Text = prefix .. text .. suffix
	end
	driver.Changed:Connect(render)
	render()
	local tween = TweenService:Create(driver, TweenInfo.new(options.Duration or 0.7, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { Value = target })
	tween.Completed:Once(function() driver:Destroy() end)
	tween:Play()
	return tween
end

AnimatedNumber.format = commas
return AnimatedNumber
