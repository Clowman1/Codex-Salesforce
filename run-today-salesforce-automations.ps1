$ErrorActionPreference = "Stop"

$sf = "C:\Program Files\sf\bin\sf.cmd"
$sfProject = "C:\Users\ChristopherLowman\Documents\Codex\2026-05-11\what-all-are-you-able-to-2\salesforce-work"
$targetOrg = "my-org"
$reportFolder = "C:\Users\ChristopherLowman\Desktop\Nickley Reports"
$apiVersion = "66.0"
$runStarted = Get-Date

function Invoke-SfQuery {
    param([Parameter(Mandatory = $true)][string]$Query)
    $compactQuery = (($Query -split "\r?\n") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join " "
    $output = Invoke-Process $sf @("data", "query", "--target-org", $targetOrg, "--query", $compactQuery, "--json")
    $jsonText = ($output | Out-String).Trim()
    $result = $jsonText | ConvertFrom-Json
    if ($result.status -ne 0) {
        throw "Salesforce query failed: $jsonText"
    }
    return @($result.result.records)
}

function Invoke-Process {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_.Replace('\', '\\').Replace('"', '\"')) + '"'
        } else {
            $_
        }
    }) -join " "
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode). stdout: $stdout stderr: $stderr"
    }
    return $stdout
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Check,
        [string]$Type,
        [object]$Record,
        [string]$Details
    )
    $Issues.Add([pscustomobject]@{
        Check = $Check
        Type = $Type
        Transaction = $Record.Name
        Status = $Record.Status__c
        LoanNumber = $Record.Loan_Number__c
        Id = $Record.Id
        Details = $Details
    }) | Out-Null
}

function Is-Blank {
    param($Value)
    return ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value))
}

function Exclude-TestTransactions {
    param([object[]]$Records)
    return @($Records | Where-Object { $_.Name -notlike "TEST*" -and $_.Name -ne "Lowman - 1526204355" })
}

function To-DateOnly {
    param($Value)
    if (Is-Blank $Value) { return $null }
    return ([DateTime]$Value).Date
}

