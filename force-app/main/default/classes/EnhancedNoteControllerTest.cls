/**
 * Created by toma on 9/3/2021.
 */

@IsTest
private class EnhancedNoteControllerTest {
    @TestSetup
    static void setUp(){     
        Account acc = (Account)TDF.createSObject('Account', new Map<String,Object>{
                'FirstName' => 'Test',
                'LastName' => 'Somebody',
                'PersonEmail' => 'test@email.com',
                'RecordTypeId' => [SELECT Id, Name FROM RecordType WHERE Name = 'Person Account'].Id
        });
        Transaction__c o = new Transaction__c(Borrower_Name__c=acc.Id,Name='TodaysTest',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        Enhanced_Note__c note = new Enhanced_Note__c();
        note.Transaction__c = o.Id;
        note.Subject__c = 'test';
        note.Body__c = 'testing';
        insert note;
    }

    @IsTest
    static void testBehavior() {
        Transaction__c o = [SELECT Id, Closing_Package_Sent__c FROM  Transaction__c WHERE Name = 'TodaysTest' LIMIT 1];
        List<Enhanced_Note__c> enhancedNotes  = EnhancedNotesController.getNotesRelatedToLoan(o.Id);
        System.assertEquals(1,enhancedNotes.size());
    }
    @IsTest
    static void testBehavior2(){
        Transaction__c o = [SELECT Id, Closing_Package_Sent__c FROM  Transaction__c WHERE Name = 'TodaysTest' LIMIT 1];
        List<Enhanced_Note__c> enhancedNotes  = EnhancedNotesController.getNotesRelatedToLoan(o.Id);
        EnhancedNotesController.deleteTargetNote(enhancedNotes[0].Id);
        List<Enhanced_Note__c> note = [SELECT Id,IsDeleted__c,Subject__c FROM Enhanced_Note__c WHERE Subject__c = 'test'];
        System.assertEquals(true,note[0].IsDeleted__c);
    }
    @IsTest
    static void testGetLookUpField() {
        Transaction__c o = [SELECT Id, Closing_Package_Sent__c FROM  Transaction__c WHERE Name = 'TodaysTest' LIMIT 1];
        List<Enhanced_Note__c> enhancedNotes  = EnhancedNotesController.getNotesRelatedToLoan(o.Id);
        EnhancedNotesController.getLookupField(enhancedNotes[0].Id);
    }
}