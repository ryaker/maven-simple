param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$servers = @()
$source = ""
$month = ""

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
 
$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i = $vmss.Sku.Capacity/2; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzureRmVmssVM -InstanceView  -ResourceGroupName $vmssrg -name $vmssname  -InstanceId $i).Statuses.DisplayStatus[1]
    if ($status -eq "VM running") {
    $servers += $servername
    }
}

[scriptblock]$BackupScript = {
    Add-PSSnapin WDeploySnapin3.0
    Import-Module WebAdministration

    $month = (Get-Date -Format MMMyyyy).ToString()
    New-Item -Path D:\ -Name $month -ItemType Directory -Force

    $backup = Backup-WDServer -SourceSettings @{encryptPassword='hrbl2932'} "D:\$month"
    $packageName = Split-Path $backup.Package -leaf
    write-host "Created package $packageName Errors=$($backup.Errors) Warnings=$($backup.Warnings)"

    if ( $backup.Errors -gt 0 ) {
        Exit 1
    }
}

Write-Host "Back up is in progress on $source"

Invoke-Command -ComputerName $source -ScriptBlock $BackupScript

$month = (Get-Date -Format MMMyyyy).ToString()
$packageName = (Get-ChildItem -Path "\\$source\d$\$month" | Sort-Object CreationTime -Descending | Select-Object -First 1).Name
$PackageFullPath = "\\$source\d$\$month\$packageName"

$servers | % {
    write-host "Copying package from $PackageFullPath to $_"
    New-Item -Path "\\$_\d$" -Name $month -ItemType Directory -Force
    Copy-Item -Path $PackageFullPath -Destination "\\$_\d$\$month\" -Force
    write-host "Copy package completed from $PackageFullPath to $_"
}

sleep 10

[scriptblock]$RestoreBlock = {
    $packagePath =$args[0]
    Import-Module WebAdministration 
    Add-PSSnapin WDeploySnapin3.0

    iisreset /stop
    sleep 5 
    Restore-WDServer $packagePath  -DestinationSettings @{encryptPassword='hrbl2932'}
    sleep 5
    iisreset /start

    Write-Host "Build package restored to $env:COMPUTERNAME"
}

$servers | % {
    Invoke-Command -ComputerName $_ -ScriptBlock $RestoreBlock -ArgumentList "D:\$month\$packageName" -AsJob
}

write-host "Build jobs are running on $vmssname"

do {
    $runningJobs = Get-Job | Where-Object {$_.State -ne 'Completed'}
    #$runningJobs 
    sleep 10
} while ( $runningJobs.Count -gt 0 )

write-host "Builds copied to $vmssname"
