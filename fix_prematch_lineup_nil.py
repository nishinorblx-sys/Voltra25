from pathlib import Path

path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
text = path.read_text(encoding="utf-8")

text = text.replace(
'''local function formationEntries(data: any, side: string): {any}
	local models = sortedModels(data, side)
	local players = lineupData(data, side)
	local result = {}''',
'''local function formationEntries(data: any, side: string): {any}
	local models = sortedModels(data, side)
	local players = side == "Home" and (data.HomeLineup or {}) or (data.AwayLineup or {})
	local result = {}''',
1
)

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed nil lineupData call in prematch formation entries")