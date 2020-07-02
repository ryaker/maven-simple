param (
    [string] $ResourceGroup,
    [string] $VMSS,
    [string] $environment='NonProd'
)

# [string] $ResourceGroup = 'zusw2-prod-svc-rg'
# [string] $VMSS = 'zus2plrsg'
# [string] $environment = 'Prod'

if ($environment -eq 'NonProd') {
    # NON-PROD
    $SubscriptionID = '69fc3885-7797-4f0b-922a-2d6565cb8bed'
    $ApplicationID = 'c6eacd5b-8f80-44bd-9596-411eb99f3f78'
    $AzSecret = 'p4fW_X_/ehv-RQ6MbFq4U1LAt4C+XV2X'
}
else {
    # PROD
    $SubscriptionID = '572e8311-5864-4e12-9268-70796994d12d'
    $ApplicationID = '9e2e6e1f-121b-47f7-9d7a-98388729eb88'
    $AzSecret = '.gyJPJpj:Kihx+Q*MgyKY3Yui2fJKo81'
}

$TenantID = '101f87a7-6d6b-4c6c-9d9c-223592a2ba50'
$AzPassword = ConvertTo-SecureString $AzSecret -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($ApplicationID , $AzPassword)

# Login-AzAccount -Credential $Credential -TenantId $TenantID -Subscription $SubscriptionID -ServicePrincipal
# Connect-AzAccount -Tenant $TenantID -Subscription $SubscriptionID -Credential $Credential
Add-AzAccount -Tenant $TenantID -Subscription $SubscriptionID -Credential $Credential -ServicePrincipal

$computers = Get-AzVmssVM -ResourceGroupName $ResourceGroup -VMScaleSetName $VMSS 

$jobs = @()
$computers | ForEach-Object {

    $computerName   = $_.OsProfile.ComputerName
    $computerStatus = (Get-AzVmssVM -ResourceGroupName $ResourceGroup -VMScaleSetName $VMSS -InstanceId $_.InstanceId -InstanceView).Statuses.DisplayStatus[1]

    if ($computerStatus -match 'running') {
        Write-Host "`nWorking on $computerName..."
        Copy-Item ".\scripts\Splunk\inputs.conf" -Destination "\\$computerName\C$\Temp" -Force

        $jobs += Invoke-Command -ComputerName $computerName -ScriptBlock {
            $splunkHome = "C:\Program Files\SplunkUniversalForwarder"
            $backup_date = Get-Date -Format "yyMMdd-HHmm"
            
            Write-Host "... update host name"
            ((Get-Content -Path "C:\Temp\inputs.conf") -replace "\[SOURCEHOSTNAME\]", $env:COMPUTERNAME) `
                    | Set-Content -Path "C:\Temp\inputs.conf"

            $srcInputsHash = (Get-FileHash -Path "C:\Temp\inputs.conf").Hash
            $desInputsHash = (Get-FileHash -Path "$splunkHome\etc\system\local\inputs.conf").Hash

            if ($srcInputsHash -notmatch $desInputsHash) {
                Write-Host "... copy inputs.conf to Splunk directory"
                Copy-Item "$splunkHome\etc\system\local\inputs.conf" -Destination "$splunkHome\etc\system\local\inputs-$backup_date.conf" -Force
                Copy-Item "C:\Temp\inputs.conf" -Destination "$splunkHome\etc\system\local" -Force
                
                # Write-Host "... update host name"
                # ((Get-Content -Path "$splunkHome\etc\system\local\inputs.conf") -replace "\[SOURCEHOSTNAME\]", $env:COMPUTERNAME) `
                #     | Set-Content -Path "$splunkHome\etc\system\local\inputs.conf"
                
                Write-Host "... restart Splunk"
                Set-Location $splunkHome
                .\bin\splunk restart
            } else {
                Write-Host "... target inputs.conf is updated"
            }
        } -AsJob
    }
}

$jobs | ForEach-Object {
    Wait-Job $_ | Out-Null
    Receive-Job $_
}
