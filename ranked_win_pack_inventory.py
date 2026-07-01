from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

reward_path = Path("src/server/Services/RankedWinPackReward.lua")
reward_path.parent.mkdir(parents=True, exist_ok=True)

reward_path.write_text('''--!strict
local Service = {}

local Packs = {
	{PackId = "bronze_pack", Name = "Voltra Spark Pack", Rarity = "Common", Weight = 34},
	{PackId = "silver_pack", Name = "Street Pulse Pack", Rarity = "Rare", Weight = 25},
	{PackId = "gold_pack", Name = "Neon Tactics Pack", Rarity = "Rare", Weight = 18},
	{PackId = "elite_pack", Name = "Elite Matchday Pack", Rarity = "Epic", Weight = 12},
	{PackId = "champion_pack", Name = "Voltra Vault Pack", Rarity = "Epic", Weight = 7},
	{PackId = "hero_pack", Name = "Ranked Champion Pack", Rarity = "Mythic", Weight = 3},
	{PackId = "voltra_pack", Name = "Icon Voltage Pack", Rarity = "Mythic", Weight = 1},
}

local Fallbacks = {"voltra_pack", "hero_pack", "champion_pack", "elite_pack", "gold_pack", "silver_pack", "bronze_pack"}

function Service.Roll(): any
	local total = 0
	for _, pack in Packs do
		total += pack.Weight
	end
	local roll = math.random() * total
	local cursor = 0
	for _, pack in Packs do
		cursor += pack.Weight
		if roll <= cursor then
			return table.clone(pack)
		end
	end
	return table.clone(Packs[1])
end

function Service.Grant(progression: any, player: Player, publish: ((Player, string, any) -> ())?): any
	local pack = Service.Roll()
	local granted = false
	local grantedId = pack.PackId
	if progression and progression.Inventory and progression.Inventory.AddPack then
		local attempts = {pack.PackId}
		for _, fallback in Fallbacks do
			if fallback ~= pack.PackId then
				table.insert(attempts, fallback)
			end
		end
		for _, packId in attempts do
			local ok, result = pcall(function()
				return progression.Inventory:AddPack(player, packId, packId, "RankedWin", 1)
			end)
			if ok and result then
				granted = true
				grantedId = packId
				break
			end
		end
	end
	if publish and progression and progression.GetClientData then
		pcall(function()
			publish(player, "Progression", progression:GetClientData(player))
		end)
	end
	return {
		Title = "RANKED WIN REWARD",
		Coins = 0,
		XP = 0,
		Pack = pack.Name,
		PackName = pack.Name,
		PackId = grantedId,
		Rarity = pack.Rarity,
		Packs = granted and 1 or 0,
		PackGranted = granted,
		InventoryStored = granted,
		Source = "RankedWin",
	}
end

return Service
''', encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = replace_once(
    runtime,
'''				if rankedWin then
					rewardPayload=rewardPayload or{}
					rewardPayload.PackChoices=rewardPayload.PackChoices or rankedPackChoices
					rewardPayload.PackName=rewardPayload.PackName or rewardPayload.Pack or"Ranked Champion Pack"
					rewardPayload.Rarity=rewardPayload.Rarity or"Mythic"
				end''',
'''				if rankedWin then
					rewardPayload=rewardPayload or{}
					if session.RankedWinPackGrant and rewardPayload.PackGranted~=true then
						local ok,packReward=pcall(session.RankedWinPackGrant,session,participant,rewardPayload)
						if ok and type(packReward)=="table"then
							for key,value in packReward do
								rewardPayload[key]=value
							end
						end
					end
					rewardPayload.PackChoices=rewardPayload.PackChoices or rankedPackChoices
					rewardPayload.PackName=rewardPayload.PackName or rewardPayload.Pack or"Ranked Champion Pack"
					rewardPayload.Rarity=rewardPayload.Rarity or"Mythic"
				end''',
    "ranked win inventory grant hook"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

patched_ranked_starter = False

for path in Path("src/server").rglob("*.lua"):
    if path == runtime_path or path == reward_path:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text
    if "StartRankedMatch" not in text or "Progression" not in text or "Runtime" not in text:
        continue

    if "RankedWinPackReward" not in text:
        if path.parent.name == "Services":
            text = text.replace("--!strict", "--!strict\nlocal RankedWinPackReward=require(script.Parent.RankedWinPackReward)", 1)
            if text == original:
                text = 'local RankedWinPackReward=require(script.Parent.RankedWinPackReward)\n' + text
        else:
            text = text.replace("--!strict", "--!strict\nlocal RankedWinPackReward=require(script.Parent.Parent.Services.RankedWinPackReward)", 1)
            if text == original:
                text = 'local RankedWinPackReward=require(script.Parent.Parent.Services.RankedWinPackReward)\n' + text

    def add_callback(match):
        success_var = match.group(2)
        home_arg = match.group(5).strip()
        away_arg = match.group(6).strip()
        call = match.group(1)
        if "RankedWinPackGrant" in call:
            return call
        return call + f'''
	if {success_var} then
		local rankedSession=self.Runtime:GetSession({home_arg}) or self.Runtime:GetSession({away_arg})
		if rankedSession then
			rankedSession.RankedWinPackGrant=function(_,winner:Player)
				return RankedWinPackReward.Grant(self.Progression,winner,self.Publish)
			end
		end
	end'''

    text = re.sub(
        r'(local\s+(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*=\s*self\.Runtime:StartRankedMatch\(([^,\n]+),\s*([^,\n]+),[^\n]*\))',
        add_callback,
        text,
        count=1
    )

    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("patched ranked pack inventory grant in", path)
        patched_ranked_starter = True

print("ranked win pack inventory patch applied")
if not patched_ranked_starter:
    print("warning: ranked starter file was not auto-patched")
    print("send me this output and I will patch the exact ranked queue file")