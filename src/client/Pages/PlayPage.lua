--!strict
local Page={}
local MatchSetupPage=require(script.Parent.MatchSetupPage)
function Page.new(context:any):CanvasGroup return MatchSetupPage.new(context) end
return Page
