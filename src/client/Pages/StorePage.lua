--!strict
local ModeHub=require(script.Parent.ModeHub)
local Data=require(script.Parent.Parent.Services.StoreData)
local Page={}
function Page.new(context:any):CanvasGroup return ModeHub.new(context,Data) end
return Page
