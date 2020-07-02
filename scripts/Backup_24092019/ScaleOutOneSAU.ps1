param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

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
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role = "web"; $bad_instances =@() }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $role = "svc"; $bad_instances =@() }
    "zus2pwssr" { $vmssrg = "zusw2-prod-web-rg"; $role = "web"; $bad_instances =@(1)}
}
 
$svc_sau = 4
$web_sau = 4

if ($role == "svc")
{
    $active_sau = $svc_sau;
}
else
{
    $active_sau = $web_sau;
}

$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i = 0; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzureRmVmssVM -InstanceView  -ResourceGroupName $rgName -name $vmssName  -InstanceId $vmInstance.InstanceId).Statuses.DisplayStatus[1]
    if (($status -ne "VM running") -and ($scale_count -lt $active_sau ) -and ($vmInstance.InstanceID -notin $bad_instances)) {
        $servers += $servername    
        $instances += $vmInstance.InstanceID  
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
    while ( (Test-Connection  -ComputerName ($_) -Quiet ) -ne $true) {
        write-host "waiting for $_ to boot up"
    }
    write-host "server responding"
}

write-host "Scale Up completed on $vmssname"
write-host "All servers responding, now waiting 5 minutes and will return to service"
sleep 300
$scriptblock = {
    if(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX")
    {
        Rename-Item -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX" -NewName "NLBControl.Online" -Force -Verbose
        Write-Host "$env:COMPUTERNAME is taken online"
    }
    elseif(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online")
    {
        Write-Host "$env:COMPUTERNAME is already online"
    }
}

$servers | % {
    Invoke-Command -ComputerName $_ -ScriptBlock $scriptBlock 
}