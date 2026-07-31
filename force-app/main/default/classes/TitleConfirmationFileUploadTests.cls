@IsTest
public class TitleConfirmationFileUploadTests {

    @IsTest static void testUploadFile() {
        Transaction__c trans = new Transaction__c();
        insert trans;
        
        Test.startTest();
        TitleConfirmationFileUploadController.uploadFile(trans.Id, 'Test', 'text/xml', 'tessdfsdf');
        Test.stopTest();
    }
    
    @IsTest static void testSendEmail() {
        Transaction__c trans = new Transaction__c();
        insert trans;
        
        Test.startTest();
        TitleConfirmationFileUploadController.sendEmail(trans.Id, new List<String> { 'filename1', 'filename2' }, 'test@mail.com');
        Test.stopTest();
    }
    
}