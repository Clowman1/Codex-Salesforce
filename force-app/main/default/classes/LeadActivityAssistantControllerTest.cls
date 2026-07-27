@IsTest
private class LeadActivityAssistantControllerTest {
    @IsTest
    static void getLeadContextReturnsOwnerAssignee() {
        Lead leadRecord = new Lead(
            FirstName = 'Context',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'New',
            OwnerId = UserInfo.getUserId()
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.LeadContext context = LeadActivityAssistantController.getLeadContext(leadRecord.Id);
        Test.stopTest();

        System.assertEquals(String.valueOf(UserInfo.getUserId()), context.defaultOwnerId);
        System.assert(!context.assignees.isEmpty(), 'Expected at least one event assignee option.');
    }

    @IsTest
    static void getLeadContextReturnsOwnerAndLoanPartnerAssigneesForBenjamin() {
        User benUser = createTestUser('benjamin', 'benjamin@reachhomeloans.com');
        User ownerUser = createTestUser('leadown', 'leadowner@example.com');
        User loanPartner = createTestUser('loanpart', 'loanpartner@example.com');
        User unrelatedUser = createTestUser('unrelate', 'unrelated@example.com');
        PermissionSet benAccess = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Benjamin_Lead_Activity_Access'
            LIMIT 1
        ];
        insert new PermissionSetAssignment(AssigneeId = benUser.Id, PermissionSetId = benAccess.Id);

        Id leadId;
        System.runAs(ownerUser) {
            LeadLoanPartnerAssignmentService.ownerLoanPartnerOverrides = new Map<Id, Id>{
                ownerUser.Id => loanPartner.Id
            };
            Lead leadRecord = new Lead(
                FirstName = 'Benjamin',
                LastName = 'Context',
                Company = 'Reach Test',
                Status = 'New',
                OwnerId = ownerUser.Id
            );
            insert leadRecord;
            LeadLoanPartnerAssignmentService.ownerLoanPartnerOverrides = null;
            leadId = leadRecord.Id;
            update new Lead(Id = leadId, Loan_Partner__c = loanPartner.Id);
        }

        System.runAs(benUser) {
            Test.startTest();
            LeadActivityAssistantController.LeadContext context = LeadActivityAssistantController.getLeadContext(leadId);
            Test.stopTest();

            System.assertEquals(String.valueOf(ownerUser.Id), context.defaultOwnerId);
            Set<String> assigneeIds = new Set<String>();
            for (LeadActivityAssistantController.AssigneeOption option : context.assignees) {
                assigneeIds.add(option.value);
            }
            System.assertEquals(2, assigneeIds.size(), 'Expected Benjamin to see only the Lead Owner and Loan Partner for event assignment.');
            System.assert(assigneeIds.contains(String.valueOf(ownerUser.Id)), 'Expected the Lead Owner to be assignable.');
            System.assert(assigneeIds.contains(String.valueOf(loanPartner.Id)), 'Expected the Loan Partner to be assignable.');
            System.assert(!assigneeIds.contains(String.valueOf(unrelatedUser.Id)), 'Expected unrelated users to be hidden from this Lead event assignment list.');
        }
    }

