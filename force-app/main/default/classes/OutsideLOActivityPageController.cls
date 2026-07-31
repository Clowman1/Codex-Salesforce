public with sharing class OutsideLOActivityPageController {

    @AuraEnabled
    public static List<Transaction__c> getTransactions() {
        Id userId = UserInfo.getUserId();
        List<Transaction__c> transactions = [SELECT Id, Name FROM Transaction__c 
                                             WHERE Loan_Officer__c = :userId OR OwnerId = :userId];

        return transactions;
    }

    @AuraEnabled
    public static List<Task> getTasks() {
        Id userId = UserInfo.getUserId();
        List<Task> tasks = [SELECT Subject, Status, Activity_Title__c, Activity_Type__c, ActivityDate, Activity_Start_DateTime__c, Activity_End_DateTime__c 
                                    FROM Task 
                                    WHERE OwnerId = :userId AND Activity_Type__c != null];

        return tasks;
    }

    @AuraEnabled
	public static ActivitySummary getActivitySummary() {
        Id userId = UserInfo.getUserId();
        Date today = Date.today();
        Date startOfWeek = today.toStartOfWeek().addDays(1); // Monday, because it's US based org
        Date endOfWeek = startOfWeek.addDays(4);  // Friday

        User u = [
            SELECT Calls_Daily_Goal__c, Texts_Daily_Goal__c, Emails_Daily_Goal__c,
                   Meetings_Daily_Goal__c, Open_House_Daily_Goal__c
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        List<Task> weekTasks = [
            SELECT Activity_Type__c, ActivityDate
            FROM Task
            WHERE OwnerId = :userId
              AND Status = 'Completed'
              AND ActivityDate >= :startOfWeek
              AND ActivityDate <= :endOfWeek
        ];

        ActivitySummary summary = new ActivitySummary();

        for (Task t : weekTasks) {
            if (t.ActivityDate == today) {
                summary.dailyCompleted.add(t);
            }
            summary.weeklyCompleted.add(t);
        }

        summary.dailyGoal.setGoals(u, 1);
        summary.weeklyGoal.setGoals(u, 5);

        return summary;
    }    

    public class ActivitySummary {
        @AuraEnabled public ActivityMetrics dailyCompleted { get; set; }
        @AuraEnabled public ActivityMetrics dailyGoal { get; set; }
        
        @AuraEnabled public ActivityMetrics weeklyCompleted { get; set; }
        @AuraEnabled public ActivityMetrics weeklyGoal { get; set; }
        
        public ActivitySummary() {
            dailyCompleted = new ActivityMetrics();
            dailyGoal = new ActivityMetrics();
            weeklyCompleted = new ActivityMetrics();
            weeklyGoal = new ActivityMetrics();
        }
    }
    
    public class ActivityMetrics {
        @AuraEnabled public Integer all { get; set; }
        @AuraEnabled public Integer calls { get; set; }
        @AuraEnabled public Integer texts { get; set; }
        @AuraEnabled public Integer emails { get; set; }
        @AuraEnabled public Integer meetings { get; set; }
        @AuraEnabled public Integer openHouses { get; set; }
        
        public ActivityMetrics() {
            all = 0;
            calls = 0;
            texts = 0;
            emails = 0;
            meetings = 0;
            openHouses = 0;
        }
        
        public void add(Task t) {
            all++;
            switch on t.Activity_Type__c {
                when 'Call - Prospecting', 'Call - Active Agent' {
                    calls++;
                }
                when 'Text' {
                    texts++;
                }
                when 'Email' {
                    emails++;
                }
                when 'Meeting (New Agent)', 'Meeting (Active Agent)' {
                    meetings++;
                }
                when 'Open House' {
                    openHouses++;
                }
            }
        }
        
        public void setGoals(User u, Integer multiplier) {
            calls = (u.Calls_Daily_Goal__c != null ? u.Calls_Daily_Goal__c.intValue() : 0) * multiplier;
            texts = (u.Texts_Daily_Goal__c != null ? u.Texts_Daily_Goal__c.intValue() : 0) * multiplier;
            emails = (u.Emails_Daily_Goal__c != null ? u.Emails_Daily_Goal__c.intValue() : 0) * multiplier;
            meetings = (u.Meetings_Daily_Goal__c != null ? u.Meetings_Daily_Goal__c.intValue() : 0) * multiplier;
            openHouses = (u.Open_House_Daily_Goal__c != null ? u.Open_House_Daily_Goal__c.intValue() : 0) * multiplier;
            all = calls + texts + emails + meetings + openHouses;
        }
    }
    
}