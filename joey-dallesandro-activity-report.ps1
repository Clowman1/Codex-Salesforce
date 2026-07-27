$ErrorActionPreference = "Stop"
$env:SF_AUTOUPDATE_DISABLE = "true"
$env:SFDX_AUTOUPDATE_DISABLE = "true"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$org = "my-org"
$runStarted = Get-Date

function Invoke-SfQuery {
    param(
        [string] $Query,
        [switch] $AllRows
    )

    $compactQuery = ($Query -replace "\s+", " ").Trim()
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($AllRows) {
            $raw = & $sf data query --target-org $org --query $compactQuery --all-rows --json 2>&1
        } else {
            $raw = & $sf data query --target-org $org --query $compactQuery --json 2>&1
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    $text = ($raw | ForEach-Object { "$_" } | Out-String).Trim()
    $jsonStart = $text.IndexOf("{")
    if ($jsonStart -gt 0) {
        $text = $text.Substring($jsonStart)
    }
    if ($exitCode -ne 0) {
        throw "Salesforce query failed with exit code $exitCode. $text"
    }
    $parsed = $text | ConvertFrom-Json
    if ($parsed.status -ne 0) {
        throw "Salesforce query failed: $($parsed.message)"
    }
    return @($parsed.result.records)
}

function Strip-Attributes {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [array]) {
        return @($Value | ForEach-Object { Strip-Attributes $_ })
    }
    if ($Value -is [pscustomobject]) {
        $out = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) {
            if ($prop.Name -eq "attributes") { continue }
            $out[$prop.Name] = Strip-Attributes $prop.Value
        }
        return [pscustomobject]$out
    }
    return $Value
}

function Quote-Ids {
    param([string[]] $Ids)
    if ($Ids.Count -eq 0) { return "''" }
    return (($Ids | Sort-Object -Unique | ForEach-Object { "'$_'" }) -join ",")
}

$personFilter = @"
(
  (Name LIKE '%Joey%' OR Name LIKE '%Joseph%')
  AND
  (Name LIKE '%Allesandro%' OR Name LIKE '%Alessandro%')
)
"@

$leads = Invoke-SfQuery @"
SELECT Id, Name, FirstName, LastName, Company, Email, Phone, MobilePhone, Status,
ConvertedAccountId, ConvertedContactId, CreatedDate, LastModifiedDate, Owner.Name
FROM Lead
WHERE $personFilter
ORDER BY CreatedDate DESC
"@

$accounts = Invoke-SfQuery @"
SELECT Id, Name, IsPersonAccount, PersonContactId, PersonEmail, Phone, CreatedDate,
LastModifiedDate, Owner.Name
FROM Account
WHERE $personFilter
ORDER BY CreatedDate DESC
"@

$transactions = Invoke-SfQuery @"
SELECT Id, Name, Status__c, Loan_Number__c, Borrower_Name__c, Borrower_Name__r.Name,
Account__c, Account__r.Name, CreatedDate, LastModifiedDate, Owner.Name
FROM Transaction__c
WHERE $personFilter
OR Borrower_Name__r.Name LIKE '%Allesandro%'
OR Borrower_Name__r.Name LIKE '%Alessandro%'
OR Account__r.Name LIKE '%Allesandro%'
OR Account__r.Name LIKE '%Alessandro%'
ORDER BY CreatedDate DESC
"@

$recordIds = [System.Collections.Generic.List[string]]::new()
$leadIds = @($leads | ForEach-Object { $_.Id })
$accountIds = @($accounts | ForEach-Object { $_.Id })
$contactIds = @($accounts | Where-Object { $_.PersonContactId } | ForEach-Object { $_.PersonContactId })
$transactionIds = @($transactions | ForEach-Object { $_.Id })
@($leadIds + $accountIds + $contactIds + $transactionIds) | ForEach-Object {
    if ($_ -and -not $recordIds.Contains($_)) { $recordIds.Add($_) | Out-Null }
}

$tasks = @()
$events = @()
if ($recordIds.Count -gt 0) {
    $idList = Quote-Ids @($recordIds)
    $tasks = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, Status, Priority, Type, Description,
CallDisposition, CreatedDate, LastModifiedDate, CompletedDateTime, IsClosed,
IsDeleted, Owner.Name, CreatedBy.Name, LastModifiedBy.Name, WhoId, Who.Name,
WhatId, What.Name, AccountId, Account.Name
FROM Task
WHERE WhoId IN ($idList)
OR WhatId IN ($idList)
OR AccountId IN ($idList)
ORDER BY CreatedDate DESC
"@ -AllRows

    $events = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime, Type, Description,
Location, CreatedDate, LastModifiedDate, IsDeleted, Owner.Name, CreatedBy.Name,
LastModifiedBy.Name, WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Event
WHERE WhoId IN ($idList)
OR WhatId IN ($idList)
OR AccountId IN ($idList)
ORDER BY CreatedDate DESC
"@ -AllRows
}

[pscustomobject]@{
    RunStartedLocal = $runStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")
    SearchTerms = "Joey/Joseph + Allesandro/Alessandro"
    MatchedLeads = Strip-Attributes $leads
    MatchedAccounts = Strip-Attributes $accounts
    MatchedTransactions = Strip-Attributes $transactions
    SearchedActivityRecordIds = @($recordIds)
    TaskCount = $tasks.Count
    EventCount = $events.Count
    Tasks = Strip-Attributes $tasks
    Events = Strip-Attributes $events
} | ConvertTo-Json -Depth 10
