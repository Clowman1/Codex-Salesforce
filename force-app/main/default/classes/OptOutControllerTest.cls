@IsTest
private class OptOutControllerTest {
    @IsTest
    static void handleOptOutUpdatesMatchingLeadAndContact() {
        String optOutEmail = 'borrower@example.com';
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;

        Lead leadRecord = new Lead(
            LastName = 'Borrower',
            Company = 'Example Co',
            Email = optOutEmail
        );
        Database.insert(leadRecord, dmlOptions);

        Account accountRecord = new Account(Name = 'Borrower Household');
        insert accountRecord;

        Contact contactRecord = new Contact(
            LastName = 'Borrower',
            AccountId = accountRecord.Id,
            Email = optOutEmail
        );
        Database.insert(contactRecord, dmlOptions);

        Test.startTest();
        OptOutController.handleOptOut('  ' + optOutEmail + '  ');
        Test.stopTest();

        Lead refreshedLead = [
            SELECT HasOptedOutOfEmail
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        Contact refreshedContact = [
            SELECT HasOptedOutOfEmail
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];

        System.assertEquals(true, refreshedLead.HasOptedOutOfEmail);
        System.assertEquals(true, refreshedContact.HasOptedOutOfEmail);
    }

    @IsTest
    static void handleOptOutRequiresEmail() {
        Boolean threwError = false;

        Test.startTest();
        try {
            OptOutController.handleOptOut(null);
        } catch (AuraHandledException ex) {
            threwError = true;
            System.assert(ex.getMessage().contains('No email param') || ex.getMessage().contains('Script-thrown exception'));
        }
        Test.stopTest();

        System.assertEquals(true, threwError);
    }

    @IsTest
    static void handleOptOutWrapsUnexpectedExceptions() {
        Boolean threwWrappedError = false;

        OptOutController.forceUnexpectedExceptionForTest = true;
        Test.startTest();
        try {
            OptOutController.handleOptOut('borrower@example.com');
        } catch (AuraHandledException ex) {
            threwWrappedError = true;
            System.assert(ex.getMessage().contains('Forced opt out failure') || ex.getMessage().contains('Script-thrown exception'));
        } finally {
            OptOutController.forceUnexpectedExceptionForTest = false;
        }
        Test.stopTest();

        System.assertEquals(true, threwWrappedError);
    }
}