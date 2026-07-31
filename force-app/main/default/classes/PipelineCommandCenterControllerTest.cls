@IsTest(SeeAllData=true)
private class PipelineCommandCenterControllerTest {
    private static User createUser(String suffix, String title) {
        Profile profileRecord = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        String uniqueValue = String.valueOf(DateTime.now().getTime()) + suffix;
        User userRecord = new User(
            Alias = ('pcc' + suffix).left(8),
            Email = 'pcc' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'PCC ' + suffix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Title = title,
            Username = 'pcc' + uniqueValue + '@example.com'
        );
        insert userRecord;
        return userRecord;
    }

    private static User createNamedUser(String suffix, String firstName, String lastName, String title) {
        Profile profileRecord = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        String uniqueValue = String.valueOf(DateTime.now().getTime()) + suffix;
        User userRecord = new User(
            Alias = ('pcc' + suffix).left(8),
            Email = 'pcc' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = firstName,
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Title = title,
            Username = 'pcc' + uniqueValue + '@example.com'
        );
        insert userRecord;
        return userRecord;
    }

    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Id leadRecordTypeId(String developerName) {
        return [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Lead'
            AND DeveloperName = :developerName
            LIMIT 1
        ].Id;
    }

    @IsTest
    static void getDashboardDataReturnsCards() {
        Test.startTest();
        PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data, 'Dashboard data should be returned.');
        System.assertNotEquals(null, data.statusCards, 'Status cards should be returned.');
        System.assertEquals(4, data.statusCards.size(), 'Expected the pilot dashboard status cards.');
        System.assertNotEquals(null, data.pipelineRows, 'Pipeline rows should be returned.');
        System.assert(data.pipelineTabs.size() >= 2, 'Expected pipeline tabs to be returned.');
        System.assertNotEquals(null, data.quickButtons, 'Quick buttons should be returned.');
        System.assertEquals(3, data.quickButtons.size(), 'Expected three quick buttons.');
        System.assertNotEquals(null, data.queueShortcuts, 'Queue shortcuts should be returned.');
    }

    @IsTest
    static void saveUserQuickButtonsStoresPreference() {
        List<PipelineCommandCenterController.ListViewOption> options = PipelineCommandCenterController.getListViewOptions();
        System.assert(options.size() >= 3, 'Expected at least three list views in the org.');

        List<PipelineCommandCenterController.QuickButton> buttons = new List<PipelineCommandCenterController.QuickButton>();
        for (Integer i = 0; i < 3; i++) {
            buttons.add(new PipelineCommandCenterController.QuickButton(
                options[i].label,
                options[i].objectApiName,
                options[i].filterName
            ));
        }

        Test.startTest();
        List<PipelineCommandCenterController.QuickButton> savedButtons = PipelineCommandCenterController.saveUserQuickButtons(buttons);
        Test.stopTest();

        System.assertEquals(3, savedButtons.size(), 'Expected saved quick buttons to be returned.');
        System.assertEquals(buttons[0].filterName, savedButtons[0].filterName, 'Expected first selected list view to be saved.');
    }

    @IsTest
    static void saveProcessorNoteUpdatesLatestTransactionNote() {
        List<Transaction__c> transactions = [
            SELECT Id
            FROM Transaction__c
            LIMIT 1
        ];
        System.assertEquals(1, transactions.size(), 'Expected an existing transaction for processor note update coverage.');
        String longNote = 'Home screen processor note test ';
        for (Integer i = 0; i < 20; i++) {
            longNote += 'long processor note detail segment ' + i + ' ';
        }
        longNote += 'final long note marker';

        Test.startTest();
        PipelineCommandCenterController.saveProcessorNote(transactions[0].Id, longNote);
        Test.stopTest();

        Transaction__c updatedTransaction = [
            SELECT Processor_Note__c, Processor_Note_For_Display__c, Processor_Note_Date_Time__c
            FROM Transaction__c
            WHERE Id = :transactions[0].Id
            LIMIT 1
        ];
        System.assert(updatedTransaction.Processor_Note__c.contains('Home screen processor note test'), 'Expected processor note to be updated.');
        System.assert(updatedTransaction.Processor_Note__c.contains('final long note marker'), 'Expected full processor note to remain on the rich text note field.');
        System.assert(updatedTransaction.Processor_Note_For_Display__c.contains('Home screen processor note test'), 'Expected display note to update for Home Screen refresh.');
        System.assert(updatedTransaction.Processor_Note_For_Display__c.length() <= 255, 'Expected display note preview to respect the 255-character Salesforce field limit.');
        System.assertNotEquals(null, updatedTransaction.Processor_Note_Date_Time__c, 'Expected processor note timestamp to be set.');

        List<Enhanced_Note__c> enhancedNotes = [
            SELECT Id, Subject__c, Body__c, Transaction__c, Type__c
            FROM Enhanced_Note__c
            WHERE Transaction__c = :transactions[0].Id
            AND Subject__c LIKE 'FILE NOTE%'
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        Enhanced_Note__c matchingEnhancedNote;
        for (Enhanced_Note__c enhancedNote : enhancedNotes) {
            if (enhancedNote.Body__c != null && enhancedNote.Body__c.contains('final long note marker')) {
                matchingEnhancedNote = enhancedNote;
                break;
            }
        }
        System.assertNotEquals(null, matchingEnhancedNote, 'Expected custom Enhanced Note timeline record to be created.');
        System.assert(matchingEnhancedNote.Subject__c.startsWith('FILE NOTE'), 'Expected a file-note subject for the Transaction Notes tab.');
        System.assertEquals('Note', matchingEnhancedNote.Type__c, 'Expected note type for the Transaction Notes tab.');

        List<ContentDocumentLink> linkedNotes = [
            SELECT Id, ContentDocument.FileType, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :transactions[0].Id
            AND ContentDocument.FileType = 'SNOTE'
        ];
        System.assert(!linkedNotes.isEmpty(), 'Expected an Enhanced Note to be linked to the transaction.');
    }

    @IsTest
    static void saveManagerNoteUpdatesTransactionManagerNote() {
        List<Transaction__c> transactions = [
            SELECT Id
            FROM Transaction__c
            LIMIT 1
        ];
        System.assertEquals(1, transactions.size(), 'Expected an existing transaction for manager note update coverage.');

        Test.startTest();
        PipelineCommandCenterController.saveManagerNote(transactions[0].Id, 'Home screen manager note test');
        Test.stopTest();

        Transaction__c updatedTransaction = [
            SELECT Manager_Notes__c
            FROM Transaction__c
            WHERE Id = :transactions[0].Id
            LIMIT 1
        ];
        System.assert(updatedTransaction.Manager_Notes__c.contains('Home screen manager note test'), 'Expected manager note to be updated.');

        List<Enhanced_Note__c> enhancedNotes = [
            SELECT Id, Subject__c, Body__c, Transaction__c, Type__c
            FROM Enhanced_Note__c
            WHERE Transaction__c = :transactions[0].Id
            AND Subject__c LIKE 'MANAGER NOTE%'
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        System.assert(!enhancedNotes.isEmpty(), 'Expected custom manager Enhanced Note timeline record to be created.');
    }

    @IsTest
    static void createTransactionEventAddsScheduledAppointment() {
        List<Transaction__c> transactions = [
            SELECT Id
            FROM Transaction__c
            LIMIT 1
        ];
        System.assertEquals(1, transactions.size(), 'Expected an existing transaction for event creation coverage.');
        Datetime startDateTime = System.now().addDays(1);

        Test.startTest();
        Id eventId = PipelineCommandCenterController.createTransactionEvent(
            transactions[0].Id,
            'Home Screen Test Appointment',
            startDateTime
        );
        Test.stopTest();

        Event eventRecord = [
            SELECT Subject, WhatId, OwnerId, StartDateTime, EndDateTime, DurationInMinutes,
                Event_Type__c, IsReminderSet, ReminderDateTime
            FROM Event
            WHERE Id = :eventId
            LIMIT 1
        ];
        System.assertEquals('Home Screen Test Appointment', eventRecord.Subject, 'Expected saved event subject.');
        System.assertEquals(transactions[0].Id, eventRecord.WhatId, 'Expected event to be related to the Transaction.');
        System.assertEquals(UserInfo.getUserId(), eventRecord.OwnerId, 'Expected event to be assigned to the running user.');
        System.assertEquals(startDateTime, eventRecord.StartDateTime, 'Expected selected event start time.');
        System.assertEquals(startDateTime.addMinutes(15), eventRecord.EndDateTime, 'Expected a 15-minute appointment window.');
        System.assertEquals(15, eventRecord.DurationInMinutes, 'Expected default 15-minute duration.');
        System.assertEquals('Scheduled Appointment', eventRecord.Event_Type__c, 'Expected scheduled appointment event type.');
        System.assertEquals(true, eventRecord.IsReminderSet, 'Expected reminder to be enabled.');
        System.assertEquals(startDateTime.addMinutes(-15), eventRecord.ReminderDateTime, 'Expected 15-minute reminder.');
    }

    @IsTest
    static void clearAccountPhoneNumberRemovesAllBorrowerPhoneFields() {
        List<Account> borrowerAccounts = [
            SELECT Id, Phone, PersonMobilePhone
            FROM Account
            WHERE IsPersonAccount = true
            AND (Phone != null OR PersonMobilePhone != null)
            LIMIT 1
        ];
        System.assertEquals(1, borrowerAccounts.size(), 'Expected an existing borrower person account with a phone number.');

        Account borrowerAccount = borrowerAccounts[0];
        if (String.isBlank(borrowerAccount.Phone)) {
            borrowerAccount.Phone = '555-111-2222';
        }
        if (String.isBlank(borrowerAccount.PersonMobilePhone)) {
            borrowerAccount.PersonMobilePhone = '555-111-3333';
        }
        update borrowerAccount;

        Test.startTest();
        PipelineCommandCenterController.clearAccountPhoneNumber(borrowerAccount.Id);
        Test.stopTest();

        Account clearedAccount = [
            SELECT Phone, PersonMobilePhone
            FROM Account
            WHERE Id = :borrowerAccount.Id
            LIMIT 1
        ];
        System.assertEquals(null, clearedAccount.Phone, 'Expected Phone to be cleared.');
        System.assertEquals(null, clearedAccount.PersonMobilePhone, 'Expected Person Mobile Phone to be cleared.');
    }

    @IsTest
    static void markAccountPropertySoldChecksPropertySoldField() {
        List<Account> borrowerAccounts = [
            SELECT Id, Property_Sold__c
            FROM Account
            WHERE IsPersonAccount = true
            LIMIT 1
        ];
        System.assertEquals(1, borrowerAccounts.size(), 'Expected an existing borrower person account.');

        Account borrowerAccount = borrowerAccounts[0];
        borrowerAccount.Property_Sold__c = false;
        update borrowerAccount;

        Test.startTest();
        PipelineCommandCenterController.markAccountPropertySold(borrowerAccount.Id);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Property_Sold__c
            FROM Account
            WHERE Id = :borrowerAccount.Id
            LIMIT 1
        ];
        System.assertEquals(true, updatedAccount.Property_Sold__c, 'Expected Property Sold to be checked.');
    }

    @IsTest
    static void createTitleAgentAccountCreatesCompactTitleAgent() {
        Test.startTest();
        Id accountId = PipelineCommandCenterController.createTitleAgentAccount(
            'Rapid Title Test',
            '555-867-5309',
            'rapid-title@example.com'
        );
        Test.stopTest();

        Account titleAgent = [
            SELECT Name, RecordType.DeveloperName, Type__c, Group__pc, Phone, PersonMobilePhone, PersonEmail
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        System.assertEquals('Rapid Title Test', titleAgent.Name, 'Expected title agent account name.');
        System.assertEquals('PersonAccount', titleAgent.RecordType.DeveloperName, 'Expected existing Title Agent pattern to use Person Account.');
        System.assertEquals('Title Agent Account', titleAgent.Type__c, 'Expected title agent type.');
        System.assertEquals('Title Agent', titleAgent.Group__pc, 'Expected title agent group.');
        System.assertEquals('555-867-5309', titleAgent.Phone, 'Expected phone to be copied to Account Phone.');
        System.assertEquals('555-867-5309', titleAgent.PersonMobilePhone, 'Expected phone to be copied to mobile.');
        System.assertEquals('rapid-title@example.com', titleAgent.PersonEmail, 'Expected email to be stored on the person account.');
    }

    @IsTest
    static void searchRealtorAccountsReturnsRealtorPersonAccounts() {
        Id personAccountRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
        Account realtor = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Selector',
            LastName = 'Realtor',
            Phone = '555-222-1212',
            PersonMobilePhone = '555-222-1212',
            PersonEmail = 'selector-realtor@example.com',
            Type__c = 'Realtor Account',
            Group__pc = 'Realtor',
            Is_Realtor__c = true
        );
        insert realtor;

        Test.startTest();
        List<PipelineCommandCenterController.LookupOption> options =
            PipelineCommandCenterController.searchRealtorAccounts('Selector');
        Test.stopTest();

        System.assertEquals(false, options.isEmpty(), 'Expected realtor search results.');
        System.assertEquals(realtor.Id, (Id) options[0].value, 'Expected the matching Realtor Person Account.');
        System.assertEquals('Selector Realtor', options[0].label, 'Expected the person account name.');
    }

    @IsTest
    static void markBrokerCheckReceivedUpdatesTransaction() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Broker Check Action Test',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Broker_Check_Recieved__c = false
        );
        insert transactionRecord;

        Test.startTest();
        PipelineCommandCenterController.markBrokerCheckReceived(transactionRecord.Id);
        Test.stopTest();

        Transaction__c updatedTransaction = [
            SELECT Broker_Check_Recieved__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
            LIMIT 1
        ];
        System.assertEquals(true, updatedTransaction.Broker_Check_Recieved__c, 'Expected broker check checkbox to be marked received.');
    }

    @IsTest
    static void loanOfficerGetsAssignedLeadPipeline() {
        User loanOfficer = createUser('lo', 'Loan Officer');
        Lead newLead = new Lead(
            FirstName = 'Fresh',
            LastName = 'Lead',
            Company = 'Fresh Lead',
            Status = 'New',
            RecordTypeId = leadRecordTypeId('Consumer_Lead_record_type'),
            OwnerId = loanOfficer.Id
        );
        insert newLead;
        Lead realtorLead = new Lead(
            FirstName = 'Realtor',
            LastName = 'Lead',
            Company = 'Realtor Lead',
            Status = 'New',
            RecordTypeId = leadRecordTypeId('Realtor_Lead_record_type'),
            OwnerId = loanOfficer.Id
        );
        insert realtorLead;
        Lead scheduledLead = new Lead(
            FirstName = 'Scheduled',
            LastName = 'Lead',
            Company = 'Scheduled Lead',
            Status = 'New',
            RecordTypeId = leadRecordTypeId('Consumer_Lead_record_type'),
            OwnerId = loanOfficer.Id
        );
        insert scheduledLead;
        insert new Event(
            Subject = 'Future lead follow-up',
            WhoId = scheduledLead.Id,
            OwnerId = loanOfficer.Id,
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addMinutes(15)
        );

        System.runAs(loanOfficer) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Lead', data.pipelineObjectApiName, 'Loan officers should see assigned leads.');
            System.assertEquals('Active Leads', data.pipelineTitle, 'Expected LO-specific pipeline title.');
            System.assertNotEquals(null, data.pipelineRows, 'Expected lead pipeline rows to be initialized.');
            System.assertEquals(true, data.canCreateLead, 'Loan officers should be able to create leads from the Home Screen.');
            System.assertEquals(11, data.pipelineTabs.size(), 'Loan officers should see lead tabs plus assigned transaction tabs.');
            System.assertEquals('assigned', data.pipelineTabs[0].key, 'Expected active leads first.');
            System.assertEquals('newLeadAlerts', data.pipelineTabs[1].key, 'Expected new lead alerts second.');
            System.assertEquals('activePreApprovals', data.pipelineTabs[3].key, 'Expected active pre-approvals before stagnant pre-approvals.');
            System.assertEquals('stagnantPreApprovals', data.pipelineTabs[4].key, 'Expected stagnant pre-approvals after active pre-approvals.');
            System.assertEquals('preApprovalCallsToday', data.pipelineTabs[5].key, 'Expected pre-approval call list before attention tabs.');
            System.assertEquals('status', data.pipelineTabs[0].customColumns[1].key, 'Expected Status to be the second active lead column.');
            System.assertEquals('status', data.pipelineTabs[3].customColumns[1].key, 'Expected Status to be the second pre-approval lead column.');
            System.assertEquals('status', data.pipelineTabs[5].customColumns[1].key, 'Expected Status to be the second pre-approval calls column.');
            System.assertEquals('disclosuresNeedingSigned', data.pipelineTabs[8].key, 'Expected disclosures needing signed before transaction tabs.');
            System.assertEquals('loanOfficerActiveTransactions', data.pipelineTabs[9].key, 'Expected active transaction tab after lead tabs.');
            System.assertEquals('loanOfficerClosedThisMonth', data.pipelineTabs[10].key, 'Expected closed-this-month transaction tab last.');
            System.assertEquals('Transaction__c', data.pipelineTabs[8].objectApiName, 'Expected disclosures tab to open transactions.');
            System.assertEquals('Transaction__c', data.pipelineTabs[9].objectApiName, 'Expected active transaction tab to open transactions.');
            System.assertEquals('Transaction__c', data.pipelineTabs[10].objectApiName, 'Expected closed-this-month tab to open transactions.');

            Boolean foundFreshLeadInNewAlerts = false;
            Boolean foundFreshLeadInStagnant = false;
            Boolean foundRealtorLeadInNewAlerts = false;
            Boolean foundScheduledLeadInNewAlerts = false;
            for (PipelineCommandCenterController.PipelineTab tab : data.pipelineTabs) {
                if (tab.key == 'newLeadAlerts') {
                    for (PipelineCommandCenterController.PipelineRow row : tab.rows) {
                        if (row.id == newLead.Id) {
                            foundFreshLeadInNewAlerts = true;
                        }
                        if (row.id == realtorLead.Id) {
                            foundRealtorLeadInNewAlerts = true;
                        }
                        if (row.id == scheduledLead.Id) {
                            foundScheduledLeadInNewAlerts = true;
                        }
                    }
                }
                if (tab.key == 'stagnant') {
                    for (PipelineCommandCenterController.PipelineRow row : tab.rows) {
                        if (row.id == newLead.Id) {
                            foundFreshLeadInStagnant = true;
                        }
                    }
                }
            }
            System.assert(foundFreshLeadInNewAlerts, 'A new lead should still appear in the New Leads Alert tab.');
            System.assertEquals(false, foundRealtorLeadInNewAlerts, 'Realtor leads should not appear in consumer lead Home tabs.');
            System.assertEquals(false, foundScheduledLeadInNewAlerts, 'New leads with a future event should not appear in the New Leads Alert tab.');
            System.assertEquals(false, foundFreshLeadInStagnant, 'A lead created today should not appear in Stagnant Leads just because LastActivityDate is blank.');
        }

        Lead leadRecord = (Lead) JSON.deserialize(
            '{"attributes":{"type":"Lead"},"Name":"Pipeline Lead","Status":"Working","CreatedDate":"2026-06-03T12:00:00.000+0000","Loan_Amount__c":275000,"Loan_Purpose__c":"Purchase","Owner":{"attributes":{"type":"User"},"Name":"Pipeline Owner"}}',
            Lead.class
        );
        PipelineCommandCenterController.PipelineRow row = new PipelineCommandCenterController.PipelineRow(leadRecord);
        System.assertEquals('Pipeline Lead', row.name, 'Expected lead row name to be mapped.');
        System.assertEquals('Working', row.status, 'Expected lead row status to be mapped.');

        PipelineCommandCenterController.PipelineRow eventRow = new PipelineCommandCenterController.PipelineRow(
            leadRecord,
            Date.today(),
            System.now(),
            'Follow-up call'
        );
        System.assertEquals('Follow-up call', eventRow.detail, 'Expected event subject detail to be mapped.');
    }

    @IsTest
    static void createRealtorLeadCreatesWorkingRealtorLead() {
        User benLikeUser = createUser('benrl', 'Sales');

        System.runAs(benLikeUser) {
            Test.startTest();
            Id leadId = PipelineCommandCenterController.createRealtorLead(
                'Realtor',
                'Prospect',
                '555-111-2222',
                'realtor.prospect@example.com',
                null,
                'Initial realtor lead from Command Center.'
            );
            Test.stopTest();

            Lead createdLead = [
                SELECT FirstName, LastName, Phone, Email, Comments__c, Status, OwnerId, RecordType.DeveloperName
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
            System.assertEquals('Realtor_Lead_record_type', createdLead.RecordType.DeveloperName, 'Expected a Realtor Lead record type.');
            System.assertEquals('Working', createdLead.Status, 'Expected new Realtor Leads to land in Working.');
            System.assertEquals(benLikeUser.Id, createdLead.OwnerId, 'Expected the creating user to own the Realtor Lead.');
            System.assertEquals('555-111-2222', createdLead.Phone, 'Expected phone to be saved.');
            System.assertEquals('realtor.prospect@example.com', createdLead.Email, 'Expected email to be saved.');
        }
    }

    @IsTest
    static void eligibleUsersCanAssignLeadOwnerFromCommandCenterForm() {
        User opener = createNamedUser('lauraowner', 'Laura', 'Hoyos', 'Office Coordinator');
        User selectedOwner = createUser('leadown', 'Loan Officer');

        System.runAs(opener) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            PipelineCommandCenterController.NewLeadFormOptions options = PipelineCommandCenterController.getNewLeadFormOptions();
            Id leadId = PipelineCommandCenterController.createConsumerLead(
                'Owner',
                'Assigned',
                '555-212-9898',
                'owner.assigned@example.com',
                firstActivePicklistValue(Lead.LeadSource),
                firstActivePicklistValue(Lead.Loan_Purpose__c),
                firstActivePicklistValue(Lead.Biz_Dev__c),
                null,
                selectedOwner.Id
            );
            Test.stopTest();

            System.assertEquals(true, data.canAssignNewLeadOwner, 'Eligible opener users should see the owner-assignment form.');
            System.assertEquals(true, data.canCreateLead, 'Eligible opener users should still be able to create leads.');
            System.assert(!options.ownerOptions.isEmpty(), 'Expected active owner choices to be returned.');
            System.assertNotEquals(null, leadId, 'Expected the create action to return a Lead Id.');
        }
    }

    @IsTest
    static void biancaCanUseOwnerAssignmentLeadForm() {
        User bianca = createNamedUser('bianca', 'Bianca', 'Rodrigues', 'Operations');

        System.runAs(bianca) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals(true, data.canAssignNewLeadOwner, 'Bianca should be included in the owner-assignment create lead group.');
            System.assertEquals(true, data.canCreateLead, 'Bianca should be able to open the create lead module.');
        }
    }

    @IsTest
    static void meganGetsOwnLoanOfficerAndBrandonPartnerTabs() {
        Profile profileRecord = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        String uniqueValue = String.valueOf(DateTime.now().getTime()) + 'megan';
        User megan = new User(
            Alias = 'pccmeg',
            Email = 'pcc' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Megan',
            LastName = 'Straight',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Title = 'Loan Officer',
            Username = 'pcc' + uniqueValue + '@example.com'
        );
        insert megan;

        System.runAs(megan) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Lead', data.pipelineObjectApiName, 'Megan should keep the standard loan officer lead home view.');
            System.assertEquals('assigned', data.pipelineTabs[0].key, 'Expected Megan own active leads first.');
            System.assertEquals('activePreApprovals', data.pipelineTabs[3].key, 'Expected Megan active pre-approval tab with her own lead tabs.');
            System.assertEquals('preApprovalCallsToday', data.pipelineTabs[5].key, 'Expected Megan pre-approval call tab with her own lead tabs.');
            System.assertEquals('status', data.pipelineTabs[0].customColumns[1].key, 'Expected Status to be the second active lead column.');
            System.assertEquals('status', data.pipelineTabs[3].customColumns[1].key, 'Expected Status to be the second pre-approval lead column.');
            System.assertEquals('status', data.pipelineTabs[5].customColumns[1].key, 'Expected Status to be the second pre-approval calls column.');
            System.assertEquals('loanOfficerClosedThisMonth', data.pipelineTabs[10].key, 'Expected Megan own transaction tabs before partner tabs.');
            System.assert(data.pipelineTabs.size() >= 11, 'Expected Megan to receive the normal LO tab set.');

            List<User> brandonUsers = [
                SELECT Id
                FROM User
                WHERE Username = 'bbrotsky@reachhomeloans.com'
                AND IsActive = true
                LIMIT 1
            ];
            List<User> zachUsers = [
                SELECT Id
                FROM User
                WHERE Username = 'zfritz@reachhomeloans.com'
                AND IsActive = true
                LIMIT 1
            ];
            Boolean brandonExists = !brandonUsers.isEmpty();
            Boolean zachExists = !zachUsers.isEmpty();
            Boolean zachTabsIncluded = false;
            for (PipelineCommandCenterController.PipelineTab tab : data.pipelineTabs) {
                if (tab.key == 'zachFritzActiveLeads') {
                    zachTabsIncluded = true;
                    break;
                }
            }
            if (brandonExists && zachExists && zachTabsIncluded) {
                System.assertEquals(34, data.pipelineTabs.size(), 'Expected Megan own LO tabs plus Brandon and Zach loan partner tabs and the pre-approval follow-up tab.');
                System.assertEquals('brandonActiveLeads', data.pipelineTabs[11].key, 'Expected Brandon partner lead tabs after Megan own tabs.');
                System.assertEquals('brandonActivePreApprovals', data.pipelineTabs[14].key, 'Expected Brandon active pre-approval tab.');
                System.assertEquals('brandonStagnantPreApprovals', data.pipelineTabs[15].key, 'Expected Brandon stagnant pre-approval tab.');
                System.assertEquals('brandonPreApprovalCallsToday', data.pipelineTabs[16].key, 'Expected Brandon pre-approval call tab.');
                System.assertEquals('brandonClosedThisMonth', data.pipelineTabs[21].key, 'Expected Brandon closed-this-month transaction tab before Zach tabs.');
                System.assertEquals('zachFritzActiveLeads', data.pipelineTabs[22].key, 'Expected Zach partner lead tabs after Brandon tabs.');
                System.assertEquals('zachFritzActivePreApprovals', data.pipelineTabs[25].key, 'Expected Zach active pre-approval tab.');
                System.assertEquals('zachFritzStagnantPreApprovals', data.pipelineTabs[26].key, 'Expected Zach stagnant pre-approval tab.');
                System.assertEquals('zachFritzPreApprovalCallsToday', data.pipelineTabs[27].key, 'Expected Zach pre-approval call tab.');
                System.assertEquals('zachFritzClosedThisMonth', data.pipelineTabs[32].key, 'Expected Zach closed-this-month transaction tab last.');
                System.assertEquals('status', data.pipelineTabs[11].customColumns[1].key, 'Expected Status to be the second Brandon partner lead column.');
                System.assertEquals('status', data.pipelineTabs[16].customColumns[1].key, 'Expected Status to be the second Brandon partner pre-approval call column.');
                System.assertEquals('status', data.pipelineTabs[22].customColumns[1].key, 'Expected Status to be the second Zach partner lead column.');
                System.assertEquals('status', data.pipelineTabs[27].customColumns[1].key, 'Expected Status to be the second Zach partner pre-approval call column.');
                System.assertEquals('meganPreApprovalFollowUps', data.pipelineTabs[33].key, 'Expected the pre-approval follow-up tab last.');
                System.assertEquals('ownerLO', data.pipelineTabs[33].customColumns[1].key, 'Expected Owner/LO to be the second pre-approval follow-up column.');
            } else if (brandonExists) {
                System.assertEquals(23, data.pipelineTabs.size(), 'Expected Megan own LO tabs plus Brandon loan partner tabs and the pre-approval follow-up tab.');
                System.assertEquals('brandonClosedThisMonth', data.pipelineTabs[21].key, 'Expected Brandon closed-this-month transaction tab last.');
                System.assertEquals('meganPreApprovalFollowUps', data.pipelineTabs[22].key, 'Expected the pre-approval follow-up tab last.');
            }
        }
    }

    @IsTest
    static void joeyGetsLoanOfficerAssistantLeadView() {
        List<User> assistantUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'joey@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, assistantUsers.size(), 'Expected Joey D\'Alessandro active user for the LO Assistant View.');

        System.runAs(assistantUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Pipeline Command Center', data.headerTitle, 'Expected Joey to keep the Pipeline Command Center header.');
            System.assert(data.headerSubtitle.contains('Zach Fritz'), 'Expected Joey subtitle to identify Zach Fritz pipeline scope.');
            System.assert(data.headerSubtitle.contains('Joe Olmsted'), 'Expected Joey subtitle to identify Joe Olmsted pipeline scope.');
            System.assert(data.headerSubtitle.contains('Rhett Delaney'), 'Expected Joey subtitle to identify Rhett Delaney pipeline scope.');
            System.assertEquals('Lead', data.pipelineObjectApiName, 'Joey should see Zach, Joe, and Rhett lead pipelines.');
            System.assertEquals('Active Leads', data.pipelineTitle, 'Expected lead-focused first tab.');
            System.assertEquals(24, data.pipelineTabs.size(), 'Expected Joey to see Joe, Zach, and Rhett lead and transaction tabs.');
            System.assertEquals('joeOlmstedActiveLeads', data.pipelineTabs[0].key, 'Expected Joe active leads first.');
            System.assertEquals('joeOlmstedNewLeadAlerts', data.pipelineTabs[1].key, 'Expected Joe new leads second.');
            System.assertEquals('joeOlmstedClosedThisMonth', data.pipelineTabs[7].key, 'Expected Joe transaction tabs to finish his group.');
            System.assertEquals('zachFritzActiveLeads', data.pipelineTabs[8].key, 'Expected Zach active leads after Joe tabs.');
            System.assertEquals('rhettDelaneyActiveLeads', data.pipelineTabs[16].key, 'Expected Rhett active leads after Zach tabs.');
            System.assertEquals('Joe Olmsted Active Leads', data.pipelineTabs[0].label, 'Expected Joe-specific tab label.');
            System.assertEquals('Zach Fritz Active Leads', data.pipelineTabs[8].label, 'Expected Zach-specific tab label.');
            System.assertEquals('Rhett Delaney Active Leads', data.pipelineTabs[16].label, 'Expected Rhett-specific tab label.');
            System.assertEquals('status', data.pipelineTabs[0].customColumns[1].key, 'Expected Lead Status to be the second Joe lead column.');
            System.assertEquals('status', data.pipelineTabs[8].customColumns[1].key, 'Expected Lead Status to be the second Zach lead column.');
            System.assertEquals('status', data.pipelineTabs[16].customColumns[1].key, 'Expected Lead Status to be the second Rhett lead column.');
            System.assertEquals(3, data.quickButtons.size(), 'Expected three quick buttons, whether defaults or Joey-saved preferences.');
        }
    }

    @IsTest
    static void joeyZachTabsOnlyShowLeadsWhereJoeyIsLoanPartner() {
        List<User> joeyUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'joey@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        List<User> zachUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'zfritz@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, joeyUsers.size(), 'Expected Joey D\'Alessandro active user for the LO Assistant View.');
        System.assertEquals(1, zachUsers.size(), 'Expected Zach Fritz active user for the LO Assistant View.');

        User otherPartner = createNamedUser('othlp', 'Other', 'Partner', 'Loan Partner');
        Id consumerLeadRecordTypeId = leadRecordTypeId('Consumer_Lead_record_type');
        Lead includedLead = new Lead(
            FirstName = 'Joey Zach Included',
            LastName = 'Lead',
            Company = 'Joey Zach Included Lead',
            Status = 'Working',
            OwnerId = zachUsers[0].Id,
            RecordTypeId = consumerLeadRecordTypeId
        );
        Lead excludedLead = new Lead(
            FirstName = 'Joey Zach Excluded',
            LastName = 'Lead',
            Company = 'Joey Zach Excluded Lead',
            Status = 'Working',
            OwnerId = zachUsers[0].Id,
            RecordTypeId = consumerLeadRecordTypeId
        );
        insert new List<Lead>{ includedLead, excludedLead };
        includedLead.Loan_Partner__c = joeyUsers[0].Id;
        excludedLead.Loan_Partner__c = otherPartner.Id;
        update new List<Lead>{ includedLead, excludedLead };
        insert new List<LeadShare>{
            new LeadShare(
                LeadId = includedLead.Id,
                UserOrGroupId = joeyUsers[0].Id,
                LeadAccessLevel = 'Read',
                RowCause = Schema.LeadShare.RowCause.Manual
            ),
            new LeadShare(
                LeadId = excludedLead.Id,
                UserOrGroupId = joeyUsers[0].Id,
                LeadAccessLevel = 'Read',
                RowCause = Schema.LeadShare.RowCause.Manual
            )
        };

        System.runAs(joeyUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            PipelineCommandCenterController.PipelineTab zachTab;
            for (PipelineCommandCenterController.PipelineTab tab : data.pipelineTabs) {
                if (tab.key == 'zachFritzActiveLeads') {
                    zachTab = tab;
                    break;
                }
            }

            System.assertNotEquals(null, zachTab, 'Expected Zach active leads tab for Joey.');
            Boolean foundIncludedLead = false;
            Boolean foundExcludedLead = false;
            for (PipelineCommandCenterController.PipelineRow row : zachTab.rows) {
                if (row.id == includedLead.Id) {
                    foundIncludedLead = true;
                }
                if (row.id == excludedLead.Id) {
                    foundExcludedLead = true;
                }
            }

            System.assert(foundIncludedLead, 'Expected Joey-partnered Zach lead to appear in Joey\'s Zach tab.');
            System.assertEquals(false, foundExcludedLead, 'Expected non-Joey-partnered Zach lead to stay out of Joey\'s Zach tab.');
        }
    }

    @IsTest
    static void processorGetsAssignedTransactionPipeline() {
        User processor = createUser('proc', 'Processor');
        System.runAs(processor) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Processors should see assigned transactions.');
            System.assertEquals('Active Pipeline', data.pipelineTitle, 'Expected processor transaction pipeline title.');
            System.assertNotEquals(null, data.pipelineRows, 'Expected transaction pipeline rows to be initialized.');
            System.assertEquals(false, data.canCreateLead, 'Processor-only views should not show the create lead action.');
            System.assertEquals(5, data.pipelineTabs.size(), 'Processors should see active, closing, commitment, events, and pending review tabs.');
            System.assertEquals(4, data.queueShortcuts.size(), 'Processors should see the standard queue shortcuts.');
        }

        Transaction__c transactionRecord = (Transaction__c) JSON.deserialize(
            '{"attributes":{"type":"Transaction__c"},"Name":"Pipeline Transaction","Status__c":"Conditionally Approved","Closing_Date__c":"2026-06-17","Loan_Amount_1st__c":325000,"Loan_Purpose__c":"Purchase","Owner":{"attributes":{"type":"User"},"Name":"Pipeline Owner"}}',
            Transaction__c.class
        );
        PipelineCommandCenterController.PipelineRow row = new PipelineCommandCenterController.PipelineRow(transactionRecord);
        System.assertEquals('Pipeline Transaction', row.name, 'Expected transaction row name to be mapped.');
        System.assertEquals('Conditionally Approved', row.status, 'Expected transaction row status to be mapped.');

        PipelineCommandCenterController.PipelineRow eventRow = new PipelineCommandCenterController.PipelineRow(
            transactionRecord,
            Date.today(),
            System.now(),
            'Closing prep'
        );
        System.assertEquals('Closing prep', eventRow.detail, 'Expected transaction event subject detail to be mapped.');
    }

    @IsTest
    static void angelinaGetsTeamLeadAndPersonalPipelineTabs() {
        List<User> teamLeadUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'anoble@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, teamLeadUsers.size(), 'Expected Angelina Noble active user for the Processing Team Lead view.');

        System.runAs(teamLeadUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Angelina should see transaction queues.');
            System.assert(data.pipelineTabs.size() >= 2, 'Expected Angelina to see team and personal active pipeline tabs.');
            System.assertEquals('assigned', data.pipelineTabs[0].key, 'Expected team active pipeline first.');
            System.assertEquals('Active Pipeline', data.pipelineTabs[0].label, 'Expected broad team pipeline label.');
            System.assertEquals('myActivePipeline', data.pipelineTabs[1].key, 'Expected Angelina personal active pipeline second.');
            System.assertEquals('My Active Pipeline', data.pipelineTabs[1].label, 'Expected personal pipeline label.');
        }
    }

    @IsTest
    static void openerGetsOpeningWorkflowView() {
        User opener = createUser('open', 'Opening Processor');
        System.runAs(opener) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Openers should see transaction queues.');
            System.assertEquals('Ready for Disclosures', data.pipelineTitle, 'Expected opener-specific first tab title.');
            System.assertEquals(4, data.statusCards.size(), 'Openers should see four opening status cards.');
            System.assertEquals('TRID Application', data.statusCards[0].label, 'Expected opening status card ordering.');
            System.assertEquals('Submission Form Complete', data.statusCards[1].label, 'Expected friendly label for Open status.');
            System.assertEquals(true, data.canCreateLead, 'Openers should be able to create leads from the Command Center.');
            System.assertEquals(6, data.pipelineTabs.size(), 'Openers should see opening tabs plus personal leads, appraisal, and broker-check queues.');
            System.assertEquals('readyForDisclosures', data.pipelineTabs[0].key, 'Expected ready-for-disclosures first tab.');
            System.assertEquals('waitingOnSignatures', data.pipelineTabs[1].key, 'Expected waiting-on-signatures tab.');
            System.assertEquals('readyToOpen', data.pipelineTabs[2].key, 'Expected ready-to-open tab.');
            System.assertEquals('myPersonalLeads', data.pipelineTabs[3].key, 'Expected personal lead tab after opener workflow tabs.');
            System.assertEquals('Lead', data.pipelineTabs[3].objectApiName, 'Expected personal lead tab to use Lead rows.');
            System.assertEquals('appraisalsOutstanding', data.pipelineTabs[4].key, 'Expected appraisals outstanding tab.');
            System.assertEquals('brokerChecksOutstanding', data.pipelineTabs[5].key, 'Expected broker checks outstanding tab.');
            System.assertEquals(10, data.pipelineTabs[4].customColumns.size(), 'Expected appraisals outstanding columns.');
            System.assertEquals(2, data.pipelineTabs[5].customColumns.size(), 'Expected simplified broker check columns.');
            System.assertEquals(3, data.quickButtons.size(), 'Openers should still get three quick buttons.');
            System.assertEquals('X1_Application', data.quickButtons[0].filterName, 'Expected opener default Open / Disclosures Out list view.');
            System.assertEquals(1, data.queueShortcuts.size(), 'Openers should see only the opening queue shortcut.');
            System.assertEquals('Initial_Disclosures_Required', data.queueShortcuts[0].filterName, 'Expected opener queue shortcut.');
        }
    }

    @IsTest
    static void lauraKeepsOpeningWorkflowViewAfterLicenseChange() {
        User opener = createNamedUser('laura', 'Laura', 'Hoyos', 'Office Coordinator');
        System.runAs(opener) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Laura should keep the opener transaction queues.');
            System.assertEquals('Ready for Disclosures', data.pipelineTitle, 'Laura should keep her opener-specific first tab.');
            System.assertEquals('readyForDisclosures', data.pipelineTabs[0].key, 'Expected Laura opener tab ordering after license changes.');
            System.assertEquals(true, data.canCreateLead, 'Laura should be able to create leads from the opener Command Center.');
            System.assertEquals('myPersonalLeads', data.pipelineTabs[3].key, 'Laura should see her personal lead tab.');
            System.assertEquals('Lead', data.pipelineTabs[3].objectApiName, 'Laura personal leads tab should use Lead rows.');
            System.assertEquals('X1_Application', data.quickButtons[0].filterName, 'Expected Laura opener quick buttons.');
        }
    }

    @IsTest
    static void monicaGetsCloserWorkflowView() {
        List<User> closerUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'monicaquintero@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, closerUsers.size(), 'Expected Monica Quintero active user for the Closer View.');

        System.runAs(closerUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Closers should see transaction queues.');
            System.assertEquals('Active Pipeline', data.pipelineTitle, 'Expected closer-specific first tab title.');
            System.assertEquals(4, data.statusCards.size(), 'Closers should see four closing status cards.');
            System.assertEquals('Conditionally Approved', data.statusCards[0].label, 'Expected closer status card ordering.');
            System.assertEquals('Closing', data.statusCards[1].label, 'Expected Closing status card.');
            System.assertEquals('Funding', data.statusCards[2].label, 'Expected Funding status card.');
            System.assertEquals('PC Review', data.statusCards[3].label, 'Expected PC Review status card.');
            System.assertEquals(6, data.pipelineTabs.size(), 'Closers should see the closer workflow tabs plus closer list-view tabs.');
            System.assertEquals('closerActivePipeline', data.pipelineTabs[0].key, 'Expected active pipeline first tab.');
            System.assertEquals('correspondentCloserView', data.pipelineTabs[1].key, 'Expected correspondent closer view second tab.');
            System.assertEquals('Correspondent Closer View', data.pipelineTabs[1].label, 'Expected correspondent closer tab label.');
            System.assertEquals(12, data.pipelineTabs[1].customColumns.size(), 'Expected correspondent closer columns plus EASE link.');
            System.assertEquals('brokeredCloserView', data.pipelineTabs[2].key, 'Expected brokered closer view third tab.');
            System.assertEquals('Brokered Closer View', data.pipelineTabs[2].label, 'Expected brokered closer tab label.');
            System.assertEquals(12, data.pipelineTabs[2].customColumns.size(), 'Expected brokered closer columns plus EASE link.');
            System.assertEquals('closerFilesInClosing', data.pipelineTabs[3].key, 'Expected files-in-closing tab.');
            System.assertEquals('closerFilesInFunding', data.pipelineTabs[4].key, 'Expected files-in-funding tab.');
            System.assertEquals('closerFilesClosingToday', data.pipelineTabs[5].key, 'Expected files-closing-today tab.');
            System.assertEquals(1, data.queueShortcuts.size(), 'Closers should see the closer action queue shortcut.');
            System.assertEquals('Closer_Action_Required', data.queueShortcuts[0].filterName, 'Expected closer queue shortcut.');
        }
    }

    @IsTest
    static void jamieGetsFundingLockDeskWorkflowView() {
        List<User> fundingUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'jmartinez@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, fundingUsers.size(), 'Expected Jamie Martinez active user for the Funding / LockDesk View.');

        System.runAs(fundingUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Jamie should see transaction queues.');
            System.assertEquals('Active Pipeline', data.pipelineTitle, 'Expected Jamie-specific first tab title.');
            System.assertEquals(4, data.statusCards.size(), 'Jamie should see funding, lock, and COC status cards.');
            System.assertEquals('Funding', data.statusCards[0].label, 'Expected Funding first.');
            System.assertEquals('Funder Action Required', data.statusCards[1].label, 'Expected Funder Action Required second.');
            System.assertEquals('Locks Expiring within a Week', data.statusCards[2].label, 'Expected locks expiring third.');
            System.assertEquals('Open COC Requests', data.statusCards[3].label, 'Expected COC requests fourth.');
            System.assertEquals(8, data.pipelineTabs.size(), 'Jamie should see eight specialist tabs.');
            System.assertEquals('fundingLockDeskActivePipeline', data.pipelineTabs[0].key, 'Expected active pipeline first.');
            System.assertEquals('fundingQueue', data.pipelineTabs[1].key, 'Expected funding queue second.');
            System.assertEquals(14, data.pipelineTabs[1].customColumns.size(), 'Expected Funding Queue columns to match Jamie correspondent funder view plus EASE link.');
            System.assertEquals('funderActionRequired', data.pipelineTabs[2].key, 'Expected Funder Action Required third.');
            System.assertEquals('Funder Action Required', data.pipelineTabs[2].label, 'Expected Funder Action Required tab label.');
            System.assertEquals(12, data.pipelineTabs[2].customColumns.size(), 'Expected Funder Action Required columns to match the Transaction list view.');
            System.assertEquals('jamieCorrespondentCloserView', data.pipelineTabs[3].key, 'Expected Jamie correspondent closer view fourth.');
            System.assertEquals('Jamie - Correspondent Closer View', data.pipelineTabs[3].label, 'Expected Jamie correspondent closer tab label.');
            System.assertEquals(12, data.pipelineTabs[3].customColumns.size(), 'Expected Jamie correspondent closer view columns plus EASE link.');
            System.assertEquals('pcReviewPipeline', data.pipelineTabs[4].key, 'Expected PC Review pipeline fifth.');
            System.assertEquals('needingWarehouseAssignment', data.pipelineTabs[5].key, 'Expected warehouse assignment tab sixth.');
            System.assertEquals('locksExpiring', data.pipelineTabs[6].key, 'Expected lock desk tab seventh.');
            System.assertEquals('Locks Expiring within a Week', data.pipelineTabs[6].label, 'Expected renamed lock desk tab.');
            System.assertEquals(12, data.pipelineTabs[6].customColumns.size(), 'Expected lock desk tab to show rate lock, closing, funding date, and loan officer columns.');
            System.assertEquals('openCocRequests', data.pipelineTabs[7].key, 'Expected open COC tab eighth.');
            System.assertEquals('Case', data.quickButtons[2].objectApiName, 'Expected third Jamie quick button to open Cases.');
            System.assertEquals('All_Open_COC_Requests', data.quickButtons[2].filterName, 'Expected COC list view quick button.');
            System.assertEquals(3, data.queueShortcuts.size(), 'Jamie should see specialist queue shortcuts.');
            System.assertEquals('Locks Expiring within a Week', data.queueShortcuts[0].label, 'Expected renamed lock shortcut.');
        }
    }

    @IsTest
    static void christopherGetsSpecialistManagementTabs() {
        List<User> managementUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'clowman@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, managementUsers.size(), 'Expected Christopher Lowman active user for the Management View.');

        System.runAs(managementUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            Boolean foundLocksExpiringTab = false;
            Boolean foundOpenCocRequestsTab = false;
            Boolean foundAllLoActiveLeadsTab = false;
            Boolean foundAllLoNewLeadAlertsTab = false;
            Boolean foundAllLoAttentionLeadsTab = false;
            Boolean foundAllLoStagnantLeadsTab = false;
            for (PipelineCommandCenterController.PipelineTab tab : data.pipelineTabs) {
                if (tab.key == 'allLoanOfficerActiveLeads') {
                    foundAllLoActiveLeadsTab = true;
                    System.assertEquals('All LO Active Leads', tab.label, 'Expected Christopher to see the all-LO active lead monitor tab.');
                    System.assertEquals('Lead', tab.objectApiName, 'Expected all-LO active lead monitor to open Leads.');
                }
                if (tab.key == 'allLoanOfficerNewLeadAlerts') {
                    foundAllLoNewLeadAlertsTab = true;
                    System.assertEquals('New Leads Needing Contact', tab.label, 'Expected Christopher to see all new LO leads needing contact.');
                    System.assertEquals('Lead', tab.objectApiName, 'Expected all new lead monitor to open Leads.');
                }
                if (tab.key == 'allLoanOfficerAttentionLeads') {
                    foundAllLoAttentionLeadsTab = true;
                    System.assertEquals('Leads Needing Attention', tab.label, 'Expected Christopher to see all LO leads needing attention.');
                    System.assertEquals('Lead', tab.objectApiName, 'Expected attention lead monitor to open Leads.');
                }
                if (tab.key == 'allLoanOfficerStagnantLeads') {
                    foundAllLoStagnantLeadsTab = true;
                    System.assertEquals('Stagnant Leads', tab.label, 'Expected Christopher to see all stagnant LO leads.');
                    System.assertEquals('Lead', tab.objectApiName, 'Expected stagnant lead monitor to open Leads.');
                }
                if (tab.key == 'locksExpiring') {
                    foundLocksExpiringTab = true;
                    System.assertEquals('Locks Expiring within a Week', tab.label, 'Expected Jamie-style lock expiration tab label.');
                    System.assertEquals('Transaction__c', tab.objectApiName, 'Expected lock expiration tab to open transactions.');
                    System.assertEquals(12, tab.customColumns.size(), 'Expected lock expiration tab to show rate lock, closing, funding date, and loan officer columns.');
                }
                if (tab.key == 'openCocRequests') {
                    foundOpenCocRequestsTab = true;
                    System.assertEquals('Open COC Requests', tab.label, 'Expected Jamie-style open COC request tab label.');
                    System.assertEquals('Transaction__c', tab.objectApiName, 'Expected open COC tab to open transactions.');
                }
            }
            System.assert(foundAllLoActiveLeadsTab, 'Expected Christopher management view to include all LO active leads.');
            System.assert(foundAllLoNewLeadAlertsTab, 'Expected Christopher management view to include all LO new leads needing contact.');
            System.assert(foundAllLoAttentionLeadsTab, 'Expected Christopher management view to include all LO leads needing attention.');
            System.assert(foundAllLoStagnantLeadsTab, 'Expected Christopher management view to include all LO stagnant leads.');
            System.assert(foundLocksExpiringTab, 'Expected Christopher management view to include the lock expiration tab.');
            System.assert(foundOpenCocRequestsTab, 'Expected Christopher management view to include the open COC request tab.');
        }
    }

    @IsTest
    static void brandonGetsExecutiveLoanOfficerView() {
        User brandon = createNamedUser('brand', 'Brandon', 'Brotsky', 'Loan Officer');

        System.runAs(brandon) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Transaction__c', data.pipelineObjectApiName, 'Brandon should land on transaction oversight first.');
            System.assertEquals('Management Command Center', data.headerTitle, 'Expected Brandon management header.');
            System.assertEquals('Active Pipeline', data.pipelineTitle, 'Expected executive active pipeline first.');
            System.assertEquals(true, data.canCreateLead, 'Management command centers should be able to create leads from the Home Screen.');
            System.assertEquals(4, data.statusCards.size(), 'Executive view should show four executive cards.');
            System.assertEquals('Production Board This Month', data.statusCards[0].label, 'Expected current-month production card.');
            System.assertEquals('Production Board Next Month', data.statusCards[1].label, 'Expected next-month production card.');
            System.assertEquals('Active House Leads', data.statusCards[2].label, 'Expected active house leads card.');
            System.assertEquals('Active Pre-Approvals in 2026', data.statusCards[3].label, 'Expected house pre-approval card.');
            System.assertEquals('Brandon_Production_This_Month', data.statusCards[0].filterName, 'Expected linked production list view.');
            System.assertEquals(6, data.pipelineTabs.size(), 'Expected Brandon six-tab executive/LO view.');
            System.assertEquals('executiveConversionMetrics', data.pipelineTabs[0].key, 'Expected conversion metrics first.');
            System.assertEquals('Metric', data.pipelineTabs[0].objectApiName, 'Conversion tab should use the metric table.');
            System.assert(data.pipelineTabs[0].metricRows.size() > 0, 'Expected conversion metric rows.');
            System.assertEquals('executiveAssignedLeads', data.pipelineTabs[1].key, 'Expected Brandon assigned leads second.');
            System.assertEquals('executiveNewLeadAlerts', data.pipelineTabs[2].key, 'Expected Brandon new lead alerts third.');
            System.assertEquals('executiveLeadsWithEventsToday', data.pipelineTabs[3].key, 'Expected Brandon events tab fourth.');
            System.assertEquals('executiveActivePipeline', data.pipelineTabs[4].key, 'Expected active transactions fifth.');
            System.assertEquals('executiveFilesInClosing', data.pipelineTabs[5].key, 'Expected closing transactions sixth.');
            System.assertEquals('Lead', data.pipelineTabs[1].objectApiName, 'Assigned leads tab should navigate Lead records.');
        }
    }

    @IsTest
    static void adamGetsCeoCommandCenterView() {
        List<User> executiveUsers = [
            SELECT Id
            FROM User
            WHERE Username = 'astephens@reachhomeloans.com'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, executiveUsers.size(), 'Expected Adam Stephens active user for the Executive View.');

        System.runAs(executiveUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            System.assertEquals('Metric', data.pipelineObjectApiName, 'Adam should land on company metrics.');
            System.assertEquals('CEO Command Center', data.headerTitle, 'Expected Adam CEO header.');
            System.assertEquals('Executive Overview', data.pipelineTitle, 'Expected CEO overview title.');
            System.assertEquals(4, data.statusCards.size(), 'CEO view should show four high-level cards.');
            System.assertEquals('Funded MTD', data.statusCards[0].label, 'Expected funded MTD card first.');
            System.assert(data.quickButtons.isEmpty(), 'CEO dashboard should not show transaction/list quick buttons.');
            System.assertEquals(7, data.pipelineTabs.size(), 'Expected Adam seven-tab CEO view.');
            System.assertEquals('ceoLeads', data.pipelineTabs[0].key, 'Expected lead metrics first.');
            System.assertEquals('ceoTransactions', data.pipelineTabs[1].key, 'Expected transaction metrics second.');
            System.assertEquals('ceoTrends', data.pipelineTabs[2].key, 'Expected trend metrics third.');
            System.assertEquals('ceoLoanOfficers', data.pipelineTabs[3].key, 'Expected loan officer metrics fourth.');
            System.assert(data.pipelineTabs[0].customColumns.size() > 0, 'Expected CEO tabs to use custom columns.');
            System.assert(data.pipelineTabs[0].rows.size() > 0, 'Expected CEO lead metrics rows.');
        }
    }

    @IsTest
    static void benGetsAssignedWebinarLeadTab() {
        List<User> benUsers = [
            SELECT Id
            FROM User
            WHERE Name = 'Benjamin Bondarevsky'
            AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(1, benUsers.size(), 'Expected Benjamin Bondarevsky active user for the Ben Command Center.');

        System.runAs(benUsers[0]) {
            Test.startTest();
            PipelineCommandCenterController.DashboardData data = PipelineCommandCenterController.getDashboardData();
            Test.stopTest();

            Boolean foundAssignedWebinarTab = false;
            Boolean foundBrandonAgedPreApprovalTab = false;
            Boolean foundHotFollowUpsTab = false;
            Boolean foundWarmFollowUpsTab = false;
            for (PipelineCommandCenterController.PipelineTab tab : data.pipelineTabs) {
                if (tab.key == 'benPastClientHotFollowUps') {
                    foundHotFollowUpsTab = true;
                    System.assertEquals('Hot Follow Ups', tab.label, 'Expected Ben hot follow-up tab label.');
                    System.assertEquals('Account', tab.objectApiName, 'Expected Ben hot follow-up tab to open Account records.');
                    System.assertEquals(11, tab.customColumns.size(), 'Expected Ben hot follow-up tab to include the borrower rating column.');
                }
                if (tab.key == 'benPastClientWarmFollowUps') {
                    foundWarmFollowUpsTab = true;
                    System.assertEquals('Warm Follow Ups', tab.label, 'Expected Ben warm follow-up tab label.');
                    System.assertEquals('Account', tab.objectApiName, 'Expected Ben warm follow-up tab to open Account records.');
                    System.assertEquals(11, tab.customColumns.size(), 'Expected Ben warm follow-up tab to include the borrower rating column.');
                }
                if (tab.key == 'benConsumerWebinarAssigned') {
                    foundAssignedWebinarTab = true;
                    System.assertEquals('My Assigned Webinar Leads', tab.label, 'Expected Ben assigned webinar tab label.');
                    System.assertEquals('Lead', tab.objectApiName, 'Expected Ben assigned webinar tab to open Lead records.');
                    System.assertEquals(12, tab.customColumns.size(), 'Expected Ben webinar tab to include the requested lead, event, and loan columns.');
                }
                if (tab.key == 'benPreApprovalBrandonAged') {
                    foundBrandonAgedPreApprovalTab = true;
                    System.assertEquals('Brandon\'s Aged Pre-Approvals', tab.label, 'Expected Brandon aged pre-approval tab label.');
                    System.assertEquals('Lead', tab.objectApiName, 'Expected Brandon aged pre-approval tab to open Lead records.');
                    System.assertEquals(8, tab.customColumns.size(), 'Expected Brandon aged pre-approval tab to match the Zach tab columns.');
                }
            }
            System.assert(foundHotFollowUpsTab, 'Expected Ben Command Center to include the Hot Follow Ups tab.');
            System.assert(foundWarmFollowUpsTab, 'Expected Ben Command Center to include the Warm Follow Ups tab.');
            System.assert(foundAssignedWebinarTab, 'Expected Ben Command Center to include the assigned webinar leads tab.');
            System.assert(foundBrandonAgedPreApprovalTab, 'Expected Ben Command Center to include the Brandon aged pre-approval tab.');
        }
    }
}