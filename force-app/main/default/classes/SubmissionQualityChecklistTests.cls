@IsTest
public class SubmissionQualityChecklistTests {

    @IsTest static void testGetExistingChecklist() {
        Transaction__c t = new Transaction__c();
        t.Name = 'Test';
        insert t;
        
        Test.startTest();
        SubmissionQualityChecklistController.getChecklistItems();
        SubmissionQualityChecklistController.getExistingChecklist(t.Id);
        SubmissionQualityChecklistController.saveChecklistAnswers(t.Id, new Map<String, String> { 'VA_specific_disclosures__c' => 'Yes' });
        Test.stopTest();
    }
}