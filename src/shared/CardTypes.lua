--!strict
export type CardRarity="Common"|"Bronze"|"Silver"|"Gold"|"Rare"|"Elite"|"Legendary"|"Icon"|"Mythic"
export type CardType="Base"|"Team of the Week"|"Rising Star"|"Voltra Hero"|"Champion"|"Event"|"Limited"|"Spark"|"Electrum"|"Hero"|"Storm"|"Mythic"
export type CardInstance={cardInstanceId:string,playerId:string,rarity:CardRarity,cardType:string,location:string,locked:boolean?,favorite:boolean?}
return table.freeze({Rarities=table.freeze({"Common","Bronze","Silver","Gold","Rare","Elite","Legendary","Icon","Mythic"}),CardTypes=table.freeze({"Base","Team of the Week","Rising Star","Voltra Hero","Champion","Event","Limited","Spark","Electrum","Hero","Storm","Mythic"})})
