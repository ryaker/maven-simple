param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$servers = @()

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg" }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg" }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg" }
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg" }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg" }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg" }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg" }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg" }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg" }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg" }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg" }
}
 
$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i = $vmss.Sku.Capacity/2; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $servers += $servername
}

$ids = $($vmss.Sku.Capacity/2)..$(($vmss.Sku.Capacity)-1)
$ids | % {
Start-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_ -Verbose -AsJob
}

sleep 240

do {
    $runningJobs = Get-Job | Where-Object {$_.State -ne 'Completed'}
    #$runningJobs 
    sleep 10
} while ( $runningJobs.Count -gt 0 )

$scriptblock = {
    if(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online")
    {
        Rename-Item -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online" -NewName "NLBControl.OnlineX" -Force -Verbose
        Write-Host "$env:COMPUTERNAME is taken offline"
    }
    elseif(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX")
    {
        Write-Host "$env:COMPUTERNAME is already offline"
    }
}

$servers | % {
    Invoke-Command -ComputerName $_ -ScriptBlock $scriptBlock -AsJob
}

do {
    $runningJobs = Get-Job | Where-Object {$_.State -ne 'Completed'}
    #$runningJobs 
    sleep 10
} while ( $runningJobs.Count -gt 0 )

write-host "Scale Up completed on $vmssname"