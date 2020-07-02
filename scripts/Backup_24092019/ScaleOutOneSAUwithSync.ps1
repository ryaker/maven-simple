param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname,
    [Parameter(Mandatory = $true)]
    [ValidateSet("True","False")]
    [string]$FlipStatus
)
function GetInstances{
    param
    (
    [string]$vmssName,
    [string]$rgName
    )
    
    $instances = @()
    
    
    
    $VMs = Get-AzureRmVmssVM -ResourceGroupName $rgName -name $vmssName  
    
    foreach( $vmInstance in $VMs ) {
        $vmName = $vmInstance.OSProfile.ComputerName
        $instances += $vmInstance.InstanceID
        
        }
    
        return $instances
    }
    
Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$role = ""
$servers = @()
$instances = @()
$scale_count = 0

$Date = (Get-Date).ToString('dd-MM-yyyy-hhmm')

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg"; $role = "web"; $bad_instances =@(24,34); $source = "zuswpwssb000000"}
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg"; $role = "web"; $bad_instances =@() ; $source = "zuswpwssg000000"}
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(); $source = "zus2pwssb000000"}
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(); $source = "zus2pwssg000000" }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(); $source = "Zeuwpwsg2000000" }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(); $source = "Zeuwpwsb2000000" }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(3,9); $source = "Zseapwsg2000000" }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(); $source = "Zseapwsb2000000" }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@(); $source = "zuswpsssb000000" }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@(); $source = "zuswpsssg000000" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@(); $source = "zus2psssb000000" }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@(); $source = "zus2psssg000000" }
    "zus2pwssr" { $vmssrg = "zusw2-prod-web-rg"; $role = "web"; $bad_instances =@(1); $source = "zus2pwssr000000" }
}

$svc_sau = 4
$web_sau = 4
$min_farm_web = 2
$min_farm_svc = 8

if ($role -eq "svc")
{
    $active_sau = $svc_sau;
}
else
{
    $active_sau = $web_sau;
}

$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname
$all_instances  = GetInstances -vmssName $vmssname -rgName $vmssrg

