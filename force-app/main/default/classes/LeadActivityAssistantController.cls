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

        public LeadContext(String defaultOwnerId, List<AssigneeOption> assignees, Boolean hasBuyerAgent, Boolean isConsumerLead) {
            this.defaultOwnerId = defaultOwnerId;
            this.assignees = assignees;
            this.hasBuyerAgent = hasBuyerAgent;
            this.isConsumerLead = isConsumerLead;
        }
    }

    @AuraEnabled
    public static LeadContext getLeadContext(Id leadId) {
        validateLeadId(leadId);
        Lead leadRecord = [
            SELECT OwnerId, Owner.Name, Loan_Partner__c, Loan_Partner__r.Name, Realtor_Buying_Agent__c,
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
        return new LeadContext(defaultAssigneeId, assignees, leadRecord.Realtor_Buying_Agent__c != null, isConsumerLead(leadRecord));
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
        Integer reminderMinutes
    ) {
        validateLeadId(leadId);
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject is required.');
        }

        String trimmedSubject = subject.trim();
        Datetime startsAt = parseDateTime(followUpDateTime);
        Lead leadBeforeSave = [
            SELECT Status
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        Task taskRecord = new Task();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Task.fields.getMap();
        taskRecord.WhoId = leadId;
        taskRecord.Subject = taskSubject(trimmedSubject);
        taskRecord.Description = String.isBlank(internalNote) ? null : internalNote.trim();
        taskRecord.ActivityDate = Date.today();
        taskRecord.Status = String.isBlank(taskStatus) ? 'Completed' : taskStatus.trim();
        taskRecord.Priority = 'Normal';
        taskRecord.Type = 'Call';
        taskRecord.TaskSubtype = 'Call';
        taskRecord.CallType = 'Outbound';
        putIfCreateable(taskRecord, fields, 'Lead__c', leadId);
        putIfCreateable(taskRecord, fields, 'Subject__c', restrictedTaskSubjectValue(trimmedSubject));
        putIfCreateable(taskRecord, fields, 'InteractionType__c', 'Call');
        putIfCreateable(taskRecord, fields, 'Direction__c', 'Outbound');
        putIfCreateable(taskRecord, fields, 'Create_Enhanced_Note__c', false);
        putIfCreateable(taskRecord, fields, 'Follow_Up_Date__c', startsAt);
        putIfFieldExists(taskRecord, fields, 'External_Message_to_Buyer_s_Agent__c', normalizeBuyerAgentMessage(buyerAgentMessage));
        putIfFieldExists(taskRecord, fields, 'External_Message_to_Buyer_s_Agent_Contin__c', normalizeBuyerAgentMessage(buyerAgentMessageMore));

        try {
            insert taskRecord;
        } catch (DmlException ex) {
            throw new AuraHandledException(friendlyTaskError(ex));
        }

        applyLeadStatusFallback(leadId, leadBeforeSave.Status, trimmedSubject);
        if (startsAt != null) {
            alignFlowCreatedFollowUpEvent(
                leadId,
                startsAt,
                isUserId(ownerId) ? ownerId : null,
                durationMinutes,
                reminderSet,
                reminderMinutes,
                internalNote
            );
        }
        createLeadNote(leadId, trimmedSubject, internalNote);
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
        validateLeadId(leadId);
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
        eventRecord.WhoId = leadId;
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
        updateLeadAppointmentDateTime(leadId, startsAt);
        return new SaveResult(eventRecord.Id, 'Event scheduled.');
    }

    private static void validateLeadId(Id leadId) {
        if (leadId == null || String.valueOf(leadId).left(3) != Lead.SObjectType.getDescribe().getKeyPrefix()) {
            throw new AuraHandledException('A Lead record is required.');
        }
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

    private static Id resolveEventOwnerId(Id leadId, Id requestedOwnerId) {
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
        String description
    ) {
        List<Event> events = [
            SELECT Id, OwnerId, StartDateTime, EndDateTime, IsReminderSet, ReminderDateTime, Description
            FROM Event
            WHERE WhoId = :leadId
            AND StartDateTime = :startsAt
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (events.isEmpty()) {
            createEvent(
                leadId,
                'Scheduled Appointment',
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
        putIfUpdateable(eventRecord, fields, 'EndDateTime', startsAt.addMinutes(duration));
        putIfUpdateable(eventRecord, fields, 'Description', normalizeText(description));
        putIfUpdateable(eventRecord, fields, 'IsReminderSet', shouldSetReminder);
        putIfUpdateable(eventRecord, fields, 'ReminderDateTime', shouldSetReminder ? startsAt.addMinutes(-reminder) : null);
        update eventRecord;
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

    private static void createLeadNote(Id leadId, String subject, String internalNote) {
        if (String.isBlank(internalNote)) {
            return;
        }
        String cleanedNote = internalNote.trim();
        String enhancedBody = '<p>' + cleanedNote.escapeHtml4() + '</p>';
        if (!enhancedNoteAlreadyExists(leadId, cleanedNote, enhancedBody)) {
            insert new Enhanced_Note__c(
                Lead__c = leadId,
                Subject__c = taskSubject(subject),
                Body__c = enhancedBody,
                Type__c = 'Note',
                Direction__c = 'Outbound'
            );
        }

        ContentNote leadNote = new ContentNote(
            Title = 'Lead Call Note - ' + DateTime.now().format('M/d/yyyy h:mm a'),
            Content = Blob.valueOf(cleanedNote)
        );
        insert leadNote;

        insert new ContentDocumentLink(
            ContentDocumentId = leadNote.Id,
            LinkedEntityId = leadId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static Boolean enhancedNoteAlreadyExists(Id leadId, String cleanedNote, String enhancedBody) {
        for (Enhanced_Note__c existingNote : [
            SELECT Id, Body__c
            FROM Enhanced_Note__c
            WHERE Lead__c = :leadId
            AND CreatedDate = TODAY
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            String existingBody = String.valueOf(existingNote.Body__c);
            if (existingNote.Body__c == enhancedBody || (!String.isBlank(existingBody) && existingBody.contains(cleanedNote))) {
                return true;
            }
        }
        return false;
    }

    private static void updateLeadAppointmentDateTime(Id leadId, Datetime startsAt) {
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
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leadRecord.Appointment_Date_Time__c == null || leadRecord.Appointment_Date_Time__c < startsAt) {
            update new Lead(Id = leadId, Appointment_Date_Time__c = startsAt);
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