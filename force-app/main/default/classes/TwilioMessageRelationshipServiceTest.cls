@IsTest
private class TwilioMessageRelationshipServiceTest {
    @IsTest
    static void relateByMessageIds_empty_is_noop() {
        Test.startTest();
        TwilioMessageRelationshipService.relateByMessageIds(new Set<Id>());
        TwilioMessageRelationshipService.reassignOutboundOwnerByMessageIds(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'no exception');
    }

    @IsTest
    static void resolveClientPhone_inbound_uses_from_number() {
        TwilioSF__Message__c m = new TwilioSF__Message__c();
        m.TwilioSF__Direction__c = 'inbound';
        m.TwilioSF__From_Number_Unformatted__c = '+15551112222';
        m.TwilioSF__To_Number_Unformatted__c = '+15553334444';
        System.assertEquals('+15551112222', TwilioMessageRelationshipService.resolveClientPhone(m));
    }

    @IsTest
    static void resolveClientPhone_outbound_api_uses_to_number() {
        TwilioSF__Message__c m = new TwilioSF__Message__c();
        m.TwilioSF__Direction__c = 'outbound-api';
        m.TwilioSF__From_Number_Unformatted__c = '+15551112222';
        m.TwilioSF__To_Number_Unformatted__c = '+15559998888';
        System.assertEquals('+15559998888', TwilioMessageRelationshipService.resolveClientPhone(m));
    }

    @IsTest
    static void resolveClientPhone_other_direction_falls_back_to_from_then_to() {
        TwilioSF__Message__c m1 = new TwilioSF__Message__c();
        m1.TwilioSF__Direction__c = 'status-callback';
        m1.TwilioSF__From_Number_Unformatted__c = '+15550000001';
        m1.TwilioSF__To_Number_Unformatted__c = '+15550000002';
        System.assertEquals('+15550000001', TwilioMessageRelationshipService.resolveClientPhone(m1));

        TwilioSF__Message__c m2 = new TwilioSF__Message__c();
        m2.TwilioSF__Direction__c = 'status-callback';
        m2.TwilioSF__To_Number_Unformatted__c = '+15550000099';
        System.assertEquals('+15550000099', TwilioMessageRelationshipService.resolveClientPhone(m2));
    }

    @IsTest
    static void getAutomatedProcessUserId_returns_user_and_caches() {
        Test.startTest();
        Id first = TwilioMessageRelationshipService.getAutomatedProcessUserId();
        Id second = TwilioMessageRelationshipService.getAutomatedProcessUserId();
        Test.stopTest();
        System.assertEquals(first, second, 'Cached result should match');
    }

    @IsTest
    static void reassignOutboundOwner_early_exit_when_owner_not_automated_process() {
        // Message owned by the running user (not Automated Process), so SOQL filter returns empty -> no-op, no exception.
        Account a = new Account(Name = 'Owner Early Exit Co');
        insert a;
        Contact c = new Contact(FirstName = 'Owner', LastName = 'Early', AccountId = a.Id, Phone = '+18135557777');
        insert c;
        Transaction__c t = new Transaction__c(
            Name = 'Owner Early Exit Txn', Account__c = a.Id, Borrower_Name__c = a.Id
        );
        insert t;

        TwilioSF__Message__c msg = new TwilioSF__Message__c(
            TwilioSF__Direction__c = 'outbound-api',
            TwilioSF__From_Number__c = '+14155550000',
            TwilioSF__From_Number_Unformatted__c = '4155550000',
            TwilioSF__To_Number__c = '+18135557777',
            TwilioSF__To_Number_Unformatted__c = '8135557777',
            TwilioSF__Body__c = 'owner early exit',
            TwilioSF__SF_Parent_Record_Id__c = String.valueOf(t.Id),
            TwilioSF__Message_SID__c = 'SMowner_exit'
        );
        insert msg;

        Id ownerBefore = [SELECT OwnerId FROM TwilioSF__Message__c WHERE Id = :msg.Id].OwnerId;

        Test.startTest();
        TwilioMessageRelationshipService.reassignOutboundOwnerByMessageIds(new Set<Id>{ msg.Id });
        Test.stopTest();

        Id ownerAfter = [SELECT OwnerId FROM TwilioSF__Message__c WHERE Id = :msg.Id].OwnerId;
        System.assertEquals(ownerBefore, ownerAfter, 'Owner should stay unchanged because filter excluded the row');
    }

