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

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg"; $role = "web"; $bad_instances =@(24,34) }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg"; $role = "web"; $bad_instances =@() }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role = "web"; $bad_instances =@()}
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@(3,9) }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2pwssr" { $vmssrg = "zusw2-prod-web-rg"; $role = "web"; $bad_instances =@() }
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
    $StartVMJobs += Start-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_ -Verbose -AsJob
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
elseif($FlipStatus -eq "False")
{
    write-host "All servers have been started and will be kept offline"
    $servers | % {
        Invoke-Command -ComputerName $_ -ScriptBlock $scriptblockoffline 
        write-host "$_ is responding fine and kept offline at server level"
    }
}