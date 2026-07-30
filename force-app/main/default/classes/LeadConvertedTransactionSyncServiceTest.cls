@IsTest
private class LeadConvertedTransactionSyncServiceTest {
    @IsTest
    static void syncsLoanPartnerWhenConvertedTransactionLinkIsStamped() {
        User leadLoanPartner = createUser('leadlp');
        User incorrectPartner = createUser('wronglp');

        Account lender = new Account(
            Name = 'Lead Conversion Sync Lender',
            Type = 'Investor'
        );
        insert lender;

        Lead sourceLead = new Lead(
            FirstName = 'Sync',
            LastName = 'Borrower',
            Company = 'Sync Borrower'
        );
        insert sourceLead;
        update new Lead(Id = sourceLead.Id, Loan_Partner__c = leadLoanPartner.Id);

        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];

        Database.LeadConvert leadConvert = new Database.LeadConvert();
        leadConvert.setLeadId(sourceLead.Id);
        leadConvert.setConvertedStatus(convertedStatus.MasterLabel);
        leadConvert.setDoNotCreateOpportunity(true);

        Database.LeadConvertResult convertResult = Database.convertLead(leadConvert);
        System.assert(convertResult.isSuccess(), 'Lead conversion should succeed in test setup.');

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Lead Conversion Sync Transaction',
            Status__c = 'Processing',
            Borrower_Name__c = convertResult.getAccountId(),
            Account__c = convertResult.getAccountId(),
            Lender_lookup__c = lender.Id,
            Loan_Partner__c = incorrectPartner.Id
        );
        insert transactionRecord;

        Test.startTest();
        update new Lead(
            Id = sourceLead.Id,
            Converted_Transaction_ID__c = transactionRecord.Id
        );
        Test.stopTest();

        Transaction__c refreshed = [
            SELECT Loan_Partner__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];
        System.assertEquals(leadLoanPartner.Id, refreshed.Loan_Partner__c);
    }

    @IsTest
    static void syncsLoanPartnerByConvertedAccountWhenTransactionLinkIsMissing() {
        User leadLoanPartner = createUser('acctlp');

        Account lender = new Account(
            Name = 'Lead Conversion Account Sync Lender',
            Type = 'Investor'
        );
        insert lender;

        Lead sourceLead = new Lead(
            FirstName = 'Account',
            LastName = 'Borrower',
            Company = 'Account Borrower'
        );
        insert sourceLead;
        update new Lead(Id = sourceLead.Id, Loan_Partner__c = leadLoanPartner.Id);

        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];

        Database.LeadConvert leadConvert = new Database.LeadConvert();
        leadConvert.setLeadId(sourceLead.Id);
        leadConvert.setConvertedStatus(convertedStatus.MasterLabel);
        leadConvert.setDoNotCreateOpportunity(true);

        Database.LeadConvertResult convertResult = Database.convertLead(leadConvert);
        System.assert(convertResult.isSuccess(), 'Lead conversion should succeed in test setup.');

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Lead Conversion Account Sync Transaction',
            Status__c = 'Processing',
            Borrower_Name__c = convertResult.getAccountId(),
            Account__c = convertResult.getAccountId(),
            Lender_lookup__c = lender.Id
        );
        insert transactionRecord;

        Lead convertedLead = [
            SELECT Id, IsConverted, ConvertedAccountId, Converted_Transaction_ID__c, Loan_Partner__c
            FROM Lead
            WHERE Id = :sourceLead.Id
        ];

        Test.startTest();
        LeadConvertedTransactionSyncService.syncLoanPartnerToConvertedTransactions(
            new List<Lead>{ convertedLead },
            new Map<Id, Lead>{ convertedLead.Id => new Lead(Id = convertedLead.Id) }
        );
        Test.stopTest();

        Transaction__c refreshed = [
            SELECT Loan_Partner__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];
        System.assertEquals(leadLoanPartner.Id, refreshed.Loan_Partner__c);
    }

    private static User createUser(String prefix) {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];
        String uniqueValue = prefix + String.valueOf(System.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User testUser = new User(
            Alias = uniqueValue.left(8),
            Email = uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = prefix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniqueValue + '@example.com'
        );
        insert testUser;
        return testUser;
    }
}
