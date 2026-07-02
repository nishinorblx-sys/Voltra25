local SevenWinLoginRewardConfig = {}

SevenWinLoginRewardConfig.MinimumWins = 7
SevenWinLoginRewardConfig.BaseChance = 0.55
SevenWinLoginRewardConfig.ChancePerWin = 0.035
SevenWinLoginRewardConfig.MaxChance = 0.95
SevenWinLoginRewardConfig.ClaimKey = "SevenWinLoginReward_v1"
SevenWinLoginRewardConfig.RemoteFolderName = "SevenWinLoginRewardRemotes"
SevenWinLoginRewardConfig.PendingRemoteName = "PendingSevenWinLoginReward"
SevenWinLoginRewardConfig.ConfirmRemoteName = "ConfirmSevenWinLoginReward"
SevenWinLoginRewardConfig.FallbackPacks = {
	"BronzePack",
	"SilverPack",
	"GoldPack",
}

return SevenWinLoginRewardConfig
