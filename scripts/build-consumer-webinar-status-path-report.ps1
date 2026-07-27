param(
    [string]$SfPath = "C:\Program Files\sf\bin\sf.cmd",
    [string]$TargetOrg = "my-org",
    [string]$OutputPath = "reports\consumer_webinar_status_path_report.csv"
)

$ErrorActionPreference = "Stop"

function Invoke-SfJsonQuery {
    param([string]$Query)

    $raw = & $SfPath data query --target-org $TargetOrg --query $Query --json
    $jsonStart = ($raw | Select-String -Pattern '^\s*\{' | Select-Object -First 1).LineNumber
    if (-not $jsonStart) {
        throw "Salesforce CLI did not return JSON for query: $Query"
    }
    $json = ($raw | Select-Object -Skip ($jsonStart - 1)) -join "`n"
    return $json | ConvertFrom-Json
}

$earlyStatuses = @(
    "New",
    "Contact Attempt 1",
    "Contact Attempt 2",
    "Contact Attempt 3",
    "Contact Attempt 4",
    "Contact Attempt 5"
)

$nurtureStatuses = @(
    "Nurturing",
    "Nurture - Preapproval",
    "Nurture - Pre-Approval",
    "30 Day Follow Up",
    "30 Day + Follow Up",
    "Credit Repair"
)

$leadQuery = @"
SELECT Id, Name, CreatedDate, LeadSource, Status, Owner.Name, Phone, Email,
       Webinar_Date__c, Webinar_Registration_Date__c,
       Referral_Source__c, Referral_Source__r.Name
FROM Lead
WHERE LeadSource = 'Consumer Webinar'
"@ -replace "`r?`n", " "

$historyQuery = @"
SELECT LeadId, Field, OldValue, NewValue, CreatedDate
FROM LeadHistory
WHERE Lead.LeadSource = 'Consumer Webinar'
AND Field = 'Status'
ORDER BY LeadId, CreatedDate ASC
"@ -replace "`r?`n", " "

$leadResult = Invoke-SfJsonQuery -Query $leadQuery
$historyResult = Invoke-SfJsonQuery -Query $historyQuery

$historiesByLead = @{}
foreach ($row in $historyResult.result.records) {
    if (-not $historiesByLead.ContainsKey($row.LeadId)) {
        $historiesByLead[$row.LeadId] = New-Object System.Collections.Generic.List[object]
    }
    $historiesByLead[$row.LeadId].Add($row)
}

$reportRows = foreach ($lead in $leadResult.result.records) {
    $history = @()
    if ($historiesByLead.ContainsKey($lead.Id)) {
        $history = $historiesByLead[$lead.Id] | Sort-Object CreatedDate
    }

    $lastContactStatus = $null
    $lastContactDate = $null
    $firstExitStatus = $null
    $firstExitDate = $null
    $firstExitType = $null
    $nurtureDate = $null

    foreach ($h in $history) {
        $oldStatus = [string]$h.OldValue
        $newStatus = [string]$h.NewValue

        if ($earlyStatuses -contains $newStatus) {
            $lastContactStatus = $newStatus
            $lastContactDate = $h.CreatedDate
        }

        if (($earlyStatuses -contains $oldStatus) -and -not ($earlyStatuses -contains $newStatus) -and -not $firstExitStatus) {
            $firstExitStatus = $newStatus
            $firstExitDate = $h.CreatedDate
            $lastContactStatus = $oldStatus
            $lastContactDate = $h.CreatedDate

            if ($nurtureStatuses -contains $newStatus) {
                $firstExitType = "Nurture/Non-working"
            } else {
                $firstExitType = "Working/Advancing"
            }
        }

        if (($nurtureStatuses -contains $newStatus) -and -not $nurtureDate) {
            $nurtureDate = $h.CreatedDate
        }
    }

    if (-not $firstExitStatus) {
        if ($earlyStatuses -notcontains $lead.Status) {
            $firstExitStatus = $lead.Status
            $firstExitType = if ($nurtureStatuses -contains $lead.Status) { "Nurture/Non-working" } else { "Working/Advancing" }
        } else {
            $firstExitType = "Still Early Contact"
        }
    }

    if ($firstExitType -eq "Working/Advancing") {
        [pscustomobject]@{
            "Lead Name" = $lead.Name
            "Lead Id" = $lead.Id
            "Lead URL" = "https://reachhomeloans.lightning.force.com/lightning/r/Lead/$($lead.Id)/view"
            "Current Status" = $lead.Status
            "Lead Owner" = $lead.Owner.Name
            "Lead Source" = $lead.LeadSource
            "Referral Source" = $lead.Referral_Source__r.Name
            "Webinar Date" = $lead.Webinar_Date__c
            "Webinar Registration Date" = $lead.Webinar_Registration_Date__c
            "Created Date" = $lead.CreatedDate
            "Phone" = $lead.Phone
            "Email" = $lead.Email
            "Last Contact Status Before Exit" = $lastContactStatus
            "Last Contact Status Date" = $lastContactDate
            "Moved To Working/Nurture Status" = $firstExitStatus
            "Moved To Working/Nurture Date" = $firstExitDate
            "First Exit Classification" = $firstExitType
            "Moved To Nurture Date" = $nurtureDate
        }
    }
}

$fullOutput = Join-Path (Get-Location) $OutputPath
$folder = Split-Path -Parent $fullOutput
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder | Out-Null
}

$reportRows | Sort-Object "Webinar Date", "Lead Owner", "Lead Name" | Export-Csv -Path $fullOutput -NoTypeInformation

Write-Host "Created report: $fullOutput"
Write-Host "Rows included: $(@($reportRows).Count)"
