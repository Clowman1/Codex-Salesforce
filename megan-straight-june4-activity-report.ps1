$ErrorActionPreference = "Stop"
$env:SF_AUTOUPDATE_DISABLE = "true"
$env:SFDX_AUTOUPDATE_DISABLE = "true"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$org = "my-org"
$outputDir = "C:\Users\ChristopherLowman\Documents\New project"
$csvPath = Join-Path $outputDir "megan-straight-june4-from-1pm-activity.csv"
$jsonPath = Join-Path $outputDir "megan-straight-june4-from-1pm-activity.json"

$userId = "0055x00000BWkSBAA1"
$accountId = "001Qi00000R1UhYIAV"
$contactId = "003Qi00000SmR2uIAF"
$windowStartUtc = "2026-06-04T17:00:00Z"
$windowEndUtc = "2026-06-05T04:00:00Z"
$reportTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")

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

function To-Eastern {
    param($DateValue)
    if (-not $DateValue) { return $null }
    return [System.TimeZoneInfo]::ConvertTime([datetimeoffset]::Parse("$DateValue"), $reportTimeZone).ToString("yyyy-MM-dd h:mm:ss tt")
}

function Strip-Attributes {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [array]) { return @($Value | ForEach-Object { Strip-Attributes $_ }) }
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

function Join-Values {
    param([object[]] $Values)
    return (($Values | Where-Object { $null -ne $_ -and "$_".Trim().Length -gt 0 }) -join " | ")
}

function Add-Row {
    param(
        [System.Collections.Generic.List[object]] $Rows,
        [string] $Source,
        [string] $When,
        [string] $Title,
        [string] $Related,
        [string] $Actor,
        [string] $Status,
        [string] $Direction,
        [string] $Details,
        [string] $Id
    )

    $Rows.Add([pscustomobject]@{
        TimeET = To-Eastern $When
        TimeRaw = $When
        Source = $Source
        Title = $Title
        Related = $Related
        Actor = $Actor
        Status = $Status
        Direction = $Direction
        Details = $Details
        Id = $Id
    }) | Out-Null
}

$tasksByUser = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, Status, Priority, Type, Description, CallDisposition,
CreatedDate, LastModifiedDate, CompletedDateTime, IsClosed,
OwnerId, Owner.Name, CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Task
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (CreatedById = '$userId' OR OwnerId = '$userId' OR LastModifiedById = '$userId')
ORDER BY CreatedDate ASC
"@ -AllRows

$tasksOnRecord = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, Status, Priority, Type, Description, CallDisposition,
CreatedDate, LastModifiedDate, CompletedDateTime, IsClosed,
OwnerId, Owner.Name, CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Task
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (WhoId IN ('$contactId','$accountId') OR WhatId = '$accountId' OR AccountId = '$accountId')
ORDER BY CreatedDate ASC
"@ -AllRows

$eventsByUser = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime, Type, Description, Location,
CreatedDate, LastModifiedDate, OwnerId, Owner.Name, CreatedById, CreatedBy.Name,
LastModifiedById, LastModifiedBy.Name, WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Event
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (CreatedById = '$userId' OR OwnerId = '$userId' OR LastModifiedById = '$userId')
ORDER BY CreatedDate ASC
"@ -AllRows

$eventsOnRecord = Invoke-SfQuery @"
SELECT Id, Subject, ActivityDate, StartDateTime, EndDateTime, Type, Description, Location,
CreatedDate, LastModifiedDate, OwnerId, Owner.Name, CreatedById, CreatedBy.Name,
LastModifiedById, LastModifiedBy.Name, WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name
FROM Event
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (WhoId IN ('$contactId','$accountId') OR WhatId = '$accountId' OR AccountId = '$accountId')
ORDER BY CreatedDate ASC
"@ -AllRows

