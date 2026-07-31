@isTest
private class OutsideLOActivityPageControllerTests {

    @testSetup
    static void setupData() {
        // Create a test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'testuser' + DateTime.now().getTime() + '@example.com',
            Calls_Daily_Goal__c = 2,
            Texts_Daily_Goal__c = 3,
            Emails_Daily_Goal__c = 4,
            Meetings_Daily_Goal__c = 1,
            Open_House_Daily_Goal__c = 1
        );
        insert u;

        // Create some Transactions
        insert new List<Transaction__c>{
            new Transaction__c(Name = 'Test Transaction 1', Loan_Officer__c = u.Id),
            new Transaction__c(Name = 'Test Transaction 2', OwnerId = u.Id)
        };

        // Create Tasks: Some for today and this week
        Date today = Date.today();
        Date startOfWeek = today.toStartOfWeek().addDays(1); // Monday
        List<Task> tasks = new List<Task>{
            new Task(
                OwnerId = u.Id,
                Subject = 'Call with Agent',
                Status = 'Completed',
                Activity_Type__c = 'Call - Active Agent',
                ActivityDate = today,
                Activity_Start_DateTime__c = DateTime.now(),
                Activity_End_DateTime__c = DateTime.now().addMinutes(30)
            ),
            new Task(
                OwnerId = u.Id,
                Subject = 'Send Email',
                Status = 'Completed',
                Activity_Type__c = 'Email',
                ActivityDate = today.addDays(1),
                Activity_Start_DateTime__c = DateTime.now(),
                Activity_End_DateTime__c = DateTime.now().addMinutes(15)
            )
        };
        insert tasks;
    }

    @isTest
    static void testGetTransactions() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            List<Transaction__c> results = OutsideLOActivityPageController.getTransactions();
            Test.stopTest();

            System.assertNotEquals(0, results.size(), 'Should return transactions for the user');
        }
    }

    @isTest
    static void testGetTasks() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            List<Task> tasks = OutsideLOActivityPageController.getTasks();
            Test.stopTest();

            System.assertNotEquals(0, tasks.size(), 'Should return tasks with non-null Activity Type');
            System.assertNotEquals(null, tasks[0].Activity_Type__c, 'Activity Type should not be null');
        }
    }

    @isTest
    static void testGetActivitySummary() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            OutsideLOActivityPageController.ActivitySummary summary = OutsideLOActivityPageController.getActivitySummary();
            Test.stopTest();

            /*System.assertNotEquals(null, summary, 'Activity summary should not be null');
            System.assertEquals(1, summary.dailyCompleted.calls, 'Should count 1 call today');
            System.assertEquals(2, summary.dailyGoal.calls, 'Daily goal should match user record * multiplier 1');
            System.assertEquals(5 * 2, summary.weeklyGoal.calls + summary.weeklyGoal.texts +
                summary.weeklyGoal.emails + summary.weeklyGoal.meetings + summary.weeklyGoal.openHouses, 'Weekly goal total should match daily goals * 5');*/
        }
    }
}