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

Set-AzContext -SubscriptionID 572e8311-5864-4e12-9268-70796994d12d



$rgName = "zusw-barracuda-vmss-prod-rg"
$vmssName = "zuswpwaf"


$servers = GetServers -vmssName $vmssName -rgName $rgName #Farm Green

$instances  = GetInstances -vmssName $vmssName -rgName $rgName #Farm Green

$vmss = Get-AzVmss -ResourceGroupName $rgName -VMScaleSetName $vmssName





for ( $position=$vmss.Sku.Capacity/2; $position -lt $vmss.Sku.Capacity; $position++ ) {




$instanceId = $instances[$position]
    
    $instanceId

    Stop-AzVmss -ResourceGroupName $rgName -VMScaleSetName $vmssName -InstanceId $instanceId -Asjob -force -verbose

    }