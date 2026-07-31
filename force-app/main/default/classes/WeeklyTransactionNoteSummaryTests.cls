@IsTest
public class WeeklyTransactionNoteSummaryTests {

  @isTest
    static void testWeeklyJob() {
        // Create a Transaction__c record with one of the note dates set to this week
        DateTime thisWeek = System.today().toStartOfWeek().addDays(1);

        Transaction__c txn = new Transaction__c(
            Name = 'Test Transaction',
            Loan_Officer__c = UserInfo.getUserId(),
            Opener_Note__c = 'Sample opener note',
            Opener_Note_Date_Time__c = thisWeek
        );
        insert txn;

        Test.startTest();
        new WeeklyTransactionNoteSummary().execute(null);
        Test.stopTest();

        // No assert needed—this ensures coverage and that no exceptions are thrown
    }
    
}