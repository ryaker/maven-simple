param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$role =""
$servers = @()
$instances = @()

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg"; $role ="web"}
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg"; $role ="web" }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role ="web"}
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg"; $role ="web" }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role ="web" }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $role ="web" }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role ="web" }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $role ="web" }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $role ="svc" }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $role ="svc" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $role ="svc" }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $role ="svc" }
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
$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i=0; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $status = (Get-AzVmssVM -InstanceView  -ResourceGroupName $rgName -name $vmssName  -InstanceId $i).Statuses.DisplayStatus[1]
    if ($status -eq "VM running") {
        $servers += $servername    
        $instances += $i
    }
    else {
        Write-Host "Status: $vmName" $status
    }
}
$Count=$servers.Count+4
If ($Count -le $VMSS.Sku.Capacity)
{
$ids = $($Count-4)..$Count-1
$ids | % {
Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_
#Start-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $_ -Verbose 
}
}
sleep 60

<#
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
    Invoke-Command -ComputerName $_ -ScriptBlock $scriptBlock 
}

#>
write-host "Scale Up completed on $vmssname"