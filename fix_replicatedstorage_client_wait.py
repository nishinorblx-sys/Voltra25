from pathlib import Path
import re

root = Path.cwd()

helper = r'''
local Players = game:GetService("Players")

local function vtrClientRoot()
	local current = script

	while current do
		if current.Name == "VTRClient" or current.Name == "Client" then
			return current
		end

		current = current.Parent
	end

	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChild("PlayerScripts")
	local found = playerScripts and (playerScripts:FindFirstChild("VTRClient") or playerScripts:FindFirstChild("Client"))

	return found or script.Parent
end
'''

def add_helper(text):
    if "local function vtrClientRoot()" in text:
        return text

    if 'local ReplicatedStorage = game:GetService("ReplicatedStorage")' in text:
        return text.replace('local ReplicatedStorage = game:GetService("ReplicatedStorage")', 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n' + helper.strip(), 1)

    return helper.strip() + "\n" + text

def patch_text(text):
    original = text

    if 'WaitForChild("Client")' in text:
        text = add_helper(text)

    text = text.replace('ReplicatedStorage:WaitForChild("Client")', 'vtrClientRoot()')
    text = text.replace('game:GetService("ReplicatedStorage"):WaitForChild("Client")', 'vtrClientRoot()')
    text = text.replace('ReplicatedStorage:WaitForChild("Client", 15)', 'vtrClientRoot()')
    text = text.replace('ReplicatedStorage:WaitForChild("Client", 10)', 'vtrClientRoot()')
    text = text.replace('ReplicatedStorage.Client', 'vtrClientRoot()')

    text = text.replace('local Players = game:GetService("Players")\nlocal Players = game:GetService("Players")', 'local Players = game:GetService("Players")')
    text = text.replace('local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal Players = game:GetService("Players")\n\nlocal Players = game:GetService("Players")', 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal Players = game:GetService("Players")')

    return text if text != original else original

patched = []

for path in (root / "src/client").rglob("*.lua"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    new = patch_text(text)

    if new != text:
        path.write_text(new.strip() + "\n", encoding="utf-8")
        patched.append(path.relative_to(root).as_posix())

for item in patched:
    print("patched", item)

print("done")