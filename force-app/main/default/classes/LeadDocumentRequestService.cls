public with sharing class LeadDocumentRequestService {
    private static final String DEFAULT_STATUS = 'New';
    private static final String REQUESTED_STATUS = 'Requested';
    private static final String REVIEW_STATUS = 'Review';
    private static final String APPROVED_STATUS = 'Approved';
    private static final String REVIEW_STATUS_FIELD = 'Condition_Document_Review_Status__c';
    private static final String REVIEW_PENDING = 'Pending Review';
    private static final String REVIEW_ACCEPTED = 'Accepted';
    private static final String REVIEW_REJECTED = 'Rejected';
    private static final String EMAIL_TEMPLATE_DEVELOPER_NAME = 'Lead_Initial_Documents_Needed';
    private static final String REQUESTED_DOCUMENT_LIST_PLACEHOLDER = '{{REQUESTED_DOCUMENT_LIST}}';
    private static final String OWNER_SIGNATURE_PLACEHOLDER = '{{OWNER_SIGNATURE}}';
    private static final String LEAD_PORTAL_LINK_PLACEHOLDER = '{{LEAD_PORTAL_LINK}}';
    private static final String ORG_WIDE_FROM_ADDRESS = 'reachus@reachhomeloans.com';
    @TestVisible private static String testLeadHomeUrlOverride;
    @TestVisible private static Map<Id, String> testLeadPortalHashesByLeadId = new Map<Id, String>();

    public class LeadDocumentRequestException extends Exception {}

    public class RequestInput {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String internalNotes { get; set; }
        @AuraEnabled public String comments { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Boolean includeInEmail { get; set; }
        @AuraEnabled public Boolean canBorrowerSee { get; set; }
        @AuraEnabled public Id referenceId { get; set; }
    }

    public class RequestItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public String internalNotes;
        @AuraEnabled public String comments;
        @AuraEnabled public String subject;
        @AuraEnabled public String category;
        @AuraEnabled public String type;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Date requestedDate;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public Boolean includeInEmail;
        @AuraEnabled public Boolean canBorrowerSee;
        @AuraEnabled public Id convertedConditionId;
        @AuraEnabled public Id referenceId;
        @AuraEnabled public Decimal fileCount;

        public RequestItem(Lead_Document_Request__c requestRecord, Decimal linkedFileCount) {
            id = requestRecord.Id;
            name = requestRecord.Name;
            status = requestRecord.Status__c;
            description = requestRecord.Description__c;
            internalNotes = requestRecord.Internal_Notes__c;
            comments = requestRecord.Comments__c;
            subject = requestRecord.Subject__c;
            category = requestRecord.Category__c;
            type = requestRecord.Type__c;
            createdDate = requestRecord.CreatedDate;
            requestedDate = requestRecord.Requested_Date__c;
            assignedToName = requestRecord.Owner == null ? null : requestRecord.Owner.Name;
            includeInEmail = requestRecord.Include_In_Email__c;
            canBorrowerSee = requestRecord.Can_Borrower_See__c;
            convertedConditionId = requestRecord.Converted_Condition__c;
            referenceId = requestRecord.Lead_Document_Request_Reference__c;
            fileCount = linkedFileCount == null ? 0 : linkedFileCount;
        }
    }

    public class LeadDocumentRequestData {
        @AuraEnabled public Id leadId;
        @AuraEnabled public String leadName;
        @AuraEnabled public String borrowerEmail;
        @AuraEnabled public String portalLink;
        @AuraEnabled public Boolean isConverted;
        @AuraEnabled public Id convertedTransactionId;
        @AuraEnabled public List<RequestItem> requests;
    }

    public class EmailInformation {
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
    }

    public class EmailTemplateOption {
        @AuraEnabled public String label;
        @AuraEnabled public String developerName;

        public EmailTemplateOption(String label, String developerName) {
            this.label = label;
            this.developerName = developerName;
        }
    }

    public class DocumentItem {
        @AuraEnabled public Id id;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String filename;
        @AuraEnabled public String folderName;
        @AuraEnabled public String reviewStatus;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Decimal contentSize;

        public DocumentItem(ContentDocument documentRecord) {
            id = documentRecord.Id;
            contentVersionId = documentRecord.LatestPublishedVersionId;
            filename = String.isBlank(documentRecord.FileExtension)
                ? documentRecord.Title
                : documentRecord.Title + '.' + documentRecord.FileExtension;
            folderName = documentRecord.LatestPublishedVersion == null
                ? null
                : String.valueOf(documentRecord.LatestPublishedVersion.get('Folder__c'));
            reviewStatus = documentRecord.LatestPublishedVersion == null
                ? null
                : (Schema.SObjectType.ContentVersion.fields.getMap().containsKey(REVIEW_STATUS_FIELD)
                    ? String.valueOf(documentRecord.LatestPublishedVersion.get(REVIEW_STATUS_FIELD))
                    : null);
            createdByName = documentRecord.CreatedBy == null ? null : documentRecord.CreatedBy.Name;
            createdDate = documentRecord.CreatedDate;
            contentSize = documentRecord.LatestPublishedVersion == null
                ? null
                : documentRecord.LatestPublishedVersion.ContentSize;
        }
    }

    public static LeadDocumentRequestData initializeInternalData(Id leadId) {
        Lead leadRecord = getLeadOrThrow(leadId);
        ensurePortalHash(leadId);

        leadRecord = getLeadOrThrow(leadId);
        List<Lead_Document_Request__c> requestRecords =
            LeadDocumentRequestRepository.getInstance().selectByLeadIds(new Set<Id>{ leadId });
        Map<Id, Decimal> fileCountsByRequestId = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Map<Id, Lead_Document_Request__c>(requestRecords).keySet());

        LeadDocumentRequestData data = new LeadDocumentRequestData();
        data.leadId = leadRecord.Id;
        data.leadName = leadRecord.Name;
        data.borrowerEmail = leadRecord.Email;
        data.portalLink = buildLeadPortalLink(leadRecord);
        data.isConverted = leadRecord.IsConverted;
        data.convertedTransactionId = leadRecord.Converted_Transaction_ID__c;
        data.requests = new List<RequestItem>();
        for (Lead_Document_Request__c requestRecord : requestRecords) {
            data.requests.add(new RequestItem(requestRecord, fileCountsByRequestId.get(requestRecord.Id)));
        }
        return data;
    }

    public static List<RequestItem> saveRequests(Id leadId, List<RequestInput> inputs) {
        Lead leadRecord = getLeadOrThrow(leadId);
        ensureLeadIsOpenForDocumentRequests(leadRecord);

        if (inputs == null) {
            inputs = new List<RequestInput>();
        }

        List<Lead_Document_Request__c> recordsToInsert = new List<Lead_Document_Request__c>();
        List<Lead_Document_Request__c> recordsToUpdate = new List<Lead_Document_Request__c>();
        for (RequestInput input : inputs) {
            if (input == null || (input.id == null
                && String.isBlank(input.name)
                && String.isBlank(input.subject)
                && String.isBlank(input.description)
                && String.isBlank(input.category))) {
                continue;
            }

            String resolvedName = String.isNotBlank(input.name)
                ? input.name
                : (String.isNotBlank(input.subject) ? input.subject : 'Document Request');

            Lead_Document_Request__c requestRecord = new Lead_Document_Request__c(
                Id = input.id,
                Lead__c = leadId,
                Name = resolvedName,
                Status__c = String.isBlank(input.status) ? DEFAULT_STATUS : input.status,
                Description__c = input.description,
                Internal_Notes__c = input.internalNotes,
                Comments__c = input.comments,
                Subject__c = input.subject,
                Category__c = input.category,
                Type__c = String.isBlank(input.type) ? 'Processor' : input.type,
                Include_In_Email__c = input.includeInEmail == true,
                Can_Borrower_See__c = input.canBorrowerSee == true,
                Lead_Document_Request_Reference__c = input.referenceId
            );
            if (requestRecord.Id == null) {
                recordsToInsert.add(requestRecord);
            } else {
                recordsToUpdate.add(requestRecord);
            }
        }

        if (!recordsToInsert.isEmpty()) {
            assertSaveSucceeded(
                Database.insert(recordsToInsert, false, AccessLevel.SYSTEM_MODE),
                'save Lead document requests'
            );
        }
        if (!recordsToUpdate.isEmpty()) {
            assertSaveSucceeded(
                Database.update(recordsToUpdate, false, AccessLevel.SYSTEM_MODE),
                'update Lead document requests'
            );
        }
        if (recordsToInsert.isEmpty() && recordsToUpdate.isEmpty()) {
            throw new LeadDocumentRequestException('Enter request details before saving.');
        }

        return initializeInternalData(leadId).requests;
    }

    public static List<RequestItem> createRequestsFromReferences(Id leadId, List<Id> referenceIds) {
        return createRequestsFromReferences(leadId, referenceIds, 'Processor');
    }

    public static List<RequestItem> createRequestsFromReferences(Id leadId, List<Id> referenceIds, String requestType) {
        Lead leadRecord = getLeadOrThrow(leadId);
        ensureLeadIsOpenForDocumentRequests(leadRecord);
        Set<Id> uniqueReferenceIds = referenceIds == null ? new Set<Id>() : new Set<Id>(referenceIds);
        if (uniqueReferenceIds.isEmpty()) {
            throw new LeadDocumentRequestException('Select at least one document package item before saving.');
        }

        Map<Id, Lead_Document_Request_Reference__c> referencesById =
            LeadDocumentRequestReferenceRepository.getInstance().selectByIds(uniqueReferenceIds);
        List<Lead_Document_Request__c> recordsToInsert = new List<Lead_Document_Request__c>();
        for (Id referenceId : uniqueReferenceIds) {
            Lead_Document_Request_Reference__c referenceRecord = referencesById.get(referenceId);
            if (referenceRecord == null || referenceRecord.Active__c != true) {
                continue;
            }
            recordsToInsert.add(buildRequestFromReference(leadId, referenceRecord, requestType));
        }
        if (recordsToInsert.isEmpty()) {
            throw new LeadDocumentRequestException('No active document package items were found to create.');
        }

        assertSaveSucceeded(
            Database.insert(recordsToInsert, false, AccessLevel.SYSTEM_MODE),
            'save Lead document requests from references'
        );

        return initializeInternalData(leadId).requests;
    }

    public static void deleteRequest(Id requestId) {
        if (requestId == null) {
            return;
        }
        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            return;
        }
        ensureLeadIsOpenForDocumentRequests(getLeadOrThrow(requestRecord.Lead__c));
        Database.delete(new Lead_Document_Request__c(Id = requestId), false, AccessLevel.SYSTEM_MODE);
    }

    public static RequestItem saveNotes(Id requestId, String description, String internalNotes) {
        Lead_Document_Request__c requestRecord = getEditableRequestOrThrow(requestId);
        Lead_Document_Request__c updateRecord = new Lead_Document_Request__c(
            Id = requestId,
            Description__c = description,
            Internal_Notes__c = internalNotes
        );
        Database.update(updateRecord, true, AccessLevel.SYSTEM_MODE);
        requestRecord.Description__c = description;
        requestRecord.Internal_Notes__c = internalNotes;
        Decimal fileCount = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Set<Id>{ requestId }).get(requestId);
        return new RequestItem(requestRecord, fileCount);
    }

    public static RequestItem addComment(Id requestId, String commentText, Boolean publicComment) {
        Lead_Document_Request__c requestRecord = getEditableRequestOrThrow(requestId);
        if (String.isBlank(commentText)) {
            throw new LeadDocumentRequestException('Enter a comment before sending.');
        }

        String existingComments = String.isBlank(requestRecord.Comments__c) ? '' : requestRecord.Comments__c + '\n\n';
        String visibility = publicComment == true ? 'Portal' : 'Internal';
        String commentEntry = '[' + Datetime.now().format('MM/dd/yyyy hh:mm a') + '] ' +
            UserInfo.getName() +
            ' (' +
            visibility +
            '): ' +
            commentText.trim();
        String combinedComments = existingComments + commentEntry;
        if (combinedComments.length() > 32768) {
            combinedComments = combinedComments.substring(combinedComments.length() - 32768);
        }

        Database.update(
            new Lead_Document_Request__c(Id = requestId, Comments__c = combinedComments),
            true,
            AccessLevel.SYSTEM_MODE
        );
        requestRecord.Comments__c = combinedComments;
        Decimal fileCount = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Set<Id>{ requestId }).get(requestId);
        return new RequestItem(requestRecord, fileCount);
    }

    public static RequestItem handleInternalFileUpload(Id requestId, List<Id> contentVersionIds) {
        if (requestId == null) {
            throw new LeadDocumentRequestException('A document request is required for file upload.');
        }
        Set<Id> versionIds = contentVersionIds == null ? new Set<Id>() : new Set<Id>(contentVersionIds);
        if (versionIds.isEmpty()) {
            throw new LeadDocumentRequestException('At least one uploaded document is required.');
        }

        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            throw new LeadDocumentRequestException('Unable to locate the document request for upload.');
        }
        ensureLeadIsOpenForDocumentRequests(getLeadOrThrow(requestRecord.Lead__c));

        String folderName = String.isNotBlank(requestRecord.Category__c) ? requestRecord.Category__c : requestRecord.Name;
        associateContentVersions(versionIds, requestId);
        updateContentVersions(versionIds, folderName, requestId);
        Database.update(
            new Lead_Document_Request__c(Id = requestId, Status__c = 'Review'),
            true,
            AccessLevel.SYSTEM_MODE
        );

        requestRecord.Status__c = 'Review';
        Decimal fileCount = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Set<Id>{ requestId }).get(requestId);
        return new RequestItem(requestRecord, fileCount);
    }

    public static List<DocumentItem> getRequestDocuments(Id requestId) {
        if (requestId == null) {
            return new List<DocumentItem>();
        }

        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            return new List<DocumentItem>();
        }

        List<DocumentItem> documents = new List<DocumentItem>();
        for (ContentDocument documentRecord : LeadDocumentRequestRepository.getInstance()
            .selectDocumentsByLinkedEntityId(requestId)) {
            documents.add(new DocumentItem(documentRecord));
        }
        return documents;
    }

    public static RequestItem approveRequestDocument(Id requestId, Id contentDocumentId) {
        if (requestId == null || contentDocumentId == null) {
            throw new LeadDocumentRequestException('A document request and document are required.');
        }

        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            throw new LeadDocumentRequestException('Unable to locate the Lead document request.');
        }
        ensureLeadIsOpenForDocumentRequests(getLeadOrThrow(requestRecord.Lead__c));

        updateLatestContentVersionReviewStatus(contentDocumentId, REVIEW_ACCEPTED, null, requestId);
        String nextStatus = countPendingDocuments(requestId) == 0 ? APPROVED_STATUS : REVIEW_STATUS;
        Database.update(
            new Lead_Document_Request__c(Id = requestId, Status__c = nextStatus),
            true,
            AccessLevel.SYSTEM_MODE
        );
        requestRecord.Status__c = nextStatus;
        Decimal fileCount = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Set<Id>{ requestId }).get(requestId);
        return new RequestItem(requestRecord, fileCount);
    }

    public static RequestItem rejectRequestDocument(
        Id requestId,
        Id contentDocumentId,
        String rejectionReason,
        String updatedRequestDescription
    ) {
        if (requestId == null || contentDocumentId == null) {
            throw new LeadDocumentRequestException('A document request and document are required.');
        }
        if (String.isBlank(rejectionReason)) {
            throw new LeadDocumentRequestException('Please enter a rejection comment.');
        }

        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            throw new LeadDocumentRequestException('Unable to locate the Lead document request.');
        }
        ensureLeadIsOpenForDocumentRequests(getLeadOrThrow(requestRecord.Lead__c));

        updateLatestContentVersionReviewStatus(contentDocumentId, REVIEW_REJECTED, 'Junk', null);
        removeDocumentLink(requestId, contentDocumentId);

        Lead_Document_Request__c requestUpdate = new Lead_Document_Request__c(Id = requestId);
        requestUpdate.Status__c = countPendingDocuments(requestId) > 0 ? REVIEW_STATUS : REQUESTED_STATUS;
        requestUpdate.Can_Borrower_See__c = true;
        requestUpdate.Include_In_Email__c = true;
        if (String.isNotBlank(updatedRequestDescription)) {
            requestUpdate.Description__c = updatedRequestDescription.trim();
            requestRecord.Description__c = requestUpdate.Description__c;
        }
        Database.update(requestUpdate, true, AccessLevel.SYSTEM_MODE);

        requestRecord.Status__c = requestUpdate.Status__c;
        requestRecord.Can_Borrower_See__c = true;
        requestRecord.Include_In_Email__c = true;
        Decimal fileCount = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Set<Id>{ requestId }).get(requestId);
        return new RequestItem(requestRecord, fileCount);
    }

    private static Lead_Document_Request__c getEditableRequestOrThrow(Id requestId) {
        if (requestId == null) {
            throw new LeadDocumentRequestException('A Lead document request is required.');
        }
        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            throw new LeadDocumentRequestException('Unable to locate the Lead document request.');
        }
        ensureLeadIsOpenForDocumentRequests(getLeadOrThrow(requestRecord.Lead__c));
        return requestRecord;
    }

    public static EmailInformation getEmailPreview(Id leadId) {
        return getEmailTemplatePreview(leadId, EMAIL_TEMPLATE_DEVELOPER_NAME);
    }

    public static List<EmailTemplateOption> getEmailTemplateOptions() {
        return new List<EmailTemplateOption>{
            new EmailTemplateOption('Initial Documents Needed', EMAIL_TEMPLATE_DEVELOPER_NAME)
        };
    }

    public static EmailInformation getEmailTemplatePreview(Id leadId, String templateDeveloperName) {
        Lead leadRecord = getLeadOrThrow(leadId);
        ensureLeadIsOpenForDocumentRequests(leadRecord);
        ensurePortalHash(leadId);
        leadRecord = getLeadOrThrow(leadId);

        List<Lead_Document_Request__c> requestRecords =
            LeadDocumentRequestRepository.getInstance().selectIncludedForEmail(leadId);
        Messaging.SingleEmailMessage rendered = renderTemplate(leadRecord, requestRecords, templateDeveloperName);

        EmailInformation preview = new EmailInformation();
        preview.subject = rendered.getSubject();
        preview.htmlBody = rendered.getHtmlBody();
        return preview;
    }

    public static void sendRequestEmail(Id leadId) {
        EmailInformation rendered = getEmailTemplatePreview(leadId, EMAIL_TEMPLATE_DEVELOPER_NAME);
        sendEditedRequestEmail(leadId, rendered.subject, rendered.htmlBody);
    }

    public static void sendEditedRequestEmail(Id leadId, String subject, String htmlBody) {
        Lead leadRecord = getLeadOrThrow(leadId);
        ensureLeadIsOpenForDocumentRequests(leadRecord);
        if (String.isBlank(leadRecord.Email)) {
            throw new LeadDocumentRequestException('Lead primary borrower email is required before sending document requests.');
        }
        ensurePortalHash(leadId);
        leadRecord = getLeadOrThrow(leadId);

        List<Lead_Document_Request__c> requestRecords =
            LeadDocumentRequestRepository.getInstance().selectIncludedForEmail(leadId);
        if (requestRecords.isEmpty()) {
            throw new LeadDocumentRequestException('At least one document request must be included in the email.');
        }
        if (String.isBlank(subject)) {
            throw new LeadDocumentRequestException('Email subject is required before sending.');
        }
        if (String.isBlank(htmlBody)) {
            throw new LeadDocumentRequestException('Email body is required before sending.');
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(leadRecord.Id);
        mail.setToAddresses(new List<String>{ leadRecord.Email });
        mail.setTreatTargetObjectAsRecipient(false);
        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(true);

        Id orgWideEmailAddressId = LeadDocumentRequestRepository.getInstance()
            .selectOrgWideEmailAddressId(ORG_WIDE_FROM_ADDRESS);
        if (orgWideEmailAddressId != null) {
            mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }

        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }

        markIncludedRequestsAsRequested(requestRecords);
    }

    public static void populateMissingPortalHashes(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Lead leadRecord : LeadDocumentRequestRepository.getInstance().selectLeadsForPortalHash(leadIds).values()) {
            if (String.isBlank(getLeadPortalHash(leadRecord))) {
                String encryptedLeadId = encryptLeadId(leadRecord.Id);
                if (LeadDocumentRequestRepository.getInstance().hasLeadPortalHashField()) {
                    Lead updateRecord = new Lead(Id = leadRecord.Id);
                    updateRecord.put('Portal_Hash_Parameter__c', encryptedLeadId);
                    leadsToUpdate.add(updateRecord);
                }
                if (Test.isRunningTest()) {
                    testLeadPortalHashesByLeadId.put(leadRecord.Id, encryptedLeadId);
                }
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            Database.update(leadsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    public static Id decryptLeadId(String hashFromURL) {
        return Id.valueOf(BorrowerPortalEncryptionService.decryptString(hashFromURL));
    }

    public static String encryptLeadId(Id leadId) {
        return BorrowerPortalEncryptionService.encryptString(String.valueOf(leadId));
    }

    private static Lead getLeadOrThrow(Id leadId) {
        Map<Id, Lead> leads = LeadDocumentRequestRepository.getInstance().selectLeadsByIds(new Set<Id>{ leadId });
        Lead leadRecord = leads.get(leadId);
        if (leadRecord == null) {
            throw new LeadDocumentRequestException('Unable to locate a lead for document collection.');
        }
        return leadRecord;
    }

    private static void ensureLeadIsOpenForDocumentRequests(Lead leadRecord) {
        if (leadRecord != null && leadRecord.IsConverted) {
            throw new LeadDocumentRequestException('Lead document requests can no longer be edited after conversion.');
        }
    }

    private static void ensurePortalHash(Id leadId) {
        populateMissingPortalHashes(new Set<Id>{ leadId });
    }

    private static Messaging.SingleEmailMessage renderTemplate(
        Lead leadRecord,
        List<Lead_Document_Request__c> requestRecords,
        String templateDeveloperName
    ) {
        String resolvedTemplateDeveloperName = String.isBlank(templateDeveloperName)
            ? EMAIL_TEMPLATE_DEVELOPER_NAME
            : templateDeveloperName;
        EmailTemplate template = LeadDocumentRequestRepository.getInstance()
            .selectEmailTemplateByDeveloperName(resolvedTemplateDeveloperName);
        if (template == null) {
            return buildFallbackMessage(null, leadRecord, requestRecords);
        }

        try {
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(
                template.Id,
                leadRecord.Id,
                null
            );
            String renderedHtmlBody = rendered.getHtmlBody();
            if (String.isBlank(renderedHtmlBody)) {
                return buildFallbackMessage(template.Subject, leadRecord, requestRecords);
            }
            rendered.setHtmlBody(prepareRenderedHtmlBody(renderedHtmlBody, leadRecord, requestRecords));
            return rendered;
        } catch (Exception renderException) {
            return buildFallbackMessage(template.Subject, leadRecord, requestRecords);
        }
    }

    private static Messaging.SingleEmailMessage buildFallbackMessage(
        String templateSubject,
        Lead leadRecord,
        List<Lead_Document_Request__c> requestRecords
    ) {
        Messaging.SingleEmailMessage fallback = new Messaging.SingleEmailMessage();
        fallback.setSubject(String.isBlank(templateSubject) ? 'Documents Needed' : templateSubject);
        fallback.setHtmlBody(buildFallbackHtmlBody(leadRecord, requestRecords));
        return fallback;
    }

    private static Lead_Document_Request__c buildRequestFromReference(
        Id leadId,
        Lead_Document_Request_Reference__c referenceRecord,
        String requestType
    ) {
        String resolvedItemDescription = resolveReferenceItemDescription(referenceRecord);
        String resolvedCategoryName = resolveReferenceConditionName(referenceRecord, resolvedItemDescription);
        return new Lead_Document_Request__c(
            Lead__c = leadId,
            Name = resolvedCategoryName,
            Subject__c = resolvedItemDescription,
            Status__c = DEFAULT_STATUS,
            Description__c = resolvedItemDescription,
            Category__c = resolveRuntimePicklistValue(
                Lead_Document_Request__c.Category__c,
                referenceRecord.Category__c
            ),
            Type__c = resolveRuntimePicklistValue(
                Lead_Document_Request__c.Type__c,
                String.isBlank(requestType) ? 'Processor' : requestType
            ),
            Include_In_Email__c = referenceRecord.Include_In_Email__c,
            Can_Borrower_See__c = referenceRecord.Can_Borrower_See__c,
            Lead_Document_Request_Reference__c = referenceRecord.Id
        );
    }

    private static String resolveReferenceRequestName(Lead_Document_Request_Reference__c referenceRecord) {
        if (referenceRecord == null) {
            return 'Document Request';
        }
        String label = referenceRecord.Borrower_Label__c;
        if (new Set<String>{ 'ID', 'Income', 'Assets', 'Gift Letter', 'WVOE' }.contains(label)
            && String.isNotBlank(referenceRecord.Borrower_Description__c)) {
            return referenceRecord.Borrower_Description__c;
        }
        return String.isNotBlank(label) ? label : 'Document Request';
    }

    private static String resolveReferenceItemDescription(Lead_Document_Request_Reference__c referenceRecord) {
        String resolvedName = resolveReferenceRequestName(referenceRecord);
        if (referenceRecord == null || referenceRecord.Package__c != 'Special Income Types') {
            return resolvedName;
        }
        if (String.isBlank(referenceRecord.Borrower_Label__c) || String.isBlank(referenceRecord.Borrower_Description__c)) {
            return resolvedName;
        }
        return referenceRecord.Borrower_Label__c + ' - ' + formatChecklistText(referenceRecord.Borrower_Description__c);
    }

    private static String formatChecklistText(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.replace('\r\n', '\n')
            .replace('\r', '\n')
            .replace('\n- ', ', ')
            .replace('\n', ', ')
            .replace('- ', '')
            .trim();
    }

    private static String resolveReferenceConditionName(
        Lead_Document_Request_Reference__c referenceRecord,
        String resolvedItemDescription
    ) {
        if (referenceRecord == null) {
            return 'Condition';
        }
        String category = referenceRecord.Category__c;
        String label = referenceRecord.Borrower_Label__c;
        if (category == 'ID' || label == 'ID' || isIdentificationItem(resolvedItemDescription)) {
            return 'Identification';
        }
        if (category == 'Assets' || category == 'Gift Letter' || label == 'Assets' || label == 'Gift Letter') {
            return 'Asset';
        }
        if (category == 'REO') {
            return 'Other Items';
        }
        if (String.isNotBlank(category)) {
            return category;
        }
        return String.isNotBlank(label) ? label : 'Condition';
    }

    private static Boolean isIdentificationItem(String value) {
        String normalizedValue = String.isBlank(value) ? '' : value.toLowerCase();
        return normalizedValue.contains('photo id')
            || normalizedValue.contains('driver')
            || normalizedValue.contains('state id')
            || normalizedValue.contains('passport')
            || normalizedValue.contains('visa')
            || normalizedValue.contains('itin')
            || normalizedValue.contains('resident card')
            || normalizedValue.contains('employment authorization');
    }

    private static String resolveRuntimePicklistValue(Schema.SObjectField fieldToken, String requestedValue) {
        if (String.isBlank(requestedValue)) {
            return null;
        }
        Schema.DescribeFieldResult describeResult = fieldToken.getDescribe();
        if (!describeResult.isRestrictedPicklist()) {
            return requestedValue;
        }
        for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == requestedValue) {
                return requestedValue;
            }
        }
        return null;
    }

    private static void assertSaveSucceeded(Database.SaveResult[] saveResults, String operation) {
        List<String> errorMessages = new List<String>();
        for (Database.SaveResult saveResult : saveResults) {
            if (saveResult.isSuccess()) {
                continue;
            }
            for (Database.Error error : saveResult.getErrors()) {
                errorMessages.add(error.getMessage());
            }
        }

        if (!errorMessages.isEmpty()) {
            throw new LeadDocumentRequestException(
                'Unable to ' + operation + ': ' + String.join(errorMessages, '; ')
            );
        }
    }

    private static String buildFallbackHtmlBody(Lead leadRecord, List<Lead_Document_Request__c> requestRecords) {
        String borrowerName = String.isBlank(leadRecord.FirstName) ? 'there' : leadRecord.FirstName.escapeHtml4();
        String body = '<p>Hi ' + borrowerName + ',</p>' +
            '<p>To keep your loan moving, we would like to begin collecting a few documents while your file is still in the lead stage.</p>' +
            '<p>Please upload any requested documentation to this secure portal.</p>' +
            buildRequestedDocumentListHtml(requestRecords);
        body += '<p><a href="' + buildLeadPortalLink(leadRecord).escapeHtml4() +
            '">Upload Files</a></p>' +
            '<p>Please remember that I am here to assist you every step of the way. If you need help gathering any documents or have questions, please reply to this email.</p>' +
            '<p>All the best,</p>';
        return body;
    }

    private static void associateContentVersions(Set<Id> contentVersionIds, Id requestId) {
        List<ContentVersion> versions = LeadDocumentRequestRepository.getInstance()
            .selectContentVersionsByLatestIds(contentVersionIds);
        Map<Id, ContentVersion> versionsById = new Map<Id, ContentVersion>(versions);
        Set<Id> existingDocumentIds = new Set<Id>();
        for (ContentDocumentLink existingLink : LeadDocumentRequestRepository.getInstance()
            .selectDocumentLinksByEntityIds(new Set<Id>{ requestId })) {
            existingDocumentIds.add(existingLink.ContentDocumentId);
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (Id contentVersionId : contentVersionIds) {
            ContentVersion version = versionsById.get(contentVersionId);
            if (version == null || existingDocumentIds.contains(version.ContentDocumentId)) {
                continue;
            }
            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = version.ContentDocumentId,
                LinkedEntityId = requestId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        if (!linksToInsert.isEmpty()) {
            Database.insert(linksToInsert, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void updateContentVersions(Set<Id> contentVersionIds, String folderName, Id requestId) {
        List<ContentVersion> versionsToUpdate = new List<ContentVersion>();
        for (Id contentVersionId : contentVersionIds) {
            ContentVersion versionRecord = new ContentVersion(
                Id = contentVersionId,
                Folder__c = String.isBlank(folderName) ? 'No Category' : folderName,
                Lead_Document_Request__c = requestId
            );
            if (Schema.SObjectType.ContentVersion.fields.getMap().containsKey(REVIEW_STATUS_FIELD)) {
                versionRecord.put(REVIEW_STATUS_FIELD, REVIEW_PENDING);
            }
            versionsToUpdate.add(versionRecord);
        }

        if (!versionsToUpdate.isEmpty()) {
            Database.update(versionsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void updateLatestContentVersionReviewStatus(
        Id contentDocumentId,
        String reviewStatus,
        String folder,
        Id requestId
    ) {
        if (contentDocumentId == null) {
            return;
        }

        List<ContentVersion> latestVersions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = TRUE
            WITH SYSTEM_MODE
        ];
        if (latestVersions.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> fields = Schema.SObjectType.ContentVersion.fields.getMap();
        List<ContentVersion> versionsToUpdate = new List<ContentVersion>();
        for (ContentVersion latestVersion : latestVersions) {
            ContentVersion versionUpdate = new ContentVersion(Id = latestVersion.Id);
            if (fields.containsKey(REVIEW_STATUS_FIELD)) {
                versionUpdate.put(REVIEW_STATUS_FIELD, reviewStatus);
            }
            if (String.isNotBlank(folder) && fields.containsKey('Folder__c')) {
                versionUpdate.Folder__c = folder;
            }
            if (fields.containsKey('Lead_Document_Request__c')) {
                versionUpdate.Lead_Document_Request__c = requestId;
            }
            versionsToUpdate.add(versionUpdate);
        }
        Database.update(versionsToUpdate, true, AccessLevel.SYSTEM_MODE);
    }

    private static Integer countPendingDocuments(Id requestId) {
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : LeadDocumentRequestRepository.getInstance()
            .selectDocumentLinksByEntityIds(new Set<Id>{ requestId })) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        if (contentDocumentIds.isEmpty()) {
            return 0;
        }

        if (!Schema.SObjectType.ContentVersion.fields.getMap().containsKey(REVIEW_STATUS_FIELD)) {
            return 0;
        }

        String query =
            'SELECT Id, ' +
            REVIEW_STATUS_FIELD +
            ' FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = TRUE WITH SYSTEM_MODE';
        Integer pendingCount = 0;
        for (SObject latestVersion : Database.query(query)) {
            String status = (String) latestVersion.get(REVIEW_STATUS_FIELD);
            if (String.isBlank(status) || status == REVIEW_PENDING) {
                pendingCount++;
            }
        }
        return pendingCount;
    }

    private static void removeDocumentLink(Id requestId, Id contentDocumentId) {
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestId
            AND ContentDocumentId = :contentDocumentId
            WITH SYSTEM_MODE
        ];
        if (!linksToDelete.isEmpty()) {
            Database.delete(linksToDelete, true, AccessLevel.SYSTEM_MODE);
        }
    }

    private static String prepareRenderedHtmlBody(
        String htmlBody,
        Lead leadRecord,
        List<Lead_Document_Request__c> requestRecords
    ) {
        String bodyWithPortalLink = addLeadPortalLink(htmlBody, leadRecord);
        String bodyWithDocuments = addRequestedDocumentList(bodyWithPortalLink, requestRecords);
        return addOwnerSignature(bodyWithDocuments, leadRecord);
    }

    private static String addLeadPortalLink(String htmlBody, Lead leadRecord) {
        if (!htmlBody.contains(LEAD_PORTAL_LINK_PLACEHOLDER)) {
            return htmlBody;
        }
        return htmlBody.replace(
            LEAD_PORTAL_LINK_PLACEHOLDER,
            buildLeadPortalLink(leadRecord).escapeHtml4()
        );
    }

    private static String addRequestedDocumentList(
        String htmlBody,
        List<Lead_Document_Request__c> requestRecords
    ) {
        String requestedDocumentsHtml = buildRequestedDocumentListHtml(requestRecords);
        if (htmlBody.contains(REQUESTED_DOCUMENT_LIST_PLACEHOLDER)) {
            return htmlBody.replace(REQUESTED_DOCUMENT_LIST_PLACEHOLDER, requestedDocumentsHtml);
        }
        Integer closingBodyIndex = htmlBody.toLowerCase().lastIndexOf('</body>');
        if (closingBodyIndex < 0) {
            return htmlBody + requestedDocumentsHtml;
        }
        return htmlBody.substring(0, closingBodyIndex) +
            requestedDocumentsHtml +
            htmlBody.substring(closingBodyIndex);
    }

    private static String addOwnerSignature(String htmlBody, Lead leadRecord) {
        String signature = buildOwnerSignature(leadRecord);
        if (htmlBody.contains(OWNER_SIGNATURE_PLACEHOLDER)) {
            return htmlBody.replace(OWNER_SIGNATURE_PLACEHOLDER, signature);
        }
        return htmlBody;
    }

    private static String buildOwnerSignature(Lead leadRecord) {
        if (leadRecord == null || leadRecord.OwnerId == null) {
            return '';
        }
        User owner = LeadDocumentRequestRepository.getInstance()
            .selectUsersByIds(new Set<Id>{ leadRecord.OwnerId })
            .get(leadRecord.OwnerId);
        if (owner == null) {
            return '';
        }

        List<String> nameAndTitle = new List<String>();
        if (String.isNotBlank(owner.Name)) {
            nameAndTitle.add(owner.Name.escapeHtml4());
        }
        if (String.isNotBlank(owner.Title)) {
            nameAndTitle.add(owner.Title.escapeHtml4());
        }

        List<String> contactParts = new List<String>();
        if (String.isNotBlank(owner.Phone)) {
            contactParts.add('(p): ' + owner.Phone.escapeHtml4());
        }
        if (String.isNotBlank(owner.Fax)) {
            contactParts.add('(f): ' + owner.Fax.escapeHtml4());
        }

        String signature = String.join(nameAndTitle, ' | ');
        if (!contactParts.isEmpty()) {
            signature += (String.isBlank(signature) ? '' : '<br/>') + String.join(contactParts, ' | ');
        }
        signature += '<br/>327 Plaza Real #215, Boca Raton, FL, 33432';
        if (String.isNotBlank(owner.NMLS__c)) {
            signature += '<br/>NMLS: ' + owner.NMLS__c.escapeHtml4();
        }
        return signature;
    }

    private static String buildRequestedDocumentListHtml(List<Lead_Document_Request__c> requestRecords) {
        String body = '<ul>';
        for (Lead_Document_Request__c requestRecord : requestRecords) {
            body += '<li><strong>' + requestRecord.Name.escapeHtml4() + '</strong>';
            if (String.isNotBlank(requestRecord.Description__c)) {
                body += ' - ' + requestRecord.Description__c.escapeHtml4();
            }
            body += '</li>';
        }
        body += '</ul>';
        return body;
    }

    public static String getLeadPortalHash(Lead leadRecord) {
        if (leadRecord == null) {
            return null;
        }
        if (LeadDocumentRequestRepository.getInstance().hasLeadPortalHashField()) {
            return (String) leadRecord.get('Portal_Hash_Parameter__c');
        }
        return Test.isRunningTest() ? testLeadPortalHashesByLeadId.get(leadRecord.Id) : null;
    }

    public static String buildLeadPortalLink(Lead leadRecord) {
        if (leadRecord == null) {
            return '';
        }

        if (LeadDocumentRequestRepository.getInstance().hasLeadPortalLinkField()) {
            String formulaLink = (String) leadRecord.get('Lead_Portal_Link_As_URL__c');
            if (String.isNotBlank(formulaLink)) {
                return formulaLink;
            }
        }

        String portalHash = getLeadPortalHash(leadRecord);
        if (String.isBlank(portalHash)) {
            return '';
        }

        String configuredUrl = getConfiguredLeadHomeUrl();
        if (String.isBlank(configuredUrl)) {
            return '';
        }

        String separator = configuredUrl.contains('?') ? '&' : '?';
        return configuredUrl + separator + 'id=' + EncodingUtil.urlEncode(portalHash, 'UTF-8');
    }

    public static Id getTestLeadIdForPortalHash(String portalHash) {
        if (!Test.isRunningTest() || String.isBlank(portalHash)) {
            return null;
        }
        for (Id leadId : testLeadPortalHashesByLeadId.keySet()) {
            if (testLeadPortalHashesByLeadId.get(leadId) == portalHash) {
                return leadId;
            }
        }
        return null;
    }

    private static String getConfiguredLeadHomeUrl() {
        if (Test.isRunningTest() && testLeadHomeUrlOverride != null) {
            return testLeadHomeUrlOverride;
        }
        if (!BorrowerPortalSettings__c.SObjectType.getDescribe().fields.getMap().containsKey('Lead_Borrower_Home_Url__c')) {
            return null;
        }
        BorrowerPortalSettings__c defaults = BorrowerPortalSettings__c.getOrgDefaults();
        return defaults == null ? null : (String) defaults.get('Lead_Borrower_Home_Url__c');
    }

    private static void markIncludedRequestsAsRequested(List<Lead_Document_Request__c> requestRecords) {
        List<Lead_Document_Request__c> requestsToUpdate = new List<Lead_Document_Request__c>();
        for (Lead_Document_Request__c requestRecord : requestRecords) {
            if (requestRecord.Status__c == DEFAULT_STATUS) {
                requestsToUpdate.add(new Lead_Document_Request__c(
                    Id = requestRecord.Id,
                    Status__c = REQUESTED_STATUS,
                    Requested_Date__c = Date.today(),
                    Can_Borrower_See__c = true
                ));
            }
        }

        if (!requestsToUpdate.isEmpty()) {
            Database.update(requestsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }
}