    @IsTest
    static void reassignOutboundOwner_reassigns_to_transaction_last_modified_by() {
        // Override Automated Process user so the SOQL filter matches the running user's messages.
        TwilioMessageRelationshipService.automatedProcessOverrideForTest = UserInfo.getUserId();

        Account a = new Account(Name = 'Reassign Owner Co');
        insert a;
        Transaction__c t = new Transaction__c(
            Name = 'Reassign Owner Txn', Account__c = a.Id, Borrower_Name__c = a.Id
        );
        insert t;

        TwilioSF__Message__c msg = new TwilioSF__Message__c(
            TwilioSF__Direction__c = 'outbound-api',
            TwilioSF__From_Number__c = '+14155550000',
            TwilioSF__From_Number_Unformatted__c = '4155550000',
            TwilioSF__To_Number__c = '+18135558888',
            TwilioSF__To_Number_Unformatted__c = '8135558888',
            TwilioSF__Body__c = 'owner reassign test',
            TwilioSF__SF_Parent_Record_Id__c = String.valueOf(t.Id),
            TwilioSF__Message_SID__c = 'SMreassign'
        );
        insert msg;

        Test.startTest();
        TwilioMessageRelationshipService.reassignOutboundOwnerByMessageIds(new Set<Id>{ msg.Id });
        Test.stopTest();

        Transaction__c refreshed = [SELECT LastModifiedById FROM Transaction__c WHERE Id = :t.Id];
        Id after = [SELECT OwnerId FROM TwilioSF__Message__c WHERE Id = :msg.Id].OwnerId;
        System.assertEquals(refreshed.LastModifiedById, after,
            'Owner should be Transaction.LastModifiedById after reassignment');
    }

    @IsTest
    static void reassignOutboundOwner_skips_when_parent_not_transaction() {
        // Parent id is a real Lead Id (00Q...) -> isLikelyTransactionId = false -> txnIds empty -> early exit, no update.
        TwilioMessageRelationshipService.automatedProcessOverrideForTest = UserInfo.getUserId();

        Lead l = new Lead(
            FirstName = 'ParentNotTxn', LastName = 'X', Company = 'X',
            Phone = '+18135556666', Status = 'Open - Not Contacted'
        );
        insert l;

        TwilioSF__Message__c msg = new TwilioSF__Message__c(
            TwilioSF__Direction__c = 'outbound-api',
            TwilioSF__From_Number__c = '+14155550000',
            TwilioSF__From_Number_Unformatted__c = '4155550000',
            TwilioSF__To_Number__c = '+18135556666',
            TwilioSF__To_Number_Unformatted__c = '8135556666',
            TwilioSF__Body__c = 'parent is lead',
            TwilioSF__SF_Parent_Record_Id__c = String.valueOf(l.Id),
            TwilioSF__Message_SID__c = 'SMparent_lead'
        );
        insert msg;

        Id ownerBefore = [SELECT OwnerId FROM TwilioSF__Message__c WHERE Id = :msg.Id].OwnerId;
        Test.startTest();
        TwilioMessageRelationshipService.reassignOutboundOwnerByMessageIds(new Set<Id>{ msg.Id });
        Test.stopTest();
        Id ownerAfter = [SELECT OwnerId FROM TwilioSF__Message__c WHERE Id = :msg.Id].OwnerId;
        System.assertEquals(ownerBefore, ownerAfter, 'Owner stays unchanged when parent is not a Transaction');
    }

    @IsTest
    static void relateByMessageIds_unknown_id_is_noop() {
        // Build a fake TwilioSF__Message__c Id (correct key prefix) that does not exist so queryMessages returns empty.
        String prefix = TwilioSF__Message__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = (Id) (prefix + '000000000000AAA');
        Test.startTest();
        TwilioMessageRelationshipService.relateByMessageIds(new Set<Id>{ fakeId });
        Test.stopTest();
        System.assert(true, 'empty-rows path should not throw');
    }

    @IsTest
    static void relateByMessageIds_matches_by_phone_when_no_lead() {
        // Account + Contact exist but the message has NO Lead reference. Relationship must still resolve via phone.
        Account a = new Account(Name = 'Phone Match Co');
        insert a;
        Contact c = new Contact(FirstName = 'Phone', LastName = 'Match', AccountId = a.Id, Phone = '+18135559911');
        insert c;
        Transaction__c t = new Transaction__c(
            Name = 'Phone Match Txn', Account__c = a.Id, Borrower_Name__c = a.Id
        );
        insert t;

        TwilioSF__Message__c msg = new TwilioSF__Message__c(
            TwilioSF__Direction__c = 'inbound',
            TwilioSF__From_Number__c = '+18135559911',
            TwilioSF__From_Number_Unformatted__c = '18135559911',
            TwilioSF__To_Number__c = '+14155550000',
            TwilioSF__To_Number_Unformatted__c = '14155550000',
            TwilioSF__Body__c = 'phone-only match',
            TwilioSF__Message_SID__c = 'SMphone_match'
        );
        insert msg;

        Test.startTest();
        TwilioMessageRelationshipService.relateByMessageIds(new Set<Id>{ msg.Id });
        Test.stopTest();

        TwilioSF__Message__c after = [
            SELECT TwilioSF__Account__c, TwilioSF__Contact__c, TwilioSF__SF_Parent_Record_Id__c
            FROM TwilioSF__Message__c WHERE Id = :msg.Id
        ];
        System.assertEquals(c.Id, after.TwilioSF__Contact__c, 'Contact should be stamped from phone match');
        System.assertEquals(a.Id, after.TwilioSF__Account__c, 'Account should be stamped from phone match');
        System.assertEquals(String.valueOf(t.Id), after.TwilioSF__SF_Parent_Record_Id__c, 'Parent should be Transaction Id');
    }

