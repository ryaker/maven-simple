param(
    [string]$ContainerName = "autoscale",
    [string]$BlobName = "test.txt"
)
<#
$azureAplicationId = "9e2e6e1f-121b-47f7-9d7a-98388729eb88"
$azureTenantId = "101f87a7-6d6b-4c6c-9d9c-223592a2ba50"
$azurePassword = ConvertTo-SecureString ".gyJPJpj:Kihx+Q*MgyKY3Yui2fJKo81" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureAplicationId , $azurePassword)
Add-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal
#>
Select-AzSubscription -Subscription "MTS Development and QA - Non Prod (0602)"

Add-Type -Path 'C:\Program Files\WindowsPowerShell\Modules\Az.Storage\1.6.0\Microsoft.Azure.Storage.Common.dll'
$accessCondition = New-Object Microsoft.Azure.Storage.AccessCondition

$lockAquired = $false
$TimeSpan = New-TimeSpan -Minutes 1
$DefaultLeaseID = "1111111a-222b-333c-444d-55555555555e"
$leaseID = ""

$storageAccounts = Get-AzStorageAccount -ResourceGroupName "splunk-usw-hrbl-rg" -Name "zuswhrblsplunkfiles" -ErrorAction Stop 
 
$selectedStorageAccount = $storageAccounts

If ($selectedStorageAccount) { 
    $key = (Get-AzStorageAccountKey -ResourceGroupName $selectedStorageAccount.ResourceGroupName -name $selectedStorageAccount.StorageAccountName -ErrorAction Stop)[0].value 
    $storageContext = New-AzStorageContext -StorageAccountName $selectedStorageAccount.StorageAccountName -StorageAccountKey $key -ErrorAction Stop 
    $storageContainer = Get-AzStorageContainer -Context $storageContext -Name $ContainerName -ErrorAction Stop 
    $blob = Get-AzStorageBlob -Context $storageContext -Container  $ContainerName -Blob $BlobName -ErrorAction Stop     
    $leaseStatus = $blob.ICloudBlob.Properties.LeaseStatus; 

    If ($leaseStatus -eq "Unlocked") { 
        Write-Host "The '$BlobName' blob lease status is $leaseStatus and lock will be acquired now"
        #string AcquireLease(TimeSpan? leaseTime, string proposedLeaseId, AccessCondition accessCondition = null, BlobRequestOptions options = null, OperationContext operationContext = null);
        try {
            $leaseID = $blob.ICloudBlob.AcquireLease($TimeSpan, $DefaultLeaseID, $null, $null, $null) 
            $lockAquired = $true
            $blob = Get-AzStorageBlob -Context $storageContext -Container  $ContainerName -Blob $BlobName -ErrorAction Stop
            $leaseStatus = $blob.ICloudBlob.Properties.LeaseStatus; 
            Write-Host "The '$BlobName' blob's lease status is $leaseStatus with lease ID: $leaseID"
            for ($i = 0; $i -lt 5; $i++) {
                write-host "Lock acquired..waiting for activity to complete"
                $AccessCondition.LeaseId = $leaseID
                $blob.ICloudBlob.RenewLease($AccessCondition)
                Start-Sleep -Seconds 50
            }
            $blob.ICloudBlob.ReleaseLease($AccessCondition)
            write-host "Lock released..Activity completed"
        }
        catch {
            $lockAquired = $false
        }
    } 
    ElseIf ($leaseStatus -eq "Locked") { 
        do {
            #$blob.ICloudBlob.BreakLease() 
            $blob = Get-AzStorageBlob -Context $storageContext -Container  $ContainerName -Blob $BlobName -ErrorAction Stop
            $leaseStatus = $blob.ICloudBlob.Properties.LeaseStatus;
            Write-Host "Already in locked status..waiting for 60 seconds for unlock" 
            sleep -Seconds 60
            Write-Host "The '$BlobName' blob's lease status is $leaseStatus."
        }while ($leaseStatus -eq "Locked")
        Write-Host "The '$BlobName' blob's lease status is $leaseStatus.Its ready to be used"
        $lockAquired = $false
    } 
} 
Else { 
    Write-Warning  Write-Warning "Cannot find storage account '$StorageAccountName' because it does not exist. Please make sure thar the name of storage is correct." 
}

return $lockAquired