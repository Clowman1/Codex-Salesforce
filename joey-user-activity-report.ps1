$ErrorActionPreference = "Stop"
$env:SF_AUTOUPDATE_DISABLE = "true"
$env:SFDX_AUTOUPDATE_DISABLE = "true"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$org = "my-org"
$userId = "005Qi000007nP2rIAE"
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
    if ($jsonStart -gt 0) { $text = $text.Substring($jsonStart) }
    if ($exitCode -ne 0) { throw "Salesforce query failed with exit code $exitCode. $text" }

    $parsed = $text | ConvertFrom-Json
    if ($parsed.status -ne 0) { throw "Salesforce query failed: $($parsed.message)" }
    return @($parsed.result.records)
}

function Related-Scope {
    param($Record)

    $scopes = [System.Collections.Generic.List[string]]::new()
    if ("$($Record.WhoId)" -like "00Q*") { $scopes.Add("Lead") | Out-Null }
    if ("$($Record.WhatId)" -like "001*" -or "$($Record.AccountId)" -like "001*") { $scopes.Add("Account") | Out-Null }
    if ("$($Record.WhatId)" -like "a01*") { $scopes.Add("Transaction") | Out-Null }
    return @($scopes | Sort-Object -Unique)
}

function Activity-Row {
    param(
        [string] $Kind,
        $Record
    )

    $scopes = @(Related-Scope $Record)
    if ($scopes.Count -eq 0) { return $null }

    [pscustomobject]@{
        Kind = $Kind
        Scope = ($scopes -join ", ")
        Id = $Record.Id
        Subject = $Record.Subject
        ActivityDate = $Record.ActivityDate
        StartDateTime = $Record.StartDateTime
        EndDateTime = $Record.EndDateTime
        Status = $Record.Status
        Type = $Record.Type
        Description = $Record.Description
        CreatedDate = $Record.CreatedDate
        LastModifiedDate = $Record.LastModifiedDate
        Owner = $Record.Owner.Name
        CreatedBy = $Record.CreatedBy.Name
        LastModifiedBy = $Record.LastModifiedBy.Name
        WhoId = $Record.WhoId
        WhoName = $Record.Who.Name
        WhatId = $Record.WhatId
        WhatName = $Record.What.Name
        AccountId = $Record.AccountId
        AccountName = $Record.Account.Name
        IsDeleted = $Record.IsDeleted
    }
}

$user = Invoke-SfQuery @"
SELECT Id, Name, Username, IsActive
FROM User
WHERE Id = '$userId'
"@

$tasks = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, Status, Priority, Type, Description, CallDisposition,
CreatedDate, LastModifiedDate, CompletedDateTime, IsClosed, IsDeleted,
OwnerId, Owner.Name, CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Task
WHERE CreatedById = '$userId'
OR OwnerId = '$userId'
ORDER BY CreatedDate DESC
"@ -AllRows

$events = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime, Type, Description, Location,
CreatedDate, LastModifiedDate, IsDeleted,
OwnerId, Owner.Name, CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Event
WHERE CreatedById = '$userId'
OR OwnerId = '$userId'
ORDER BY CreatedDate DESC
"@ -AllRows

$activity = [System.Collections.Generic.List[object]]::new()
foreach ($task in $tasks) {
    $row = Activity-Row "Task" $task
    if ($null -ne $row) { $activity.Add($row) | Out-Null }
}
foreach ($event in $events) {
    $row = Activity-Row "Event" $event
    if ($null -ne $row) { $activity.Add($row) | Out-Null }
}

$activity = @($activity | Sort-Object @{ Expression = { if ($_.CreatedDate) { $_.CreatedDate } else { "" } }; Descending = $true })
$counts = $activity | Group-Object Scope, Kind | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Group = $_.Name; Count = $_.Count }
}

$outputDir = "C:\Users\ChristopherLowman\Documents\New project"
$csvPath = Join-Path $outputDir "joey-user-activity-all.csv"
$jsonPath = Join-Path $outputDir "joey-user-activity-all.json"

$activity | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$fullReport = [pscustomobject]@{
    RunStartedLocal = $runStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")
    User = $user
    QueriedRule = "Task/Event where CreatedById or OwnerId equals $userId; related to Lead, Account, or Transaction by WhoId, WhatId, or AccountId"
    RawTaskCountForUser = $tasks.Count
    RawEventCountForUser = $events.Count
    RelevantActivityCount = $activity.Count
    Counts = @($counts)
    Activity = @($activity)
}
$fullReport | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8

[pscustomobject]@{
    RunStartedLocal = $fullReport.RunStartedLocal
    UserName = $user[0].Name
    UserId = $user[0].Id
    RawTaskCountForUser = $tasks.Count
    RawEventCountForUser = $events.Count
    RelevantActivityCount = $activity.Count
    Counts = @($counts)
    CsvPath = $csvPath
    JsonPath = $jsonPath
    NewestFive = @($activity | Select-Object -First 5)
} | ConvertTo-Json -Depth 6
