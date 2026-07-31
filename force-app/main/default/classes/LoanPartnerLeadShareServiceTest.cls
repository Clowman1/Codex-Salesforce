@IsTest
private class LoanPartnerLeadShareServiceTest {
    private static final String STANDARD_USER_PROFILE = 'Standard User';
    private static final String USER_KEY_LP_ONE = 'lpone';
    private static final String USER_KEY_LP_TWO = 'lptwo';
    private static final String USER_KEY_PARENT = 'parent';
    private static final String USER_KEY_SHARED_LP = 'sharedlp';
    private static final String USER_KEY_PARENT_ONE = 'parent1';
    private static final String USER_KEY_PARENT_TWO = 'parent2';
    private static final String USER_KEY_CHUNK_LP = 'chunklp';
    private static final String USER_KEY_CHUNK_PARENT = 'chunkparent';
    private static final String USER_KEY_SAFE_LP = 'safelp';
    private static final String USER_KEY_SAFE_PARENT = 'safeparent';
    private static Id cachedUserRoleId;

    @TestSetup
    static void setupUsers() {
        insert new List<User>{
            createUser(USER_KEY_LP_ONE),
            createUser(USER_KEY_LP_TWO),
            createUser(USER_KEY_PARENT),
            createUser(USER_KEY_SHARED_LP),
            createUser(USER_KEY_PARENT_ONE),
            createUser(USER_KEY_PARENT_TWO),
            createUser(USER_KEY_CHUNK_LP),
            createUser(USER_KEY_CHUNK_PARENT),
            createUser(USER_KEY_SAFE_LP),
            createUser(USER_KEY_SAFE_PARENT)
        };
    }

    @IsTest
    static void testSetChangeAndClearLoanPartnerLifecycle() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        User loanPartnerOne = getTestUser(USER_KEY_LP_ONE);
        User loanPartnerTwo = getTestUser(USER_KEY_LP_TWO);
        User parentUser = getTestUser(USER_KEY_PARENT);

        parentUser.Loan_Partner__c = loanPartnerOne.Id;
        runAsCurrentUser(new List<User>{ parentUser });

        List<Lead> leads = new List<Lead>{
            new Lead(LastName = 'LP-Lead-1', Company = 'Test Co', OwnerId = parentUser.Id),
            new Lead(LastName = 'LP-Lead-2', Company = 'Test Co', OwnerId = parentUser.Id)
        };
        insert leads;

