--!strict

local PackWalkoutDirector = require(script.Parent.Parent.Controllers.PackWalkoutDirector)

local PackOpeningSequence = {}

function PackOpeningSequence.play(parent: Instance, props: any): CanvasGroup
	local director = PackWalkoutDirector.new(parent, props or {})
	local overlay = director:Play()
	overlay:SetAttribute("VTRPackWalkoutTier", director.Selection.Tier)
	overlay:SetAttribute("VTRPackWalkoutReducedMotion", director.Selection.ReducedMotion)
	return overlay
end

return PackOpeningSequence
