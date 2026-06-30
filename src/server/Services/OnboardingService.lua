--!strict
local Clubs=require(script.Parent.Parent.Data.ClubTemplates)
local OnboardingService={};OnboardingService.__index=OnboardingService
function OnboardingService.new(profiles:any) return setmetatable({Profiles=profiles},OnboardingService) end
function OnboardingService:GetState(player:Player):any? local p=self.Profiles:GetProfile(player);return p and p.Onboarding or nil end
function OnboardingService:Advance(player:Player,expectedStep:number,nextStep:number):boolean local p=self.Profiles:GetProfile(player);if not p or p.Onboarding.Complete or p.Onboarding.Step~=expectedStep or nextStep<=expectedStep then return false end;p.Onboarding.Step=nextStep;return true end
function OnboardingService:Complete(player:Player):boolean local p=self.Profiles:GetProfile(player);if not p or not p.Onboarding.SquadFilled then return false end;p.Onboarding.Complete=true;p.OnboardingCompleted=true;p.Onboarding.Step=10;return true end
return OnboardingService
