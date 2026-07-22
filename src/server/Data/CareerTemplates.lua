--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CareerConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerConfig)

local ok, creation = CareerConfig.NormalizeCreation({FirstName = "Rin", LastName = "Vale", PrimaryPosition = "CAM", OriginId = "academy_graduate", ArchetypeId = "advanced_creator"})

return {
	Player = ok and CareerConfig.BuildPlayerCareer(1, creation) or {Type = "Player", Name = "RIN VALE", Season = "2026/27", Overall = 62, Club = "VOLTRA ACADEMY", Stats = {Appearances = 0, Goals = 0, Assists = 0}},
	Manager = CareerConfig.DefaultManagerSlot(1),
}
