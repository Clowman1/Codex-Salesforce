@IsTest
private class TransactionUtmCopyServiceTest {
    @IsTest
    static void copiesBlankUtmFieldsOnly() {
        Lead sourceLead = new Lead(
            FirstName = 'Utm',
            LastName = 'Borrower',
            Company = 'Utm Borrower',
            First_UTM_Source__c = 'meta',
            First_UTM_Medium__c = 'paid_social',
            First_UTM_Campaign__c = 'campaign-1',
            First_UTM_Term__c = 'term-1',
            First_UTM_Content__c = 'content-1',
            Last_UTM_Source__c = 'last-source',
            Last_UTM_Medium__c = 'last-medium',
            Last_UTM_Campaign__c = 'last-campaign',
            Last_UTM_Term__c = 'last-term',
            Last_UTM_Content__c = 'last-content',
            Meta_Campaign_ID__c = 'meta-campaign',
            Meta_Adset_ID__c = 'meta-adset',
            Meta_Ad_ID__c = 'meta-ad',
            Hyros_Ad_ID__c = 'hyros-ad',
            FB_Click_ID__c = 'fb-click',
            Source_URL__c = 'https://example.com/source',
            Form_Name__c = 'Example Form',
            Landing_Page__c = 'https://example.com/landing',
            Referrer__c = 'https://example.com/referrer'
        );

        Transaction__c target = new Transaction__c(
            First_UTM_Source__c = null,
            First_UTM_Medium__c = 'do-not-overwrite'
        );

        Boolean changed = TransactionUtmCopyService.copyBlankUtmFields(target, target, sourceLead);

        System.assertEquals(true, changed, 'Expected at least one UTM value to be copied.');
        System.assertEquals('meta', target.First_UTM_Source__c);
        System.assertEquals('do-not-overwrite', target.First_UTM_Medium__c, 'Existing populated values should not be overwritten.');
        System.assertEquals('campaign-1', target.First_UTM_Campaign__c);
        System.assertEquals('last-term', target.Last_UTM_Term__c);
        System.assertEquals('meta-campaign', target.Meta_Campaign_ID__c);
        System.assertEquals('https://example.com/source', target.Source_URL__c);
        System.assertEquals('Example Form', target.Form_Name__c);
        System.assertEquals('https://example.com/landing', target.Landing_Page__c);
        System.assertEquals('https://example.com/referrer', target.Referrer__c);
    }

    @IsTest
    static void transactionTriggerInvokesUtmSafetyPath() {
        Account lender = new Account(
            Name = 'UTM Trigger Coverage Lender',
            Type = 'Investor'
        );
        insert lender;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'UTM Trigger Coverage',
            Status__c = 'Processing',
            Lender_lookup__c = lender.Id
        );

        insert transactionRecord;

        transactionRecord.Status__c = 'Submitted';
        update transactionRecord;

        Transaction__c refreshed = [
            SELECT Current_Status_Since__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];
        System.assertEquals(Date.today(), refreshed.Current_Status_Since__c);
    }

    @IsTest
    static void triggerCopiesFromConvertedLeadByAccount() {
        Account lender = new Account(
            Name = 'UTM Converted Lead Lender',
            Type = 'Investor'
        );
        insert lender;
        User loanPartner = createUser('utmlp');

        Lead sourceLead = new Lead(
            FirstName = 'Converted',
            LastName = 'Borrower',
            Company = 'Converted Borrower',
            First_UTM_Source__c = 'converted-source',
            First_UTM_Medium__c = 'converted-medium',
            Last_UTM_Term__c = 'converted-last-term',
            Meta_Campaign_ID__c = 'converted-meta-campaign',
            Source_URL__c = 'https://example.com/converted-source'
        );
        insert sourceLead;
        update new Lead(Id = sourceLead.Id, Loan_Partner__c = loanPartner.Id);

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
            Name = 'UTM Converted Lead Transaction',
            Status__c = 'Processing',
            Borrower_Name__c = convertResult.getAccountId(),
            Account__c = convertResult.getAccountId(),
            Lender_lookup__c = lender.Id,
            First_UTM_Medium__c = 'keep-existing'
        );

        Test.startTest();
        insert transactionRecord;
        Test.stopTest();

        Transaction__c refreshed = [
            SELECT First_UTM_Source__c, First_UTM_Medium__c, Last_UTM_Term__c,
                Meta_Campaign_ID__c, Source_URL__c, Loan_Partner__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];
        System.assertEquals('converted-source', refreshed.First_UTM_Source__c);
        System.assertEquals('keep-existing', refreshed.First_UTM_Medium__c, 'Existing populated values should not be overwritten.');
        System.assertEquals('converted-last-term', refreshed.Last_UTM_Term__c);
        System.assertEquals('converted-meta-campaign', refreshed.Meta_Campaign_ID__c);
        System.assertEquals('https://example.com/converted-source', refreshed.Source_URL__c);
        System.assertEquals(loanPartner.Id, refreshed.Loan_Partner__c, 'Converted Lead Loan Partner should stamp the new Transaction.');
    }

    @IsTest
    static void transactionOwnerChangeDoesNotChangeSelectedLoanPartner() {
        User selectedLoanPartner = createUser('selectedlp');
        User newOwner = createUser('newowner');
        Account lender = new Account(
            Name = 'Owner Change Lender',
            Type = 'Investor'
        );
        insert lender;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Owner Change Transaction',
            Status__c = 'Processing',
            Lender_lookup__c = lender.Id,
            Loan_Partner__c = selectedLoanPartner.Id
        );
        insert transactionRecord;

        Test.startTest();
        update new Transaction__c(
            Id = transactionRecord.Id,
            OwnerId = newOwner.Id
        );
        Test.stopTest();

        Transaction__c refreshed = [
            SELECT OwnerId, Loan_Partner__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];
        System.assertEquals(newOwner.Id, refreshed.OwnerId);
        System.assertEquals(
            selectedLoanPartner.Id,
            refreshed.Loan_Partner__c,
            'Changing Transaction Owner must not change the selected Loan Partner.'
        );
    }

    private static User createUser(String prefix) {
        String uniqueValue = prefix + String.valueOf(System.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User testUser = new User(
            Alias = uniqueValue.left(8),
            Email = uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = prefix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            Username = uniqueValue + '@example.com'
        );
        insert testUser;
        return testUser;
    }
}