$callLogs = Invoke-SfQuery @"
SELECT Id, Name, CreatedDate, LastModifiedDate, OwnerId, Owner.Name, CreatedById, CreatedBy.Name,
Call_DateTime__c, Account__c, Account__r.Name, Lead__c, Lead__r.Name,
Created_From_Task_ID__c, Direction__c
FROM Call_Log__c
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (OwnerId = '$userId' OR CreatedById = '$userId' OR Account__c = '$accountId')
ORDER BY CreatedDate ASC
"@ -AllRows

$callInsights = Invoke-SfQuery @"
SELECT Id, Name, CreatedDate, LastModifiedDate, OwnerId, Owner.Name, CreatedById, CreatedBy.Name,
Lead__c, Lead__r.Name, Account__c, Account__r.Name, Transaction__c, Transaction__r.Name,
Salesforce_User__c, Salesforce_User__r.Name, Recording_Start_DateTime__c, Direction__c,
Title__c, Duration__c, Summary__c, Recipient_Phone_Number__c, AI_Score__c
FROM Call_Insight__c
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (Salesforce_User__c = '$userId' OR OwnerId = '$userId' OR CreatedById = '$userId' OR Account__c = '$accountId')
ORDER BY CreatedDate ASC
"@ -AllRows

$smsHistory = Invoke-SfQuery @"
SELECT FIELDS(ALL)
FROM smagicinteract__smsMagic__c
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (smagicinteract__User__c = '$userId' OR OwnerId = '$userId' OR CreatedById = '$userId')
ORDER BY CreatedDate ASC
LIMIT 200
"@

$emailMessages = Invoke-SfQuery @"
SELECT Id, CreatedDate, LastModifiedDate, Subject, FromName, FromAddress, ToAddress,
Status, Incoming, RelatedToId, RelatedTo.Name, CreatedById, CreatedBy.Name, LastModifiedById,
LastModifiedBy.Name, TextBody
FROM EmailMessage
WHERE CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
AND (CreatedById = '$userId' OR LastModifiedById = '$userId' OR RelatedToId = '$accountId')
ORDER BY CreatedDate ASC
"@ -AllRows

$loginHistory = Invoke-SfQuery @"
SELECT Id, LoginTime, SourceIp, LoginType, Status, Application, Browser, Platform
FROM LoginHistory
WHERE UserId = '$userId'
AND LoginTime >= $windowStartUtc
AND LoginTime < $windowEndUtc
ORDER BY LoginTime ASC
"@ -AllRows

$setupAudit = Invoke-SfQuery @"
SELECT Id, CreatedDate, Action, Section, Display, CreatedById, CreatedBy.Name
FROM SetupAuditTrail
WHERE CreatedById = '$userId'
AND CreatedDate >= $windowStartUtc
AND CreatedDate < $windowEndUtc
ORDER BY CreatedDate ASC
"@ -AllRows

$rows = [System.Collections.Generic.List[object]]::new()

foreach ($task in @($tasksByUser + $tasksOnRecord | Sort-Object Id -Unique)) {
    $related = if ($task.Who.Name) { $task.Who.Name } elseif ($task.What.Name) { $task.What.Name } else { $task.Account.Name }
    Add-Row $rows "Task" $task.CreatedDate $task.Subject $related $task.CreatedBy.Name $task.Status $null $task.Description $task.Id
}

foreach ($event in @($eventsByUser + $eventsOnRecord | Sort-Object Id -Unique)) {
    $related = if ($event.Who.Name) { $event.Who.Name } elseif ($event.What.Name) { $event.What.Name } else { $event.Account.Name }
    $details = Join-Values @("Scheduled: $(To-Eastern $event.StartDateTime)", $event.Description, $event.Location)
    Add-Row $rows "Event" $event.CreatedDate $event.Subject $related $event.CreatedBy.Name $null $null $details $event.Id
}