Push-Location $sfProject
try {
    $issues = [System.Collections.Generic.List[object]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    $tridQuery = @"
SELECT Id, Name, Status__c, TRID_Date__c, Disclosures_Out_Date__c, Disclosures_Due_Date__c
FROM Transaction__c
WHERE TRID_Date__c != null
AND Status__c NOT IN ('Cancelled','Post-Closed')
"@
    $tridRecords = Exclude-TestTransactions (Invoke-SfQuery $tridQuery)
    foreach ($record in $tridRecords) {
        $tridDate = To-DateOnly $record.TRID_Date__c
        $outDate = To-DateOnly $record.Disclosures_Out_Date__c
        $dueDate = To-DateOnly $record.Disclosures_Due_Date__c
        if ($null -eq $outDate) {
            Add-Issue $issues "TRID compliance" "Missing disclosure out date" $record "TRID date exists but Disclosures Out Date is blank"
        } elseif ($null -ne $dueDate -and $outDate -gt $dueDate) {
            Add-Issue $issues "TRID compliance" "Disclosure out after due date" $record "Disclosures Out Date $($outDate.ToString('yyyy-MM-dd')) is after due date $($dueDate.ToString('yyyy-MM-dd'))"
        } elseif ($null -ne $tridDate -and $tridDate -gt $outDate) {
            Add-Issue $issues "TRID compliance" "TRID after disclosure out" $record "TRID Date $($tridDate.ToString('yyyy-MM-dd')) is after Disclosures Out Date $($outDate.ToString('yyyy-MM-dd'))"
        }
    }

    $loanQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Base_Loan_Amount__c, Loan_Amount_1st__c, Rate_1st_TD__c,
Loan_Purpose__c, Refinance_Purpose__c, Loan_Type_1st_TD__c, Loan_Program_1st__c, Loan_Product_1st_TD__c,
Term_1st__c, Purchase_Price__c, Appraised_Value__c, Property_Address__c, Property_City__c,
Property_State__c, Property_Postal_Code__c, Property_Type__c, Occupancy__c, FICO__c, LTV__c, CLTV__c,
DTI_Back_End__c, DTI_Front_End__c, Closing_Date__c
FROM Transaction__c
WHERE Status__c IN ('Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
"@
    $loanRecords = Exclude-TestTransactions (Invoke-SfQuery $loanQuery)
    foreach ($record in $loanRecords) {
        $missing = [System.Collections.Generic.List[string]]::new()
        foreach ($field in @(
            @("Loan Number", $record.Loan_Number__c),
            @("Base Loan Amount", $record.Base_Loan_Amount__c),
            @("Total Loan Amount", $record.Loan_Amount_1st__c),
            @("Rate", $record.Rate_1st_TD__c),
            @("Loan Purpose", $record.Loan_Purpose__c),
            @("Loan Type", $record.Loan_Type_1st_TD__c),
            @("Loan Program", $record.Loan_Program_1st__c),
            @("Term", $record.Term_1st__c),
            @("Property Address", $record.Property_Address__c),
            @("Property City", $record.Property_City__c),
            @("Property State", $record.Property_State__c),
            @("Property Postal Code", $record.Property_Postal_Code__c),
            @("Property Type", $record.Property_Type__c),
            @("Occupancy", $record.Occupancy__c),
            @("FICO", $record.FICO__c),
            @("LTV", $record.LTV__c),
            @("Back-End DTI", $record.DTI_Back_End__c)
        )) {
            if (Is-Blank $field[1]) { $missing.Add($field[0]) | Out-Null }
        }
        if ([string]$record.Loan_Purpose__c -match "Purchase" -and (Is-Blank $record.Purchase_Price__c)) {
            $missing.Add("Purchase Price") | Out-Null
        }
        if ([string]$record.Loan_Purpose__c -match "Refinance" -and (Is-Blank $record.Refinance_Purpose__c)) {
            $missing.Add("Refinance Purpose") | Out-Null
        }
        if ($missing.Count -gt 0) {
            Add-Issue $issues "Loan-level data integrity" "Missing key data" $record ("Missing " + ($missing -join ", "))
        }

        $invalid = [System.Collections.Generic.List[string]]::new()
        if ($null -ne $record.Base_Loan_Amount__c -and [decimal]$record.Base_Loan_Amount__c -le 0) { $invalid.Add("Base Loan Amount zero/negative") | Out-Null }
        if ($null -ne $record.Loan_Amount_1st__c -and [decimal]$record.Loan_Amount_1st__c -le 0) { $invalid.Add("Total Loan Amount zero/negative") | Out-Null }
        if ($null -ne $record.Base_Loan_Amount__c -and $null -ne $record.Loan_Amount_1st__c -and [decimal]$record.Base_Loan_Amount__c -gt [decimal]$record.Loan_Amount_1st__c) { $invalid.Add("Base Loan Amount greater than Total Loan Amount") | Out-Null }
        if ($null -ne $record.Rate_1st_TD__c -and ([decimal]$record.Rate_1st_TD__c -le 0 -or [decimal]$record.Rate_1st_TD__c -gt 25)) { $invalid.Add("Rate outside 0-25") | Out-Null }
        if ($null -ne $record.FICO__c -and ([decimal]$record.FICO__c -lt 300 -or [decimal]$record.FICO__c -gt 850)) { $invalid.Add("FICO outside 300-850") | Out-Null }
        if ($null -ne $record.LTV__c -and ([decimal]$record.LTV__c -le 0 -or [decimal]$record.LTV__c -gt 150)) { $invalid.Add("LTV outside 0-150") | Out-Null }
        if ($null -ne $record.DTI_Back_End__c -and ([decimal]$record.DTI_Back_End__c -le 0 -or [decimal]$record.DTI_Back_End__c -gt 100)) { $invalid.Add("Back-End DTI outside 0-100") | Out-Null }
        if ($invalid.Count -gt 0) {
            Add-Issue $issues "Loan-level data integrity" "Invalid value" $record ($invalid -join "; ")
        }
    }

    $agentQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c
FROM Transaction__c
WHERE Status__c IN ('TRID Application','Open','Disclosures Out','Pre-Processing','Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
AND Realtor_Buying_Agent__c = null
"@
    foreach ($record in (Exclude-TestTransactions (Invoke-SfQuery $agentQuery))) {
        Add-Issue $issues "Realtor Buying Agent completeness" "Missing buying agent" $record "Realtor - Buying Agent is blank"
    }

    $mersQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Channel__c
FROM Transaction__c
WHERE Status__c IN ('TRID Application','Open','Disclosures Out','Pre-Processing','Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
AND Channel__c = 'Correspondent'
AND MERS_Min__c = null
"@
    foreach ($record in (Exclude-TestTransactions (Invoke-SfQuery $mersQuery))) {
        Add-Issue $issues "MERS MIN completeness" "Missing MERS MIN" $record "Correspondent Transaction has blank MERS MIN"
    }

    $borrowerActiveQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Funding_Date__c, Borrower_Name__r.Id, Borrower_Name__r.Name, Borrower_Name__r.IsPersonAccount, Borrower_Name__r.SSN__pc, Borrower_Name__r.PersonBirthdate
FROM Transaction__c
WHERE Status__c IN ('Processing','Submitted','Suspended','Waiting On Loan Officer','Conditionally Approved','Re-Submitted','Approved','Closing','Funding','PC Review')
"@
    $borrowerPostClosedQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c, Funding_Date__c, Borrower_Name__r.Id, Borrower_Name__r.Name, Borrower_Name__r.IsPersonAccount, Borrower_Name__r.SSN__pc, Borrower_Name__r.PersonBirthdate
FROM Transaction__c
WHERE Status__c = 'Post-Closed'
AND Funding_Date__c >= 2026-01-01
AND Funding_Date__c < 2027-01-01
"@
    foreach ($scope in @(@("Active Processing+", $borrowerActiveQuery), @("Post-Closed funded in 2026", $borrowerPostClosedQuery))) {
        foreach ($record in (Exclude-TestTransactions (Invoke-SfQuery $scope[1]))) {
            $borrower = $record.Borrower_Name__r
            $borrowerIssues = [System.Collections.Generic.List[string]]::new()
            if ($null -eq $borrower) {
                $borrowerIssues.Add("missing borrower Account") | Out-Null
            } else {
                if ($borrower.IsPersonAccount -ne $true) { $borrowerIssues.Add("borrower is not a Person Account") | Out-Null }
                if (Is-Blank $borrower.SSN__pc) { $borrowerIssues.Add("borrower SSN missing") | Out-Null }
                if (Is-Blank $borrower.PersonBirthdate) { $borrowerIssues.Add("borrower Birthdate missing") | Out-Null }
            }
            if ($borrowerIssues.Count -gt 0) {
                $borrowerName = if ($null -eq $borrower) { "No borrower Account" } else { "$($borrower.Name) ($($borrower.Id))" }
                Add-Issue $issues "Borrower SSN/Birthdate completeness" $scope[0] $record "$borrowerName`: $($borrowerIssues -join '; ')"
            }
        }
    }

    $statusQuery = @"
SELECT Id, Name, Status__c, Loan_Number__c
FROM Transaction__c
WHERE Status__c IN ('Open','Pre-Processing','Processing')
"@
    $statusRecords = Exclude-TestTransactions (Invoke-SfQuery $statusQuery)
    if ($statusRecords.Count -gt 0) {
        $ids = ($statusRecords | ForEach-Object { "'$($_.Id)'" }) -join ","
        $historyQuery = "SELECT ParentId, CreatedDate, NewValue FROM Transaction__History WHERE Field = 'Status__c' AND ParentId IN ($ids) ORDER BY CreatedDate DESC"
        $historyRecords = Invoke-SfQuery $historyQuery
        foreach ($record in $statusRecords) {
            $latest = @($historyRecords | Where-Object { $_.ParentId -eq $record.Id -and [string]$_.NewValue -eq [string]$record.Status__c } | Sort-Object CreatedDate -Descending | Select-Object -First 1)
            if ($latest.Count -eq 0) {
                Add-Issue $issues "Status aging over 24 hours" "Missing status history timestamp" $record "No matching Status__c history row for current status $($record.Status__c)"
            } else {
                $changedAt = [DateTime]$latest[0].CreatedDate
                $hours = ($runStarted.ToUniversalTime() - $changedAt.ToUniversalTime()).TotalHours
                if ($hours -gt 24) {
                    $label = if ($record.Status__c -eq "Open") { "Submission Form Complete" } else { $record.Status__c }
                    Add-Issue $issues "Status aging over 24 hours" "Aged status" $record "$label since $($changedAt.ToString('yyyy-MM-dd HH:mm:ss')) UTC ($([Math]::Round($hours, 1)) hours)"
                }
            }
        }
    }

    $orgJson = (Invoke-Process $sf @("org", "display", "--target-org", $targetOrg, "--verbose", "--json") | ConvertFrom-Json)
    if ($orgJson.status -ne 0) { throw "Unable to obtain Salesforce session for report downloads" }
    $instanceUrl = $orgJson.result.instanceUrl
    $accessToken = $orgJson.result.accessToken
    New-Item -ItemType Directory -Force -Path $reportFolder | Out-Null

    $reports = @(
        [pscustomobject]@{ Name = "Contracts From Nickley (This Month)"; Id = "00OQi000000wTsrMAE"; FileName = "Contracts From Nickley (This Month).xlsx" },
        [pscustomobject]@{ Name = "Nickley Leads This Month"; Id = "00OQi000004m3u9MAA"; FileName = "Nickley Leads This Month.xlsx" },
        [pscustomobject]@{ Name = "Nickley Realtor Lookback Last Week"; Id = "00OQi000002w0CzMAI"; FileName = "Nickley Realtor Lookback Last Week.xlsx" },
        [pscustomobject]@{ Name = "Nickley Pre-Approvals This Month"; Id = "00OQi000005ZLrVMAW"; FileName = "Nickley Pre-Approvals This Month.xlsx" }
    )
    $downloadResults = [System.Collections.Generic.List[object]]::new()
    foreach ($report in $reports) {
        $reportId = $report.Id
        $path = Join-Path $reportFolder $report.FileName
        try {
            $uri = "$instanceUrl/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId=$reportId"
            Invoke-WebRequest -Uri $uri -Headers @{ Cookie = "sid=$accessToken" } -OutFile $path -UseBasicParsing | Out-Null
            if ((Get-Item $path).Length -lt 1000) {
                $refreshQuery = "SELECT Id, Name FROM Report WHERE Name = '$($report.Name.Replace("'","\'"))' LIMIT 1"
                $fresh = @(Invoke-SfQuery $refreshQuery)
                if ($fresh.Count -gt 0) {
                    $reportId = $fresh[0].Id
                    $uri = "$instanceUrl/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId=$reportId"
                    Invoke-WebRequest -Uri $uri -Headers @{ Cookie = "sid=$accessToken" } -OutFile $path -UseBasicParsing | Out-Null
                }
            }
            $item = Get-Item $path
            $downloadResults.Add([pscustomobject]@{ Name = $report.Name; Path = $item.FullName; Size = $item.Length; Status = "Downloaded"; Error = $null }) | Out-Null
        } catch {
            $downloadResults.Add([pscustomobject]@{ Name = $report.Name; Path = $path; Size = $null; Status = "Failed"; Error = $_.Exception.Message }) | Out-Null
        }
    }

    $counts = $issues | Group-Object Check, Type | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{ Category = $_.Name; Count = $_.Count }
    }

    [pscustomobject]@{
        RunStarted = $runStarted.ToString("yyyy-MM-dd HH:mm:ss zzz")
        RunCompleted = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
        QueryScopes = [pscustomobject]@{
            TridRecords = $tridRecords.Count
            LoanRecords = $loanRecords.Count
            StatusAgingRecords = $statusRecords.Count
        }
        TotalExceptions = $issues.Count
        Counts = @($counts)
        Issues = @($issues)
        Skipped = @($skipped)
        ReportDownloads = @($downloadResults)
    } | ConvertTo-Json -Depth 8
} finally {
    Pop-Location
}
