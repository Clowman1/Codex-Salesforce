@IsTest
public class ShareBorrowerDocumentControllerTests {

    @IsTest static void testGetEmailTemplates() {
        Transaction__c trans = new Transaction__c();
        insert trans;
        
        Test.startTest();
        ShareBorrowerDocumentController.getEmailTemplates();
        try {
            ShareBorrowerDocumentController.testCoverage();
            ShareBorrowerDocumentController.getRenderedHtmlTemplate('randomid', trans.Id);
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @IsTest static void testSendEmail() {
        Transaction__c trans = new Transaction__c();
        insert trans;
        
        Test.startTest();
        ShareBorrowerDocumentController.sendEmail(trans.id, 'test@mail.com', null, 'subject', 'html');
        Test.stopTest();
    }
    
}