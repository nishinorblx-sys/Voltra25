from pathlib import Path
import re

service_path=Path("src/server/Services/DailyLoginRewardService.lua")
catalog_path=Path("src/shared/Catalog.lua")
text=service_path.read_text(encoding="utf-8",errors="ignore")
catalog=catalog_path.read_text(encoding="utf-8",errors="ignore") if catalog_path.exists() else ""

def pack_id(*ids):
	for item in ids:
		if re.search(rf'\b{re.escape(item)}\s*=',catalog) or re.search(rf'\["{re.escape(item)}"\]\s*=',catalog):
			return item
	return ids[0]

basic_pack=pack_id("basic_pack","bronze_pack","starter_pack","common_pack")
rare_pack=pack_id("rare_pack","gold_pack","silver_pack")
epic_pack=pack_id("epic_pack","elite_pack","voltra_pack")
icon_pack=pack_id("icon_pack","hero_pack","legendary_pack")

if "local DAILY_REWARD_TRACK" in text:
	text=re.sub(
		r"local DAILY_REWARD_TRACK\s*=\s*\{[\s\S]*?\n\}",
		f'''local DAILY_REWARD_TRACK = {{
	{{Day=1,Type="Coins",Amount=1000}},
	{{Day=2,Type="VoltraPoints",Amount=250}},
	{{Day=3,Type="Celebration",ItemId="basic_goal_celebration",Name="Basic Goal Celebration"}},
	{{Day=4,Type="Pack",ItemId="{basic_pack}",Name="Basic Pack"}},
	{{Day=5,Type="Coins",Amount=2000}},
	{{Day=6,Type="Pack",ItemId="{rare_pack}",Name="Rare Pack"}},
	{{Day=7,Type="RandomPlayer",MinOVR=75,MaxOVR=82,Name="75-82 OVR Random Player"}},
	{{Day=8,Type="Coins",Amount=3000}},
	{{Day=9,Type="VoltraPoints",Amount=500}},
	{{Day=10,Type="Pack",ItemId="{epic_pack}",Name="Epic Pack"}},
	{{Day=11,Type="RandomPlayer",MinOVR=80,MaxOVR=84,Name="80-84 OVR Random Player"}},
	{{Day=12,Type="Coins",Amount=5000}},
	{{Day=13,Type="Pack",ItemId="{icon_pack}",Name="Icon Pack"}},
	{{Day=14,Type="RandomPlayer",MinOVR=83,MaxOVR=88,Name="83-88 OVR Random Player"}},
}}''',
		text,
		count=1
	)
else:
	m=re.search(r"\nlocal function",text)
	if not m:
		raise SystemExit("helper insertion point not found")
	track=f'''
local DAILY_REWARD_TRACK = {{
	{{Day=1,Type="Coins",Amount=1000}},
	{{Day=2,Type="VoltraPoints",Amount=250}},
	{{Day=3,Type="Celebration",ItemId="basic_goal_celebration",Name="Basic Goal Celebration"}},
	{{Day=4,Type="Pack",ItemId="{basic_pack}",Name="Basic Pack"}},
	{{Day=5,Type="Coins",Amount=2000}},
	{{Day=6,Type="Pack",ItemId="{rare_pack}",Name="Rare Pack"}},
	{{Day=7,Type="RandomPlayer",MinOVR=75,MaxOVR=82,Name="75-82 OVR Random Player"}},
	{{Day=8,Type="Coins",Amount=3000}},
	{{Day=9,Type="VoltraPoints",Amount=500}},
	{{Day=10,Type="Pack",ItemId="{epic_pack}",Name="Epic Pack"}},
	{{Day=11,Type="RandomPlayer",MinOVR=80,MaxOVR=84,Name="80-84 OVR Random Player"}},
	{{Day=12,Type="Coins",Amount=5000}},
	{{Day=13,Type="Pack",ItemId="{icon_pack}",Name="Icon Pack"}},
	{{Day=14,Type="RandomPlayer",MinOVR=83,MaxOVR=88,Name="83-88 OVR Random Player"}},
}}
'''
	text=text[:m.start()]+"\n"+track+text[m.start():]

text=re.sub(
	r"local TRACK\s*=\s*\{[\s\S]*?\n\}",
	"local TRACK = DAILY_REWARD_TRACK",
	text,
	count=1
)

text=text.replace("math.clamp(tonumber(state.TrackDay) or 1, 1, 7)","math.clamp(tonumber(state.TrackDay) or 1, 1, #DAILY_REWARD_TRACK)")
text=text.replace("math.clamp(tonumber(state.TrackDay)or 1,1,7)","math.clamp(tonumber(state.TrackDay)or 1,1,#DAILY_REWARD_TRACK)")
text=text.replace("(state.TrackDay % 7) + 1","(state.TrackDay % #DAILY_REWARD_TRACK) + 1")
text=text.replace("(state.TrackDay%7)+1","(state.TrackDay%#DAILY_REWARD_TRACK)+1")

