public with sharing class LeadActivityAssistantController {
    private static final String BENJAMIN_BONDAREVSKY_NAME = 'Benjamin Bondarevsky';

    public class SaveResult {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String message;

        public SaveResult(Id recordId, String message) {
            this.recordId = recordId;
            this.message = message;
        }
    }

    public class AssigneeOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public AssigneeOption(String label, Id value) {
            this.label = label;
            this.value = value == null ? null : String.valueOf(value);
        }
    }

    public class LeadContext {
        @AuraEnabled public String defaultOwnerId;
        @AuraEnabled public List<AssigneeOption> assignees;
        @AuraEnabled public Boolean hasBuyerAgent;
        @AuraEnabled public Boolean isConsumerLead;
        @AuraEnabled public String leadName;
        @AuraEnabled public String objectApiName;

        public LeadContext(String defaultOwnerId, List<AssigneeOption> assignees, Boolean hasBuyerAgent, Boolean isConsumerLead, String leadName, String objectApiName) {
            this.defaultOwnerId = defaultOwnerId;
            this.assignees = assignees;
            this.hasBuyerAgent = hasBuyerAgent;
            this.isConsumerLead = isConsumerLead;
            this.leadName = leadName;
            this.objectApiName = objectApiName;
        }
    }

    @AuraEnabled
    public static LeadContext getLeadContext(Id leadId) {
        validateActivityRecordId(leadId);
        if (isAccountId(leadId)) {
            return getAccountContext(leadId);
        }
        Lead leadRecord = [
            SELECT Name, OwnerId, Owner.Name, Loan_Partner__c, Loan_Partner__r.Name, Realtor_Buying_Agent__c,
                RecordType.DeveloperName, RecordType.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        List<AssigneeOption> assignees = standardLeadAssignees(leadRecord);
        if (assignees.isEmpty()) {
            assignees.add(new AssigneeOption('Me', UserInfo.getUserId()));
        }

        String defaultAssigneeId = isUserId(leadRecord.OwnerId) ? String.valueOf(leadRecord.OwnerId) : assignees[0].value;
        return new LeadContext(defaultAssigneeId, assignees, leadRecord.Realtor_Buying_Agent__c != null, isConsumerLead(leadRecord), leadRecord.Name, 'Lead');
    }

    private static LeadContext getAccountContext(Id accountId) {
        Account accountRecord = [
            SELECT Name, IsPersonAccount, OwnerId, Owner.Name, Follow_Up_LO__c, Follow_Up_LO__r.Name,
                Preferred_LO__c, Preferred_LO__r.Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (!accountRecord.IsPersonAccount) {
            throw new AuraHandledException('A Person Account record is required.');
        }

        List<AssigneeOption> assignees = standardAccountAssignees(accountRecord);
        if (assignees.isEmpty()) {
            assignees.add(new AssigneeOption('Me', UserInfo.getUserId()));
        }

        String defaultAssigneeId = isUserId(accountRecord.OwnerId) ? String.valueOf(accountRecord.OwnerId) : assignees[0].value;
        return new LeadContext(defaultAssigneeId, assignees, false, false, accountRecord.Name, 'Account');
    }

    @AuraEnabled
    public static SaveResult logCall(
        Id leadId,
        String subject,
        String taskStatus,
        String internalNote,
        String followUpDateTime,
        String buyerAgentMessage,
        String buyerAgentMessageMore,
        Id ownerId,
        Integer durationMinutes,
        Boolean reminderSet,
        Integer reminderMinutes,
        String eventSubject
    ) {
        validateActivityRecordId(leadId);
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject is required.');
        }

        String trimmedSubject = subject.trim();
        Datetime startsAt = parseDateTime(followUpDateTime);
        Boolean isLeadRecord = isLeadId(leadId);
        Lead leadBeforeSave;
        if (isLeadRecord) {
            leadBeforeSave = [
                SELECT Status
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
        }

        Task taskRecord = new Task();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Task.fields.getMap();
        if (isLeadRecord) {
            taskRecord.WhoId = leadId;
        } else {
            taskRecord.WhatId = leadId;
        }
        taskRecord.Subject = taskSubject(trimmedSubject);
        taskRecord.Description = String.isBlank(internalNote) ? null : internalNote.trim();
        taskRecord.ActivityDate = Date.today();
        taskRecord.Status = String.isBlank(taskStatus) ? 'Completed' : taskStatus.trim();
        taskRecord.Priority = 'Normal';
        taskRecord.Type = 'Call';
        taskRecord.TaskSubtype = 'Call';
        taskRecord.CallType = 'Outbound';
        if (isLeadRecord) {
            putIfCreateable(taskRecord, fields, 'Lead__c', leadId);
        } else {
            putIfCreateable(taskRecord, fields, 'Account__c', leadId);
        }
        putIfCreateable(taskRecord, fields, 'Subject__c', restrictedTaskSubjectValue(trimmedSubject));
        putIfCreateable(taskRecord, fields, 'InteractionType__c', 'Call');
        putIfCreateable(taskRecord, fields, 'Direction__c', 'Outbound');
        putIfCreateable(taskRecord, fields, 'Create_Enhanced_Note__c', false);
        putIfCreateable(taskRecord, fields, 'Follow_Up_Date__c', startsAt);
        if (isLeadRecord) {
            putIfFieldExists(taskRecord, fields, 'External_Message_to_Buyer_s_Agent__c', normalizeBuyerAgentMessage(buyerAgentMessage));
            putIfFieldExists(taskRecord, fields, 'External_Message_to_Buyer_s_Agent_Contin__c', normalizeBuyerAgentMessage(buyerAgentMessageMore));
        }

        try {
            insert taskRecord;
        } catch (DmlException ex) {
            throw new AuraHandledException(friendlyTaskError(ex));
        }

        if (isLeadRecord) {
            applyLeadStatusFallback(leadId, leadBeforeSave.Status, trimmedSubject);
        }
        if (startsAt != null) {
            alignFlowCreatedFollowUpEvent(
                leadId,
                startsAt,
                isUserId(ownerId) ? ownerId : null,
                durationMinutes,
                reminderSet,
                reminderMinutes,
                internalNote,
                eventSubject
            );
        }
        createActivityNote(leadId, trimmedSubject, internalNote);
        return new SaveResult(taskRecord.Id, 'Call logged.');
    }

    @AuraEnabled
    public static SaveResult createEvent(
        Id leadId,
        String subject,
        Id ownerId,
        String startDateTime,
        Integer durationMinutes,
        Boolean reminderSet,
        Integer reminderMinutes,
        String description
    ) {
        validateActivityRecordId(leadId);
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Event subject is required.');
        }

        Datetime startsAt = parseDateTime(startDateTime);
        if (startsAt == null) {
            throw new AuraHandledException('Start date/time is required.');
        }

        Integer duration = durationMinutes == null || durationMinutes <= 0 ? 15 : durationMinutes;
        Integer reminder = reminderMinutes == null || reminderMinutes < 0 ? 15 : reminderMinutes;
        Id eventOwnerId = resolveEventOwnerId(leadId, ownerId);
        Event eventRecord = new Event();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Event.fields.getMap();
        if (isLeadId(leadId)) {
            eventRecord.WhoId = leadId;
        } else {
            eventRecord.WhatId = leadId;
        }
        eventRecord.OwnerId = eventOwnerId;
        eventRecord.Subject = subject.trim();
        eventRecord.StartDateTime = startsAt;
        eventRecord.EndDateTime = startsAt.addMinutes(duration);
        eventRecord.Description = normalizeText(description);
        putIfCreateable(eventRecord, fields, 'Event_Type__c', 'Scheduled Appointment');
        Boolean shouldSetReminder = reminderSet == null ? true : reminderSet;
        eventRecord.IsReminderSet = shouldSetReminder;
        if (shouldSetReminder) {
            eventRecord.ReminderDateTime = startsAt.addMinutes(-reminder);
        }

        insert eventRecord;
        updateAppointmentDateTime(leadId, startsAt);
        return new SaveResult(eventRecord.Id, 'Event scheduled.');
    }

    private static void validateActivityRecordId(Id recordId) {
        if (recordId == null || (!isLeadId(recordId) && !isAccountId(recordId))) {
            throw new AuraHandledException('A Lead or Person Account record is required.');
        }
    }

    private static Boolean isLeadId(Id recordId) {
        return recordId != null && recordId.getSObjectType() == Lead.SObjectType;
    }

    private static Boolean isAccountId(Id recordId) {
        return recordId != null && recordId.getSObjectType() == Account.SObjectType;
    }

    private static Boolean isUserId(Id recordId) {
        return recordId != null && String.valueOf(recordId).left(3) == User.SObjectType.getDescribe().getKeyPrefix();
    }

    private static Boolean isConsumerLead(Lead leadRecord) {
        return !isRealtorLead(leadRecord);
    }

    private static Boolean isRealtorLead(Lead leadRecord) {
        if (leadRecord == null || leadRecord.RecordType == null) {
            return false;
        }
        String developerName = leadRecord.RecordType.DeveloperName == null ? '' : leadRecord.RecordType.DeveloperName;
        String recordTypeName = leadRecord.RecordType.Name == null ? '' : leadRecord.RecordType.Name;
        return (developerName + ' ' + recordTypeName).toLowerCase().contains('realtor');
    }

    private static List<AssigneeOption> standardLeadAssignees(Lead leadRecord) {
        List<AssigneeOption> assignees = new List<AssigneeOption>();
        Set<Id> assigneeIds = new Set<Id>();
        if (isUserId(leadRecord.OwnerId)) {
            assignees.add(new AssigneeOption('Lead Owner: ' + leadRecord.Owner.Name, leadRecord.OwnerId));
            assigneeIds.add(leadRecord.OwnerId);
        }
        if (isUserId(leadRecord.Loan_Partner__c) && leadRecord.Loan_Partner__c != leadRecord.OwnerId) {
            assignees.add(new AssigneeOption('Loan Partner: ' + leadRecord.Loan_Partner__r.Name, leadRecord.Loan_Partner__c));
            assigneeIds.add(leadRecord.Loan_Partner__c);
        }
        User benjaminBondarevsky = benjaminBondarevskyUser();
        if (benjaminBondarevsky != null && !assigneeIds.contains(benjaminBondarevsky.Id)) {
            assignees.add(new AssigneeOption(BENJAMIN_BONDAREVSKY_NAME, benjaminBondarevsky.Id));
        }
        return assignees;
    }

    private static List<AssigneeOption> standardAccountAssignees(Account accountRecord) {
        List<AssigneeOption> assignees = new List<AssigneeOption>();
        Set<Id> assigneeIds = new Set<Id>();
        if (isUserId(accountRecord.OwnerId)) {
            assignees.add(new AssigneeOption('Account Owner: ' + accountRecord.Owner.Name, accountRecord.OwnerId));
            assigneeIds.add(accountRecord.OwnerId);
        }
        if (isUserId(accountRecord.Follow_Up_LO__c) && !assigneeIds.contains(accountRecord.Follow_Up_LO__c)) {
            assignees.add(new AssigneeOption('Follow Up LO: ' + accountRecord.Follow_Up_LO__r.Name, accountRecord.Follow_Up_LO__c));
            assigneeIds.add(accountRecord.Follow_Up_LO__c);
        }
        if (isUserId(accountRecord.Preferred_LO__c) && !assigneeIds.contains(accountRecord.Preferred_LO__c)) {
            assignees.add(new AssigneeOption('Preferred LO: ' + accountRecord.Preferred_LO__r.Name, accountRecord.Preferred_LO__c));
            assigneeIds.add(accountRecord.Preferred_LO__c);
        }
        User benjaminBondarevsky = benjaminBondarevskyUser();
        if (benjaminBondarevsky != null && !assigneeIds.contains(benjaminBondarevsky.Id)) {
            assignees.add(new AssigneeOption(BENJAMIN_BONDAREVSKY_NAME, benjaminBondarevsky.Id));
        }
        return assignees;
    }

    private static Id resolveEventOwnerId(Id leadId, Id requestedOwnerId) {
        if (isAccountId(leadId)) {
            return resolveAccountEventOwnerId(leadId, requestedOwnerId);
        }
        Lead leadRecord = [
            SELECT OwnerId, Loan_Partner__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        Set<Id> validOwnerIds = new Set<Id>();
        if (isUserId(leadRecord.OwnerId)) {
            validOwnerIds.add(leadRecord.OwnerId);
        }
        if (isUserId(leadRecord.Loan_Partner__c)) {
            validOwnerIds.add(leadRecord.Loan_Partner__c);
        }
        User benjaminBondarevsky = benjaminBondarevskyUser();
        if (benjaminBondarevsky != null) {
            validOwnerIds.add(benjaminBondarevsky.Id);
        }
        if (isUserId(requestedOwnerId) && validOwnerIds.contains(requestedOwnerId)) {
            return requestedOwnerId;
        }
        if (isUserId(leadRecord.OwnerId)) {
            return leadRecord.OwnerId;
        }
        return UserInfo.getUserId();
    }

    private static Id resolveAccountEventOwnerId(Id accountId, Id requestedOwnerId) {
        Account accountRecord = [
            SELECT OwnerId, Follow_Up_LO__c, Preferred_LO__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        Set<Id> validOwnerIds = new Set<Id>();
        if (isUserId(accountRecord.OwnerId)) {
            validOwnerIds.add(accountRecord.OwnerId);
        }
        if (isUserId(accountRecord.Follow_Up_LO__c)) {
            validOwnerIds.add(accountRecord.Follow_Up_LO__c);
        }
        if (isUserId(accountRecord.Preferred_LO__c)) {
            validOwnerIds.add(accountRecord.Preferred_LO__c);
        }
        User benjaminBondarevsky = benjaminBondarevskyUser();
        if (benjaminBondarevsky != null) {
            validOwnerIds.add(benjaminBondarevsky.Id);
        }
        if (isUserId(requestedOwnerId) && validOwnerIds.contains(requestedOwnerId)) {
            return requestedOwnerId;
        }
        if (isUserId(accountRecord.OwnerId)) {
            return accountRecord.OwnerId;
        }
        return UserInfo.getUserId();
    }

    private static User benjaminBondarevskyUser() {
        List<User> users = [
            SELECT Id, Name
            FROM User
            WHERE Name = :BENJAMIN_BONDAREVSKY_NAME
            AND IsActive = true
            ORDER BY CreatedDate ASC, Id ASC
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    private static String normalizeText(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static String normalizeBuyerAgentMessage(String value) {
        String normalized = normalizeText(value);
        return normalized != null && normalized.length() > 255 ? normalized.substring(0, 255) : normalized;
    }

    private static String taskSubject(String subject) {
        return subject + ' on ' + DateTime.now().format('M/d/yyyy h:mm:ss a');
    }

    private static String restrictedTaskSubjectValue(String subject) {
        Set<String> subjectValues = new Set<String>{
            'Call - No Contact',
            'Call - Contacted/Call Back',
            'Call - Working',
            'Call - Application',
            'Call - Docs Requested',
            'Call - Docs Received',
            'Call - Nurturing',
            'Call',
            'Document follow up',
            'Other',
            'Nurture - Preapproval',
            'Under Contract'
        };
        return subjectValues.contains(subject) ? subject : null;
    }

    private static void applyLeadStatusFallback(Id leadId, String statusBeforeSave, String subject) {
        if (String.isBlank(subject)) {
            return;
        }

        Lead leadAfterSave = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leadAfterSave.Status != statusBeforeSave) {
            return;
        }

        String nextStatus = subject == 'Call - No Contact'
            ? nextNoContactStatus(statusBeforeSave)
            : nextLeadStatus(statusBeforeSave, subject);

        if (!String.isBlank(nextStatus) && nextStatus != leadAfterSave.Status) {
            update new Lead(Id = leadId, Status = nextStatus);
        }
    }

    private static String nextNoContactStatus(String currentStatus) {
        if (String.isBlank(currentStatus) || currentStatus == 'New') {
            return 'Contact Attempt 1';
        }
        if (currentStatus != null && currentStatus.startsWith('Contact Attempt ')) {
            String attemptText = currentStatus.replace('Contact Attempt ', '').trim();
            Integer attemptNumber;
            try {
                attemptNumber = Integer.valueOf(attemptText);
            } catch (Exception ex) {
                return null;
            }
            if (attemptNumber >= 1 && attemptNumber < 6) {
                return 'Contact Attempt ' + String.valueOf(attemptNumber + 1);
            }
            if (attemptNumber == 6) {
                return 'Contact Attempt 6';
            }
        }
        return null;
    }

    private static String nextLeadStatus(String currentStatus, String subject) {
        if (subject == 'Call - No Contact') {
            if (currentStatus == 'Contact Attempt 1') {
                return 'Contact Attempt 2';
            }
            if (currentStatus == 'Contact Attempt 2') {
                return 'Contact Attempt 3';
            }
            if (currentStatus == 'Contact Attempt 3') {
                return 'Contact Attempt 3';
            }
            if (currentStatus == 'New' || currentStatus == 'Contacted/Call Back' || String.isBlank(currentStatus)) {
                return 'Contact Attempt 1';
            }
        }

        Map<String, String> statusBySubject = new Map<String, String>{
            'Call - Contacted/Call Back' => 'Contacted/Call Back',
            'Call - Working' => 'Working',
            'Call - Application' => 'Application',
            'Call - Docs Requested' => 'Documents Requested',
            'Call - Docs Received' => 'Documents Received for Review',
            'Call - Nurturing' => 'Nurturing',
            '30 Day Follow Up' => '30 Day + Follow Up',
            'Call Preapproved' => 'Pre-Approval',
            'Nurture - Preapproval' => 'Nurture - Preapproval',
            'Under Contract' => 'Under Contract'
        };
        return statusBySubject.get(subject);
    }

    private static void alignFlowCreatedFollowUpEvent(
        Id leadId,
        Datetime startsAt,
        Id ownerId,
        Integer durationMinutes,
        Boolean reminderSet,
        Integer reminderMinutes,
        String description,
        String subject
    ) {
        List<Event> events;
        if (isLeadId(leadId)) {
            events = [
                SELECT Id, OwnerId, Subject, StartDateTime, EndDateTime, IsReminderSet, ReminderDateTime, Description
                FROM Event
                WHERE WhoId = :leadId
                AND StartDateTime = :startsAt
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } else {
            events = [
                SELECT Id, OwnerId, Subject, StartDateTime, EndDateTime, IsReminderSet, ReminderDateTime, Description
                FROM Event
                WHERE WhatId = :leadId
                AND StartDateTime = :startsAt
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        }
        if (events.isEmpty()) {
            createEvent(
                leadId,
                followUpEventSubject(leadId, subject),
                ownerId,
                String.valueOf(startsAt).replace(' ', 'T').left(16),
                durationMinutes,
                reminderSet,
                reminderMinutes,
                description
            );
            return;
        }

        Integer duration = durationMinutes == null || durationMinutes <= 0 ? 15 : durationMinutes;
        Integer reminder = reminderMinutes == null || reminderMinutes < 0 ? 15 : reminderMinutes;
        Boolean shouldSetReminder = reminderSet == null ? true : reminderSet;
        Event eventRecord = events[0];
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Event.fields.getMap();
        if (ownerId != null) {
            putIfUpdateable(eventRecord, fields, 'OwnerId', ownerId);
        }
        putIfUpdateable(eventRecord, fields, 'Subject', followUpEventSubject(leadId, subject));
        putIfUpdateable(eventRecord, fields, 'EndDateTime', startsAt.addMinutes(duration));
        putIfUpdateable(eventRecord, fields, 'Description', normalizeText(description));
        putIfUpdateable(eventRecord, fields, 'IsReminderSet', shouldSetReminder);
        putIfUpdateable(eventRecord, fields, 'ReminderDateTime', shouldSetReminder ? startsAt.addMinutes(-reminder) : null);
        update eventRecord;
    }

    private static String followUpEventSubject(Id leadId, String subject) {
        if (!String.isBlank(subject)) {
            return subject.trim();
        }
        if (isAccountId(leadId)) {
            Account accountRecord = [
                SELECT Name
                FROM Account
                WHERE Id = :leadId
                LIMIT 1
            ];
            return 'Follow Up - ' + accountRecord.Name;
        }
        Lead leadRecord = [
            SELECT Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        return 'Follow Up - ' + leadRecord.Name;
    }

    private static String friendlyTaskError(DmlException ex) {
        String message = ex.getDmlMessage(0);
        if (String.isBlank(message)) {
            message = ex.getMessage();
        }
        if (isPreApprovalRequirementError(message)) {
            return 'To move this Lead to Pre-Approval, fill in both Lead Rating and Loan Amount on the Lead record, then try again.';
        }
        if (message != null && message.contains('Follow Up Date Time field cannot be blank')) {
            return 'This call requires a future event. Please select a Start Date and Start Time, or make sure this Lead already has a future event set.';
        }
        if (message != null && message.contains('External Message to Buyer')) {
            return 'This status requires an External Message to Buyer Agent before the call can be logged.';
        }
        if (message != null && message.contains('comments cannot be blank')) {
            return 'Internal Note is required for this call action.';
        }
        return String.isBlank(message) ? 'The call could not be logged. Please review the required fields and try again.' : message;
    }

    private static Boolean isPreApprovalRequirementError(String message) {
        if (String.isBlank(message)) {
            return false;
        }

        String normalized = message.toLowerCase();
        return normalized.contains('lead rating')
            && normalized.contains('amount')
            && normalized.contains('pre-approval');
    }

    private static Datetime parseDateTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.trim().replace('T', ' ');
        if (normalized.length() == 16) {
            normalized += ':00';
        }
        return Datetime.valueOf(normalized);
    }

    private static void createActivityNote(Id recordId, String subject, String internalNote) {
        if (String.isBlank(internalNote)) {
            return;
        }
        String cleanedNote = internalNote.trim();
        String enhancedBody = '<p>' + cleanedNote.escapeHtml4() + '</p>';
        if (!enhancedNoteAlreadyExists(recordId, cleanedNote, enhancedBody)) {
            Enhanced_Note__c enhancedNote = new Enhanced_Note__c(
                Subject__c = taskSubject(subject),
                Body__c = enhancedBody,
                Type__c = 'Note',
                Direction__c = 'Outbound'
            );
            if (isLeadId(recordId)) {
                enhancedNote.Lead__c = recordId;
            } else {
                enhancedNote.Account__c = recordId;
            }
            insert enhancedNote;
        }

        ContentNote noteRecord = new ContentNote(
            Title = (isLeadId(recordId) ? 'Lead Call Note - ' : 'Account Call Note - ') + DateTime.now().format('M/d/yyyy h:mm a'),
            Content = Blob.valueOf(cleanedNote)
        );
        insert noteRecord;

        insert new ContentDocumentLink(
            ContentDocumentId = noteRecord.Id,
            LinkedEntityId = recordId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static Boolean enhancedNoteAlreadyExists(Id recordId, String cleanedNote, String enhancedBody) {
        List<Enhanced_Note__c> existingNotes;
        if (isLeadId(recordId)) {
            existingNotes = [
                SELECT Id, Body__c
                FROM Enhanced_Note__c
                WHERE Lead__c = :recordId
                AND CreatedDate = TODAY
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        } else {
            existingNotes = [
                SELECT Id, Body__c
                FROM Enhanced_Note__c
                WHERE Account__c = :recordId
                AND CreatedDate = TODAY
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        }
        for (Enhanced_Note__c existingNote : existingNotes) {
            String existingBody = String.valueOf(existingNote.Body__c);
            if (existingNote.Body__c == enhancedBody || (!String.isBlank(existingBody) && existingBody.contains(cleanedNote))) {
                return true;
            }
        }
        return false;
    }

    private static void updateAppointmentDateTime(Id recordId, Datetime startsAt) {
        if (isAccountId(recordId)) {
            updateAccountAppointmentDateTime(recordId, startsAt);
            return;
        }
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Lead.fields.getMap();
        if (!fields.containsKey('Appointment_Date_Time__c')) {
            return;
        }
        Schema.DescribeFieldResult describeResult = fields.get('Appointment_Date_Time__c').getDescribe();
        if (!describeResult.isUpdateable()) {
            return;
        }

        Lead leadRecord = [
            SELECT Appointment_Date_Time__c
            FROM Lead
            WHERE Id = :recordId
            LIMIT 1
        ];
        if (leadRecord.Appointment_Date_Time__c == null || leadRecord.Appointment_Date_Time__c < startsAt) {
            update new Lead(Id = recordId, Appointment_Date_Time__c = startsAt);
        }
    }

    private static void updateAccountAppointmentDateTime(Id accountId, Datetime startsAt) {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        if (!fields.containsKey('Appointment_Date_Time__c')) {
            return;
        }
        Schema.DescribeFieldResult describeResult = fields.get('Appointment_Date_Time__c').getDescribe();
        if (!describeResult.isUpdateable()) {
            return;
        }

        Account accountRecord = [
            SELECT Appointment_Date_Time__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accountRecord.Appointment_Date_Time__c == null || accountRecord.Appointment_Date_Time__c < startsAt) {
            update new Account(Id = accountId, Appointment_Date_Time__c = startsAt);
        }
    }

    private static void putIfCreateable(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (value == null || !fields.containsKey(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult describeResult = fields.get(fieldName).getDescribe();
        if (describeResult.isCreateable()) {
            record.put(fieldName, value);
        }
    }

    private static void putIfFieldExists(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (value == null || !fields.containsKey(fieldName)) {
            return;
        }
        record.put(fieldName, value);
    }

    private static void putIfUpdateable(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (!fields.containsKey(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult describeResult = fields.get(fieldName).getDescribe();
        if (describeResult.isUpdateable()) {
            record.put(fieldName, value);
        }
    }
}
