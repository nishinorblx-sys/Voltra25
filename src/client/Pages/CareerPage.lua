--!strict
local ModeHub=require(script.Parent.ModeHub)
local Data=require(script.Parent.Parent.Services.CareerData)
local BadgePreview=require(script.Parent.Parent.Components.BadgePreview)
local Page={}
function Page.new(context:any):CanvasGroup local group=ModeHub.new(context,Data);local badge=BadgePreview.new(group,context.Data.Progression.ClubMembership,UDim2.fromOffset(58,58));badge.AnchorPoint=Vector2.new(1,0);badge.Position=UDim2.new(1,-32,0,18);badge.ZIndex=18;return group end
return Page
