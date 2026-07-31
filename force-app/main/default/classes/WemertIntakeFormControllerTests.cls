@IsTest
public class WemertIntakeFormControllerTests {

    @IsTest static void testGetRealtorAccounts() {
        
        Test.startTest();
        WemertIntakeFormController.getRealtorAccounts();
        WemertIntakeFormController.getLoanOfficers('');
        Test.stopTest();
        
    }
    
}