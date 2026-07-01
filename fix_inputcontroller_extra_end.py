from pathlib import Path

path = Path("src/client/Gameplay/InputController.lua")
text = path.read_text(encoding="utf-8")

start = text.find("\nfunction Controller:_createMobileControls()")
finish = text.find("\nfunction Controller:Start()", start)

if start != -1 and finish != -1:
    text = text[:start] + "\n" + text[finish:]

text = text.replace("\n\tself:_createMobileControls()", "")

text = text.replace(
'''function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end
	local touch = self.TouchVector or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or touch
end''',
'''function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end''',
1
)

text = text.replace(
'''function Controller:Destroy()
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end''',
'''function Controller:Destroy()
	if self.MobileControls then self.MobileControls:Destroy();self.MobileControls=nil end
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end''',
1
)

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed InputController extra end and removed old mobile controls")