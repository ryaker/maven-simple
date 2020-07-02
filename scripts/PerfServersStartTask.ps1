#Non-Prod
$nonprod = Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"

$IPs = @()
$servers = 'pzeaperftst01',	'pzeaperftst02',	'pzus2perftst01',	'pzus2perftst02',	'pzus2perftst03',	'pzus2perftst04'
$rgs = 'pzsea-perf-testvms-rg',	'pzsea-perf-testvms-rg',	'pzus2-perf-testvms-rg',	'pzus2-perf-testvms-rg',	'pzus2-perf-testvms-rg',	'pzus2-perf-testvms-rg'

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
    $job = Start-AzVM -Name $servers[$i] -ResourceGroupName $rgs[$i] -Verbose -AsJob
}

sleep 180

write-host "Started Servers : $servers"

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
  $IP = (Get-AzPublicIpAddress -Name "$($servers[$i])-ip" -ResourceGroupName $rgs[$i]).IpAddress
  $IPs += $IP
}

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
 Write-Host "$($servers[$i]) : $($IPs[$i])"
}

## Prod
$prod = Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
$servers = 'pzeuwperftst01',	'pzeuwperftst02'
$rgs = 'pzeuw-perf-testvms-rg',	'pzeuw-perf-testvms-rg'
$IPs = @()

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
    $job = Start-AzVM -Name $servers[$i] -ResourceGroupName $rgs[$i] -Verbose -AsJob
}

sleep 180

write-host "Started Servers : $servers"

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
  $IP = (Get-AzPublicIpAddress -Name "$($servers[$i])-ip" -ResourceGroupName $rgs[$i]).IpAddress
  $IPs += $IP
}

for($i = 0; $i -lt $servers.Count;$i=$i+1)
{
 Write-Host "$($servers[$i]) : $($IPs[$i])"
}