        LoanPartnerLeadShareService.processRelationshipChangesChunk(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, null, loanPartnerOne.Id)
            },
            null,
            false
        );

        Integer lpOneShares = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId IN :leads
            AND UserOrGroupId = :loanPartnerOne.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(leads.size(), lpOneShares, 'Existing leads must be shared to LP with Edit.');

        Lead futureLead = new Lead(
            LastName = 'LP-Lead-Future',
            Company = 'Test Co',
            OwnerId = parentUser.Id
        );
        insert futureLead;

        Integer futureLeadShares = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :futureLead.Id
            AND UserOrGroupId = :loanPartnerOne.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(1, futureLeadShares, 'Future leads must be shared to LP with Edit.');

        LoanPartnerLeadShareService.processRelationshipChangesChunk(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, loanPartnerOne.Id, loanPartnerTwo.Id)
            },
            null,
            false
        );

        Integer lpOneSharesAfterChange = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId IN :leads
            AND UserOrGroupId = :loanPartnerOne.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        Integer lpTwoSharesAfterChange = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId IN :leads
            AND UserOrGroupId = :loanPartnerTwo.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(0, lpOneSharesAfterChange, 'Old LP shares should be removed.');
        System.assertEquals(leads.size(), lpTwoSharesAfterChange, 'New LP shares should be created.');

        LoanPartnerLeadShareService.processRelationshipChangesChunk(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, loanPartnerTwo.Id, null)
            },
            null,
            false
        );

        Integer lpTwoSharesAfterClear = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId IN :leads
            AND UserOrGroupId = :loanPartnerTwo.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(0, lpTwoSharesAfterClear, 'LP shares should be removed when relationship is cleared.');

    }

    @IsTest
    static void testMultipleParentsUseSameLoanPartnerGroup() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        User sharedLoanPartner = getTestUser(USER_KEY_SHARED_LP);
        User parentOne = getTestUser(USER_KEY_PARENT_ONE);
        User parentTwo = getTestUser(USER_KEY_PARENT_TWO);

        parentOne.Loan_Partner__c = sharedLoanPartner.Id;
        parentTwo.Loan_Partner__c = sharedLoanPartner.Id;

        runAsCurrentUser(new List<User>{ parentOne, parentTwo });
        LoanPartnerLeadShareService.processRelationshipChangesChunk(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentOne.Id, null, sharedLoanPartner.Id),
                new LoanPartnerLeadShareService.RelationshipChange(parentTwo.Id, null, sharedLoanPartner.Id)
            },
            null,
            true
        );

        Group sharedGroup = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :('LP_' + String.valueOf(sharedLoanPartner.Id))
            LIMIT 1
        ];
        Integer memberships = [
            SELECT COUNT()
            FROM GroupMember
            WHERE GroupId = :sharedGroup.Id
            AND UserOrGroupId IN :new Set<Id>{ parentOne.Id, parentTwo.Id }
        ];
        System.assertEquals(2, memberships, 'Both parent users should be members of the same LP group.');
    }

    @IsTest
    static void testAsyncChunkingProcessesLargeLeadVolume() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        User loanPartner = getTestUser(USER_KEY_CHUNK_LP);
        User parentUser = getTestUser(USER_KEY_CHUNK_PARENT);

        List<Lead> manyLeads = new List<Lead>();
        for (Integer i = 0; i < 505; i++) {
            manyLeads.add(new Lead(
                LastName = 'ChunkLead-' + i,
                Company = 'Test Co',
                OwnerId = parentUser.Id
            ));
        }
        insert manyLeads;

        LoanPartnerLeadShareService.QueueableResult firstChunkResult =
            LoanPartnerLeadShareService.processRelationshipChangesChunk(
                new List<LoanPartnerLeadShareService.RelationshipChange>{
                    new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, null, null)
                },
                null,
                false
            );
        System.assertEquals(true, firstChunkResult.hasMore, 'First chunk should indicate more leads remain.');
        System.assertNotEquals(null, firstChunkResult.lastProcessedLeadId, 'First chunk should advance the cursor.');

        LoanPartnerLeadShareService.QueueableResult secondChunkResult =
            LoanPartnerLeadShareService.processRelationshipChangesChunk(
                new List<LoanPartnerLeadShareService.RelationshipChange>{
                    new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, null, null)
                },
                firstChunkResult.lastProcessedLeadId,
                false
            );
        System.assertEquals(false, secondChunkResult.hasMore, 'Second chunk should finish the remaining leads.');
    }

    @IsTest
    static void testSafeCleanupPreservesManualReadShares() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        User loanPartner = getTestUser(USER_KEY_SAFE_LP);
        User parentUser = getTestUser(USER_KEY_SAFE_PARENT);

        parentUser.Loan_Partner__c = loanPartner.Id;
        runAsCurrentUser(new List<User>{ parentUser });
        LoanPartnerLeadShareService.processRelationshipChangesChunk(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, null, loanPartner.Id)
            },
            null,
            false
        );

        Lead leadRecord = new Lead(
            LastName = 'SafeCleanupLead',
            Company = 'Test Co',
            OwnerId = parentUser.Id
        );
        insert leadRecord;

        List<LeadShare> existingEditShares = [
            SELECT Id
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :loanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        delete existingEditShares;

        insert new LeadShare(
            LeadId = leadRecord.Id,
            UserOrGroupId = loanPartner.Id,
            RowCause = 'Manual',
            LeadAccessLevel = 'Read'
        );

        parentUser.Loan_Partner__c = null;
        runAsCurrentUser(new List<User>{ parentUser });
        LoanPartnerLeadShareService.processRelationshipChangesChunk(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, loanPartner.Id, null)
            },
            null,
            false
        );

        Integer remainingManualReadShares = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :loanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Read'
        ];
        System.assertEquals(1, remainingManualReadShares, 'Safety-first cleanup must preserve manual Read shares.');
    }

    @IsTest
    static void testQueueableExecutesLeadShareProcessingWithoutChaining() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        User loanPartner = getTestUser(USER_KEY_LP_ONE);
        User parentUser = getTestUser(USER_KEY_PARENT);

        Lead leadRecord = new Lead(
            LastName = 'QueueableShareLead',
            Company = 'Test Co',
            OwnerId = parentUser.Id
        );
        insert leadRecord;

        Test.startTest();
        System.enqueueJob(new LoanPartnerLeadShareQueueable(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, null, loanPartner.Id)
            },
            null,
            false
        ));
        Test.stopTest();

        Integer shareCount = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :loanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(1, shareCount, 'Queueable should create a direct lead share.');
    }

    @IsTest
    static void testQueueableChainsAfterGroupSyncPhase() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        LoanPartnerLeadShareQueueable.bypassFollowupEnqueueInTests = true;
        User loanPartner = getTestUser(USER_KEY_LP_TWO);
        User parentUser = getTestUser(USER_KEY_PARENT_ONE);

        Test.startTest();
        System.enqueueJob(new LoanPartnerLeadShareQueueable(
            new List<LoanPartnerLeadShareService.RelationshipChange>{
                new LoanPartnerLeadShareService.RelationshipChange(parentUser.Id, null, loanPartner.Id)
            },
            null,
            true
        ));
        Test.stopTest();

        Group lpGroup = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :('LP_' + String.valueOf(loanPartner.Id))
            LIMIT 1
        ];
        Integer membershipCount = [
            SELECT COUNT()
            FROM GroupMember
            WHERE GroupId = :lpGroup.Id
            AND UserOrGroupId = :parentUser.Id
        ];
        System.assertEquals(1, membershipCount, 'Queueable should sync group membership before chaining.');
    }

    @IsTest
    static void testLeadTriggerSharesOnInsertAndOwnerChange() {
        LoanPartnerLeadShareService.bypassQueueableEnqueueInTests = true;
        User initialLoanPartner = getTestUser(USER_KEY_LP_ONE);
        User nextLoanPartner = getTestUser(USER_KEY_LP_TWO);
        User initialOwner = getTestUser(USER_KEY_PARENT_ONE);
        User nextOwner = getTestUser(USER_KEY_PARENT_TWO);

        initialOwner.Loan_Partner__c = initialLoanPartner.Id;
        nextOwner.Loan_Partner__c = nextLoanPartner.Id;
        runAsCurrentUser(new List<User>{ initialOwner, nextOwner });

        Lead leadRecord = new Lead(
            LastName = 'TriggerOwnerChangeLead',
            Company = 'Test Co',
            OwnerId = initialOwner.Id
        );
        insert leadRecord;

        Integer initialShareCount = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :initialLoanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(1, initialShareCount, 'Lead trigger should share to the initial owner loan partner.');

        leadRecord.OwnerId = nextOwner.Id;
        update leadRecord;

        Integer oldShareCount = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :initialLoanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        Integer newShareCount = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :nextLoanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(0, oldShareCount, 'Lead trigger should remove the old owner loan partner share.');
        System.assertEquals(1, newShareCount, 'Lead trigger should add the new owner loan partner share.');
    }

    private static User createUser(String key) {
        String aliasValue = 'u' + key;
        if (aliasValue.length() > 8) {
            aliasValue = aliasValue.substring(0, 8);
        }
        String randomSuffix = String.valueOf(Crypto.getRandomInteger()).replace('-', 'n');
        String uniqueValue = key + '.' + String.valueOf(Datetime.now().getTime()) + '.' + randomSuffix;
        return new User(
            Alias = aliasValue,
            Email = 'user.' + uniqueValue + '@test.com',
            Username = 'user.' + uniqueValue + '@test.com',
            FirstName = 'First' + key,
            LastName = 'Last' + key,
            MobilePhone = '2484567890',
            Title = 'Loan Officer',
            Phone = '9876543210',
            Fax = '1112223333',
            OverrideEmailSignature__c = false,
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            UserRoleId = getUserRoleId(),
            ProfileId = [SELECT Id FROM Profile WHERE Name = :STANDARD_USER_PROFILE LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
    }

    private static User getTestUser(String key) {
        return [
            SELECT Id, Loan_Partner__c
            FROM User
            WHERE LastName = :('Last' + key)
            LIMIT 1
        ];
    }

    private static void runAsCurrentUser(List<User> usersToUpdate) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update usersToUpdate;
        }
    }
    private static Id getUserRoleId() {
        if (cachedUserRoleId == null) {
            List<User> usersWithRoles = [
                SELECT UserRoleId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                AND UserRoleId != null
                LIMIT 1
            ];
            if (!usersWithRoles.isEmpty()) {
                cachedUserRoleId = usersWithRoles[0].UserRoleId;
            }
        }
        return cachedUserRoleId;
    }
}