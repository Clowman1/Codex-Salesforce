/**
 * @author Illia Ostrovskyi
 * @since 22.08.2023
 */
public with sharing class BorrowerDocumentPortalController  {
    private static final String UNASSIGNED_DOCUMENT_FOLDER = 'Unassigned';
    private static final String PLACEHOLDER_CONDITION_NAME = 'No Description Available - Please Update Manually';

    public with sharing class DataWrapper{
        @AuraEnabled
        public List<LoanCondition> conditions;
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public String photoUrl;
        @AuraEnabled
        public String processorPhotoUrl;
        @AuraEnabled
        public String phoneNum;
        @AuraEnabled
        public String processorNum;
        @AuraEnabled
        public String mobilePhoneNum;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String processorName;
        @AuraEnabled
        public String borrowerName;
        @AuraEnabled
        public String loanOfficerEmail;
        @AuraEnabled
        public String processorEmail;
        @AuraEnabled
        public Decimal approvedDocuments;
        @AuraEnabled
        public Decimal requestedDocuments;
        @AuraEnabled
        public Decimal outstandingDocuments;
        @AuraEnabled
        public Decimal pendingReviewDocuments;

        public DataWrapper() {
            this.conditions = new List<LoanCondition>();
        }

        public DataWrapper(BorrowerPortalService.BorrowerPortalData data) {
            this();
            if (data == null) {
                return;
            }

            this.recordId = data.recordId;
            this.photoUrl = data.photoUrl;
            this.processorPhotoUrl = data.processorPhotoUrl;
            this.phoneNum = data.phoneNum;
            this.processorNum = data.processorNum;
            this.mobilePhoneNum = data.mobilePhoneNum;
            this.name = data.name;
            this.processorName = data.processorName;
            this.borrowerName = data.borrowerName;
            this.loanOfficerEmail = data.loanOfficerEmail;
            this.processorEmail = data.processorEmail;
            this.approvedDocuments = data.approvedDocuments;
            this.requestedDocuments = data.requestedDocuments;
            this.outstandingDocuments = data.outstandingDocuments;
            this.pendingReviewDocuments = data.pendingReviewDocuments;

            if (data.conditions == null) {
                return;
            }

            for (BorrowerPortalService.BorrowerPortalCondition condition : data.conditions) {
                this.conditions.add(new LoanCondition(condition));
            }
        }
    }

    public class LoanCondition{
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String parentId;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public List<ContentDocument> files;
        @AuraEnabled
        public String notes;
        @AuraEnabled
        public Decimal fileCount;
        @AuraEnabled
        public Integer commentCount;
        @AuraEnabled
        public Integer activeCommentCount;
        @AuraEnabled
        public Boolean hasActiveComments;

        public LoanCondition() {
            this.files = new List<ContentDocument>();
        }

        public LoanCondition(BorrowerPortalService.BorrowerPortalCondition condition){
            this();
            if (condition == null) {
                return;
            }

            this.name = condition.name;
            this.id = condition.id;
            this.parentId = condition.parentId;
            this.status = condition.status;
            this.description = condition.description;
            this.notes = condition.notes;
            this.fileCount = condition.fileCount;
            this.commentCount = condition.commentCount;
            this.activeCommentCount = condition.activeCommentCount;
            this.hasActiveComments = condition.hasActiveComments;
        }
    }

    @AuraEnabled(cacheable=true)
    public static DataWrapper initializeData(String hashFromURL, Boolean isInSitePreview){
        try {
            return new DataWrapper(BorrowerPortalService.initializeData(hashFromURL, isInSitePreview));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id decryptRecordId(String hashFromURL){
        return BorrowerPortalService.decryptTransactionId(hashFromURL);
    }

    @AuraEnabled
    public static void sendGenericDocumentPlatformEvents(List<String> contentDocumentIds, String recordId){
        try {
            BorrowerPortalService.handleGenericUpload(parseIdValues(contentDocumentIds), Id.valueOf(recordId));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static LoanCondition updateLoanConditionOnFileUpload(List<Id> contentVersionIds, Id conditionId) {
        Set<Id> versionsIds = new Set<Id>(contentVersionIds);
        try {
            return new PortalUploadWriter().applyConditionUpload(versionsIds, conditionId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'BorrowerDocumentPortalController.updateLoanConditionOnFileUpload failed for conditionId=' +
                conditionId + ' versions=' + versionsIds + ' :: ' + e.getTypeName() + ': ' + e.getMessage() +
                '\n' + e.getStackTraceString()
            );
            throw new AuraHandledException(e.getTypeName() + ': ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void markProcessorCommentsViewedByBorrower(Id conditionId) {
        try {
            BorrowerPortalService.markProcessorCommentsViewedByBorrower(conditionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void markProcessorCommentUnreadForBorrower(Id commentId) {
        try {
            BorrowerPortalService.markProcessorCommentUnreadForBorrower(commentId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Performs the post-upload writes (CDL → Condition, ContentVersion stamp, Status→Review) in an
     * elevated `without sharing` context so the borrower portal's guest user can complete the
     * upload chain, AND builds the refreshed LoanCondition response via a SYSTEM_MODE read so
     * FLS restrictions on the guest profile (e.g. no read access on Condition__c.Status__c) do
     * not cause `Security.stripInaccessible` downstream to strip fields we need.
     *
     * The portal hash on the parent Transaction is the security boundary here: this method is
     * only reachable via the @AuraEnabled entry point called from the hash-authenticated
     * borrower portal LWC.
     */
    private without sharing class PortalUploadWriter {
        public LoanCondition applyConditionUpload(Set<Id> contentVersionIds, Id conditionId) {
            Condition__c conditionForFolder = selectConditionForFolder(conditionId);
            String folderName = resolveConditionDocumentFolder(conditionForFolder);

            FileUploadHandler.associateContentVersions(contentVersionIds, conditionId);
            FileUploadHandler.updateContentVersions(contentVersionIds, folderName, conditionId);
            FileUploadHandler.setLoanConditionToReview(conditionId);

            List<Condition__c> refreshed = [
                SELECT Id, Name, Transaction__c, Status__c, Description__c, UW_Notes__c
                FROM Condition__c
                WHERE Id = :conditionId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            Decimal fileCount = selectLinkedDocumentCountsByEntityIds(new Set<Id>{ conditionId }).get(conditionId);

            LoanCondition response = new LoanCondition();
            if (!refreshed.isEmpty()) {
                Condition__c condition = refreshed[0];
                response.id = condition.Id;
                response.name = condition.Name;
                response.parentId = condition.Transaction__c;
                response.status = condition.Status__c;
                response.description = condition.Description__c;
                response.notes = condition.UW_Notes__c;
            } else {
                response.id = conditionId;
            }
            response.fileCount = fileCount == null ? 0 : fileCount;
            return response;
        }

        private Condition__c selectConditionForFolder(Id conditionId) {
            List<Condition__c> conditions = [
                SELECT Id, Name, Subject__c, Description__c, Category__c
                FROM Condition__c
                WHERE Id = :conditionId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return conditions.isEmpty() ? null : conditions[0];
        }

        private String resolveConditionDocumentFolder(Condition__c conditionRecord) {
            if (conditionRecord == null) {
                return UNASSIGNED_DOCUMENT_FOLDER;
            }

            List<String> candidates = new List<String>{
                conditionRecord.Category__c,
                conditionRecord.Name,
                conditionRecord.Subject__c
            };
            for (String candidate : candidates) {
                String normalized = normalizeFolderName(candidate);
                if (String.isNotBlank(normalized)) {
                    return normalized;
                }
            }

            return UNASSIGNED_DOCUMENT_FOLDER;
        }

        private String normalizeFolderName(String value) {
            if (String.isBlank(value)) {
                return null;
            }

            String folderName = value.trim();
            if (folderName == PLACEHOLDER_CONDITION_NAME || folderName.startsWith('a02')) {
                return null;
            }

            return folderName.length() > 80 ? folderName.substring(0, 80) : folderName;
        }
    }

    public class BorrowerPortalPreApprovalData {
        @AuraEnabled
        public String loanTerm;
        @AuraEnabled
        public Decimal monthlyIncome;
        @AuraEnabled
        public Decimal purchasePrice;
        @AuraEnabled
        public Decimal downPayment;
        @AuraEnabled
        public Decimal propertyTaxes;
        @AuraEnabled
        public Decimal interestRate;
        @AuraEnabled
        public Decimal insurance;
        @AuraEnabled
        public String borrowerFirstName;
        @AuraEnabled
        public String borrowerLastName;
        @AuraEnabled
        public String coBorrowerFirstName;
        @AuraEnabled
        public String coBorrowerLastName;
        @AuraEnabled
        public String propertyStreet;
        @AuraEnabled
        public String propertyCity;
        @AuraEnabled
        public String propertyState;
        @AuraEnabled
        public String propertyZip;
        @AuraEnabled
        public Decimal loanAmount;
        @AuraEnabled
        public Decimal loanToValue;
        @AuraEnabled
        public String loanType;
        @AuraEnabled
        public String loanOfficerFirstName;
        @AuraEnabled
        public String loanOfficerLastName;
        @AuraEnabled
        public String loanOfficerTitle;
        @AuraEnabled
        public String loanOfficerPhone;
        @AuraEnabled
        public String loanOfficerMobile;
        @AuraEnabled
        public String loanOfficerNMLS;

        public BorrowerPortalPreApprovalData() {
        }

        public BorrowerPortalPreApprovalData(BorrowerPortalService.BorrowerPortalPreApprovalData data) {
            if (data == null) {
                return;
            }

            this.loanTerm = data.loanTerm;
            this.monthlyIncome = data.monthlyIncome;
            this.purchasePrice = data.purchasePrice;
            this.downPayment = data.downPayment;
            this.propertyTaxes = data.propertyTaxes;
            this.interestRate = data.interestRate;
            this.insurance = data.insurance;
            this.borrowerFirstName = data.borrowerFirstName;
            this.borrowerLastName = data.borrowerLastName;
            this.coBorrowerFirstName = data.coBorrowerFirstName;
            this.coBorrowerLastName = data.coBorrowerLastName;
            this.propertyStreet = data.propertyStreet;
            this.propertyCity = data.propertyCity;
            this.propertyState = data.propertyState;
            this.propertyZip = data.propertyZip;
            this.loanAmount = data.loanAmount;
            this.loanToValue = data.loanToValue;
            this.loanType = data.loanType;
            this.loanOfficerFirstName = data.loanOfficerFirstName;
            this.loanOfficerLastName = data.loanOfficerLastName;
            this.loanOfficerTitle = data.loanOfficerTitle;
            this.loanOfficerPhone = data.loanOfficerPhone;
            this.loanOfficerMobile = data.loanOfficerMobile;
            this.loanOfficerNMLS = data.loanOfficerNMLS;
        }
    }

    @AuraEnabled
    public static BorrowerPortalPreApprovalData getFieldsForBorrowerPortalPreapproval(String hashId) {
        try {
            return new BorrowerPortalPreApprovalData(BorrowerPortalService.getPreApprovalData(hashId));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> getDataFromFieldName(String apiName, String hashUrl) {
        try {
            return mapRelatedRecordData(BorrowerPortalService.getContactData(apiName, hashUrl));
        } catch (Exception e) {
            throw new AuraHandledException('Error in fetching data: ' + e.getMessage());
        }
    }

    private static Map<String, String> mapRelatedRecordData(
        BorrowerPortalService.BorrowerPortalContactData relatedRecord
    ) {
        Map<String, String> result = new Map<String, String>();
        result.put('FirstName', relatedRecord.firstName);
        result.put('LastName', relatedRecord.lastName);
        result.put('Title', relatedRecord.title);
        result.put('NMLS', relatedRecord.nmls);
        result.put('Phone', relatedRecord.phone);
        result.put('Email', relatedRecord.email);
        result.put('HeadShotUrl', relatedRecord.headShotUrl);

        return result;
    }

    private static LoanCondition refreshLoanCondition(Id conditionId) {
        TransactionCondition refreshedCondition = TransactionConditionRepository.getInstance().getConditionById(
            conditionId
        );
        Decimal fileCount = selectLinkedDocumentCountsByEntityIds(new Set<Id>{ conditionId }).get(conditionId);
        return new LoanCondition(
            new BorrowerPortalService.BorrowerPortalCondition(refreshedCondition, fileCount)
        );
    }

    private static Map<Id, Decimal> selectLinkedDocumentCountsByEntityIds(Set<Id> entityIds) {
        Map<Id, Decimal> documentCountsByEntityId = new Map<Id, Decimal>();
        if (entityIds == null || entityIds.isEmpty()) {
            return documentCountsByEntityId;
        }

        for (AggregateResult result : [
            SELECT LinkedEntityId linkedEntityId, COUNT(Id) documentCount
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
            GROUP BY LinkedEntityId
        ]) {
            documentCountsByEntityId.put(
                (Id)result.get('linkedEntityId'),
                (Decimal)result.get('documentCount')
            );
        }

        return documentCountsByEntityId;
    }

    private static List<Id> parseIdValues(List<String> idValues) {
        List<Id> parsedIds = new List<Id>();
        if (idValues == null) {
            return parsedIds;
        }

        for (String idValue : idValues) {
            if (String.isBlank(idValue)) {
                continue;
            }
            parsedIds.add(Id.valueOf(idValue));
        }
        return parsedIds;
    }

    @InvocableMethod(Label='Encrypt Opportunity Id')
    public static List<String> encryptOpportunityId(List<Request> requests){
        List<String> listOfHashStrings = new List<String>();
        if (requests == null) {
            return listOfHashStrings;
        }

        for(Request req: requests){
            listOfHashStrings.add(
                req != null && req.recordId != null
                    ? BorrowerPortalService.encryptTransactionId(req.recordId)
                    : null
            );
        }

        return listOfHashStrings;
    }

    public class Request{
        @InvocableVariable
        public Id recordId;
    }

    public class BorrowerDocumentPortalControllerException extends Exception {}
}