@IsTest
public class IntakeFormControllerTests {

    @IsTest static void test() {
        RecordType personAccountRecordType = [SELECT Id FROM RecordType WHERE Name = 'Person Account'];
        Account acc = new Account();
        acc.LastName = 'Test';
        acc.PersonEmail = 'test@gmail.com';
        acc.RecordTypeId = personAccountRecordType.Id;
        insert acc;
        
        Test.startTest();
        IntakeFormController.getLoanOfficers('test@gmail.com');
        Test.stopTest();
    }
}