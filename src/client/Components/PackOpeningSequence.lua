--!strict

local PackWalkoutDirector = require(script.Parent.Parent.Controllers.PackWalkoutDirector)

local PackOpeningSequence = {}

function PackOpeningSequence.play(parent: Instance, props: any): CanvasGroup
	local director = PackWalkoutDirector.new(parent, props or {})
	local overlay = director:Play()
	overlay:SetAttribute("VTRPackWalkoutTier", director.Selection.Tier)
	overlay:SetAttribute("VTRPackWalkoutReducedMotion", director.Selection.ReducedMotion)
	overlay:SetAttribute("VTRPackWalkoutPremium", director.Selection.Profile and director.Selection.Profile.Walkout == true)
	overlay:SetAttribute("VTRPackWalkoutBestRating", director.Selection.BestCard and (director.Selection.BestCard.Rating or director.Selection.BestCard.overall or director.Selection.BestCard.Overall) or 0)
	return overlay
end

return PackOpeningSequence