    @IsTest
    static void relateByMessageIds_replaces_lead_style_parent_with_transaction() {
        // SF_Parent_Record_Id__c initially points at a Lead (00Q...) — service must upgrade it to Transaction after match.
        Account a = new Account(Name = 'Replace Parent Co');
        insert a;
        Contact c = new Contact(FirstName = 'Replace', LastName = 'Parent', AccountId = a.Id, Phone = '+18135552002');
        insert c;
        Transaction__c t = new Transaction__c(
            Name = 'Replace Parent Txn', Account__c = a.Id, Borrower_Name__c = a.Id
        );
        insert t;

        // A fake 00Q-prefixed Id is not needed — any blank lead is fine; use a real Lead Id.
        Lead leadStub = new Lead(
            FirstName = 'LeadStub', LastName = 'X', Company = 'X', Phone = '+18135552002', Status = 'Open - Not Contacted'
        );
        insert leadStub;

        TwilioSF__Message__c msg = new TwilioSF__Message__c(
            TwilioSF__Direction__c = 'inbound',
            TwilioSF__From_Number__c = '+18135552002',
            TwilioSF__From_Number_Unformatted__c = '18135552002',
            TwilioSF__To_Number__c = '+14155550000',
            TwilioSF__To_Number_Unformatted__c = '14155550000',
            TwilioSF__Body__c = 'replace parent id',
            TwilioSF__SF_Parent_Record_Id__c = String.valueOf(leadStub.Id),
            TwilioSF__Message_SID__c = 'SMreplace_parent'
        );
        insert msg;

        Test.startTest();
        TwilioMessageRelationshipService.relateByMessageIds(new Set<Id>{ msg.Id });
        Test.stopTest();

        TwilioSF__Message__c after = [
            SELECT TwilioSF__SF_Parent_Record_Id__c FROM TwilioSF__Message__c WHERE Id = :msg.Id
        ];
        System.assertEquals(String.valueOf(t.Id), after.TwilioSF__SF_Parent_Record_Id__c,
            'Lead-style parent id should be upgraded to Transaction Id');
    }

    @IsTest
    static void relateByMessageIds_stamps_account_contact_from_converted_lead() {
        Lead l = new Lead(
            FirstName = 'MsgRel',
            LastName = 'Test',
            Company = 'MsgRel Co',
            Phone = '+18135550001',
            Status = 'Open - Not Contacted'
        );
        insert l;

        LeadStatus convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus(convertedStatus.MasterLabel);
        lc.setDoNotCreateOpportunity(true);
        Database.LeadConvertResult r = Database.convertLead(lc);
        System.assertEquals(true, r.isSuccess());

        TwilioSF__Message__c msg = new TwilioSF__Message__c(
            TwilioSF__Direction__c = 'outbound-api',
            TwilioSF__From_Number__c = '+14155551234',
            TwilioSF__From_Number_Unformatted__c = '4155551234',
            TwilioSF__To_Number__c = '+18135550001',
            TwilioSF__To_Number_Unformatted__c = '8135550001',
            TwilioSF__Body__c = 'test',
            TwilioSF__Lead__c = l.Id,
            TwilioSF__Message_SID__c = 'SMtest_rel'
        );
        insert msg;

        Test.startTest();
        TwilioMessageRelationshipService.relateByMessageIds(new Set<Id>{ msg.Id });
        Test.stopTest();

        TwilioSF__Message__c after = [
            SELECT Id, TwilioSF__Account__c, TwilioSF__Contact__c
            FROM TwilioSF__Message__c WHERE Id = :msg.Id
        ];
        System.assertEquals(r.getAccountId(), after.TwilioSF__Account__c, 'Account should be stamped from converted Lead');
        System.assertEquals(r.getContactId(), after.TwilioSF__Contact__c, 'Contact should be stamped from converted Lead');
    }
}