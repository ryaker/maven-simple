param(
[Parameter(Mandatory=$true)]
[string]$vmssname
)

#Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""

switch ($vmssname) {
   "zuswpwssb" {$vmssrg = "zusw-prod-web-rg"}
   "zuswpwssg" {$vmssrg = "zusw-prod-web-rg"}
   "zuswpsssb" {$vmssrg = "zusw-prod-svc-rg"}
   "zuswpsssg" {$vmssrg = "zusw-prod-svc-rg"}
   "zuswqwssa" {$vmssrg = "zusw-qa-web-rg"}
}
 
$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname
 
for ( $i=0; $i -lt $vmss.Sku.Capacity; $i++ ) {
     
     $resetBlock = {
        Write-Host "$env:COMPUTERNAME"
    }
   
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    
    Invoke-Command -ComputerName "$servername.hrbl.net" -ScriptBlock $resetBlock
}