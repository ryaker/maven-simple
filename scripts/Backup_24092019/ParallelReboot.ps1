param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname,
    [Parameter(Mandatory = $true)]
    [ValidateRange (1,2)]
    [int]$set,
    [Parameter(Mandatory = $true)]
    [string]$SVCUsername,
    [Parameter(Mandatory = $true)]
    [string]$SVCPassword
)

$evenset = @()
$oddset = @()

$SVCUsername = "herbalifecorp\vinayn-a"
$SVCPassword = "Bjnga_123"
$Password = ConvertTo-SecureString $SVCPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($SVCUsername,$Password);

workflow Parallel-Reboot
{
    Param
    (
        [string[]]$Computers,
        [PSCredential]$Credential
    )

    foreach -parallel ($computer in $Computers)
    {
            #Restart-Computer -ComputerName $serverName -Wait -For WinRM -Delay 5 -Force
        InlineScript {
            try
            {
            $s = New-PSSession -ComputerName $using:computer -Credential $using:Credential
            Invoke-Command -Session $s -ScriptBlock {
             Get-CimInstance -ClassName win32_operatingsystem | select csname, lastbootuptime
               #New-Item -Path c:\temp\ -Name rundeck.txt -ItemType File -Force
                }
            }
            finally {
                Remove-PSSession -Session $s
            }
        }       
    }
}

Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg" }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg" }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg" }
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg" }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg" }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg" }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg" }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg" }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg" }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg" }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg" }
    "zuswqwssa" { $vmssrg = "zusw-qa-web-rg" }
}
 
$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i=0; $i -lt $vmss.Sku.Capacity/2; $i++ ) {   
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssName -InstanceId $i
    $i2=($vmss.Sku.Capacity)-$i-1
    $vm2 = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssName -InstanceId $i2
 
    $oddset += $vm.OSProfile.ComputerName
    $evenset += $vm2.OSProfile.ComputerName
}

if($set -eq 1)
{
Parallel-Reboot -Computers $oddset -Credential $Credential
}
elseif($set -eq 2)
{
Parallel-Reboot -Computers $evenset
}