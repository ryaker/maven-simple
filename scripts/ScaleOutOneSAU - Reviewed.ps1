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
    
    
    
    $VMs = Get-AzVmssVM -ResourceGroupName $rgName -name $vmssName  
    
    foreach( $vmInstance in $VMs ) {
        $vmName = $vmInstance.OSProfile.ComputerName
        $instances += $vmInstance.InstanceID
        
        }
    
        return $instances
    }

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$role = ""
$servers = @()
$instances = @()
$scale_count = 0

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg"; $role = "web"; $bad_instances =@(8,24,34) }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg"; $role = "web"; $bad_instances =@(28,33) }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role = "web"; $bad_instances =@()}
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(9) }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(3,9) }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@(16) }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2pwssr" { $vmssrg = "zusw2-prod-web-rg"; $role = "web"; $bad_instances =@(1) }
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

$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname
$all_instances  = GetInstances -vmssName $vmssname -rgName $vmssrg

for ( $i = 0; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $all_instances[$i]
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzVmssVM -InstanceView  -ResourceGroupName $vmssrg -VMScaleSetName $vmssname  -InstanceId $all_instances[$i]).Statuses.DisplayStatus[1]
    if (($status -ne "VM running") -and ($scale_count -lt $active_sau ) -and ($vm.InstanceID -notin $bad_instances)) {
        $servers += $servername    
        $instances += $vm.InstanceID  
        $scale_count++
        Write-Host "To Be turned On Status: $servername" $status
    }
    else {
        Write-Host "Status: $servername" $status
    }
}

$StartVMJobs = @()

$instances | % {
    $StartVMJobs += Start-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_ -Verbose -AsJob
}

foreach ($startVMJob in $startVMJobs) {
    Wait-Job $startVMJob                                                                                                                  
    $receivestartVMJob = Receive-Job $startVMJob                                                                                                           
}

$servers | % {
    while ((Test-NetConnection -ComputerName $_ -Port 3389).TcpTestSucceeded -ne "True") {
        write-host "waiting for $_ to boot up"
    }
    write-host "server $_ is responding"
}

write-host "Scale Up completed on $vmssname"

$scriptblockonline = {
    $WAS = (Get-Service -Name WAS).Status
    $W3SVC = (Get-Service -Name W3SVC).Status

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

$scriptblockoffline = {
    $WAS = (Get-Service -Name WAS).Status
    $W3SVC = (Get-Service -Name W3SVC).Status

    if((Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX") -and ($WAS -eq "Running") -and ($W3SVC -eq "Running"))
    {
        Write-Host "$env:COMPUTERNAME is already offline"
    }
    elseif((Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online") -and ($WAS -eq "Running") -and ($W3SVC -eq "Running"))
    {
        Rename-Item -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online" -NewName "NLBControl.OnlineX" -Force -Verbose
        Write-Host "$env:COMPUTERNAME is taken offline"
    }
}


$splunk_start_block = {
Stop-Service -Name SplunkForwarder -Force  	
sleep 2
Start-Service -Name SplunkForwarder
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
elseif($FlipStatus -eq "False")
{
    write-host "All servers have been started and will be kept offline"
    $servers | % {
        Invoke-Command -ComputerName $_ -ScriptBlock $scriptblockoffline 
        write-host "$_ is responding fine and kept offline at server level"
    }
}