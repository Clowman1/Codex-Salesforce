public without sharing class LeadDocumentPortalService {
    private static final String REVIEW_STATUS = 'Review';
    private static final String GENERIC_UPLOAD_NAME = 'Generic Document Portal Upload';
    private static final String UNASSIGNED_DOCUMENT_FOLDER = 'Unassigned';
    private static final String ORG_WIDE_FROM_ADDRESS = 'reachus@reachhomeloans.com';

    public class LeadDocumentPortalException extends Exception {}

    public class PortalRequest {
        @AuraEnabled public Id id;
        @AuraEnabled public Id parentId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public String notes;
        @AuraEnabled public Decimal fileCount;

        public PortalRequest(Lead_Document_Request__c requestRecord, Decimal linkedFileCount) {
            id = requestRecord.Id;
            parentId = requestRecord.Lead__c;
            name = requestRecord.Name;
            status = requestRecord.Status__c;
            description = requestRecord.Description__c;
            notes = requestRecord.Subject__c;
            fileCount = linkedFileCount == null ? 0 : linkedFileCount;
        }
    }

    public class PortalData {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String borrowerName;
        @AuraEnabled public String name;
        @AuraEnabled public String loanOfficerEmail;
        @AuraEnabled public String loanOfficerTitle;
        @AuraEnabled public String loanOfficerNmls;
        @AuraEnabled public String phoneNum;
        @AuraEnabled public String mobilePhoneNum;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public Decimal approvedDocuments;
        @AuraEnabled public Decimal requestedDocuments;
        @AuraEnabled public Decimal outstandingDocuments;
        @AuraEnabled public Decimal pendingReviewDocuments;
        @AuraEnabled public String redirectUrl;
        @AuraEnabled public List<PortalRequest> requests;
    }

    public static PortalData initializeData(String hashFromURL, Boolean isInSitePreview) {
        Lead leadRecord = isInSitePreview
            ? getPreviewLead()
            : LeadDocumentRequestRepository.getInstance().selectLeadByPortalHash(hashFromURL);
        if (leadRecord == null && Test.isRunningTest()) {
            Id testLeadId = LeadDocumentRequestService.getTestLeadIdForPortalHash(hashFromURL);
            if (testLeadId != null) {
                leadRecord = LeadDocumentRequestRepository.getInstance()
                    .selectLeadsByIds(new Set<Id>{ testLeadId }).get(testLeadId);
            }
        }

        if (leadRecord == null) {
            throw new LeadDocumentPortalException('Unable to locate a lead document portal record.');
        }

        PortalData response = new PortalData();
        response.recordId = leadRecord.Id;
        response.borrowerName = buildBorrowerName(leadRecord);
        response.requests = new List<PortalRequest>();
        applyRequestCounts(response, new List<Lead_Document_Request__c>());

        if (leadRecord.Converted_Transaction_ID__c != null) {
            response.redirectUrl = buildConvertedTransactionRedirectUrl(leadRecord.Converted_Transaction_ID__c);
            return response;
        }

        List<Lead_Document_Request__c> visibleRequests =
            LeadDocumentRequestRepository.getInstance().selectVisibleByLeadId(leadRecord.Id);
        Map<Id, Decimal> fileCountsByRequestId = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Map<Id, Lead_Document_Request__c>(visibleRequests).keySet());

        applyRequestCounts(response, visibleRequests);
        for (Lead_Document_Request__c requestRecord : visibleRequests) {
            response.requests.add(new PortalRequest(requestRecord, fileCountsByRequestId.get(requestRecord.Id)));
        }

        Map<Id, User> usersById = LeadDocumentRequestRepository.getInstance()
            .selectUsersByIds(new Set<Id>{ leadRecord.OwnerId });
        User loanOfficer = usersById.get(leadRecord.OwnerId);
        response.name = buildUserName(loanOfficer);
        response.loanOfficerEmail = loanOfficer?.Email;
        response.loanOfficerTitle = loanOfficer?.Title;
        response.loanOfficerNmls = loanOfficer?.NMLS__c;
        response.phoneNum = loanOfficer?.Phone;
        response.mobilePhoneNum = loanOfficer?.MobilePhone;
        response.photoUrl = loanOfficer?.Headshot_URL__c;

        return response;
    }

    public static PortalRequest updateRequestOnFileUpload(List<Id> contentVersionIds, Id requestId, String hashFromURL) {
        if (requestId == null) {
            throw new LeadDocumentPortalException('A document request is required for borrower document upload.');
        }

        Set<Id> versionIds = contentVersionIds == null ? new Set<Id>() : new Set<Id>(contentVersionIds);
        if (versionIds.isEmpty()) {
            throw new LeadDocumentPortalException('At least one uploaded document is required.');
        }

        Lead leadRecord = getActivePortalLead(hashFromURL);
        Lead_Document_Request__c requestRecord = LeadDocumentRequestRepository.getInstance()
            .selectRequestForPortalUpload(requestId);
        if (requestRecord == null) {
            throw new LeadDocumentPortalException('Unable to locate the document request for upload.');
        }
        if (requestRecord.Lead__c != leadRecord.Id) {
            throw new LeadDocumentPortalException('The document request does not belong to this lead portal session.');
        }

        String folderName = String.isNotBlank(requestRecord.Category__c) ? requestRecord.Category__c : requestRecord.Name;
        associateContentVersions(versionIds, requestId);
        updateContentVersions(versionIds, folderName, requestId);
        Database.update(
            new Lead_Document_Request__c(Id = requestId, Status__c = REVIEW_STATUS),
            true,
            AccessLevel.SYSTEM_MODE
        );

        requestRecord.Status__c = REVIEW_STATUS;
        Decimal fileCount = LeadDocumentRequestRepository.getInstance()
            .selectLinkedDocumentCountsByRequestIds(new Set<Id>{ requestId }).get(requestId);
        return new PortalRequest(requestRecord, fileCount);
    }

    public static void handleGenericUpload(List<Id> contentVersionIds, String hashFromURL) {
        Set<Id> versionIds = contentVersionIds == null ? new Set<Id>() : new Set<Id>(contentVersionIds);
        if (versionIds.isEmpty()) {
            throw new LeadDocumentPortalException('At least one uploaded document is required.');
        }

        Lead leadRecord = getActivePortalLead(hashFromURL);
        Id leadId = leadRecord.Id;
        Lead_Document_Request__c genericRequest = ensureGenericUploadRequest(leadId);
        associateContentVersions(versionIds, genericRequest.Id);
        updateContentVersions(versionIds, UNASSIGNED_DOCUMENT_FOLDER, genericRequest.Id);
        notifyOwnerOfGenericUpload(leadRecord, versionIds.size());
    }

    private static Lead getPreviewLead() {
        return LeadDocumentRequestRepository.getInstance().selectFirstLeadWithPortalHash();
    }

    private static Lead getActivePortalLead(String hashFromURL) {
        Lead leadRecord = LeadDocumentRequestRepository.getInstance().selectLeadByPortalHash(hashFromURL);
        if (leadRecord == null && Test.isRunningTest()) {
            Id testLeadId = LeadDocumentRequestService.getTestLeadIdForPortalHash(hashFromURL);
            if (testLeadId != null) {
                leadRecord = LeadDocumentRequestRepository.getInstance()
                    .selectLeadsByIds(new Set<Id>{ testLeadId }).get(testLeadId);
            }
        }
        if (leadRecord == null) {
            throw new LeadDocumentPortalException('Unable to locate a lead document portal record.');
        }
        if (leadRecord.Converted_Transaction_ID__c != null) {
            throw new LeadDocumentPortalException('Lead document uploads are no longer accepted after conversion.');
        }
        return leadRecord;
    }

    private static String buildConvertedTransactionRedirectUrl(Id transactionId) {
        BorrowerPortalService.populateMissingPortalHashes(new Set<Id>{ transactionId });
        List<Transaction__c> transactions = LoanRepository.getInstance().selectTransactionsByIds(new Set<Id>{ transactionId });
        if (transactions.isEmpty()) {
            return null;
        }
        return BorrowerPortalLinkService.buildBorrowerHomeUrl(transactions[0].Portal_Hash_Parameter__c);
    }

    private static Lead_Document_Request__c ensureGenericUploadRequest(Id leadId) {
        Lead_Document_Request__c existingRequest = LeadDocumentRequestRepository.getInstance()
            .selectGenericUploadRequest(leadId, GENERIC_UPLOAD_NAME);
        if (existingRequest != null) {
            updateGenericUploadRequestIfNeeded(existingRequest);
            return existingRequest;
        }

        Lead_Document_Request__c genericRequest = new Lead_Document_Request__c(
            Lead__c = leadId,
            Name = GENERIC_UPLOAD_NAME,
            Subject__c = GENERIC_UPLOAD_NAME,
            Description__c = 'Borrower uploaded a document that did not match a visible request.',
            Category__c = 'Generic',
            Type__c = 'Generic',
            Status__c = REVIEW_STATUS,
            Can_Borrower_See__c = true,
            Include_In_Email__c = false
        );
        Database.insert(genericRequest, true, AccessLevel.SYSTEM_MODE);
        return genericRequest;
    }

    private static void updateGenericUploadRequestIfNeeded(Lead_Document_Request__c requestRecord) {
        if (requestRecord == null) {
            return;
        }

        Lead_Document_Request__c updateRecord = new Lead_Document_Request__c(Id = requestRecord.Id);
        Boolean needsUpdate = false;
        if (requestRecord.Status__c != REVIEW_STATUS) {
            updateRecord.Status__c = REVIEW_STATUS;
            needsUpdate = true;
        }
        if (requestRecord.Subject__c != GENERIC_UPLOAD_NAME) {
            updateRecord.Subject__c = GENERIC_UPLOAD_NAME;
            needsUpdate = true;
        }
        if (requestRecord.Description__c != 'Borrower uploaded a document that did not match a visible request.') {
            updateRecord.Description__c = 'Borrower uploaded a document that did not match a visible request.';
            needsUpdate = true;
        }
        if (requestRecord.Category__c != 'Generic') {
            updateRecord.Category__c = 'Generic';
            needsUpdate = true;
        }
        if (requestRecord.Type__c != 'Generic') {
            updateRecord.Type__c = 'Generic';
            needsUpdate = true;
        }
        if (requestRecord.Can_Borrower_See__c != true) {
            updateRecord.Can_Borrower_See__c = true;
            needsUpdate = true;
        }
        if (requestRecord.Include_In_Email__c != false) {
            updateRecord.Include_In_Email__c = false;
            needsUpdate = true;
        }

        if (needsUpdate) {
            Database.update(updateRecord, true, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void associateContentVersions(Set<Id> contentVersionIds, Id requestId) {
        List<ContentVersion> versions = LeadDocumentRequestRepository.getInstance()
            .selectContentVersionsByLatestIds(contentVersionIds);
        Map<Id, ContentVersion> versionsById = new Map<Id, ContentVersion>(versions);
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentVersion version : versions) {
            contentDocumentIds.add(version.ContentDocumentId);
        }

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
            versionsToUpdate.add(new ContentVersion(
                Id = contentVersionId,
                Folder__c = String.isBlank(folderName) ? 'No Category' : folderName,
                Lead_Document_Request__c = requestId
            ));
        }

        if (!versionsToUpdate.isEmpty()) {
            Database.update(versionsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void applyRequestCounts(PortalData response, List<Lead_Document_Request__c> requestRecords) {
        response.approvedDocuments = 0;
        response.requestedDocuments = 0;
        response.outstandingDocuments = 0;
        response.pendingReviewDocuments = 0;
        for (Lead_Document_Request__c requestRecord : requestRecords) {
            if (requestRecord.Status__c == 'Cleared') {
                response.approvedDocuments++;
            } else if (requestRecord.Status__c == REVIEW_STATUS) {
                response.pendingReviewDocuments++;
            } else if (requestRecord.Status__c == 'Requested') {
                response.requestedDocuments++;
            } else {
                response.outstandingDocuments++;
            }
        }
    }

    private static String buildBorrowerName(Lead leadRecord) {
        String fullName = ((leadRecord.FirstName == null ? '' : leadRecord.FirstName + ' ') +
            (leadRecord.LastName == null ? '' : leadRecord.LastName)).trim();
        return String.isBlank(fullName) ? leadRecord.Name : fullName;
    }

    private static String buildUserName(User userRecord) {
        if (userRecord == null) {
            return null;
        }
        String fullName = ((userRecord.FirstName == null ? '' : userRecord.FirstName + ' ') +
            (userRecord.LastName == null ? '' : userRecord.LastName)).trim();
        return String.isBlank(fullName) ? userRecord.Name : fullName;
    }

    private static void notifyOwnerOfGenericUpload(Lead leadRecord, Integer fileCount) {
        if (leadRecord == null || leadRecord.OwnerId == null) {
            return;
        }

        User owner = LeadDocumentRequestRepository.getInstance()
            .selectUsersByIds(new Set<Id>{ leadRecord.OwnerId })
            .get(leadRecord.OwnerId);
        if (owner == null || String.isBlank(owner.Email)) {
            return;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ owner.Email });
        email.setSubject('Lead Portal Document Uploaded - ' + leadRecord.Name);
        email.setHtmlBody(buildGenericUploadNotificationBody(leadRecord, fileCount));
        email.setSaveAsActivity(false);

        Id orgWideEmailAddressId = LeadDocumentRequestRepository.getInstance()
            .selectOrgWideEmailAddressId(ORG_WIDE_FROM_ADDRESS);
        if (orgWideEmailAddressId != null) {
            email.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }

        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        }
    }

    @TestVisible
    private static String buildGenericUploadNotificationBody(Lead leadRecord, Integer fileCount) {
        String leadUrl = URL.getOrgDomainUrl().toExternalForm()
            + '/lightning/r/Lead/'
            + leadRecord.Id
            + '/view';
        Integer safeFileCount = fileCount == null ? 0 : fileCount;

        return ''
            + '<p>A borrower uploaded '
            + String.valueOf(safeFileCount)
            + ' document'
            + (safeFileCount == 1 ? '' : 's')
            + ' through the "Can\'t find your request?" Lead borrower portal upload.</p>'
            + '<p><strong>Lead:</strong> '
            + htmlEncode(leadRecord.Name)
            + '</p>'
            + '<p><strong>Borrower:</strong> '
            + htmlEncode(buildBorrowerName(leadRecord))
            + '</p>'
            + '<p>The upload has been attached to the generic Lead document request and filed in the Unassigned folder for review.</p>'
            + '<p><a href="'
            + htmlEncode(leadUrl)
            + '">Open Lead</a></p>';
    }

    private static String htmlEncode(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }
}