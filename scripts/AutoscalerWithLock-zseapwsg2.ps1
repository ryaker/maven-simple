$ErrorActionPreference = "Stop"

Enum ScaleDisposition
{
    NoChange = 1
    ScaleIn = 2
    ScaleOut = 3
}

$startTime = Get-Date -Format "dd/MM/yyyy HH:mm:ss" 
Write-Host "StartTime: " $startTime -foregroundcolor "green"

function PostToSplunk {
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

    # Conversion of http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2Fexport 
    # example using curl, to PowerShell with Invoke-RestMethod cmdlet
    #
    # generic forwarder credential
    $secpasswd = ConvertTo-SecureString "hrbl@1234" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("tfsapi@herbalife.com", $secpasswd)

    #$secpasswd = ConvertTo-SecureString "B1968ronx" -AsPlainText -Force
    #$cred = New-Object System.Management.Automation.PSCredential ("richardya@herbalife.com", $secpasswd)

    if ( $cpu -gt $maxCpu -or $mem -gt $maxMem -or $con -gt $maxCon) {
        $shouldScaleOut = $true
    } else {
        $shouldScaleOut = $false
    }

    if ( $shouldScaleOut ) {
        return [ScaleDisposition]::ScaleOut
    }

    if ( $cpu -lt $minCpu ) {
        $shouldScaleIn=$true
    } else {
        $shouldScaleIn=$false 
    }
    $formattedMessage = "Autoscale Log: ScaleSet: $scaleSetName   CPUTime: $cpu  Memory: $mem CurrentConnections: $con ScaleIn: $shouldScaleIn ScaleOut: $shouldScaleOut"

    #Name of our splunk cloud instance
    $splunk_server = 'hrbl.splunkcloud.com'

    $url = "https://${splunk_server}:8089/services/receivers/simple?source=AutoScaleScript&sourcetype=Action&host=${env:computername}"
    $datetime = Get-Date -Format o
    $body = "${datetime}  {$formattedMessage}"

    Try {
        Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body
    }
    Catch {
        Write-Host  "Exception PostToSplunk " $_  -foregroundcolor "red"
    }
    finally { }
}

function getScaleSetCounterValue {
param( $scaleSetName, $counterName, $counterValue)

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

    # Conversion of http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2Fexport 
    # example using curl, to PowerShell with Invoke-RestMethod cmdlet
    #

    # generic forwarder credential
    $secpasswd = ConvertTo-SecureString "hrbl@1234" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("tfsapi@herbalife.com", $secpasswd)

    # This will allow for self-signed SSL certs to work
    #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    $server = 'hrbl.splunkcloud.com'
    $url = "https://${server}:8089/services/search/jobs/export" # braces needed b/c the colon is otherwise a scope operator

    if($counterName -ne "WMI:CPUTime")
    {
        $search = "search index=perfmon host={0}* AND host!={0}00 AND host!={0}00a source={1} | stats avg({2})" -f $scaleSetName, $counterName, $counterValue # Cmdlet handles urlencoding
    }
    else
    {
        $search = "search index=main host={0}* sourcetype=cpumetrics | eval CPU=CPU | stats avg(CPU)" -f $scaleSetName
    }


    $body = @{
        search = $search
        output_mode = "json"
        earliest_time = "-10m"
        latest_time = "-10s"
    }
    $response = Invoke-RestMethod -Method Post -Uri $url -Credential $cred -Body $body
    
    try {
        $result = $response.result
        
        $prop = Get-Member -InputObject $result -MemberType NoteProperty
        $propValue = $prop.Definition -split "="
    } catch 
    {
        write-host Error 
        return -1
    }

    return [Int64]$propValue[1]
}

function getScaleSetScaleActionDisposition {
param( $scaleSetName)

    #$maxCpu=15.0
    $maxCpu=55.0
    $maxMem=95.0
    $maxCon=500.0
    #$maxCon=25.0

    #$minCpu =9.0
    $minCpu =45.0
    $minMem =50.0
    $minCon =100.0
    #$minCon =15.0

    #write-host "`n`n`nEvalutating systems counters to determine if scale in or scale out required"

    $cpu = getScaleSetCounterValue -scaleSetName $scaleSetName -counterName "WMI:CPUTime" -counterValue "PercentProcessorTime"
    $mem = getScaleSetCounterValue -scaleSetName $scaleSetName -counterName "WMI:Memory" -counterValue "PercentCommittedBytesInUse"
    $con = getScaleSetCounterValue -scaleSetName $scaleSetName -counterName "WMI:ConcurrentConnections" -counterValue "CurrentConnections"

    if ( $cpu -eq -1 -or $mem -eq -1 -or $con -eq -1) {
        return [ScaleDisposition]::NoChange
    }

    write-host "actuals " $cpu $mem $con

    PostToSplunk

    $shouldScaleOut=$false
    $shouldScaleIn=$false

    if ( $cpu -gt $maxCpu -or $mem -gt $maxMem -or $con -gt $maxCon) {
        $shouldScaleOut = $true
    } else {
        $shouldScaleOut = $false
    }

    if ( $shouldScaleOut ) {
        return [ScaleDisposition]::ScaleOut
    }

    if ( $cpu -lt $minCpu ) {
        $shouldScaleIn=$true
    } else {
        $shouldScaleIn=$false 
    }

    if ( $shouldScaleIn ) {
        return [ScaleDisposition]::ScaleIn
    }

    if ( -not ($shouldScaleOut -or $shouldScaleIn ) ) {
        return [ScaleDisposition]::NoChange
    }
}

$count = 0

$scaleOutBlock = get-command "C:\rundeck\scripts\ScaleOutOneSAU - Reviewed.ps1" | select -ExpandProperty ScriptBlock 
$scaleInBlock = get-command "C:\rundeck\scripts\ScaleInOneSAU - Reviewed.ps1" | select -ExpandProperty ScriptBlock 

do {
    $scaleSetList = "zseapwsg2" #"zus2pwssg", "zus2pwssb", "zuswpwssg", "zuswpwssb", "zseapwsg2", "zseapwsb2", "zeuwpwsg2", "zeuwpwsb2"
    $disposition = [ScaleDisposition]::NoChange

    foreach ( $scaleSet in $scaleSetList )
    {
        $disposition = getScaleSetScaleActionDisposition -scaleSetName $scaleSet
        if ( $disposition -eq [ScaleDisposition]::ScaleIn ) {
            #audit -vmssname $scaleSet
            Invoke-Command -ScriptBlock $scaleInBlock -ArgumentList $scaleSet
        } 
        if ( $disposition -eq [ScaleDisposition]::ScaleOut ) {
            Invoke-Command -ScriptBlock $scaleOutBlock -ArgumentList $scaleSet,$true
            write-host -f Red $scaleSet ":" $disposition
        } 
        if ( $disposition -eq [ScaleDisposition]::NoChange ) {
            write-host -f Green $scaleSet ":" $disposition
        } 
        $disposition = [ScaleDisposition]::NoChange
        $count = $count + 1
    }

}while($count -lt $scaleSetList.Count)