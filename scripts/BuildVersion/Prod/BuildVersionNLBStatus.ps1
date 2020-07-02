$script:author = 'Azrad'
# Write-Host $author

Import-Module WebAdministration
$nlbServerLevel = 'C:\Program Files\Herbalife\Configuration\NlbControl.Online'
$nlbAppData = 'App_Data\NLBControl.Online'
$isOnlineServerLevel = $False
# $siteStatusColor = 'Red'
$scaleSetName = $env:COMPUTERNAME.Substring(0, 9)
# $datacenterName = $env:COMPUTERNAME.Substring(0, 4)

$webSet = @{
    'serverGroup' = 'Web'
    'members' = @('pws')
    'appType' = 'Vertical'
}
$serviceSet = @{
    'serverGroup' = 'Svc'
    'members' = @('pss', 'pls', 'plr')
    'appType' = 'Service'
}
$adminSet = @{
    'serverGroup' = 'Admin'
    'members' = @('pas', 'p1as')
    'appType' = 'Service'
}

$greenSet = @{
    'farm' = 'Green'
    'members' = @('pwssg', 'pwsg2', 'psssg', 'plssg', 'plrsg', 'pasg', 'p1asg')
}
$blackSet = @{
    'farm' = 'Black'
    'members' = @('pwssb', 'pwsb2', 'psssb', 'plssb', 'plrsb', 'pasb', 'p1asb')
}
$redSet = @{
    'farm' = 'Red'
    'members' = @('pwssr')
}
$performanceSet = @{
    'farm' = 'Performance'
    'members' = @('pwssp')
}

$farmName = ''
$datacenterName = ''
@($greenSet, $blackSet, $redSet, $performanceSet) | foreach-object {
    # write-host "[$computerName]"
    $setName = $_.farm
    # write-host $setName
    
    $_.members | foreach-object {
        $member = $_
        if ([string]::isnullorempty($farmName)) {
            # write-host "...test for $member"
            $farmName = if ($env:COMPUTERNAME -match $member) { $setName }
            $datacenterName = ($env:COMPUTERNAME -split $member)[0]
        }
    }
}

$serverGroup = ''
$appType = ''
@($webSet, $serviceSet, $adminSet) | foreach-object {
    $setServerGroup = $_.serverGroup
    $setAppType = $_.appType
    # write-host "...serverGroup is $setServerGroup"
    $_.members | foreach-object {
        # write-host "...test for $_"
        if (-not $serverGroup) {
            $serverGroup = if ($env:COMPUTERNAME -match $_) { $setServerGroup }
            $appType = $setAppType
        }
    }
}

if (Test-Path -Path $nlbServerLevel) {
    $isOnlineServerLevel = $True
}

$OSVersion = [System.Environment]::OSVersion.Version

if ($OSVersion.Major -eq 10) {
    $sites = Get-IISSite
}
else {
    $sites = Get-ChildItem IIS:\Sites
}

$sites | ForEach-Object {
    $isOnline = $False
    $nlbStatus = 0
    $siteName = $_.Name

    $site = Get-Website -Name $siteName
    $physicalPath = $site.physicalPath
    $binPhysicalPath = "${physicalPath}\bin"
    $targetPath = if (Test-Path -Path $binPhysicalPath) { $binPhysicalPath } else { $physicalPath }

    if ($site.State -eq 'Started' -and (Test-Path -Path $physicalPath)) {
        if (Test-Path -Path $physicalPath\$nlbAppData) {
            $isOnline = $True
        }

        if ($isOnline -and $isOnlineServerLevel) {
            # $siteStatusColor = 'Green'
            $nlbStatus = 1
        }

        $webBindings = (Get-WebBinding -Name $siteName | Select-Object -First 1) -split ':'

        if (Test-Path -Path "$physicalPath\App_Data\build_info.json") {
            $buildVersionFile = "build_info.json"
            $buildVersionFilePath = "$physicalPath\App_Data\$buildVersionFile"
            $json = (Get-Content $buildVersionFilePath | ConvertFrom-Json)
            $fileVersion = $json.build_version
        }
        else {
            $buildVersionFiles = Get-ChildItem -Path "$targetPath" | Where-Object {$_.Extension -eq '.dll' -or $_.Extension -eq '.exe'} | Sort-Object LastWriteTime -Descending | Select-Object -First 10
            $fileVersion = ''

            $buildVersionFiles | ForEach-Object {
                $targetBuildVersionFilePath = "${targetPath}\$_"
                # Write-Host "... buildVersionFilePath: ${targetBuildVersionFilePath}"

                if ([string]::IsNullOrEmpty($fileVersion)) {
                    $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($targetBuildVersionFilePath).FileVersion
                    $buildVersionFile = $_
                    $buildVersionFilePath = "${targetPath}\${buildVersionFile}"
                    #Write-Host ">>> ${fileVersion} (${buildVersionFilePath})"
                }
            }

            if ([string]::IsNullOrEmpty($fileVersion)) {
                $buildVersionFile = Get-ChildItem -Path $targetPath | Where-Object {$_.Name -eq 'Version.txt'} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                $buildVersionFilePath = "${targetPath}\${buildVersionFile}"
                $fileVersion = Get-Content $buildVersionFilePath
                #Write-Host ">>> ${fileVersion} (${buildVersionFilePath})"
            }
        }

        if ($fileVersion) {
            $object = Get-Item -Path $buildVersionFilePath
            $BuildLastWriteTime = $object.LastWriteTime

            $eventDate = Get-Date
            $eventText = "{0}: ServerGroup={12}, Datacenter={1}, Scaleset={7}, Hostname={2}, Farm={3}, {13}={4}, Port={9}, NLBStatus={5}, BuildVersion={6}, BuildVersionFile={8}, BuildLastWriteTime={10}, Path={11}" `
                -f $eventDate, $datacenterName, $env:COMPUTERNAME, $farmName, $siteName, $nlbStatus, $fileVersion, $scaleSetName, $buildVersionFile, $webBindings[1], $BuildLastWriteTime, $physicalpath, $serverGroup, $appType

            Write-Host $eventText
            Write-Host `r`n`n`r
        }
    }
}
