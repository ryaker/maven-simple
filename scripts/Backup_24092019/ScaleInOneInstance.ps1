param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
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

$svc_sau = 1
$web_sau = 1
$min_farm_web = 2
$min_farm_svc = 8

if ($role -eq "svc")
{
    $active_sau = $svc_sau;
    $active_min = $min_farm_svc;
}
else
{
    $active_sau = $web_sau;
    $active_min = $min_farm_web;
}

$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname
$all_instances  = GetInstances -vmssName $vmssname -rgName $vmssrg


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

$total_on = 0

for ( $i = 0; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $all_instances[$i]
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzureRmVmssVM -InstanceView  -ResourceGroupName $vmssrg -VMScaleSetName $vmssname  -InstanceId $all_instances[$i]).Statuses.DisplayStatus[1]
    $status
 
    if (($status -eq "VM running")) {
        Write-Host "TStatus: $servername" $status
        $total_on++
    }
    else {
        Write-Host "Status: $servername" $status
    }
}

$total_on

if (($total_on - $active_sau) -lt $active_min )
{
    throw 'Not scaling down because we will go below min'
}

for ( $i = $vmss.Sku.Capacity-1; $i -ge 0; $i-- ) {  
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $all_instances[$i]
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzureRmVmssVM -InstanceView  -ResourceGroupName $vmssrg -VMScaleSetName $vmssname  -InstanceId $all_instances[$i]).Statuses.DisplayStatus[1]
    $status
    if (($status -eq "VM running") -and ($scale_count -lt $active_sau ) -and ($all_instances[$i] -notin $bad_instances)) {
        $servers += $servername    
        $instances += $all_instances[$i]  
        $scale_count++
        Write-Host "ScaleCount:" $scale_count
        Write-Host "To Be turned Off Status:" $servername $status
        Write-Host "---------------------------------------"
    }
    else {
        Write-Host "Status: $servername" $status
        Write-Host "---------------------------------------"
    }
}

Write-Host "========================================="
$scale_count
Write-Host "===============------------------------------==============="
$servers
Write-Host "===============------------------------------==============="
$instances


$servers | % {
    Invoke-Command -ComputerName $_ -ScriptBlock $scriptBlock -AsJob
}

sleep 180

$StopVMJobs = @()

$instances | % {
    $StopVMJobs += Stop-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_ -Force -Verbose -AsJob
}

foreach ($StopVMJob in $StopVMJobs) {
    Wait-Job $StopVMJob                                                                                                                  
    $receiveStopVMJob = Receive-Job $StopVMJob                                                                                                           
}

write-host "Scale down completed on $vmssname"

<#
$servers | % {
    Stop-Computer -ComputerName $_ -AsJob -Force
}#>