if "local function randomPlayerReward" not in text:
	insert=r'''
local function randomPlayerReward(minOVR:number,maxOVR:number): any?
	local pools={}
	if PlayerDatabase.Pools then
		for _,pool in PlayerDatabase.Pools do
			if type(pool)=="table" then
				for _,player in pool do
					local overall=tonumber(player.overall or player.Rating)or 0
					if overall>=minOVR and overall<=maxOVR then
						table.insert(pools,player)
					end
				end
			end
		end
	end
	if #pools==0 and PlayerDatabase.Players then
		for _,player in PlayerDatabase.Players do
			local overall=tonumber(player.overall or player.Rating)or 0
			if overall>=minOVR and overall<=maxOVR then
				table.insert(pools,player)
			end
		end
	end
	if #pools==0 then return nil end
	return pools[math.random(1,#pools)]
end

'''
	m=re.search(r"\nfunction Service:_grant",text)
	if not m:
		raise SystemExit("_grant not found")
	text=text[:m.start()]+"\n"+insert+text[m.start():]

if "PlayerDatabase" not in text.split("local DAILY_REWARD_TRACK")[0]:
	if "local Catalog" in text:
		text=text.replace(
			re.search(r"local Catalog[^\n]*\n",text).group(0),
			re.search(r"local Catalog[^\n]*\n",text).group(0)+'local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)\n',
			1
		)
	else:
		text='local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)\n'+text

grant_pattern=r'''function Service:_grant\(player: Player, profile: any, reward: any, vip: boolean\?\): \(boolean, string, any\?\)[\s\S]*?\nend\n\nfunction Service:Claim'''
replacement=r'''function Service:_grant(player: Player, profile: any, reward: any, vip: boolean?): (boolean, string, any?)
	if reward.Type == "Coins" then
		local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
		if amount <= 0 then return false, "Invalid coin reward.", nil end
		profile.Currency.Coins = math.min(EconomyConfig.MaximumCoins, (tonumber(profile.Currency.Coins) or 0) + amount)
		return true, "+" .. tostring(amount) .. " coins claimed.", {Type = "Coins", Amount = amount}
	elseif reward.Type == "VoltraPoints" then
		local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
		if amount <= 0 then return false, "Invalid Voltra Points reward.", nil end
		profile.Currency.VoltraPoints = math.max(0, tonumber(profile.Currency.VoltraPoints) or 0) + amount
		return true, "+" .. tostring(amount) .. " Voltra Points claimed.", {Type = "VoltraPoints", Amount = amount}
	elseif reward.Type == "Bolts" then
		local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
		if amount <= 0 then return false, "Invalid bolts reward.", nil end
		profile.Currency.Bolts = math.min(EconomyConfig.MaximumBolts, (tonumber(profile.Currency.Bolts) or 0) + amount)
		return true, "+" .. tostring(amount) .. " bolts claimed.", {Type = "Bolts", Amount = amount}
	elseif reward.Type == "Pack" then
		local packId = tostring(reward.ItemId or "")
		local definition = Catalog.Packs[packId]
		if not definition then return false, "Unknown pack reward.", nil end
		local ok, packs = self.Inventory:AddPack(player, packId, definition.Name, "DailyLogin", 1)
		if not ok then return false, "Pack grant failed.", nil end
		VTRPendingPackAnimation.Queue(player, packId)
		if self.Publish and self.Inventory and self.Inventory.GetClientData then self.Publish(player,"Inventory",self.Inventory:GetClientData(player))end
		return true, tostring(reward.Name or definition.Name) .. " claimed.", {Type = "Pack", ItemId = packId, Pack = packs and packs[1], Packs = packs, Amount = 1}
	elseif reward.Type == "Celebration" then
		profile.OwnedCosmetics = profile.OwnedCosmetics or {}
		profile.OwnedCosmetics.Celebrations = profile.OwnedCosmetics.Celebrations or {}
		if not table.find(profile.OwnedCosmetics.Celebrations,reward.ItemId) then table.insert(profile.OwnedCosmetics.Celebrations,reward.ItemId) end
		profile.StoreOwnership = profile.StoreOwnership or {}
		profile.StoreOwnership.Cosmetics = profile.StoreOwnership.Cosmetics or {}
		if not table.find(profile.StoreOwnership.Cosmetics,reward.ItemId) then table.insert(profile.StoreOwnership.Cosmetics,reward.ItemId) end
		return true, tostring(reward.Name or "Celebration") .. " claimed.", {Type = "Celebration", ItemId = reward.ItemId}
	elseif reward.Type == "RandomPlayer" then
		local definition = randomPlayerReward(tonumber(reward.MinOVR) or 1, tonumber(reward.MaxOVR) or 99)
		if not definition then return false, "No player reward available.", nil end
		local added, instance = self.Inventory:AddCard(player, definition)
		if not added or not instance then return false, "Player grant failed.", nil end
		instance.location = "club"
		instance.Location = "club"
		return true, tostring(reward.Name or "Random Player") .. " claimed.", {Type = "RandomPlayer", Card = instance, MinOVR = reward.MinOVR, MaxOVR = reward.MaxOVR}
	end
	return false, "Unsupported reward.", nil
end

function Service:Claim'''
text=re.sub(grant_pattern,replacement,text,count=1)

if "DAY 14" in text:
	pass

service_path.write_text(text.strip()+"\n",encoding="utf-8")
print("daily rewards track patched")
print("basic_pack",basic_pack)
print("rare_pack",rare_pack)
print("epic_pack",epic_pack)
print("icon_pack",icon_pack)