    @IsTest
    static void logCallCreatesTask() {
        Lead leadRecord = new Lead(
            FirstName = 'Pilot',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.SaveResult result = LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call',
            'Completed',
            'Internal note for testing',
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            30,
            true,
            15
        );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId);
        Task taskRecord = [
            SELECT WhoId, Lead__c, Subject, Subject__c, Description, Type, Status, Priority, TaskSubtype, InteractionType__c,
                Direction__c, CallType, Follow_Up_Date__c, External_Message_to_Buyer_s_Agent__c, External_Message_to_Buyer_s_Agent_Contin__c
            FROM Task
            WHERE Id = :result.recordId
        ];
        System.assertEquals(leadRecord.Id, taskRecord.WhoId);
        System.assertEquals(leadRecord.Id, taskRecord.Lead__c);
        System.assert(taskRecord.Subject.startsWith('Call'), 'Expected the call subject to retain the entered value.');
        System.assertEquals('Call', taskRecord.Subject__c);
        System.assertEquals('Normal', taskRecord.Priority);
        System.assertEquals('Call', taskRecord.Type);
        System.assertEquals('Call', taskRecord.TaskSubtype);
        System.assertEquals('Call', taskRecord.InteractionType__c);
        System.assertEquals('Outbound', taskRecord.Direction__c);
        System.assertEquals('Outbound', taskRecord.CallType);
        System.assertNotEquals(null, taskRecord.Follow_Up_Date__c);
        System.assertEquals('Internal note for testing', taskRecord.Description);
        List<ContentDocumentLink> linkedNotes = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadRecord.Id
        ];
        System.assert(!linkedNotes.isEmpty(), 'Expected the internal note to be linked to the Lead Notes tab.');
        List<Enhanced_Note__c> enhancedNotes = [
            SELECT Id, Lead__c, Subject__c, Body__c, Type__c
            FROM Enhanced_Note__c
            WHERE Lead__c = :leadRecord.Id
        ];
        Boolean foundVisibleEnhancedNote = false;
        for (Enhanced_Note__c enhancedNote : enhancedNotes) {
            if (enhancedNote.Body__c != null && enhancedNote.Body__c.contains('Internal note for testing')) {
                foundVisibleEnhancedNote = true;
            }
        }
        System.assert(foundVisibleEnhancedNote, 'Expected the internal note to be visible in Enhanced Notes.');
    }

    @IsTest
    static void logCallNoContactUpdatesLeadStatus() {
        Lead leadRecord = new Lead(
            FirstName = 'Attempt',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call - No Contact',
            'Completed',
            null,
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Lead updatedLead = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals('Contact Attempt 1', updatedLead.Status);
    }

    @IsTest
    static void logCallNoContactCyclesLeadStatus() {
        Lead leadRecord = new Lead(
            FirstName = 'AttemptTwo',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'Contact Attempt 1'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call - No Contact',
            'Completed',
            null,
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Lead updatedLead = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals('Contact Attempt 2', updatedLead.Status);
    }

    @IsTest
    static void logCallNoContactDoesNotChangeAdvancedLeadStatus() {
        Lead leadRecord = new Lead(
            FirstName = 'Working',
            LastName = 'NoContact',
            Company = 'Reach Test',
            Status = 'Working'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call - No Contact',
            'Completed',
            null,
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Lead updatedLead = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals('Working', updatedLead.Status);
    }

    @IsTest
    static void logCallSubjectUpdatesMappedLeadStatus() {
        Lead leadRecord = new Lead(
            FirstName = 'Working',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call - Docs Requested',
            'Completed',
            null,
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Lead updatedLead = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals('Documents Requested', updatedLead.Status);
    }

    @IsTest
    static void logCallThirtyDayFollowUpUsesStandardSubjectAndUpdatesLeadStatus() {
        Lead leadRecord = new Lead(
            FirstName = 'Thirty',
            LastName = 'FollowUp',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.SaveResult result = LeadActivityAssistantController.logCall(
            leadRecord.Id,
            '30 Day Follow Up',
            'Completed',
            'Follow up in 30 days',
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Task taskRecord = [
            SELECT Subject, Subject__c
            FROM Task
            WHERE Id = :result.recordId
        ];
        System.assert(taskRecord.Subject.startsWith('30 Day Follow Up'), 'Expected standard Subject to retain the selected activity outcome.');
        System.assertEquals(null, taskRecord.Subject__c, '30 Day Follow Up is not available on the restricted custom Subject field.');
        Lead updatedLead = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals('30 Day + Follow Up', updatedLead.Status);
    }

    @IsTest
    static void logCallPreapprovedUsesStandardSubjectAndUpdatesLeadStatus() {
        Lead leadRecord = new Lead(
            FirstName = 'Preapproval',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'Documents Requested',
            Rating = 'Warm',
            Loan_Amount__c = 250000
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.SaveResult result = LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call Preapproved',
            'Completed',
            'Borrower is pre-approved.',
            '2026-07-01T10:00',
            null,
            null,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Task taskRecord = [
            SELECT Subject, Subject__c
            FROM Task
            WHERE Id = :result.recordId
        ];
        System.assert(taskRecord.Subject.startsWith('Call Preapproved'), 'Expected standard Subject to retain the selected activity outcome.');
        System.assertEquals(null, taskRecord.Subject__c, 'Call Preapproved is not available on the restricted custom Subject field.');
        Lead updatedLead = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals('Pre-Approval', updatedLead.Status);
    }

    @IsTest
    static void createEventCreatesScheduledAppointment() {
        Lead leadRecord = new Lead(
            FirstName = 'Event',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Test.startTest();
        LeadActivityAssistantController.SaveResult result = LeadActivityAssistantController.createEvent(
            leadRecord.Id,
            'Scheduled Appointment',
            UserInfo.getUserId(),
            '2026-07-01T10:00',
            15,
            true,
            15,
            'Meet with borrower'
        );
        Test.stopTest();

        Event eventRecord = [
            SELECT WhoId, Subject, StartDateTime, EndDateTime, IsReminderSet, ReminderDateTime
            FROM Event
            WHERE Id = :result.recordId
        ];
        System.assertEquals(leadRecord.Id, eventRecord.WhoId);
        System.assertEquals('Scheduled Appointment', eventRecord.Subject);
        Long durationMs = eventRecord.EndDateTime.getTime() - eventRecord.StartDateTime.getTime();
        System.assertEquals(15, Integer.valueOf(durationMs / (1000 * 60)));
        System.assertEquals(true, eventRecord.IsReminderSet);
        Long reminderMs = eventRecord.StartDateTime.getTime() - eventRecord.ReminderDateTime.getTime();
        System.assertEquals(15, Integer.valueOf(reminderMs / (1000 * 60)));
        Lead updatedLead = [
            SELECT Appointment_Date_Time__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(eventRecord.StartDateTime, updatedLead.Appointment_Date_Time__c);
    }

    @IsTest
    static void createEventAssignsOnlyOwnerOrLoanPartner() {
        User ownerUser = createTestUser('evtowner', 'evtowner@example.com');
        User loanPartner = createTestUser('evtlp', 'evtlp@example.com');
        User unrelatedUser = createTestUser('evtother', 'evtother@example.com');
        Id leadId;
        System.runAs(ownerUser) {
            Lead leadRecord = new Lead(
                FirstName = 'Partner',
                LastName = 'Event',
                Company = 'Reach Test',
                Status = 'New',
                OwnerId = ownerUser.Id
            );
            insert leadRecord;
            leadId = leadRecord.Id;
            update new Lead(Id = leadId, Loan_Partner__c = loanPartner.Id);
        }

        Test.startTest();
        LeadActivityAssistantController.SaveResult partnerResult = LeadActivityAssistantController.createEvent(
            leadId,
            'Scheduled Appointment',
            loanPartner.Id,
            '2026-07-01T10:00',
            15,
            true,
            15,
            'Loan partner event'
        );
        LeadActivityAssistantController.SaveResult fallbackResult = LeadActivityAssistantController.createEvent(
            leadId,
            'Scheduled Appointment',
            unrelatedUser.Id,
            '2026-07-02T10:00',
            15,
            true,
            15,
            'Invalid assignee should fall back'
        );
        Test.stopTest();

        Map<Id, Event> eventsById = new Map<Id, Event>([
            SELECT OwnerId
            FROM Event
            WHERE Id IN :new Set<Id>{ partnerResult.recordId, fallbackResult.recordId }
        ]);
        System.assertEquals(loanPartner.Id, eventsById.get(partnerResult.recordId).OwnerId, 'Expected Loan Partner event assignment to be honored.');
        System.assertEquals(ownerUser.Id, eventsById.get(fallbackResult.recordId).OwnerId, 'Expected unsupported assignees to fall back to the Lead Owner.');
    }

    @IsTest
    static void logCallStoresBuyerAgentMessagesForTwilioFlow() {
        Lead leadRecord = new Lead(
            FirstName = 'Twilio',
            LastName = 'Lead',
            Company = 'Reach Test',
            Status = 'New',
            LeadSource = 'Realtor Referral'
        );
        insert leadRecord;

        String longPrimaryMessage = 'Primary buyer agent message. ';
        while (longPrimaryMessage.length() <= 300) {
            longPrimaryMessage += 'x';
        }
        String longContinuationMessage = ' Continued buyer agent message. ';
        while (longContinuationMessage.length() <= 300) {
            longContinuationMessage += 'y';
        }

        Test.startTest();
        LeadActivityAssistantController.SaveResult result = LeadActivityAssistantController.logCall(
            leadRecord.Id,
            'Call - Working',
            'Completed',
            'Internal note',
            '2026-07-01T10:00',
            longPrimaryMessage,
            longContinuationMessage,
            UserInfo.getUserId(),
            15,
            true,
            15
        );
        Test.stopTest();

        Task taskRecord = [
            SELECT WhoId, Lead__c, External_Message_to_Buyer_s_Agent__c, External_Message_to_Buyer_s_Agent_Contin__c
            FROM Task
            WHERE Id = :result.recordId
        ];
        System.assertEquals(leadRecord.Id, taskRecord.WhoId);
        System.assertEquals(leadRecord.Id, taskRecord.Lead__c);
        System.assertEquals(255, taskRecord.External_Message_to_Buyer_s_Agent__c.length());
        System.assertEquals(255, taskRecord.External_Message_to_Buyer_s_Agent_Contin__c.length());
        System.assert(taskRecord.External_Message_to_Buyer_s_Agent__c.startsWith('Primary buyer agent message.'));
        System.assert(taskRecord.External_Message_to_Buyer_s_Agent_Contin__c.startsWith('Continued buyer agent message.'));
    }

    private static User createTestUser(String aliasPrefix, String email) {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];
        String uniqueValue = String.valueOf(System.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User userRecord = new User(
            FirstName = aliasPrefix,
            LastName = 'User',
            Alias = aliasPrefix.left(Math.min(8, aliasPrefix.length())),
            Email = email,
            Username = aliasPrefix + uniqueValue + '@example.com',
            CommunityNickname = aliasPrefix + uniqueValue,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileRecord.Id
        );
        insert userRecord;
        return userRecord;
    }
}
