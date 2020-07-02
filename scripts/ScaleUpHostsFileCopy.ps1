param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$servers = @()
$source = ""

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg"; $source = "zuswpwssb000000" }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg"; $source = "zuswpwssg000000" }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg"; $source = "zus2pwssb000000" }
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg"; $source = "zus2pwssg000000" }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $source = "Zeuwpwsg2000000" }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $source = "Zeuwpwsb2000000" }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $source = "Zseapwsg2000000" }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $source = "Zseapwsb2000000" }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $source = "zuswpsssb000000" }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $source = "zuswpsssg000000" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $source = "zus2psssb000000" }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $source = "zus2psssg000000" }
}
 
$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i = $vmss.Sku.Capacity/2; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $servers += $servername
}

$scriptblock = {
    $Date = (Get-Date).ToString('dd-MM-yyyy-hhmm')
    $sourceserver = $args[0]
    if(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online")
    {
        Rename-Item -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online" -NewName "NLBControl.OnlineX" -Force -Verbose
        Write-Host "$env:COMPUTERNAME is taken offline"
        Rename-Item -Path "C:\Windows\System32\drivers\etc\hosts" -NewName "hosts-$Date" -Force
        sleep 5
        Copy-Item -Path "\\$sourceserver\c$\Windows\System32\drivers\etc\hosts" -Destination "C:\Windows\System32\drivers\etc" -Force
        sleep 5
        ipconfig /flushdns
        if(Test-Path -Path "C:\Windows\System32\drivers\etc\host")
        {
            Write-Host "Host file updated on $env:COMPUTERNAME"
        }
    }
    elseif(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX")
    {
        Write-Host "$env:COMPUTERNAME is already offline"
        Rename-Item -Path "C:\Windows\System32\drivers\etc\hosts" -NewName "hosts-$Date" -Force
        sleep 5
        Copy-Item -Path "\\$sourceserver\c$\Windows\System32\drivers\etc\hosts" -Destination "C:\Windows\System32\drivers\etc" -Force
        sleep 5
        ipconfig /flushdns
        if(Test-Path -Path "C:\Windows\System32\drivers\etc\host")
        {
            Write-Host "Host file updated on $env:COMPUTERNAME"
        }
    }
}

$servers | % {
    Invoke-Command -ComputerName $_ -ScriptBlock $scriptBlock -ArgumentList $source -AsJob
}

do {
    $runningJobs = Get-Job | Where-Object {$_.State -ne 'Completed'}
    #$runningJobs 
    sleep 10
} while ( $runningJobs.Count -gt 0 )

write-host "Host file copied to $vmssname"