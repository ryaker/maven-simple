#Non-Prod
$nonprod = Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"

$IPs = @()
$servers = 'pzeaperftst01',	'pzeaperftst02',	'pzus2perftst01',	'pzus2perftst02',	'pzus2perftst03',	'pzus2perftst04'
$rgs = 'pzsea-perf-testvms-rg',	'pzsea-perf-testvms-rg',	'pzus2-perf-testvms-rg',	'pzus2-perf-testvms-rg',	'pzus2-perf-testvms-rg',	'pzus2-perf-testvms-rg'

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
    Stop-AzVM -Name $servers[$i] -ResourceGroupName $rgs[$i] -Force
    Write-Host " $($servers[$i]) is stopped now"
}

sleep 60

write-host "Stopped Servers : $servers"

## Prod
$prod = Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
$servers = 'pzeuwperftst01',	'pzeuwperftst02'
$rgs = 'pzeuw-perf-testvms-rg',	'pzeuw-perf-testvms-rg'
$IPs = @()

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
    Stop-AzVM -Name $servers[$i] -ResourceGroupName $rgs[$i] -Force
    Write-Host " $($servers[$i]) is stopped now"
}

sleep 60

write-host "Stopped Servers : $servers"