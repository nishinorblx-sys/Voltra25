from pathlib import Path

path = Path("src/client/Gameplay/InputController.lua")
text = path.read_text(encoding="utf-8")

bad = '''
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end

function Controller:MobileAimVector(kind: string?): Vector2?'''

good = '''

function Controller:MobileAimVector(kind: string?): Vector2?'''

text = text.replace(bad, good, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed extra end after Controller:Move")