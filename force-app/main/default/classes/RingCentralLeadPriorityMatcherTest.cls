@IsTest
private class RingCentralLeadPriorityMatcherTest {
    @IsTest
    static void testNewestOpenLeadSelectedByNormalizedPhone() {
        Lead olderLead = new Lead(FirstName = 'Old', LastName = 'Lead', Phone = '(813) 555-1111');
        Lead newerLead = new Lead(FirstName = 'New', LastName = 'Lead', MobilePhone = '+1 813-555-1111');
        insert new List<Lead>{ olderLead, newerLead };

        Test.setCreatedDate(olderLead.Id, System.now().addDays(-2));
        Test.setCreatedDate(newerLead.Id, System.now().addDays(-1));

        String incomingPhone = '+1 (813) 555-1111';
        String normalized = RingCentralLeadPriorityMatcher.normalizePhoneNumber(incomingPhone);
        Map<String, Id> openLeadMap = RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(
            new Set<String>{ incomingPhone }
        );

        System.assertEquals(newerLead.Id, openLeadMap.get(normalized), 'Newest open Lead should be selected.');
    }

    @IsTest
    static void testTaskRelationshipLeadPriorityAndFallback() {
        Account accountRow = new Account(Name = 'Fallback Account');
        insert accountRow;

        Contact fallbackContact = new Contact(FirstName = 'Fallback', LastName = 'Contact', Phone = '813-555-2222', AccountId = accountRow.Id);
        insert fallbackContact;

        Lead openLead = new Lead(FirstName = 'Lead', LastName = 'Preferred', MobilePhone = '8135552222');
        insert openLead;

        String incomingPhone = '(813) 555-2222';
        String normalized = RingCentralLeadPriorityMatcher.normalizePhoneNumber(incomingPhone);

        Map<String, Id> leadMap = new Map<String, Id>{ normalized => openLead.Id };
        Map<String, Id> contactMap = new Map<String, Id>{ normalized => fallbackContact.Id };
        Map<String, Id> whatMap = new Map<String, Id>{ normalized => accountRow.Id };

        Map<String, Id> smsLeadResolution = RingCentralLogSMS.resolveTaskRelationship(incomingPhone, leadMap, contactMap, whatMap);
        System.assertEquals(openLead.Id, smsLeadResolution.get('whoId'));
        System.assertEquals(null, smsLeadResolution.get('whatId'));

        Map<String, Id> callLeadResolution = GetRingCentralCallLog.resolveTaskRelationship(incomingPhone, leadMap, contactMap, whatMap);
        System.assertEquals(openLead.Id, callLeadResolution.get('whoId'));
        System.assertEquals(null, callLeadResolution.get('whatId'));

        Map<String, Id> smsFallbackResolution = RingCentralLogSMS.resolveTaskRelationship(incomingPhone, new Map<String, Id>(), contactMap, whatMap);
        System.assertEquals(fallbackContact.Id, smsFallbackResolution.get('whoId'));
        System.assertEquals(accountRow.Id, smsFallbackResolution.get('whatId'));

        Map<String, Id> callFallbackResolution = GetRingCentralCallLog.resolveTaskRelationship(incomingPhone, new Map<String, Id>(), contactMap, whatMap);
        System.assertEquals(fallbackContact.Id, callFallbackResolution.get('whoId'));
        System.assertEquals(accountRow.Id, callFallbackResolution.get('whatId'));
    }

    @IsTest
    static void testInvocableResolvesLeadAndAccount() {
        Account firstAccount = new Account(Name = 'First Account');
        Account secondAccount = new Account(Name = 'Second Account');
        insert new List<Account>{ firstAccount, secondAccount };

        Contact firstContact = new Contact(FirstName = 'First', LastName = 'Contact', Phone = '+1 813-555-3333', AccountId = firstAccount.Id);
        Contact secondContact = new Contact(FirstName = 'Second', LastName = 'Contact', MobilePhone = '+1 813-555-4444', AccountId = secondAccount.Id);
        insert new List<Contact>{ firstContact, secondContact };

        Lead leadMatch = new Lead(FirstName = 'Primary', LastName = 'Lead', MobilePhone = '8135553333');
        insert leadMatch;

        RingSenseRelateCallInsightInvocable.Input firstInput = new RingSenseRelateCallInsightInvocable.Input();
        firstInput.callInsightId = UserInfo.getUserId();
        firstInput.recipientPhoneNumber = '(813) 555-3333';

        RingSenseRelateCallInsightInvocable.Input secondInput = new RingSenseRelateCallInsightInvocable.Input();
        secondInput.callInsightId = UserInfo.getUserId();
        secondInput.recipientPhoneNumber = '(813) 555-4444';

        List<RingSenseRelateCallInsightInvocable.Output> outputs = RingSenseRelateCallInsightInvocable.resolveRelationships(
            new List<RingSenseRelateCallInsightInvocable.Input>{ firstInput, secondInput }
        );

        System.assertEquals(2, outputs.size());
        System.assertEquals(leadMatch.Id, outputs[0].leadId, 'Lead should be populated when open lead matches.');
        System.assertEquals(firstAccount.Id, outputs[0].accountId, 'Account should still be populated alongside lead.');
        System.assertEquals(null, outputs[0].transactionId, 'Transaction is null when no active transaction exists.');

        System.assertEquals(null, outputs[1].leadId, 'No lead should be returned when no lead matches.');
        System.assertEquals(secondAccount.Id, outputs[1].accountId, 'Fallback account should be returned via contact match.');
    }

    @IsTest
    static void testNurtureLeadIsNeverMatchedByPhone() {
        Lead nurtureLead = new Lead(
            FirstName = 'Nurtured',
            LastName = 'Borrower',
            MobilePhone = '8135558888',
            Status = 'Nurturing'
        );
        Lead nurturePreApprovalLead = new Lead(
            FirstName = 'Nurture',
            LastName = 'PreApproval',
            MobilePhone = '8135559999',
            Status = 'Nurture - Preapproval'
        );
        insert new List<Lead>{ nurtureLead, nurturePreApprovalLead };

        System.assertEquals(
            0,
            RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(new Set<String>{ '+1 (813) 555-8888' }).size(),
            'A Nurturing lead must never be matched for call logging.'
        );
        System.assertEquals(
            0,
            RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(new Set<String>{ '+1 (813) 555-9999' }).size(),
            'A Nurture - Preapproval lead must never be matched for call logging.'
        );
    }

    @IsTest
    static void testMatcherNullAndEmptyInputs() {
        System.assertEquals(null, RingCentralLeadPriorityMatcher.normalizePhoneNumber(null));
        System.assertEquals(null, RingCentralLeadPriorityMatcher.normalizePhoneNumber(''));

        System.assertEquals(0, RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(new Set<String>()).size());
        System.assertEquals(0, RingCentralLeadPriorityMatcher.getContactIdsByPhoneNumbers(null).size());
        System.assertEquals(0, RingCentralLeadPriorityMatcher.getTransactionIdsByPhoneNumbers(new Set<String>()).size());
        System.assertEquals(0, RingCentralLeadPriorityMatcher.getAccountIdsByContactIds(new Set<Id>()).size());
        System.assertEquals(0, RingCentralLeadPriorityMatcher.getMostRecentActiveTransactionByAccountIds(null).size());
    }
}