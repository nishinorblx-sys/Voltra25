--!strict
export type RewardKind="XP"|"Coins"|"Bolts"|"Pack"|"Card"|"Kit"|"Cosmetic"|"StadiumTheme"
export type Reward={Type:RewardKind,Amount:number?,ItemId:string?}
return table.freeze({XP="XP",Coins="Coins",Bolts="Bolts",Pack="Pack",Card="Card",Kit="Kit",Cosmetic="Cosmetic",StadiumTheme="StadiumTheme"})
