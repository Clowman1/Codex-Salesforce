@IsTest
private class AccountRecordHeroControllerTest {
    @IsTest
    static void createPastClientLeadUsesSelectedLoanPurpose() {
        Account accountRecord = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            FirstName = 'Karen',
            LastName = 'Ozuna-Aracena',
            PersonEmail = 'karen.ozuna@example.com',
            Phone = '5551234567',
            PersonMobilePhone = '5559876543',
            PersonLeadSource = 'Past Client'
        );
        insert accountRecord;

        Test.startTest();
        Id leadId = AccountRecordHeroController.createPastClientLead(accountRecord.Id, 'Purchase');
        Test.stopTest();

        Lead leadRecord = [
            SELECT FirstName, LastName, Company, Email, Phone, MobilePhone, LeadSource,
                Loan_Purpose__c, Biz_Dev__c, Branch__c, RecordType.DeveloperName
            FROM Lead
            WHERE Id = :leadId
        ];

        System.assertEquals('Karen', leadRecord.FirstName);
        System.assertEquals('Ozuna-Aracena', leadRecord.LastName);
        System.assertEquals('karen.ozuna@example.com', leadRecord.Email);
        System.assertNotEquals(null, leadRecord.Phone);
        System.assertNotEquals(null, leadRecord.MobilePhone);
        System.assertEquals('Past Client', leadRecord.LeadSource);
        System.assertEquals('Purchase', leadRecord.Loan_Purpose__c);
        System.assertEquals('Biz Dev - Reach', leadRecord.Biz_Dev__c);
        System.assertEquals('Boca Raton', leadRecord.Branch__c);
        System.assertNotEquals(null, leadRecord.RecordType.DeveloperName);
    }

    @IsTest
    static void createPastClientLeadRejectsMissingPurpose() {
        Account accountRecord = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            FirstName = 'Purpose',
            LastName = 'Required',
            PersonEmail = 'purpose.required@example.com'
        );
        insert accountRecord;

        try {
            AccountRecordHeroController.createPastClientLead(accountRecord.Id, null);
            System.assert(false, 'Expected missing loan purpose to throw an exception.');
        } catch (AuraHandledException expectedException) {
            System.assertNotEquals(null, expectedException);
        }
    }

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> personAccountRecordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ];
        System.assert(!personAccountRecordTypes.isEmpty(), 'Person Account record type is required for this test.');
        return personAccountRecordTypes[0].Id;
    }
}
