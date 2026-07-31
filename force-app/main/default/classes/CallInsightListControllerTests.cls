@IsTest
public class CallInsightListControllerTests {

    @IsTest
    public static void testGetCallInsights() {
        
        Account a = new Account(Name = 'Test');
        insert a;
        
        Lead l = new Lead(LastName = 'Test');
        insert l;
        
        Test.startTest();
        CallInsightListController.getCallInsights(l.Id);
        CallInsightListController.getCallInsights(a.Id);
        Test.stopTest();
    }
    
}