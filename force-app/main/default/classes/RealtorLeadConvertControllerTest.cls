@IsTest
private class RealtorLeadConvertControllerTest {
    @IsTest
    static void testControllerDelegatesToService() {
        Id realtorLeadRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Lead'
            AND DeveloperName = 'Realtor_Lead_record_type'
            LIMIT 1
        ].Id;

        Lead leadRecord = new Lead(
            RecordTypeId = realtorLeadRecordTypeId,
            FirstName = 'Controller',
            LastName = 'Lead',
            Company = 'Controller Realty',
            Email = 'controller-test@example.com'
        );
        insert leadRecord;

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertController.convertLead(leadRecord.Id);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Controller should return a response.');
        System.assertEquals(true, response.success, 'Controller should return a successful response for eligible lead.');
        System.assertNotEquals(null, response.accountId, 'Response should include linked account id.');
    }
}