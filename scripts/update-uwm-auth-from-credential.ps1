Add-Type -AssemblyName System.Web

$sf = 'C:\Program Files\sf\bin\sf.cmd'
$targetOrg = 'my-org'

$credential = Get-Credential -Message 'Enter UWM/EASE Azure values. Username = Client ID. Password = new Secret Key.'
if ($null -eq $credential) {
    throw 'Credential prompt was cancelled.'
}

$clientId = $credential.UserName
$secretPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
try {
    $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPtr)
} finally {
    if ($secretPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPtr)
    }
}

if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
    throw 'Both Client ID and Secret Key are required.'
}

$deployRoot = Join-Path $env:TEMP ('uwm-auth-update-' + [Guid]::NewGuid().ToString('N'))
$metadataDir = Join-Path $deployRoot 'customMetadata'
New-Item -ItemType Directory -Path $metadataDir -Force | Out-Null

function New-AuthRecordXml {
    param(
        [Parameter(Mandatory=$true)][string]$Label,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret
    )

    $escapedClientId = [System.Web.HttpUtility]::HtmlEncode($ClientId)
    $escapedClientSecret = [System.Web.HttpUtility]::HtmlEncode($ClientSecret)
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>$Label</label>
    <protected>false</protected>
    <values>
        <field>ClientSecret__c</field>
        <value xsi:type="xsd:string">$escapedClientId</value>
    </values>
    <values>
        <field>AuthProviderName__c</field>
        <value xsi:type="xsd:string">$escapedClientSecret</value>
    </values>
</CustomMetadata>
"@
}

$records = @('UWM_ConditionsAuth', 'UWM_InsightsOAuth')
foreach ($record in $records) {
    $path = Join-Path $metadataDir ("UWM_InsightsAuthSettings.$record.md-meta.xml")
    New-AuthRecordXml -Label $record -ClientId $clientId -ClientSecret $clientSecret | Set-Content -Path $path -Encoding UTF8
}

try {
    $deployJson = & $sf project deploy start --target-org $targetOrg --source-dir $metadataDir --wait 10 --json
    $deploy = $deployJson | ConvertFrom-Json
    if ($deploy.status -ne 0 -or -not $deploy.result.success) {
        throw ($deployJson | Out-String)
    }

    $verifyJson = & $sf data query --target-org $targetOrg --query "SELECT DeveloperName, ClientSecret__c, AuthProviderName__c FROM UWM_InsightsAuthSettings__mdt WHERE DeveloperName IN ('UWM_InsightsOAuth','UWM_ConditionsAuth')" --json
    $verify = $verifyJson | ConvertFrom-Json
    $bad = @()
    foreach ($record in $verify.result.records) {
        if ($record.ClientSecret__c -ne $clientId -or $record.AuthProviderName__c -ne $clientSecret) {
            $bad += $record.DeveloperName
        }
    }
    if ($bad.Count -gt 0) {
        throw ('Post-deploy verification failed for: ' + ($bad -join ', '))
    }

    [PSCustomObject]@{
        success = $true
        updatedRecords = $records
        clientIdLength = $clientId.Length
        secretLength = $clientSecret.Length
        deployId = $deploy.result.id
    } | ConvertTo-Json
} finally {
    $clientSecret = $null
    $clientId = $null
    if (Test-Path $deployRoot) {
        Remove-Item -LiteralPath $deployRoot -Recurse -Force
    }
}
