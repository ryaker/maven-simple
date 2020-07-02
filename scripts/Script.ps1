param(
[Parameter(Mandatory=$true)]
[string]$vmssname
)

#Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""

switch ($vmssname) {
   "zuswpwssb" {$vmssrg = "zusw-prod-web-rg"}
   "zuswpwssg" {$vmssrg = "zusw-prod-web-rg"}
   "zuswpsssb" {$vmssrg = "zusw-prod-svc-rg"}
   "zuswpsssg" {$vmssrg = "zusw-prod-svc-rg"}
   "zuswqwssa" {$vmssrg = "zusw-qa-web-rg"}
}
 
$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname
 
for ( $i=0; $i -lt $vmss.Sku.Capacity; $i++ ) {
     
     $resetBlock = {
        Write-Host "$env:COMPUTERNAME"
    }
   
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    
    Invoke-Command -ComputerName "$servername.hrbl.net" -ScriptBlock $resetBlock
}