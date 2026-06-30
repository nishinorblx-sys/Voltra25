--!strict
export type ItemKind="PlayerCard"|"Pack"|"Kit"|"Cosmetic"|"StadiumTheme"|"Currency"
export type InventoryItem={Id:string,Kind:ItemKind,Quantity:number,AcquiredAt:number}
return table.freeze({PlayerCard="PlayerCard",Pack="Pack",Kit="Kit",Cosmetic="Cosmetic",StadiumTheme="StadiumTheme",Currency="Currency"})
