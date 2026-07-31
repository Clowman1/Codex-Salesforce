public with sharing class FundedProgressTrackerController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getVolumeProgress() {
        // Get current user
        Id userId = UserInfo.getUserId();
        
        // Get current year and month
        Date today = Date.today();
        Integer currentYear = today.year();
        Integer currentMonth = today.month();
        
        // Aggregate volume for the current month and year
        AggregateResult[] annualResult = [
            SELECT SUM(Loan_Amount_1st__c) totalAnnual 
            FROM Transaction__c 
            WHERE Status__c = 'Post-Closed' AND Loan_Officer__c = :userId AND Funding_Date__c = THIS_YEAR
        ];
        
        AggregateResult[] monthlyResult = [
            SELECT SUM(Loan_Amount_1st__c) totalMonthly 
            FROM Transaction__c 
            WHERE Status__c = 'Post-Closed' AND Loan_Officer__c = :userId AND Funding_Date__c = THIS_MONTH
        ];
        
        AggregateResult[] quarterlyResult = [
            SELECT SUM(Loan_Amount_1st__c) totalQuarterly
            FROM Transaction__c 
            WHERE Status__c = 'Post-Closed' AND Loan_Officer__c = :userId AND Funding_Date__c = THIS_QUARTER
        ];

        
        // Get user's volume goals
        User currentUser = [SELECT Annual_Volume_Goal__c, Quarterly_Volume_Goal__c, Monthly_Volume_Goal__c FROM User WHERE Id = :userId LIMIT 1];
        
        // Prepare response
        Map<String, Decimal> progress = new Map<String, Decimal>();
        progress.put('annualVolume', (annualResult.isEmpty() || annualResult[0].get('totalAnnual') == null) ? 0 : (Decimal)annualResult[0].get('totalAnnual'));
        progress.put('monthlyVolume', (monthlyResult.isEmpty() || monthlyResult[0].get('totalMonthly') == null) ? 0 : (Decimal)monthlyResult[0].get('totalMonthly'));
        progress.put('quarterlyVolume', (quarterlyResult.isEmpty() || quarterlyResult[0].get('totalQuarterly') == null) ? 0 : (Decimal) quarterlyResult[0].get('totalQuarterly'));
        
        progress.put('annualGoal', (currentUser.Annual_Volume_Goal__c != null) ? currentUser.Annual_Volume_Goal__c : 1);
        progress.put('monthlyGoal', (currentUser.Monthly_Volume_Goal__c != null) ? currentUser.Monthly_Volume_Goal__c : 1);
        progress.put('quarterlyGoal', (currentUser.Quarterly_Volume_Goal__c != null) ? currentUser.Quarterly_Volume_Goal__c : 1);
        
        return progress;
    }
}