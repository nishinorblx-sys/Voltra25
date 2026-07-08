from pathlib import Path
import re

root = Path.cwd()
path = root / "src/server/Services/MatchSetupService.lua"

text = path.read_text(encoding="utf-8", errors="ignore")

if "_commitReturnedSoloMatch" not in text:
	insert_after = re.search(r"function Service:_commitCampaignWin\(player:Player,teamId:string,tierIndex:number,replay:boolean\?\)[\s\S]*?\nend", text)

	if not insert_after:
		raise SystemExit("could not find _commitCampaignWin block")

	helper = r'''

function Service:_returnedMatchIsWin(ended:any,setup:any):boolean
	if type(ended)=="table" then
		local result=tostring(ended.Result or ended.result or ended.Outcome or ended.outcome or ended.MatchResult or ended.matchResult or "")
		if result=="Win" or result=="Won" or result=="Victory" or result=="ForfeitWin" then
			return true
		end

		local home=tonumber(ended.HomeScore or ended.homeScore or ended.HomeGoals or ended.homeGoals or ended.Home or ended.home)
		local away=tonumber(ended.AwayScore or ended.awayScore or ended.AwayGoals or ended.awayGoals or ended.Away or ended.away)
		local side=tostring(ended.PlayerSide or ended.playerSide or ended.UserSide or ended.userSide or setup.PlayerSide or setup.UserSide or "Home")

		if home and away then
			if side=="Away" then
				return away>home
			end

			return home>away
		end
	end

	return false
end

function Service:_commitReturnedSoloMatch(player:Player,profile:any):boolean
	if not player or not profile then
		return false
	end

	local setup=profile.MatchSetup
	if type(setup)~="table" then
		return false
	end

	local ended=setup.EndedMatch or setup.CompletedMatch or setup.MatchResult or setup.ResultPayload or setup.LastResult or setup

	if setup.Completed~=true and setup.ResultCommitted~=false and type(setup.EndedMatch)~="table" and type(setup.CompletedMatch)~="table" and type(setup.MatchResult)~="table" and type(setup.ResultPayload)~="table" then
		return false
	end

	local changed=false
	local matchType=tostring(setup.MatchType or setup.MatchMode or setup.Mode or setup.Type or "")
	local teleportMode=tostring(setup.TeleportMatchMode or setup.ReturnMatchMode or "")

	if setup.WorldCup==true or matchType=="WorldCup" or matchType=="World Cup" or teleportMode=="WorldCupSolo" or matchType=="WorldCupSolo" then
		changed=self:_commitWorldCupPlayedMatch(player,ended) or changed
	end

	if self:_isCampaignMatch(setup) and self:_returnedMatchIsWin(ended,setup) then
		changed=self:_commitCampaignWin(player,tostring(setup.CampaignTeamId or ""),tonumber(setup.CampaignTier) or 1,setup.CampaignReplay==true) or changed
	end

	if changed then
		setup.Completed=false
		setup.ResultCommitted=true
		setup.EndedMatch=nil
		setup.CompletedMatch=nil
		setup.MatchResult=nil
		setup.ResultPayload=nil
		setup.LastResult=nil
		setup.SavedAt=os.time()

		if self.Publish then
			pcall(function()
				self.Publish(player,"Progression",self.Progression and self.Progression:GetClientData(player))
			end)
			pcall(function()
				self.Publish(player,"MatchSetup",setup)
			end)
			pcall(function()
				self.Publish(player,"WorldCup",profile.WorldCup)
			end)
		end
	end

	return changed
end
'''
	pos = insert_after.end()
	text = text[:pos] + helper + text[pos:]

def insert_commit_call(text, name):
	pattern = re.compile(r"(function Service:" + re.escape(name) + r"\(player:Player[^\)]*\)\n)")
	matches = list(pattern.finditer(text))
	for match in reversed(matches):
		start = match.end()
		next_text = text[start:start + 260]
		if "_commitReturnedSoloMatch" in next_text:
			continue

		call = "\tlocal vtrReturnedProfile=self.Profiles and self.Profiles:GetProfile(player)\n\tif vtrReturnedProfile then self:_commitReturnedSoloMatch(player,vtrReturnedProfile) end\n"
		text = text[:start] + call + text[start:]
	return text

for name in [
	"GetConfig",
	"GetWorldCup",
	"GetTeams",
	"StartMatch",
	"WatchMatch",
	"HandleSoloCampaignTeleport",
]:
	text = insert_commit_call(text, name)

text = text.replace("self.Publish(player,\"Progression\",self.Progression and self.Progression:GetClientData(player))", "local vtrProgressionData=self.Progression and self.Progression.GetClientData and self.Progression:GetClientData(player) or nil;if vtrProgressionData then self.Publish(player,\"Progression\",vtrProgressionData) end")

path.write_text(text.strip() + "\n", encoding="utf-8")

print("patched src/server/Services/MatchSetupService.lua")