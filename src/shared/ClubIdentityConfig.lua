--!strict

local Config = {}

Config.Colors = {
	{ Id="electric_green", Name="ELECTRIC GREEN", Hex="B7FF1A" }, { Id="neon_lime", Name="NEON LIME", Hex="9FFF00" },
	{ Id="volt_yellow", Name="VOLT YELLOW", Hex="E7FF3A" }, { Id="solar_yellow", Name="SOLAR YELLOW", Hex="FFD43B" },
	{ Id="signal_orange", Name="SIGNAL ORANGE", Hex="FF7A18" }, { Id="flare_red", Name="FLARE RED", Hex="FF384D" },
	{ Id="crimson", Name="CRIMSON", Hex="B91835" }, { Id="magenta", Name="MAGENTA", Hex="E52DFF" },
	{ Id="voltra_purple", Name="VOLTRA PURPLE", Hex="7D2CFF" }, { Id="ultraviolet", Name="ULTRAVIOLET", Hex="4B2BFF" },
	{ Id="royal_blue", Name="ROYAL BLUE", Hex="245BFF" }, { Id="sky_blue", Name="SKY BLUE", Hex="39B8FF" },
	{ Id="electric_cyan", Name="ELECTRIC CYAN", Hex="19E6E6" }, { Id="teal", Name="TEAL", Hex="17C3B2" },
	{ Id="forest", Name="FOREST", Hex="167A42" }, { Id="emerald", Name="EMERALD", Hex="21C66B" },
	{ Id="pure_black", Name="PURE BLACK", Hex="050505" }, { Id="graphite", Name="GRAPHITE", Hex="111111" },
	{ Id="gunmetal", Name="GUNMETAL", Hex="292D31" }, { Id="silver", Name="METALLIC SILVER", Hex="D9D9D9" },
	{ Id="white", Name="VOLTRA WHITE", Hex="F5F7F2" }, { Id="cream", Name="CREAM", Hex="F1E3C2" },
	{ Id="bronze", Name="BRONZE", Hex="B66A3C" }, { Id="gold", Name="CHAMPION GOLD", Hex="E8B84A" },
}
Config.KitStyles = { "Solid", "Vertical Stripes", "Horizontal Stripes", "Diagonal Sash", "Split", "Gradient", "Hoops", "Lightning Trim", "Volt Pattern", "Checker Accent" }
Config.BadgePresets = { "Classic", "Modern", "Electric", "Heritage", "Elite", "Minimal" }
Config.BadgeShapes = { "Shield", "Circle", "Hex", "Diamond", "Crest", "V Badge" }
Config.BadgeSymbols = {
	"Lightning Bolt", "Football", "Crown", "Star", "Wings", "Flame", "Wolf Head", "Dragon Head", "Falcon", "Lion Head",
	"Shark", "Tiger", "Phoenix", "Shield Sword", "Mountain", "Tornado", "Viper", "Eagle", "Panther", "Meteor",
	"Skull", "Knight Helmet", "Rocket", "Volt V", "Spartan Helmet",
}
Config.BadgeColorBehaviors = { "Tri Color", "Primary Focus", "Secondary Focus", "Accent Focus", "High Contrast" }

local legacyStyle = { strike="Diagonal Sash", pulse="Lightning Trim", grid="Checker Accent" }
function Config.ResolveStyle(value: any): string return legacyStyle[value] or (table.find(Config.KitStyles, value) and value) or "Solid" end
function Config.ResolveColor(value: any): string
	if type(value) == "string" then
		for _, color in Config.Colors do if color.Id == value or string.upper(color.Hex) == string.upper(value) then return color.Hex end end
		-- Read-only team previews may use database kit hex values outside the
		-- customizable club palette. Server saves still require ColorId().
		if string.match(value, "^%x%x%x%x%x%x$") then return string.upper(value) end
	end
	return "B7FF1A"
end
function Config.ColorId(value: any): string?
	if type(value) ~= "string" then return nil end
	for _, color in Config.Colors do if color.Id == value or string.upper(color.Hex) == string.upper(value) then return color.Id end end
	return nil
end
function Config.IsChoice(list: { string }, value: any): boolean return type(value) == "string" and table.find(list, value) ~= nil end

Config.Default = table.freeze({
	PrimaryColor="electric_green", SecondaryColor="pure_black", AccentColor="silver", KitStyle="Solid",
	BadgePreset="Modern", BadgeShape="Shield", BadgeSymbol="Lightning Bolt", BadgeColorBehavior="Tri Color",
})

return table.freeze(Config)
