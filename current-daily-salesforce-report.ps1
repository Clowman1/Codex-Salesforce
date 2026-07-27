$ErrorActionPreference = "Stop"
$env:SF_AUTOUPDATE_DISABLE = "true"
$env:SFDX_AUTOUPDATE_DISABLE = "true"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$org = "my-org"
$runStarted = Get-Date
$reportTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")

function Invoke-SfQuery {
    param([string] $Query)

    $compactQuery = ($Query -replace "\s+", " ").Trim()
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $raw = & $sf data query --target-org $org --query $compactQuery --json 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }
    $text = ($raw | ForEach-Object { "$_" } | Out-String).Trim()
    if ($exitCode -ne 0) {
        throw "Salesforce CLI query failed with exit code $exitCode. $text"
    }
    if (-not $text) {
        throw "Salesforce CLI returned no JSON output."
    }

    $jsonStart = $text.IndexOf("{")
    if ($jsonStart -gt 0) {
        $text = $text.Substring($jsonStart)
    }

    $parsed = $text | ConvertFrom-Json
    if ($parsed.status -ne 0) {
        throw "Salesforce query failed: $($parsed.message)"
    }

    return @($parsed.result.records)
}

function Has-Value {
    param($Value)
    return $null -ne $Value -and "$Value".Trim().Length -gt 0
}

function Calendar-Date {
    param($Value)
    if (-not (Has-Value $Value)) { return $null }
    $instant = [datetimeoffset]::Parse("$Value")
    return ([System.TimeZoneInfo]::ConvertTime($instant, $reportTimeZone)).Date
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]] $List,
        [object] $Record,
        [string] $IssueType,
        [string] $Detail
    )

    $List.Add([pscustomobject]@{
        Name = $Record.Name
        Id = $Record.Id
        Status = $Record.Status__c
        LoanNumber = $Record.Loan_Number__c
        IssueType = $IssueType
        Detail = $Detail
    }) | Out-Null
}

$reportable = [System.Collections.Generic.List[object]]::new()
$dtiOnlyCount = 0
$skipped = [System.Collections.Generic.List[string]]::new()

$activeStatuses = @(
    "TRID Application", "Open", "Disclosures Out", "Pre-Processing", "Processing",
    "Submitted", "Suspended", "Waiting On Loan Officer", "Conditionally Approved",
    "Re-Submitted", "Approved", "Closing", "Funding", "PC Review"
)
$beyondProcessingStatuses = @(
    "Submitted", "Suspended", "Waiting On Loan Officer", "Conditionally Approved",
    "Re-Submitted", "Approved", "Closing", "Funding", "PC Review"
)
$borrowerActiveStatuses = @(
    "Processing", "Submitted", "Suspended", "Waiting On Loan Officer",
    "Conditionally Approved", "Re-Submitted", "Approved", "Closing", "Funding", "PC Review"
)

$tridQuery = @"
SELECT Id, Name, Status__c, TRID_Date__c, Disclosures_Out_Date__c, Disclosures_Due_Date__c
FROM Transaction__c
WHERE TRID_Date__c != null
AND Status__c NOT IN ('Cancelled','Post-Closed')
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$tridRecords = Invoke-SfQuery $tridQuery
foreach ($r in $tridRecords) {
    $tridDate = Calendar-Date $r.TRID_Date__c
    $outDate = Calendar-Date $r.Disclosures_Out_Date__c
    $dueDate = Calendar-Date $r.Disclosures_Due_Date__c

    if ($null -eq $outDate) {
        Add-Issue $reportable $r "TRID compliance" "TRID date exists, but Disclosures Out Date is blank."
    } elseif ($null -ne $dueDate -and $outDate -gt $dueDate) {
        Add-Issue $reportable $r "TRID compliance" "Disclosures Out Date is after Disclosures Due Date."
    } elseif ($null -ne $tridDate -and $tridDate -gt $outDate) {
        Add-Issue $reportable $r "TRID compliance" "TRID date is after Disclosures Out Date."
    }
}

$loanQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Base_Loan_Amount__c, Loan_Amount_1st__c,
Rate_1st_TD__c, Loan_Purpose__c, Refinance_Purpose__c, Loan_Type_1st_TD__c,
Loan_Program_1st__c, Loan_Product_1st_TD__c, Term_1st__c, Purchase_Price__c,
Appraised_Value__c, Property_Address__c, Property_City__c, Property_State__c,
Property_Postal_Code__c, Property_Type__c, Occupancy__c, FICO__c, LTV__c,
CLTV__c, DTI_Back_End__c, DTI_Front_End__c, Closing_Date__c
FROM Transaction__c
WHERE Status__c IN ('Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$loanRecords = Invoke-SfQuery $loanQuery
foreach ($r in $loanRecords) {
    $issues = [System.Collections.Generic.List[string]]::new()
    $dtiIssues = [System.Collections.Generic.List[string]]::new()

    if (-not (Has-Value $r.Loan_Number__c)) { $issues.Add("missing Loan Number") | Out-Null }
    if (-not (Has-Value $r.Base_Loan_Amount__c)) { $issues.Add("missing Base Loan Amount") | Out-Null }
    if (-not (Has-Value $r.Loan_Amount_1st__c)) { $issues.Add("missing Total Loan Amount") | Out-Null }
    if (-not (Has-Value $r.Rate_1st_TD__c)) { $issues.Add("missing Rate") | Out-Null }
    if (-not (Has-Value $r.Loan_Purpose__c)) { $issues.Add("missing Loan Purpose") | Out-Null }
    if (-not (Has-Value $r.Loan_Type_1st_TD__c)) { $issues.Add("missing Loan Type") | Out-Null }
    if (-not (Has-Value $r.Loan_Program_1st__c)) { $issues.Add("missing Loan Program") | Out-Null }
    if (-not (Has-Value $r.Term_1st__c)) { $issues.Add("missing Term") | Out-Null }
    if (-not (Has-Value $r.Property_Address__c)) { $issues.Add("missing Property Address") | Out-Null }
    if (-not (Has-Value $r.Property_City__c)) { $issues.Add("missing Property City") | Out-Null }
    if (-not (Has-Value $r.Property_State__c)) { $issues.Add("missing Property State") | Out-Null }
    if (-not (Has-Value $r.Property_Postal_Code__c)) { $issues.Add("missing Property Postal Code") | Out-Null }
    if (-not (Has-Value $r.Property_Type__c)) { $issues.Add("missing Property Type") | Out-Null }
    if (-not (Has-Value $r.Occupancy__c)) { $issues.Add("missing Occupancy") | Out-Null }
    if (-not (Has-Value $r.FICO__c)) { $issues.Add("missing FICO") | Out-Null }
    if (-not (Has-Value $r.LTV__c)) { $issues.Add("missing LTV") | Out-Null }

    $purpose = "$($r.Loan_Purpose__c)"
    if ($purpose -match "Purchase" -and -not (Has-Value $r.Purchase_Price__c)) { $issues.Add("purchase file missing Purchase Price") | Out-Null }
    if ($purpose -match "Refinance|Refi" -and -not (Has-Value $r.Refinance_Purpose__c)) { $issues.Add("refinance file missing Refinance Purpose") | Out-Null }

    if ((Has-Value $r.Base_Loan_Amount__c) -and [decimal]$r.Base_Loan_Amount__c -le 0) { $issues.Add("Base Loan Amount zero/negative") | Out-Null }
    if ((Has-Value $r.Loan_Amount_1st__c) -and [decimal]$r.Loan_Amount_1st__c -le 0) { $issues.Add("Total Loan Amount zero/negative") | Out-Null }
    if ((Has-Value $r.Base_Loan_Amount__c) -and (Has-Value $r.Loan_Amount_1st__c) -and [decimal]$r.Base_Loan_Amount__c -gt [decimal]$r.Loan_Amount_1st__c) { $issues.Add("Base Loan Amount greater than Total Loan Amount") | Out-Null }
    if ((Has-Value $r.Rate_1st_TD__c) -and ([decimal]$r.Rate_1st_TD__c -le 0 -or [decimal]$r.Rate_1st_TD__c -gt 25)) { $issues.Add("Rate outside 0-25") | Out-Null }
    if ((Has-Value $r.FICO__c) -and ([decimal]$r.FICO__c -lt 300 -or [decimal]$r.FICO__c -gt 850)) { $issues.Add("FICO outside 300-850") | Out-Null }
    if ((Has-Value $r.LTV__c) -and ([decimal]$r.LTV__c -le 0 -or [decimal]$r.LTV__c -gt 150)) { $issues.Add("LTV outside 0-150") | Out-Null }

    if (-not (Has-Value $r.DTI_Back_End__c)) { $dtiIssues.Add("missing Back-End DTI") | Out-Null }
    if (-not (Has-Value $r.DTI_Front_End__c)) { $dtiIssues.Add("missing Front-End DTI") | Out-Null }
    if ((Has-Value $r.DTI_Back_End__c) -and ([decimal]$r.DTI_Back_End__c -lt 0 -or [decimal]$r.DTI_Back_End__c -gt 100)) { $dtiIssues.Add("Back-End DTI outside 0-100") | Out-Null }
    if ((Has-Value $r.DTI_Front_End__c) -and ([decimal]$r.DTI_Front_End__c -lt 0 -or [decimal]$r.DTI_Front_End__c -gt 100)) { $dtiIssues.Add("Front-End DTI outside 0-100") | Out-Null }

    if ($issues.Count -gt 0) {
        Add-Issue $reportable $r "Loan-level data integrity" ($issues -join "; ")
    } elseif ($dtiIssues.Count -gt 0) {
        $dtiOnlyCount++
    }
}

$buyingAgentQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Realtor_Buying_Agent__c
FROM Transaction__c
WHERE Status__c IN ('TRID Application','Open','Disclosures Out','Pre-Processing','Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
AND Realtor_Buying_Agent__c = null
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$buyingAgentRecords = Invoke-SfQuery $buyingAgentQuery
foreach ($r in $buyingAgentRecords) {
    Add-Issue $reportable $r "Realtor Buying Agent missing" "Realtor - Buying Agent is blank."
}

$mersQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Channel__c, MERS_Min__c
FROM Transaction__c
WHERE Status__c IN ('TRID Application','Open','Disclosures Out','Pre-Processing','Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
AND Channel__c = 'Correspondent'
AND MERS_Min__c = null
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$mersRecords = Invoke-SfQuery $mersQuery
foreach ($r in $mersRecords) {
    Add-Issue $reportable $r "MERS MIN missing" "Correspondent transaction missing MERS MIN."
}

$borrowerQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Funding_Date__c, Borrower_Name__c,
Borrower_Name__r.Name, Borrower_Name__r.IsPersonAccount, Borrower_Name__r.SSN__pc,
Borrower_Name__r.PersonBirthdate
FROM Transaction__c
WHERE Borrower_Name__c != null
AND (
  Status__c IN ('Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
  OR (Status__c = 'Post-Closed' AND Funding_Date__c >= 2026-01-01 AND Funding_Date__c < 2027-01-01)
)
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$borrowerRecords = Invoke-SfQuery $borrowerQuery
foreach ($r in $borrowerRecords) {
    $b = $r.Borrower_Name__r
    $issues = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $b -or $b.IsPersonAccount -ne $true) { $issues.Add("borrower Account is not a Person Account") | Out-Null }
    if ($null -eq $b -or -not (Has-Value $b.SSN__pc)) { $issues.Add("borrower SSN missing") | Out-Null }
    if ($null -eq $b -or -not (Has-Value $b.PersonBirthdate)) { $issues.Add("borrower Birthdate missing") | Out-Null }
    if ($issues.Count -gt 0) {
        $scope = if ($r.Status__c -eq "Post-Closed") { "Post-Closed funded in 2026" } else { "Active Processing+" }
        $name = "$($r.Name) / borrower $($b.Name)"
        $reportable.Add([pscustomobject]@{
            Name = $name
            Id = $r.Id
            Status = $r.Status__c
            LoanNumber = $r.Loan_Number__c
            IssueType = "Borrower SSN/Birthdate completeness"
            Detail = "$scope; $($issues -join '; ')"
        }) | Out-Null
    }
}

$agingQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c
FROM Transaction__c
WHERE Status__c IN ('Open','Pre-Processing','Processing')
AND (NOT Name LIKE 'TEST%')
AND Name != 'Lowman - 1526204355'
"@
$agingRecords = Invoke-SfQuery $agingQuery
if ($agingRecords.Count -gt 0) {
    $ids = ($agingRecords | ForEach-Object { "'$($_.Id)'" }) -join ","
    $historyQuery = @"
SELECT ParentId, NewValue, CreatedDate
FROM Transaction__History
WHERE Field = 'Status__c'
AND ParentId IN ($ids)
ORDER BY CreatedDate DESC
"@
    $historyRecords = Invoke-SfQuery $historyQuery
    foreach ($r in $agingRecords) {
        $match = @($historyRecords | Where-Object { $_.ParentId -eq $r.Id -and "$($_.NewValue)" -eq "$($r.Status__c)" } | Select-Object -First 1)
        if ($match.Count -eq 0) {
            Add-Issue $reportable $r "Status aging over 24 hours" "Missing status history timestamp."
            continue
        }
        $changedAt = ([datetimeoffset]::Parse("$($match[0].CreatedDate)")).UtcDateTime
        $hours = (($runStarted.ToUniversalTime()) - $changedAt).TotalHours
        if ($hours -gt 24) {
            $label = if ($r.Status__c -eq "Open") { "Submission Form Complete" } else { $r.Status__c }
            Add-Issue $reportable $r "Status aging over 24 hours" ("in {0} ({1}) since {2:u}, about {3:N1} hours" -f $r.Status__c, $label, $changedAt, $hours)
        }
    }
}

$counts = $reportable | Group-Object IssueType | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ IssueType = $_.Name; Count = $_.Count }
}

[pscustomobject]@{
    RunStartedLocal = $runStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")
    Status = "completed"
    SkippedChecks = @($skipped)
    TotalReportableExceptions = $reportable.Count
    DtiOnlyItemsOmitted = $dtiOnlyCount
    Counts = @($counts)
    Exceptions = @($reportable)
} | ConvertTo-Json -Depth 8
