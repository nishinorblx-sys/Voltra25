--!strict
export type MainStats={PAC:number,SHO:number,PAS:number,DRI:number,DEF:number,PHY:number}
export type PlayerDefinition={playerId:string,displayName:string,shortName:string,country:string,club:string,league:string,positions:{string},bestPosition:string,overall:number,potential:number,value:number,wage:number,releaseClause:number,preferredFoot:string,weakFoot:number,skillMoves:number,bodyType:string,specialties:{string},rarity:string,cardType:string,portraitSeed:number,age:number,heightCm:number,weightKg:number,birthDate:string,appearance:any,portrait:any,pose:any,mainStats:MainStats,detailedStats:{[string]:number}}
return table.freeze({})
