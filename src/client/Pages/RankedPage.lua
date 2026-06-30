--!strict
local ModeHub=require(script.Parent.ModeHub)
local Data=require(script.Parent.Parent.Services.RankedData)
local Page={}
function Page.new(context:any):CanvasGroup return ModeHub.new(context,Data) end
return Page
