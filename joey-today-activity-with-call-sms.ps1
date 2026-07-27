$ErrorActionPreference = "Stop"
$env:SF_AUTOUPDATE_DISABLE = "true"
$env:SFDX_AUTOUPDATE_DISABLE = "true"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$org = "my-org"
$userId = "005Qi000007nP2rIAE"
$outputDir = "C:\Users\ChristopherLowman\Documents\New project"
$csvPath = Join-Path $outputDir "joey-today-activity-with-call-sms.csv"
$jsonPath = Join-Path $outputDir "joey-today-activity-with-call-sms.json"

function Invoke-SfQuery {
    param([string] $Query, [switch] $AllRows)

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

function Quote-Ids {
    param([string[]] $Ids)
    return (($Ids | Where-Object { $_ } | Sort-Object -Unique | ForEach-Object { "'$_'" }) -join ",")
}

function To-Eastern {
    param($DateValue)
    if (-not $DateValue) { return $null }
    $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
    return [System.TimeZoneInfo]::ConvertTime([datetimeoffset]::Parse("$DateValue"), $tz).ToString("yyyy-MM-dd h:mm:ss tt")
}

function Scope-For {
    param($Record)
    $scopes = [System.Collections.Generic.List[string]]::new()
    if ("$($Record.WhoId)" -like "00Q*") { $scopes.Add("Lead") | Out-Null }
    if ("$($Record.WhoId)" -like "003*" -or "$($Record.WhatId)" -like "001*" -or "$($Record.AccountId)" -like "001*") { $scopes.Add("Account") | Out-Null }
    if ("$($Record.WhatId)" -like "a01*") { $scopes.Add("Transaction") | Out-Null }
    if ("$($Record.WhatId)" -like "006*") { $scopes.Add("Opportunity") | Out-Null }
    return (@($scopes | Sort-Object -Unique) -join ", ")
}

function Task-Channel {
    param($Task)
    $subject = "$($Task.Subject)"
    if ($subject -match "SMS|texted|Sent SMS|Message") { return "SMS" }
    if ($Task.Type -eq "Call" -or $subject -match "Called|^Call\\b|Call -") { return "Call" }
    return "Salesforce Activity"
}

$tasks = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, Status, Priority, Type, Description, CallDisposition,
CreatedDate, LastModifiedDate, CompletedDateTime, IsClosed, IsDeleted,
OwnerId, Owner.Name, CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Task
WHERE (CreatedById = '$userId' OR OwnerId = '$userId')
AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
"@ -AllRows

$events = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime, Type, Description, Location,
CreatedDate, LastModifiedDate, IsDeleted,
OwnerId, Owner.Name, CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Event
WHERE (CreatedById = '$userId' OR OwnerId = '$userId')
AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
"@ -AllRows

$taskIds = Quote-Ids @($tasks | ForEach-Object { $_.Id })
$callLogs = @()
if ($taskIds) {
    $callLogs = Invoke-SfQuery @"
SELECT Id, Name, CreatedDate, LastModifiedDate, OwnerId, CreatedById,
Call_DateTime__c, Account__c, Account__r.Name, Lead__c, Lead__r.Name,
Created_From_Task_ID__c, Direction__c
FROM Call_Log__c
WHERE CreatedDate = TODAY
AND (OwnerId = '$userId' OR CreatedById = '$userId' OR Created_From_Task_ID__c IN ($taskIds))
ORDER BY Call_DateTime__c DESC
"@ -AllRows
}

$callInsights = Invoke-SfQuery @"
SELECT Id, Name, CreatedDate, LastModifiedDate, OwnerId, CreatedById, Lead__c, Lead__r.Name,
Account__c, Account__r.Name, Transaction__c, Transaction__r.Name, Salesforce_User__c,
Recording_Start_DateTime__c, Direction__c, Title__c, Duration__c, Summary__c,
Recipient_Phone_Number__c, AI_Score__c
FROM Call_Insight__c
WHERE (Salesforce_User__c = '$userId' OR OwnerId = '$userId' OR CreatedById = '$userId')
AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
"@ -AllRows

$smsHistory = Invoke-SfQuery @"
SELECT FIELDS(ALL)
FROM smagicinteract__smsMagic__c
WHERE (smagicinteract__User__c = '$userId' OR OwnerId = '$userId' OR CreatedById = '$userId')
AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
LIMIT 200
"@

$rows = [System.Collections.Generic.List[object]]::new()

foreach ($task in $tasks) {
    $rows.Add([pscustomobject]@{
        Source = "Task"
        Channel = Task-Channel $task
        Scope = Scope-For $task
        Id = $task.Id
        Subject = $task.Subject
        ActivityDate = $task.ActivityDate
        ActivityDateTimeET = To-Eastern $task.CreatedDate
        CreatedDate = $task.CreatedDate
        Status = $task.Status
        Type = $task.Type
        Direction = $null
        RelatedName = if ($task.Who.Name) { $task.Who.Name } elseif ($task.What.Name) { $task.What.Name } else { $task.Account.Name }
        WhoName = $task.Who.Name
        WhatName = $task.What.Name
        AccountName = $task.Account.Name
        Owner = $task.Owner.Name
        CreatedBy = $task.CreatedBy.Name
        Description = $task.Description
    }) | Out-Null
}

foreach ($event in $events) {
    $rows.Add([pscustomobject]@{
        Source = "Event"
        Channel = "Salesforce Event"
        Scope = Scope-For $event
        Id = $event.Id
        Subject = $event.Subject
        ActivityDate = $event.ActivityDate
        ActivityDateTimeET = To-Eastern $event.StartDateTime
        CreatedDate = $event.CreatedDate
        Status = $null
        Type = $event.Type
        Direction = $null
        RelatedName = if ($event.Who.Name) { $event.Who.Name } elseif ($event.What.Name) { $event.What.Name } else { $event.Account.Name }
        WhoName = $event.Who.Name
        WhatName = $event.What.Name
        AccountName = $event.Account.Name
        Owner = $event.Owner.Name
        CreatedBy = $event.CreatedBy.Name
        Description = $event.Description
    }) | Out-Null
}

foreach ($callLog in $callLogs) {
    $rows.Add([pscustomobject]@{
        Source = "Call_Log__c"
        Channel = "RingCentral Call Log"
        Scope = if ($callLog.Lead__c) { "Lead" } elseif ($callLog.Account__c) { "Account" } else { "" }
        Id = $callLog.Id
        Subject = $callLog.Name
        ActivityDate = $null
        ActivityDateTimeET = To-Eastern $callLog.Call_DateTime__c
        CreatedDate = $callLog.CreatedDate
        Status = $null
        Type = "Call"
        Direction = $callLog.Direction__c
        RelatedName = if ($callLog.Lead__r.Name) { $callLog.Lead__r.Name } else { $callLog.Account__r.Name }
        WhoName = $callLog.Lead__r.Name
        WhatName = $null
        AccountName = $callLog.Account__r.Name
        Owner = $callLog.OwnerId
        CreatedBy = $callLog.CreatedById
        Description = "Created from Task $($callLog.Created_From_Task_ID__c)"
    }) | Out-Null
}

foreach ($insight in $callInsights) {
    $rows.Add([pscustomobject]@{
        Source = "Call_Insight__c"
        Channel = "RingCentral Call Insight"
        Scope = if ($insight.Transaction__c) { "Transaction" } elseif ($insight.Account__c) { "Account" } elseif ($insight.Lead__c) { "Lead" } else { "" }
        Id = $insight.Id
        Subject = $insight.Title__c
        ActivityDate = $null
        ActivityDateTimeET = To-Eastern $insight.Recording_Start_DateTime__c
        CreatedDate = $insight.CreatedDate
        Status = $null
        Type = "Call"
        Direction = $insight.Direction__c
        RelatedName = if ($insight.Lead__r.Name) { $insight.Lead__r.Name } elseif ($insight.Account__r.Name) { $insight.Account__r.Name } else { $insight.Transaction__r.Name }
        WhoName = $insight.Lead__r.Name
        WhatName = $insight.Transaction__r.Name
        AccountName = $insight.Account__r.Name
        Owner = $insight.Salesforce_User__c
        CreatedBy = $insight.CreatedById
        Description = $insight.Summary__c
    }) | Out-Null
}

foreach ($sms in $smsHistory) {
    $rows.Add([pscustomobject]@{
        Source = "smagicinteract__smsMagic__c"
        Channel = "SMS History"
        Scope = if ($sms.Transaction__c) { "Transaction" } else { "" }
        Id = $sms.Id
        Subject = $sms.Name
        ActivityDate = $null
        ActivityDateTimeET = To-Eastern $sms.CreatedDate
        CreatedDate = $sms.CreatedDate
        Status = $sms.smagicinteract__sentStatus__c
        Type = "SMS"
        Direction = $null
        RelatedName = $null
        WhoName = $null
        WhatName = $sms.Transaction__c
        AccountName = $null
        Owner = $sms.OwnerId
        CreatedBy = $sms.CreatedById
        Description = $sms.smagicinteract__SMSText__c
    }) | Out-Null
}

$sorted = @($rows | Sort-Object @{ Expression = {
    if ($_.ActivityDateTimeET) {
        [datetime]::Parse($_.ActivityDateTimeET)
    } elseif ($_.CreatedDate) {
        [datetimeoffset]::Parse($_.CreatedDate).DateTime
    } else {
        [datetime]::MinValue
    }
}; Descending = $true })

$deduped = @($sorted | Sort-Object Source, Id -Unique)
$deduped | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$lastCall = @($deduped | Where-Object { $_.Channel -match "Call" } | Sort-Object @{ Expression = { if ($_.ActivityDateTimeET) { [datetime]::Parse($_.ActivityDateTimeET) } else { [datetimeoffset]::Parse($_.CreatedDate).DateTime } }; Descending = $true } | Select-Object -First 1)
$lastSms = @($deduped | Where-Object { $_.Channel -match "SMS" } | Sort-Object @{ Expression = { if ($_.ActivityDateTimeET) { [datetime]::Parse($_.ActivityDateTimeET) } else { [datetimeoffset]::Parse($_.CreatedDate).DateTime } }; Descending = $true } | Select-Object -First 1)

$report = [pscustomobject]@{
    RunStartedLocal = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
    UserId = $userId
    TotalRows = $deduped.Count
    Counts = @($deduped | Group-Object Channel | Sort-Object Name | ForEach-Object { [pscustomobject]@{ Channel = $_.Name; Count = $_.Count } })
    LastCall = if ($lastCall.Count) { $lastCall[0] } else { $null }
    LastSms = if ($lastSms.Count) { $lastSms[0] } else { $null }
    CsvPath = $csvPath
    JsonPath = $jsonPath
    Activity = @($deduped)
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8
$report | Select-Object RunStartedLocal, UserId, TotalRows, Counts, LastCall, LastSms, CsvPath, JsonPath | ConvertTo-Json -Depth 6
