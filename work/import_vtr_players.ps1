$ErrorActionPreference = 'Stop'
$source = 'C:\Users\user\Downloads\VTRPlayers_With_Appearance.csv'
$root = Join-Path $PSScriptRoot '..\src\data'
$shards = Join-Path $root 'Players'
New-Item -ItemType Directory -Force -Path $shards | Out-Null
Get-ChildItem -LiteralPath $shards -Filter 'Shard*.lua' -ErrorAction SilentlyContinue | Remove-Item -Force

$fields = @(
 'vtrPlayerId','vtrName','vtrShortName','country','vtrClub','vtrLeague','positions','bestPosition','overall','potential','value','wage','releaseClause','preferredFoot','weakFoot','skillMoves','bodyType','specialties','rarity','cardType','portraitSeed','age','heightCm','weightKg','dob',
 'skinTone','faceShape','eyeType','eyebrowType','noseType','mouthType','hairStyle','hairColor','facialHair','facialHairColor','bodyBuild','heightClass','portraitExpression','specialPortrait','accessoryType','accessoryColor','avatarVersion','cardPose','celebrationStyle','walkStyle',
 'PAC','SHO','PAS','DRI','DEF','PHY','acceleration','sprintSpeed','finishing','shotPower','longShots','volleys','penalties','shortPassing','longPassing','vision','crossing','curve','fkAccuracy','dribbling','ballControl','agility','balance','reactions','defensiveAwareness','standingTackle','slidingTackle','interceptions','strength','stamina','aggression','jumping','headingAccuracy','attackingPosition','composure','gkDiving','gkHandling','gkKicking','gkPositioning','gkReflexes'
)
$numeric = @{}; foreach ($name in @('overall','potential','value','wage','releaseClause','weakFoot','skillMoves','portraitSeed','age','heightCm','weightKg','PAC','SHO','PAS','DRI','DEF','PHY','acceleration','sprintSpeed','finishing','shotPower','longShots','volleys','penalties','shortPassing','longPassing','vision','crossing','curve','fkAccuracy','dribbling','ballControl','agility','balance','reactions','defensiveAwareness','standingTackle','slidingTackle','interceptions','strength','stamina','aggression','jumping','headingAccuracy','attackingPosition','composure','gkDiving','gkHandling','gkKicking','gkPositioning','gkReflexes')) { $numeric[$name] = $true }

function Convert-LuaValue([string]$field, [object]$raw) {
 $value = [string]$raw
 if ($field -eq 'specialPortrait') { if ($value.ToLowerInvariant() -eq 'true') { return 'true' } else { return 'false' } }
 if ($numeric.ContainsKey($field)) { $number = 0; if ([double]::TryParse($value, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) { return $number.ToString([Globalization.CultureInfo]::InvariantCulture) }; return '0' }
 $escaped = $value.Replace('\','\\').Replace('"','\"').Replace("`r",'').Replace("`n",'\n')
 return '"' + $escaped + '"'
}

$rows = Import-Csv -LiteralPath $source
$chunkSize = 250
$shardCount = [math]::Ceiling($rows.Count / $chunkSize)
for ($shardIndex = 0; $shardIndex -lt $shardCount; $shardIndex++) {
 $start = $shardIndex * $chunkSize
 $end = [math]::Min($start + $chunkSize, $rows.Count)
 $builder = [Text.StringBuilder]::new()
 [void]$builder.AppendLine('--!strict')
 [void]$builder.AppendLine('-- Generated from VTRPlayers_With_Appearance.csv. Do not edit by hand.')
 [void]$builder.AppendLine('return {')
 for ($index = $start; $index -lt $end; $index++) {
  $row = $rows[$index]
  $values = foreach ($field in $fields) { Convert-LuaValue $field $row.$field }
  [void]$builder.Append(' {' + ($values -join ',') + '},')
  [void]$builder.AppendLine()
 }
 [void]$builder.AppendLine('}')
 $name = 'Shard{0:D3}.lua' -f ($shardIndex + 1)
 [IO.File]::WriteAllText((Join-Path $shards $name), $builder.ToString(), [Text.UTF8Encoding]::new($false))
}

$manifest = @{
 Count = $rows.Count
 ShardCount = $shardCount
 ChunkSize = $chunkSize
 Fields = $fields
 Source = [IO.Path]::GetFileName($source)
 ImportedAt = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText((Join-Path $root 'ImportManifest.json'), $manifest, [Text.UTF8Encoding]::new($false))
Write-Output "Generated $shardCount shards for $($rows.Count) players."
