--!strict
local ModeHub=require(script.Parent.ModeHub)
local Data=require(script.Parent.Parent.Services.ClubsData)
local Button=require(script.Parent.Parent.Components.Button)
local BadgePreview=require(script.Parent.Parent.Components.BadgePreview)
local ProClubsPlayerBuilder=require(script.Parent.Parent.Components.ProClubsPlayerBuilder)
local Page={}
function Page.new(context:any):CanvasGroup
	local group=ModeHub.new(context,Data);local club=context.Data.Progression.ProClubMembership or{}
	local customize=Button.new({Text="PRO PLAYER BUILDER",Variant="Primary",Size=UDim2.fromOffset(190,40),OnActivated=function()ProClubsPlayerBuilder.open(group,context)end});customize.AnchorPoint=Vector2.new(1,0);customize.Position=UDim2.new(1,-32,0,28);customize.ZIndex=20;customize.Parent=group
	local badge=BadgePreview.new(group,{PrimaryColor="electric_green",SecondaryColor="pure_black",AccentColor="silver",BadgeShape="Shield",BadgeSymbol="Lightning Bolt"},UDim2.fromOffset(62,62));badge.AnchorPoint=Vector2.new(1,0);badge.Position=UDim2.new(1,-238,0,18);badge.ZIndex=19
	return group
end
return Page
