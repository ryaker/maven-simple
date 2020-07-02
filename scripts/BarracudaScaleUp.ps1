param(
    [Parameter(Mandatory = $true)]
    [Validateset("USW","USW2","SEA","EU")]
    [string]$BarracudaDC
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$ServerType=""
$servers = @()
$vmssname = ""

switch ($BarracudaDC) {
    "USW" { $rg = "zusw-barracuda-vmss-prod-rg"; $ServerType="VMSS"; $vmssname = "zuswpwaf"}
    "USW2" { $rg = "zusw2-barracuda-prod-rg"; $ServerType="VM"; $servers = 'zus2pwaf06','zus2pwaf07','zus2pwaf08','zus2pwaf09','zus2pwaf10'}
    "SEA" { $rg = "zsea-barracuda-prod-rg"; $ServerType="VM"; $servers = 'zseapwaf05','zseapwaf06','zseapwaf07','zseapwaf08'}
    "EU" { $rg = "zeuw-barracuda-prod-rg"; $ServerType="VM"; $servers = 'zeuwpwaf05','zeuwpwaf06','zeuwpwaf07','zeuwpwaf08' }
}
 
if($ServerType -eq "VMSS")
{
    $vm = (Get-AzVMssVM -ResourceGroupName $rg -VMScaleSetName $vmssname).Name
    $InstanceId = (Get-AzVMssVM -ResourceGroupName $rg -VMScaleSetName $vmssname).InstanceId
    $servers = $vm
    Write-Host "Half of servers will be started from $servers"

    $ids = $(($servers.Count)/2)..$(($servers.Count)-1)
    $ids | % {
    Start-AzVmss -ResourceGroupName $rg -VMScaleSetName $vmssname -InstanceId $InstanceId[$_] -Verbose -AsJob
    #(Get-AzVMssVM -ResourceGroupName $rg -VMScaleSetName $vmssname -InstanceId $InstanceId[$_]).Name
    }
}

if($ServerType -eq "VM")
{
    $servers | % {
    #Get-AzVM -Name $_ -ResourceGroupName $rg -Verbose
    Start-AzVM -Name $_ -ResourceGroupName $rg -Verbose -AsJob
    }    
}

do {
    $runningJobs = Get-Job | Where-Object {$_.State -ne 'Completed'}
    #$runningJobs 
    sleep 5
} while ( $runningJobs.Count -gt 0 )

write-host "Scale up completed on $BarracudaDC"