foreach ($call in $callLogs) {
    $related = if ($call.Lead__r.Name) { $call.Lead__r.Name } else { $call.Account__r.Name }
    Add-Row $rows "Call_Log__c" $call.Call_DateTime__c $call.Name $related $call.CreatedBy.Name $null $call.Direction__c "Created from Task $($call.Created_From_Task_ID__c)" $call.Id
}

foreach ($insight in $callInsights) {
    $related = if ($insight.Lead__r.Name) { $insight.Lead__r.Name } elseif ($insight.Account__r.Name) { $insight.Account__r.Name } else { $insight.Transaction__r.Name }
    $details = Join-Values @("Duration: $($insight.Duration__c)", "Score: $($insight.AI_Score__c)", $insight.Summary__c)
    Add-Row $rows "Call_Insight__c" $insight.Recording_Start_DateTime__c $insight.Title__c $related $insight.Salesforce_User__r.Name $null $insight.Direction__c $details $insight.Id
}

foreach ($sms in $smsHistory) {
    Add-Row $rows "SMS Magic" $sms.CreatedDate $sms.Name $sms.Transaction__c $sms.CreatedBy.Name $sms.smagicinteract__sentStatus__c $null $sms.smagicinteract__SMSText__c $sms.Id
}

foreach ($email in $emailMessages) {
    $details = Join-Values @("From: $($email.FromName) <$($email.FromAddress)>", "To: $($email.ToAddress)", $email.TextBody)
    Add-Row $rows "EmailMessage" $email.CreatedDate $email.Subject $email.RelatedTo.Name $email.CreatedBy.Name $email.Status $(if ($email.Incoming) { "Incoming" } else { "Outgoing" }) $details $email.Id
}

foreach ($login in $loginHistory) {
    $details = Join-Values @($login.Application, $login.Browser, $login.Platform, $login.SourceIp)
    Add-Row $rows "LoginHistory" $login.LoginTime $login.LoginType $null "Megan Straight" $login.Status $null $details $login.Id
}

foreach ($audit in $setupAudit) {
    $details = Join-Values @($audit.Section, $audit.Display)
    Add-Row $rows "SetupAuditTrail" $audit.CreatedDate $audit.Action $null $audit.CreatedBy.Name $null $null $details $audit.Id
}

$sortedRows = @($rows | Sort-Object @{ Expression = { if ($_.TimeRaw) { [datetimeoffset]::Parse("$($_.TimeRaw)") } else { [datetimeoffset]::MinValue } } })
$sortedRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$report = [pscustomobject]@{
    RunStartedLocal = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
    Person = "Megan Straight"
    UserId = $userId
    AccountId = $accountId
    ContactId = $contactId
    WindowEastern = "2026-06-04 1:00 PM through 2026-06-04 11:59:59 PM"
    WindowUtc = "$windowStartUtc through $windowEndUtc"
    Counts = @($sortedRows | Group-Object Source | Sort-Object Name | ForEach-Object { [pscustomobject]@{ Source = $_.Name; Count = $_.Count } })
    TotalRows = $sortedRows.Count
    CsvPath = $csvPath
    JsonPath = $jsonPath
    Rows = @($sortedRows)
    Raw = [pscustomobject]@{
        TasksByUser = Strip-Attributes $tasksByUser
        TasksOnRecord = Strip-Attributes $tasksOnRecord
        EventsByUser = Strip-Attributes $eventsByUser
        EventsOnRecord = Strip-Attributes $eventsOnRecord
        CallLogs = Strip-Attributes $callLogs
        CallInsights = Strip-Attributes $callInsights
        SmsHistory = Strip-Attributes $smsHistory
        EmailMessages = Strip-Attributes $emailMessages
        LoginHistory = Strip-Attributes $loginHistory
        SetupAuditTrail = Strip-Attributes $setupAudit
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
$report | Select-Object RunStartedLocal, Person, UserId, AccountId, ContactId, WindowEastern, TotalRows, Counts, CsvPath, JsonPath | ConvertTo-Json -Depth 6