for ( $i = 0; $i -lt $vmss.Sku.Capacity; $i++ ) {
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $all_instances[$i]
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzureRmVmssVM -InstanceView  -ResourceGroupName $vmssrg -VMScaleSetName $vmssname  -InstanceId $all_instances[$i]).Statuses.DisplayStatus[1]
    Write-Host $servername $status "- Before Check"
    if (($status -ne "VM running") -and ($scale_count -lt $active_sau ) -and ($all_instances[$i] -notin $bad_instances)) {
        $servers += $servername
        $instances += $vm.InstanceID
        $scale_count++
        Write-Host "To Be turned On Status: $servername" $status
    }
    else {
        Write-Host "Status: $servername" $status
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

$StartVMJobs = @()

$instances | % {
    $StartVMJobs += Start-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_ -Verbose -AsJob
}

foreach ($startVMJob in $startVMJobs) {
    Wait-Job $startVMJob
    $receivestartVMJob = Receive-Job $startVMJob
    write-host $receivestartVMJob
}


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

$SyncVMJobs = @()

$servers | % {
    
    $uri = "http://" + $_ + ":8000/"

    while ((Invoke-WebRequest -Uri $uri -UseBasicParsing).StatusCode -ne 200) {
        write-host "waiting for $_ to be ready to take web traffic"
    }
        Write-Host "Sync Host file  on $_"
        Rename-Item -Path "\\$_\C$\Windows\System32\drivers\etc\hosts" -NewName "\\$_\C$\Windows\System32\drivers\etc\hosts-$Date" -Force  -Verbose
        sleep 5
        Copy-Item -Path "\\$source\c$\Windows\System32\drivers\etc\hosts" -Destination "\\$_\C$\Windows\System32\drivers\etc" -Force  -Verbose
        sleep 5
        ipconfig /flushdns
        if(Test-Path -Path "\\$_\C$\Windows\System32\drivers\etc\hosts")
        {
            Write-Host "Host file updated on $_"
        }


        Write-Host "Sync ExternalAppSettings file  on $_"
        if ($role -eq "svc")
        {
            Rename-Item -Path "\\$_\c$\Program Files\Herbalife\Configuration\externalAppSettings.config" -NewName "\\$_\c$\Program Files\Herbalife\Configuration\externalAppSettings-$Date.config" -Force  -Verbose
            sleep 5
            Copy-Item -Path "\\$source\c$\Program Files\Herbalife\Configuration\externalAppSettings.config" -Destination "\\$_\c$\Program Files\Herbalife\Configuration"     -Force -Verbose       
            if(Test-Path -Path "\\$_\c$\Program Files\Herbalife\Configuration\externalAppSettings.config")
            {
                Write-Host "externalAppSettings.confi file updated on $_"
            }
        }
        else
        {
            Rename-Item -Path "\\$_\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\externalAppSettings.config" -NewName "\\$_\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\externalAppSettings-$Date.config" -Force -Verbose
            sleep 5
            Copy-Item -Path "\\$source\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\externalAppSettings.config" -Destination "\\$_\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config" -Force -Verbose
            if(Test-Path -Path "\\$_\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\externalAppSettings.config")
            {
                Write-Host "externalAppSettings.confi file updated on $_"
            }
        }    
    write-host "Copying package from $PackageFullPath to $_"
    New-Item -Path "\\$_\d$" -Name $month -ItemType Directory -Force -Verbose
    Copy-Item -Path $PackageFullPath -Destination "\\$_\d$\$month\" -Force -Verbose
    write-host "Copy package completed from $PackageFullPath to $_"
    write-host "server $_ is being syncd"
    $SyncVMJobs += Invoke-Command -ComputerName $_ -ScriptBlock $RestoreBlock -ArgumentList "D:\$month\$packageName" -Verbose -AsJob
   #Invoke-Command -ComputerName $_ -ScriptBlock $RestoreBlock -ArgumentList "D:\$month\$packageName"
}

foreach ($SyncVMJob in $SyncVMJobs) {
    Wait-Job $SyncVMJob
    $receiveSyncVMJob = Receive-Job $SyncVMJob
    write-host $receiveSyncVMJob
}


write-host "Scale Up and Sync completed on $vmssname"

$servers | % {
    $uri = "http://" + $_ + ":8000/"

    while ((Invoke-WebRequest -Uri $uri -UseBasicParsing).StatusCode -ne 200) {
        write-host "waiting for $_ to Sync"
    }
    write-host "server $_ is being syncd"

}
write-host "All servers responding, now waiting 5 minutes and will return to service"






$scriptblockonline = {
    $WAS = (Get-Service -Name WAS).Status
    $W3SVC = (Get-Service -Name W3SVC).Status
    iisreset /stop
    iisreset /start

    if((Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX") -and ($WAS -eq "Running") -and ($W3SVC -eq "Running"))
    {     
        Rename-Item -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX" -NewName "NLBControl.Online" -Force -Verbose
        Write-Host "$env:COMPUTERNAME is taken online"
    }
    elseif((Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online") -and ($WAS -eq "Running") -and ($W3SVC -eq "Running"))
    {
        Write-Host "$env:COMPUTERNAME is already online"
    }
}

$splunk_start_block = {

    #.\bin\splunk.exe btool check --debug

    cd "C:\Program Files\SplunkUniversalForwarder"
    .\bin\splunk.exe stop 
    .\bin\splunk.exe start
}

$servers | % {
    write-host "$_ is restarting Splunk"
    Invoke-Command -ComputerName $_ -ScriptBlock $splunk_start_block

}

if($FlipStatus -eq "True")
{
    write-host "All servers responding, now waiting 5 minutes and will return to service"

    sleep 300

    $servers | % {
        Invoke-Command -ComputerName $_ -ScriptBlock $scriptblockonline
        write-host "$_ is responding fine and taken online at server level"
    }
}
