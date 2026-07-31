@IsTest
private class RealtorLeadConvertServiceTest {
    private static Id getRealtorLeadRecordTypeId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Lead'
            AND DeveloperName = 'Realtor_Lead_record_type'
            LIMIT 1
        ].Id;
    }

    private static Id getPersonAccountRecordTypeId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ].Id;
    }

    private static Lead createRealtorLead(String emailValue, String suffix) {
        Lead leadRecord = new Lead();
        leadRecord.RecordTypeId = getRealtorLeadRecordTypeId();
        leadRecord.FirstName = 'Test';
        leadRecord.LastName = 'Realtor ' + suffix;
        leadRecord.Company = 'Test Realty ' + suffix;
        leadRecord.Email = emailValue;
        leadRecord.Phone = '555-010' + suffix.right(1);
        insert leadRecord;
        return leadRecord;
    }

    private static void assertLeadLinkedToAccount(Id leadId, Id expectedAccountId) {
        Lead linkedLead = [
            SELECT Id, IsConverted, ConvertedAccountId, Follow_Up_Account__c
            FROM Lead
            WHERE Id = :leadId
        ];
        System.assertEquals(false, linkedLead.IsConverted, 'Lead should remain unconverted.');

        Boolean linkedByConvertedField = linkedLead.ConvertedAccountId == expectedAccountId;
        Boolean linkedByFollowUpField = linkedLead.Follow_Up_Account__c == expectedAccountId;
        System.assertEquals(
            true,
            linkedByConvertedField || linkedByFollowUpField,
            'Lead should link to the expected account via ConvertedAccountId or Follow_Up_Account__c.'
        );
    }

    @IsTest
    static void testCreatesPersonAccountWhenNoDuplicate() {
        Lead leadRecord = createRealtorLead('newrealtor@example.com', 'A1');

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(leadRecord.Id);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Conversion should succeed.');
        System.assertNotEquals(null, response.accountId, 'An account should be created/linked.');

        Account accountRecord = [
            SELECT Id, IsPersonAccount, Realtor_lead__c, Group__pc, Realtor_Group__c, Status__pc
            FROM Account
            WHERE Id = :response.accountId
        ];
        Lead reloadedLead = [
            SELECT Id, Status, Realtor_Group__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(true, accountRecord.IsPersonAccount, 'Created account must be a Person Account.');
        System.assertEquals(leadRecord.Id, accountRecord.Realtor_lead__c, 'Account should link back to the Lead.');
        System.assert(String.valueOf(accountRecord.get('Group__pc')).contains('Realtor'));
        System.assertEquals(reloadedLead.Realtor_Group__c, accountRecord.Realtor_Group__c);
        System.assertEquals(reloadedLead.Status, String.valueOf(accountRecord.get('Status__pc')));

        assertLeadLinkedToAccount(leadRecord.Id, response.accountId);
    }

    @IsTest
    static void testDuplicateEmailLinksExistingPersonAccount() {
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account existingPersonAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Existing',
            LastName = 'Realtor',
            PersonEmail = 'duplicate-realtor@example.com'
        );
        insert existingPersonAccount;

        Lead leadRecord = createRealtorLead('duplicate-realtor@example.com', 'B2');

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(leadRecord.Id);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Conversion should succeed.');
        System.assertEquals(existingPersonAccount.Id, response.accountId, 'Should reuse existing Person Account.');

        Integer matchingPersonAccountCount = [
            SELECT Count()
            FROM Account
            WHERE IsPersonAccount = true
            AND PersonEmail = 'duplicate-realtor@example.com'
        ];
        System.assertEquals(1, matchingPersonAccountCount, 'No additional Person Account should be created.');

        assertLeadLinkedToAccount(leadRecord.Id, existingPersonAccount.Id);
    }

    @IsTest
    static void testMissingRequiredFieldsError() {
        Lead leadRecord = createRealtorLead('missing-fields@example.com', 'C3');
        RealtorLeadConvertService.forceMissingRequiredFieldsForTest = true;

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(leadRecord.Id);
        Test.stopTest();

        RealtorLeadConvertService.forceMissingRequiredFieldsForTest = false;

        System.assertEquals(false, response.success, 'Response should fail when required fields are missing.');
        System.assertEquals('MISSING_REQUIRED_FIELDS', response.errorCode);
        System.assert(response.userMessage.contains('Missing required fields'), 'User message should list missing fields.');
    }

    @IsTest
    static void testConvertedAccountFallbackToFollowUpAccount() {
        Lead leadRecord = createRealtorLead('fallback@example.com', 'D4');
        RealtorLeadConvertService.forceConvertedAccountLinkFailureForTest = true;

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(leadRecord.Id);
        Test.stopTest();

        RealtorLeadConvertService.forceConvertedAccountLinkFailureForTest = false;

        System.assertEquals(true, response.success, 'Conversion should still succeed with fallback link.');
        System.assertEquals(true, response.usedFollowUpFallback, 'Fallback flag should be true when ConvertedAccountId fails.');

        Lead reloadedLead = [
            SELECT Id, ConvertedAccountId, Follow_Up_Account__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(null, reloadedLead.ConvertedAccountId, 'ConvertedAccountId should remain unset in forced fallback path.');
        System.assertEquals(response.accountId, reloadedLead.Follow_Up_Account__c, 'Fallback link should use Follow_Up_Account__c.');
    }

    @IsTest
    static void testNoEmailCreatesPersonAccount() {
        Lead leadRecord = createRealtorLead(null, 'E5');

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(leadRecord.Id);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Create should succeed when Lead email is blank.');
        System.assertNotEquals(null, response.accountId, 'A Person Account should still be created.');
        assertLeadLinkedToAccount(leadRecord.Id, response.accountId);
    }

    @IsTest
    static void testNotEligibleForNonRealtorLead() {
        Id nonRealtorRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Lead'
            AND DeveloperName != 'Realtor_Lead_record_type'
            LIMIT 1
        ].Id;

        Lead nonRealtorLead = new Lead(
            RecordTypeId = nonRealtorRecordTypeId,
            FirstName = 'Non',
            LastName = 'Realtor',
            Company = 'Test Company'
        );
        insert nonRealtorLead;

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(nonRealtorLead.Id);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Non-realtor lead should be ineligible.');
        System.assertEquals('NOT_ELIGIBLE', response.errorCode);
    }

    @IsTest
    static void testUnexpectedErrorPath() {
        RealtorLeadConvertService.forceUnhandledExceptionForTest = true;

        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(null);
        Test.stopTest();

        RealtorLeadConvertService.forceUnhandledExceptionForTest = false;

        System.assertEquals(false, response.success);
        System.assertEquals('UNEXPECTED_ERROR', response.errorCode);
    }

    @IsTest
    static void testLeadNotFoundPath() {
        Test.startTest();
        RealtorLeadConvertService.ConvertResponse response = RealtorLeadConvertService.convertLead(null);
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('NOT_ELIGIBLE', response.errorCode);
    }
}