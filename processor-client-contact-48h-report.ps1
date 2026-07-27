$ErrorActionPreference = "Stop"
$env:SF_AUTOUPDATE_DISABLE = "true"
$env:SFDX_AUTOUPDATE_DISABLE = "true"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$org = "my-org"
$outputDir = "C:\Users\ChristopherLowman\Documents\New project"
$csvPath = Join-Path $outputDir "processor-client-contact-48h.csv"
$jsonPath = Join-Path $outputDir "processor-client-contact-48h.json"
$runStarted = Get-Date
$thresholdUtc = $runStarted.ToUniversalTime().AddHours(-48)
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

function Has-Value {
    param($Value)
    return $null -ne $Value -and "$Value".Trim().Length -gt 0
}

function Parse-DateUtc {
    param($Value)
    if (-not (Has-Value $Value)) { return $null }
    return ([datetimeoffset]::Parse("$Value")).UtcDateTime
}

function To-Eastern {
    param($Value)
    $dt = Parse-DateUtc $Value
    if ($null -eq $dt) { return $null }
    return [System.TimeZoneInfo]::ConvertTimeFromUtc($dt, $reportTimeZone).ToString("yyyy-MM-dd h:mm tt")
}

function Quote-Ids {
    param([string[]] $Ids)
    $unique = @($Ids | Where-Object { Has-Value $_ } | Sort-Object -Unique)
    if ($unique.Count -eq 0) { return $null }
    return (($unique | ForEach-Object { "'$_'" }) -join ",")
}

function Split-List {
    param([object[]] $Items, [int] $Size = 100)
    for ($i = 0; $i -lt $Items.Count; $i += $Size) {
        ,@($Items[$i..([Math]::Min($i + $Size - 1, $Items.Count - 1))])
    }
}

function Add-Evidence {
    param(
        [hashtable] $EvidenceByTransaction,
        [string] $TransactionId,
        [string] $Source,
        [string] $Channel,
        $WhenUtc,
        [string] $ActorId,
        [string] $ActorName,
        [string] $Subject,
        [string] $RecordId
    )
    if (-not (Has-Value $TransactionId) -or $null -eq $WhenUtc) { return }
    $whenValue = [datetime]$WhenUtc
    if ($whenValue -lt $thresholdUtc) { return }
    if (-not $EvidenceByTransaction.ContainsKey($TransactionId)) {
        $EvidenceByTransaction[$TransactionId] = [System.Collections.Generic.List[object]]::new()
    }
    $EvidenceByTransaction[$TransactionId].Add([pscustomobject]@{
        Source = $Source
        Channel = $Channel
        WhenUtc = $whenValue
        WhenEastern = [System.TimeZoneInfo]::ConvertTimeFromUtc($whenValue, $reportTimeZone).ToString("yyyy-MM-dd h:mm tt")
        ActorId = $ActorId
        ActorName = $ActorName
        Subject = $Subject
        RecordId = $RecordId
    }) | Out-Null
}

function Task-Channel {
    param($Task)
    $subject = "$($Task.Subject)"
    if ($Task.Type -eq "Email" -or $subject -match "Email|E-mail") { return "Email" }
    if ($subject -match "SMS|texted|Sent SMS|Message") { return "SMS" }
    if ($Task.Type -eq "Call" -or $subject -match "Called|^Call\b|Call -") { return "Call" }
    return "Salesforce Activity"
}

$activeStatuses = @(
    "TRID Application", "Open", "Disclosures Out", "Pre-Processing", "Processing",
    "Submitted", "Suspended", "Waiting On Loan Officer", "Conditionally Approved",
    "Re-Submitted", "Approved", "Closing", "Funding", "PC Review"
)

$activeQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c,
Processor__c, Processor__r.Name, Processor__r.Email,
Borrower_Name__c, Borrower_Name__r.Name, Borrower_Name__r.PersonContactId,
Borrower_Email__c, Borr_Email__c, Borrowers_Phone__c,
Last_Processor_RC_Call__c, Last_Processor_RC_SMS__c
FROM Transaction__c
WHERE Status__c IN ('TRID Application','Open','Disclosures Out','Pre-Processing','Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$transactions = Invoke-SfQuery $activeQuery -AllRows

$txById = @{}
$accountToTx = @{}
$contactToTx = @{}
foreach ($tx in $transactions) {
    $txById[$tx.Id] = $tx
    if (Has-Value $tx.Borrower_Name__c) { $accountToTx[$tx.Borrower_Name__c] = $tx.Id }
    if ($null -ne $tx.Borrower_Name__r -and (Has-Value $tx.Borrower_Name__r.PersonContactId)) {
        $contactToTx[$tx.Borrower_Name__r.PersonContactId] = $tx.Id
    }
}

$evidenceByTx = @{}
foreach ($tx in $transactions) {
    Add-Evidence $evidenceByTx $tx.Id "Transaction__c" "RingCentral Call Rollup" (Parse-DateUtc $tx.Last_Processor_RC_Call__c) $tx.Processor__c $tx.Processor__r.Name "Last Processor RC Call" $tx.Id
    Add-Evidence $evidenceByTx $tx.Id "Transaction__c" "SMS Rollup" (Parse-DateUtc $tx.Last_Processor_RC_SMS__c) $tx.Processor__c $tx.Processor__r.Name "Last Processor RC SMS" $tx.Id
}

$txIds = @($transactions | ForEach-Object { $_.Id })
$accountIds = @($transactions | ForEach-Object { $_.Borrower_Name__c } | Where-Object { Has-Value $_ } | Sort-Object -Unique)
$contactIds = @($transactions | ForEach-Object { if ($_.Borrower_Name__r) { $_.Borrower_Name__r.PersonContactId } } | Where-Object { Has-Value $_ } | Sort-Object -Unique)

foreach ($chunk in (Split-List $txIds 75)) {
    $ids = Quote-Ids $chunk
    if (-not $ids) { continue }
    $tasks = Invoke-SfQuery @"
SELECT Id, Subject, Type, CreatedDate, CompletedDateTime, ActivityDate, OwnerId, Owner.Name, CreatedById, CreatedBy.Name,
WhoId, Who.Name, WhatId, What.Name, AccountId, Account.Name, Description
FROM Task
WHERE CreatedDate = LAST_N_DAYS:3
AND WhatId IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($task in $tasks) {
        $tx = $txById[$task.WhatId]
        if ($null -eq $tx -or ($task.OwnerId -ne $tx.Processor__c -and $task.CreatedById -ne $tx.Processor__c)) { continue }
        $when = Parse-DateUtc $(if (Has-Value $task.CompletedDateTime) { $task.CompletedDateTime } else { $task.CreatedDate })
        Add-Evidence $evidenceByTx $tx.Id "Task" (Task-Channel $task) $when $tx.Processor__c $tx.Processor__r.Name $task.Subject $task.Id
    }

    $emails = Invoke-SfQuery @"
SELECT Id, Subject, CreatedDate, MessageDate, FromAddress, ToAddress, Incoming, CreatedById, CreatedBy.Name, RelatedToId
FROM EmailMessage
WHERE CreatedDate = LAST_N_DAYS:3
AND RelatedToId IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($email in $emails) {
        $tx = $txById[$email.RelatedToId]
        if ($null -eq $tx) { continue }
        $fromProcessor = ($email.CreatedById -eq $tx.Processor__c) -or ((Has-Value $tx.Processor__r.Email) -and "$($email.FromAddress)".ToLower().Contains("$($tx.Processor__r.Email)".ToLower()))
        if (-not $fromProcessor -or $email.Incoming -eq $true) { continue }
        $when = Parse-DateUtc $(if (Has-Value $email.MessageDate) { $email.MessageDate } else { $email.CreatedDate })
        Add-Evidence $evidenceByTx $tx.Id "EmailMessage" "Email" $when $tx.Processor__c $tx.Processor__r.Name $email.Subject $email.Id
    }

    $callInsights = Invoke-SfQuery @"
SELECT Id, Title__c, CreatedDate, Recording_Start_DateTime__c, Transaction__c, Salesforce_User__c, Direction__c, Summary__c
FROM Call_Insight__c
WHERE CreatedDate = LAST_N_DAYS:3
AND Transaction__c IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($call in $callInsights) {
        $tx = $txById[$call.Transaction__c]
        if ($null -eq $tx -or $call.Salesforce_User__c -ne $tx.Processor__c) { continue }
        $when = Parse-DateUtc $(if (Has-Value $call.Recording_Start_DateTime__c) { $call.Recording_Start_DateTime__c } else { $call.CreatedDate })
        Add-Evidence $evidenceByTx $tx.Id "Call_Insight__c" "RingCentral Call" $when $tx.Processor__c $tx.Processor__r.Name $call.Title__c $call.Id
    }

    $sms = Invoke-SfQuery @"
SELECT Id, Name, CreatedDate, OwnerId, CreatedById, smagicinteract__User__c, Transaction__c, smagicinteract__sentStatus__c
FROM smagicinteract__smsMagic__c
WHERE CreatedDate = LAST_N_DAYS:3
AND Transaction__c IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($message in $sms) {
        $tx = $txById[$message.Transaction__c]
        if ($null -eq $tx -or ($message.smagicinteract__User__c -ne $tx.Processor__c -and $message.OwnerId -ne $tx.Processor__c -and $message.CreatedById -ne $tx.Processor__c)) { continue }
        Add-Evidence $evidenceByTx $tx.Id "smagicinteract__smsMagic__c" "SMS" (Parse-DateUtc $message.CreatedDate) $tx.Processor__c $tx.Processor__r.Name $message.Name $message.Id
    }
}

foreach ($chunk in (Split-List $accountIds 75)) {
    $ids = Quote-Ids $chunk
    if (-not $ids) { continue }
    $tasks = Invoke-SfQuery @"
SELECT Id, Subject, Type, CreatedDate, CompletedDateTime, OwnerId, Owner.Name, CreatedById, CreatedBy.Name, WhoId, WhatId, AccountId
FROM Task
WHERE CreatedDate = LAST_N_DAYS:3
AND AccountId IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($task in $tasks) {
        $txId = $accountToTx[$task.AccountId]
        $tx = $txById[$txId]
        if ($null -eq $tx -or ($task.OwnerId -ne $tx.Processor__c -and $task.CreatedById -ne $tx.Processor__c)) { continue }
        $when = Parse-DateUtc $(if (Has-Value $task.CompletedDateTime) { $task.CompletedDateTime } else { $task.CreatedDate })
        Add-Evidence $evidenceByTx $tx.Id "Task" (Task-Channel $task) $when $tx.Processor__c $tx.Processor__r.Name $task.Subject $task.Id
    }

    $callLogs = Invoke-SfQuery @"
SELECT Id, Name, CreatedDate, Call_DateTime__c, Account__c, OwnerId, CreatedById, Direction__c
FROM Call_Log__c
WHERE CreatedDate = LAST_N_DAYS:3
AND Account__c IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($call in $callLogs) {
        $txId = $accountToTx[$call.Account__c]
        $tx = $txById[$txId]
        if ($null -eq $tx -or ($call.OwnerId -ne $tx.Processor__c -and $call.CreatedById -ne $tx.Processor__c)) { continue }
        $when = Parse-DateUtc $(if (Has-Value $call.Call_DateTime__c) { $call.Call_DateTime__c } else { $call.CreatedDate })
        Add-Evidence $evidenceByTx $tx.Id "Call_Log__c" "RingCentral Call Log" $when $tx.Processor__c $tx.Processor__r.Name $call.Name $call.Id
    }
}

foreach ($chunk in (Split-List $contactIds 75)) {
    $ids = Quote-Ids $chunk
    if (-not $ids) { continue }
    $tasks = Invoke-SfQuery @"
SELECT Id, Subject, Type, CreatedDate, CompletedDateTime, OwnerId, Owner.Name, CreatedById, CreatedBy.Name, WhoId, WhatId, AccountId
FROM Task
WHERE CreatedDate = LAST_N_DAYS:3
AND WhoId IN ($ids)
ORDER BY CreatedDate DESC
"@ -AllRows
    foreach ($task in $tasks) {
        $txId = $contactToTx[$task.WhoId]
        $tx = $txById[$txId]
        if ($null -eq $tx -or ($task.OwnerId -ne $tx.Processor__c -and $task.CreatedById -ne $tx.Processor__c)) { continue }
        $when = Parse-DateUtc $(if (Has-Value $task.CompletedDateTime) { $task.CompletedDateTime } else { $task.CreatedDate })
        Add-Evidence $evidenceByTx $tx.Id "Task" (Task-Channel $task) $when $tx.Processor__c $tx.Processor__r.Name $task.Subject $task.Id
    }
}

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($tx in $transactions) {
    $evidence = if ($evidenceByTx.ContainsKey($tx.Id)) { @($evidenceByTx[$tx.Id] | Sort-Object WhenUtc -Descending) } else { @() }
    $latest = if ($evidence.Count -gt 0) { $evidence[0] } else { $null }
    if ($evidence.Count -eq 0) {
        $rows.Add([pscustomobject]@{
            Transaction = $tx.Name
            Id = $tx.Id
            Status = $tx.Status__c
            LoanNumber = $tx.Loan_Number__c
            Borrower = if ($tx.Borrower_Name__r) { $tx.Borrower_Name__r.Name } else { $null }
            Processor = if ($tx.Processor__r) { $tx.Processor__r.Name } else { $null }
            ProcessorId = $tx.Processor__c
            LastContactEastern = $null
            LastContactChannel = $null
            LastContactSource = $null
            EvidenceCountLast48Hours = 0
            Reason = if (-not (Has-Value $tx.Processor__c)) { "No processor assigned; no processor/client contact found in last 48 hours." } else { "No processor/client email, SMS, or call evidence found in last 48 hours." }
        }) | Out-Null
    }
}

$rows | Sort-Object Processor, Status, Transaction | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$report = [pscustomobject]@{
    RunStartedLocal = $runStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")
    ThresholdLocal = [System.TimeZoneInfo]::ConvertTimeFromUtc($thresholdUtc, $reportTimeZone).ToString("yyyy-MM-dd HH:mm:ss zzz")
    Status = "completed"
    ActiveTransactionCount = $transactions.Count
    TransactionsWithoutProcessorClientContactLast48Hours = $rows.Count
    CountsByProcessor = @($rows | Group-Object Processor | Sort-Object Name | ForEach-Object { [pscustomobject]@{ Processor = if ($_.Name) { $_.Name } else { "(No Processor)" }; Count = $_.Count } })
    CsvPath = $csvPath
    JsonPath = $jsonPath
    MissingContact = @($rows | Sort-Object Processor, Status, Transaction)
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8
