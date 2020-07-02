param(
    [Parameter(Mandatory = $true)]
    [string]$RedisServiceName
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
<#
Get-AzRedisCache | Select -Property Name,ResourceGroupName
#>

switch ($RedisServiceName) {
    "hlmts-euw-prod-redis"          { $Redisrg = "hlmts-euw-prod-rg" }
    "zeuw-prod-notification-redis"  { $Redisrg = "zeuw-prod-redis-rg" }
    "hlmts-usw-prod-redis"          { $Redisrg = "hlmts-usw-prod-rg" }
    "zusw-prod-redis02"             { $Redisrg = "zusw-redis-2019march18-rg" }
    "zusw-prod-profile-redis"       { $Redisrg = "zusw-prod-redis-rg" }
    "zusw-prod-notification-redis"  { $Redisrg = "zusw-prod-redis-rg" }
    "hlmts-sea-prod-redis"          { $Redisrg = "hlmts-sea-prod-redis-rg" }
    "zsea-prod-notification-redis"  { $Redisrg = "zsea-prod-redis-rg" }
    "hlmts-usw2-prod-redis"         { $Redisrg = "zusw2-prod-rg" }
    "zusw2-prod-notification-redis" { $Redisrg = "zusw2-prod-redis-rg" }
}

Set-AzRedisCache -ResourceGroupName $Redisrg -Name $RedisServiceName -ShardCount 8

sleep 180

$redis = Get-AzRedisCache -ResourceGroupName $Redisrg -Name $RedisServiceName

while($redis.ProvisioningState -eq "Scaling")
{
    Write-Host "$($redis.Name) is getting scaled"
    sleep -Seconds 60
    $redis = Get-AzRedisCache -ResourceGroupName $Redisrg -Name $RedisServiceName
}

if($redis.ProvisioningState -eq "Succeeded")
{
    Write-Host "$($redis.Name) scale up activity completed"
}