@IsTest
private class HomeToolsControllerTest {
    @IsTest
    static void getHomeToolsDataReturnsLists() {
        Test.startTest();
        HomeToolsController.HomeToolsData data = HomeToolsController.getHomeToolsData();
        Test.stopTest();

        System.assertNotEquals(null, data, 'Expected home tools data.');
        System.assertNotEquals(null, data.tasks, 'Expected task list.');
        System.assertNotEquals(null, data.events, 'Expected event list.');
        System.assertNotEquals(null, data.recentRecords, 'Expected recent record list.');
    }

    @IsTest
    static void getHomeToolsDataReturnsStandardLoanOfficerTrackers() {
        User loanOfficer = testUser('Tracker', 'Waters', 'Loan Officer');

        System.runAs(loanOfficer) {
            Test.startTest();
            HomeToolsController.HomeToolsData data = HomeToolsController.getHomeToolsData();
            Test.stopTest();

            System.assertEquals(5, data.trackers.size(), 'Standard loan officers should receive five tracker cards.');
            System.assertEquals('Active Pre-Approvals', data.trackers[0].label);
            System.assertEquals('Work Done, money on the table', data.trackers[0].helperText);
        }
    }

    @IsTest
    static void productionTrackersExcludeDpaSecondLoanTypes() {
        User loanOfficer = testUser('Martin', 'Rebagliati', 'Loan Officer');
        Date todayDate = Date.today();
        Date closeDate = Date.newInstance(todayDate.year(), todayDate.month(), Math.min(15, Date.daysInMonth(todayDate.year(), todayDate.month())));
        insert new List<Transaction__c>{
            new Transaction__c(
                Name = 'Included Production File',
                Loan_Officer__c = loanOfficer.Id,
                Status__c = 'Post-Closed',
                Closing_Date__c = closeDate,
                Loan_Amount_1st__c = 100000,
                Loan_Type_1st_TD__c = 'Conventional'
            ),
            new Transaction__c(
                Name = 'Excluded DPA Second File',
                Loan_Officer__c = loanOfficer.Id,
                Status__c = 'Post-Closed',
                Closing_Date__c = closeDate,
                Loan_Amount_1st__c = 50000,
                Loan_Type_1st_TD__c = 'DPA 2nd'
            )
        };

        System.runAs(loanOfficer) {
            Test.startTest();
            HomeToolsController.HomeToolsData data = HomeToolsController.getHomeToolsData();
            Test.stopTest();

            System.assertEquals(1, data.trackers[2].units, 'House MTD production should exclude DPA 2nd transactions.');
            System.assertEquals(100000, data.trackers[2].volume, 'House MTD production volume should exclude DPA 2nd transactions.');
        }
    }

    @IsTest
    static void getHomeToolsDataReturnsJosephCareyExceptionTrackers() {
        User josephCarey = testUser('Joseph', 'Carey', 'Loan Officer');

        System.runAs(josephCarey) {
            Test.startTest();
            HomeToolsController.HomeToolsData data = HomeToolsController.getHomeToolsData();
            Test.stopTest();

            System.assertEquals(2, data.trackers.size(), 'Joseph Carey should only receive the two personal production tracker cards.');
            System.assertEquals('Personal Deals Closed This Month', data.trackers[0].label);
            System.assertEquals('Personal Deals Closed This Year', data.trackers[1].label);
        }
    }

    private static User testUser(String firstName, String lastName, String title) {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];
        String uniqueToken = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User userRecord = new User(
            FirstName = firstName,
            LastName = lastName,
            Alias = (firstName.left(1) + lastName).left(8),
            Email = uniqueToken + '@example.com',
            Username = uniqueToken + '@example.com',
            CommunityNickname = ('u' + uniqueToken).left(40),
            Title = title,
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert userRecord;
        return userRecord;
    }
}
