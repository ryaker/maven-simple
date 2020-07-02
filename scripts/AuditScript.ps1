param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
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
    "zus2pwssr" { $vmssrg = "zusw2-prod-web-rg" }
}
 
$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname


$scriptBlock = {

    Import-Module WebAdministration

    # assertion helper function to assert correct app pool values
    function  AssertAppPoolPropertyValue($appPoolName, $propertyName, $desiredValue) {
 
        # derive the path to the setting to assert
        $appPoolPath = ("IIS:\apppools\{0}" -f $appPoolName)

        # get the actual value value
        $actualValue = get-itemProperty $appPoolPath -name $propertyName 
   
        # assert the correct value is present
        if ( $desiredValue -ne $actualValue ) {
            write-host ("APP POOL PROPERTY FAILED: {0} {1} NOT EQUAL {2}" -f $appPoolName, $propertyName, $desiredValue)
            return $False
        }

        return $True
    } 

    # assertion helper function to assert correct site values
    function  AssertSitePropertyValue($siteName, $propertyName, $desiredValue) {
 
        # derive the path to the setting to assert
        $sitePath = ("IIS:\Sites\{0}" -f $siteName)

        # get the actual value value
        $actualValue = get-itemProperty $sitePath -name $propertyName 
   
        # assert the correct value is present
        if ( $desiredValue -ne $actualValue ) {
            write-host ("SITE ASSERTION PROPERTY FAILED: {0} {1} NOT EQUAL {2}" -f $siteName, $propertyName, $desiredValue)
            return $False
        }

        return $True
    } 

    write-host "Start assertion on $env:COMPUTERNAME"
    $script:failedAssertionCount = 0

    #
    # Assert Defaults are correct "null app pool name and defaults property used here to dig up defaults

    # Failure.rapidFailProtection = False
    if ( -not (AssertAppPoolPropertyValue -appPoolName "" -propertyName "ApplicationPoolDefaults.Failure.rapidFailProtection.Value" -desiredValue $False )  ) {
        $script:failedAssertionCount++
    }

    # processModel.idleTimeout = 0
    if ( -not (AssertAppPoolPropertyValue -appPoolName "" -propertyName "ApplicationPoolDefaults.processModel.idleTimeout.Value" -desiredValue "00:00:00" )  ) {
        $script:failedAssertionCount++
    }

    # startMode = AlwaysRunning
    if ( -not (AssertAppPoolPropertyValue -appPoolName "" -propertyName "ApplicationPoolDefaults.startMode.Value" -desiredValue 1  )  ) {
        $script:failedAssertionCount++
    }

    #
    # now get the collection of app pools and check each one for the right settings
    $appPools = get-itemProperty IIS:\apppools
    foreach ( $appPool in $appPools.Children.Values ) {
    
        #
        #now assert each app pool also specfically has rapid fail disabled

        # Failure.rapidFailProtection = False
        if ( -not (AssertAppPoolPropertyValue -appPoolName $appPool.Name -propertyName "Failure.rapidFailProtection.Value" -desiredValue $False)  ) {
            $script:failedAssertionCount++
        }

        # processModel.idleTimeout = 0
        if ( -not (AssertAppPoolPropertyValue -appPoolName $appPool.Name -propertyName "processModel.idleTimeout.Value" -desiredValue ( [TimeSpan]::FromMinutes(0))) ) {
            $script:failedAssertionCount++
        }

        # startMode = AlwaysRunning
        if ( -not (AssertAppPoolPropertyValue -appPoolName $appPool.Name -propertyName "startMode.Value" -desiredValue 1 )  ) {
            $script:failedAssertionCount++
        }
    }


    #
    # now get the collection of sites and check each one for the right settings
    $sites = get-itemProperty IIS:\Sites
    foreach ( $site in $sites.Children.Values ) {

        # startMode = preloadEnabled
        if ( -not (AssertSitePropertyValue -siteName $site.Name -propertyName "applicationDefaults.preloadEnabled.Value" -desiredValue $True)  ) {
            $script:failedAssertionCount++
        }
    }

    # 
    # summarize results
    #
    if ( $script:failedAssertionCount -ne 0 ) {
        write-host ("FAILURE - {0} assertions failed!" -f $script:failedAssertionCount )
    }
    else {
        write-host ("SUCCESS - {0} assertions failed!" -f $script:failedAssertionCount )
    }
}
 
for ( $i = 0; $i -lt $vmss.Sku.Capacity; $i++ ) {
   
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    
    Invoke-Command -ComputerName "$servername.hrbl.net" -ScriptBlock $scriptBlock
}