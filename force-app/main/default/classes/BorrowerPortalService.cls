public with sharing class BorrowerPortalService {
    private static final String APPROVED_STATUS = 'Approved';
    private static final String REVIEW_STATUS = 'Review';
    private static final String GENERIC_UPLOAD_SUBJECT = 'Generic Document Portal Upload';
    private static final String UNASSIGNED_CONDITION_SUBJECT = 'Unassigned';
    private static final String UNASSIGNED_DOCUMENT_FOLDER = 'Unassigned';

    public class BorrowerPortalData {
        @AuraEnabled public List<BorrowerPortalCondition> conditions;
        @AuraEnabled public String recordId;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String processorPhotoUrl;
        @AuraEnabled public String phoneNum;
        @AuraEnabled public String processorNum;
        @AuraEnabled public String mobilePhoneNum;
        @AuraEnabled public String name;
        @AuraEnabled public String processorName;
        @AuraEnabled public String borrowerName;
        @AuraEnabled public String loanOfficerEmail;
        @AuraEnabled public String loanOfficerTitle;
        @AuraEnabled public String loanOfficerNmls;
        @AuraEnabled public String processorEmail;
        @AuraEnabled public String processorTitle;
        @AuraEnabled public String processorNmls;
        @AuraEnabled public Decimal approvedDocuments;
        @AuraEnabled public Decimal requestedDocuments;
        @AuraEnabled public Decimal outstandingDocuments;
        @AuraEnabled public Decimal pendingReviewDocuments;
    }

    public class BorrowerPortalCondition {
        @AuraEnabled public String name;
        @AuraEnabled public String id;
        @AuraEnabled public String parentId;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public String notes;
        @AuraEnabled public Decimal fileCount;
        @AuraEnabled public Integer commentCount;
        @AuraEnabled public Integer activeCommentCount;
        @AuraEnabled public Boolean hasActiveComments;

        public BorrowerPortalCondition(TransactionCondition condition, Decimal fileCount) {
            this(condition, fileCount, null);
        }

        private BorrowerPortalCondition(
            TransactionCondition condition,
            Decimal fileCount,
            PortalCommentIndicator commentIndicator
        ) {
            this.name = condition.data.Name;
            this.id = condition.data.Id;
            this.parentId = condition.data.Transaction__c;
            this.status = condition.data.Status__c;
            this.description = condition.data.Description__c;
            this.notes = condition.data.UW_Notes__c;
            this.fileCount = fileCount == null ? 0 : fileCount;
            this.commentCount = commentIndicator == null ? 0 : commentIndicator.totalPublicComments;
            this.activeCommentCount = commentIndicator == null ? 0 : commentIndicator.activeProcessorComments;
            this.hasActiveComments = this.activeCommentCount > 0;
        }
    }

    public class BorrowerPortalPreApprovalData {
        @AuraEnabled public String loanTerm;
        @AuraEnabled public Decimal monthlyIncome;
        @AuraEnabled public Decimal purchasePrice;
        @AuraEnabled public Decimal downPayment;
        @AuraEnabled public Decimal propertyTaxes;
        @AuraEnabled public Decimal interestRate;
        @AuraEnabled public Decimal insurance;
        @AuraEnabled public String borrowerFirstName;
        @AuraEnabled public String borrowerLastName;
        @AuraEnabled public String coBorrowerFirstName;
        @AuraEnabled public String coBorrowerLastName;
        @AuraEnabled public String propertyStreet;
        @AuraEnabled public String propertyCity;
        @AuraEnabled public String propertyState;
        @AuraEnabled public String propertyZip;
        @AuraEnabled public Decimal loanAmount;
        @AuraEnabled public Decimal loanToValue;
        @AuraEnabled public String loanType;
        @AuraEnabled public String loanOfficerFirstName;
        @AuraEnabled public String loanOfficerLastName;
        @AuraEnabled public String loanOfficerTitle;
        @AuraEnabled public String loanOfficerPhone;
        @AuraEnabled public String loanOfficerMobile;
        @AuraEnabled public String loanOfficerNMLS;
    }

    public class BorrowerPortalContactData {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String title;
        @AuraEnabled public String nmls;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String headShotUrl;
    }

    private class GenericUploadContext {
        Id conditionId;
        Id transactionId;
        String transactionName;
        String borrowerName;
        Id processorId;
        String processorEmail;
    }

    private class PortalCommentIndicator {
        Integer totalPublicComments = 0;
        Integer activeProcessorComments = 0;
    }

    public static BorrowerPortalData initializeData(String hashFromURL, Boolean isInSitePreview) {
        Loan loan = isInSitePreview
            ? LoanRepository.getInstance().getFirstLoanWithPortalHash()
            : LoanRepository.getInstance().getLoanForBorrowerPortalById(decryptTransactionId(hashFromURL));

        if (loan == null) {
            throw new BorrowerPortalServiceException('Unable to locate a borrower portal transaction.');
        }

        List<TransactionCondition> visibleConditions = getVisibleConditions(loan.getId());
        Map<Id, Decimal> fileCountsByConditionId = getFileCountsByConditionId(visibleConditions);
        Map<Id, PortalCommentIndicator> commentIndicatorsByConditionId =
            getPortalCommentIndicatorsByConditionId(visibleConditions);
        BorrowerPortalData response = new BorrowerPortalData();
        response.recordId = loan.getId();
        response.conditions = new List<BorrowerPortalCondition>();

        Map<Id, User> portalUsers = selectPortalUsersByIds(new Set<Id>{
            loan.getData().OwnerId,
            loan.getData().Loan_Officer__c,
            loan.getData().Processor__c
        });
        User loanOfficer = resolveLoanOfficer(loan.getData(), portalUsers);
        User processor = portalUsers.get(loan.getData().Processor__c);

        response.photoUrl = loanOfficer != null ? loanOfficer.Headshot_URL__c : null;
        response.processorPhotoUrl = processor != null ? processor.Headshot_URL__c : null;
        response.phoneNum = loanOfficer != null ? loanOfficer.Phone : null;
        response.mobilePhoneNum = loanOfficer != null ? loanOfficer.MobilePhone : null;
        response.processorNum = processor != null ? processor.Phone : null;
        response.name = buildUserName(loanOfficer);
        response.processorName = buildUserName(processor);
        response.loanOfficerEmail = loanOfficer != null ? loanOfficer.Email : null;
        response.loanOfficerTitle = loanOfficer != null ? loanOfficer.Title : null;
        response.loanOfficerNmls = loanOfficer != null ? loanOfficer.NMLS__c : null;
        response.processorEmail = processor != null ? processor.Email : null;
        response.processorTitle = processor != null ? processor.Title : null;
        response.processorNmls = processor != null ? processor.NMLS__c : null;
        response.borrowerName = buildBorrowerName(loan.getData());

        applyConditionCounts(response, visibleConditions);
        for (TransactionCondition condition : visibleConditions) {
            response.conditions.add(new BorrowerPortalCondition(
                condition,
                fileCountsByConditionId.get(condition.data.Id),
                commentIndicatorsByConditionId.get(condition.data.Id)
            ));
        }

        return response;
    }

    public static Id decryptTransactionId(String hashFromURL) {
        return Id.valueOf(BorrowerPortalEncryptionService.decryptString(hashFromURL));
    }

    public static String encryptTransactionId(Id transactionId) {
        return BorrowerPortalEncryptionService.encryptString(String.valueOf(transactionId));
    }

    public static void populateMissingPortalHashes(Set<Id> transactionIds) {
        if (transactionIds == null || transactionIds.isEmpty()) {
            return;
        }

        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
        for (Transaction__c transactionRecord : LoanRepository.getInstance()
            .selectTransactionsByIds(transactionIds)) {
            if (String.isBlank(transactionRecord.Portal_Hash_Parameter__c)) {
                transactionsToUpdate.add(new Transaction__c(
                    Id = transactionRecord.Id,
                    Portal_Hash_Parameter__c = encryptTransactionId(transactionRecord.Id)
                ));
            }
        }

        if (!transactionsToUpdate.isEmpty()) {
            update transactionsToUpdate;
        }
    }

    public static BorrowerPortalCondition updateConditionOnFileUpload(List<Id> uploadedFileIds, Id conditionId) {
        if (conditionId == null) {
            throw new BorrowerPortalServiceException('A condition is required for borrower document upload.');
        }

        Set<Id> contentDocumentIds = normalizeUploadedFileIds(uploadedFileIds);
        if (contentDocumentIds.isEmpty()) {
            throw new BorrowerPortalServiceException('At least one uploaded document is required.');
        }

        insertConditionLinks(contentDocumentIds, conditionId);
        update new Condition__c(
            Id = conditionId,
            Status__c = REVIEW_STATUS
        );

        TransactionCondition updatedCondition = TransactionConditionRepository.getInstance().getConditionById(conditionId);
        Decimal fileCount = selectLinkedDocumentCountsByEntityIds(new Set<Id>{ conditionId })
            .get(conditionId);
        return new BorrowerPortalCondition(updatedCondition, fileCount);
    }

    public static void markProcessorCommentsViewedByBorrower(Id conditionId) {
        if (conditionId == null) {
            return;
        }

        new BorrowerCommentReadWriter().markProcessorCommentsViewedByBorrower(conditionId);
    }

    public static void markProcessorCommentUnreadForBorrower(Id commentId) {
        if (commentId == null) {
            return;
        }

        new BorrowerCommentReadWriter().markProcessorCommentUnreadForBorrower(commentId);
    }

    private without sharing class BorrowerCommentReadWriter {
        void markProcessorCommentsViewedByBorrower(Id conditionId) {
            List<Condition_Comment__c> commentsToUpdate = new List<Condition_Comment__c>();
            for (Condition_Comment__c commentRecord : [
                SELECT Id
                FROM Condition_Comment__c
                WHERE Condition__c = :conditionId
                AND Portal_Comment__c = FALSE
                AND Public__c = TRUE
                AND Read__c = FALSE
            ]) {
                commentsToUpdate.add(new Condition_Comment__c(
                    Id = commentRecord.Id,
                    Read__c = true
                ));
            }

            if (!commentsToUpdate.isEmpty()) {
                update commentsToUpdate;
            }
        }

        void markProcessorCommentUnreadForBorrower(Id commentId) {
            List<Condition_Comment__c> commentsToUpdate = new List<Condition_Comment__c>();
            for (Condition_Comment__c commentRecord : [
                SELECT Id
                FROM Condition_Comment__c
                WHERE Id = :commentId
                AND Portal_Comment__c = FALSE
                AND Public__c = TRUE
                AND Read__c = TRUE
                LIMIT 1
            ]) {
                commentsToUpdate.add(new Condition_Comment__c(
                    Id = commentRecord.Id,
                    Read__c = false
                ));
            }

            if (!commentsToUpdate.isEmpty()) {
                update commentsToUpdate;
            }
        }
    }

    public static void handleGenericUpload(List<Id> uploadedFileIds, Id transactionId) {
        if (transactionId == null) {
            throw new BorrowerPortalServiceException('A transaction is required for generic borrower uploads.');
        }

        Set<Id> contentDocumentIds = normalizeUploadedFileIds(uploadedFileIds);
        if (contentDocumentIds.isEmpty()) {
            throw new BorrowerPortalServiceException('At least one uploaded document is required.');
        }

        GenericUploadContext context = ensureGenericUploadCondition(transactionId);
        insertConditionLinks(contentDocumentIds, context.conditionId);
        FileUploadHandler.updateContentVersions(
            new List<Id>(contentDocumentIds),
            UNASSIGNED_DOCUMENT_FOLDER,
            context.conditionId
        );
        notifyProcessorOfGenericUpload(context, contentDocumentIds.size());
    }

    public static BorrowerPortalPreApprovalData getPreApprovalData(String hashId) {
        Loan loan = getLoanByHash(hashId);
        Transaction__c transactionRecord = loan.getData();
        Map<Id, User> portalUsers = selectPortalUsersByIds(new Set<Id>{
            transactionRecord.OwnerId,
            transactionRecord.Loan_Officer__c
        });
        User loanOfficer = resolveLoanOfficer(transactionRecord, portalUsers);

        BorrowerPortalPreApprovalData data = new BorrowerPortalPreApprovalData();
        Decimal borrowerIncome = transactionRecord.Borrower_Income__c == null ? 0 : transactionRecord.Borrower_Income__c;
        Decimal coBorrowerIncome = transactionRecord.CoBorrower_Income__c == null ? 0 : transactionRecord.CoBorrower_Income__c;

        data.monthlyIncome = borrowerIncome + coBorrowerIncome;
        data.purchasePrice = transactionRecord.Purchase_Price__c;
        data.downPayment = transactionRecord.Down_Payment__c;
        data.interestRate = transactionRecord.Interest_Rate__c;
        data.borrowerFirstName = transactionRecord.Borrower_First_Name__c;
        data.borrowerLastName = transactionRecord.Borrower_Last_Name__c;
        data.propertyStreet = transactionRecord.Property_Address__c;
        data.propertyCity = transactionRecord.Property_City__c;
        data.propertyState = transactionRecord.Property_State__c;
        data.propertyZip = transactionRecord.Property_Postal_Code__c;
        data.loanAmount = transactionRecord.Loan_Amount__c;
        data.loanToValue = transactionRecord.LTV__c;
        data.loanType = transactionRecord.Loan_Type_1st_TD__c;
        data.loanOfficerFirstName = loanOfficer != null ? loanOfficer.FirstName : null;
        data.loanOfficerLastName = loanOfficer != null ? loanOfficer.LastName : null;
        data.loanOfficerTitle = loanOfficer != null ? loanOfficer.Title : null;
        data.loanOfficerPhone = loanOfficer != null ? loanOfficer.Phone : null;
        data.loanOfficerMobile = loanOfficer != null ? loanOfficer.MobilePhone : null;
        data.loanOfficerNMLS = loanOfficer != null ? loanOfficer.NMLS__c : null;
        return data;
    }

    public static BorrowerPortalContactData getContactData(String apiName, String hashUrl) {
        Loan loan = getLoanByHash(hashUrl);
        Map<Id, User> portalUsers = selectPortalUsersByIds(new Set<Id>{
            loan.getData().OwnerId,
            loan.getData().Loan_Officer__c,
            loan.getData().Processor__c
        });
        User relatedUser = resolvePortalContactUser(loan.getData(), apiName, portalUsers);

        if (relatedUser == null) {
            throw new BorrowerPortalServiceException('Unable to locate borrower portal contact.');
        }

        BorrowerPortalContactData data = new BorrowerPortalContactData();
        data.firstName = relatedUser.FirstName;
        data.lastName = relatedUser.LastName;
        data.title = relatedUser.Title;
        data.nmls = relatedUser.NMLS__c;
        data.phone = String.isNotBlank(relatedUser.MobilePhone) ? relatedUser.MobilePhone : relatedUser.Phone;
        data.email = relatedUser.Email;
        data.headShotUrl = relatedUser.Headshot_URL__c;
        return data;
    }

    private static List<TransactionCondition> getVisibleConditions(Id transactionId) {
        List<TransactionCondition> visibleConditions = new List<TransactionCondition>();
        for (TransactionCondition condition : TransactionConditionRepository.getInstance().getConditionsRelatedToLoan(transactionId)) {
            if (condition.data.Can_Borrower_See__c && condition.data.Status__c != APPROVED_STATUS) {
                visibleConditions.add(condition);
            }
        }
        return visibleConditions;
    }

    private static void applyConditionCounts(BorrowerPortalData response, List<TransactionCondition> conditions) {
        Decimal approvedDocs = 0;
        Decimal requestedDocs = 0;
        Decimal outstandingDocs = 0;
        Decimal pendingReviewDocs = 0;

        for (TransactionCondition condition : conditions) {
            if (condition.data.Status__c == 'Approved' || condition.data.Status__c == 'Cleared') {
                approvedDocs += 1;
            } else if (condition.data.Status__c == 'New') {
                outstandingDocs += 1;
            } else if (condition.data.Status__c == 'Requested') {
                requestedDocs += 1;
            } else if (condition.data.Status__c == 'Review') {
                pendingReviewDocs += 1;
            }
        }

        response.requestedDocuments = requestedDocs;
        response.approvedDocuments = approvedDocs;
        response.outstandingDocuments = outstandingDocs;
        response.pendingReviewDocuments = pendingReviewDocs;
    }

    private static Map<Id, Decimal> getFileCountsByConditionId(List<TransactionCondition> conditions) {
        Set<Id> conditionIds = new Set<Id>();
        for (TransactionCondition condition : conditions) {
            if (condition != null && condition.data != null && condition.data.Id != null) {
                conditionIds.add(condition.data.Id);
            }
        }
        return selectLinkedDocumentCountsByEntityIds(conditionIds);
    }

    private static Map<Id, PortalCommentIndicator> getPortalCommentIndicatorsByConditionId(
        List<TransactionCondition> conditions
    ) {
        Map<Id, PortalCommentIndicator> indicatorsByConditionId = new Map<Id, PortalCommentIndicator>();
        Set<Id> conditionIds = new Set<Id>();
        for (TransactionCondition condition : conditions) {
            if (condition != null && condition.data != null && condition.data.Id != null) {
                conditionIds.add(condition.data.Id);
            }
        }
        if (conditionIds.isEmpty()) {
            return indicatorsByConditionId;
        }

        for (Condition_Comment__c commentRecord : [
            SELECT Condition__c, Portal_Comment__c, Read__c
            FROM Condition_Comment__c
            WHERE Condition__c IN :conditionIds
            AND Public__c = TRUE
        ]) {
            PortalCommentIndicator indicator = indicatorsByConditionId.get(commentRecord.Condition__c);
            if (indicator == null) {
                indicator = new PortalCommentIndicator();
                indicatorsByConditionId.put(commentRecord.Condition__c, indicator);
            }

            indicator.totalPublicComments++;
            if (!commentRecord.Portal_Comment__c && !commentRecord.Read__c) {
                indicator.activeProcessorComments++;
            }
        }

        return indicatorsByConditionId;
    }

    private static User resolveLoanOfficer(Transaction__c transactionRecord, Map<Id, User> portalUsers) {
        if (transactionRecord == null) {
            return null;
        }

        if (transactionRecord.Loan_Officer__c != null && portalUsers.containsKey(transactionRecord.Loan_Officer__c)) {
            return portalUsers.get(transactionRecord.Loan_Officer__c);
        }
        return portalUsers.get(transactionRecord.OwnerId);
    }

    private static Loan getLoanByHash(String hashId) {
        Loan loan = LoanRepository.getInstance().getLoanForBorrowerPortalById(
            decryptTransactionId(hashId)
        );
        if (loan == null) {
            throw new BorrowerPortalServiceException('Unable to locate a borrower portal transaction.');
        }
        return loan;
    }

    private static String buildBorrowerName(Transaction__c transactionRecord) {
        List<String> nameParts = new List<String>();
        if (String.isNotBlank(transactionRecord.Borrower_First_Name__c)) {
            nameParts.add(transactionRecord.Borrower_First_Name__c);
        }
        if (String.isNotBlank(transactionRecord.Borrower_Last_Name__c)) {
            nameParts.add(transactionRecord.Borrower_Last_Name__c);
        }
        return String.join(nameParts, ' ');
    }

    private static String buildUserName(User relatedUser) {
        if (relatedUser == null) {
            return null;
        }

        List<String> nameParts = new List<String>();
        if (String.isNotBlank(relatedUser.FirstName)) {
            nameParts.add(relatedUser.FirstName);
        }
        if (String.isNotBlank(relatedUser.LastName)) {
            nameParts.add(relatedUser.LastName);
        }
        return String.join(nameParts, ' ');
    }

    private static User resolvePortalContactUser(
        Transaction__c transactionRecord,
        String apiName,
        Map<Id, User> portalUsers
    ) {
        if (apiName == 'Owner') {
            return portalUsers.get(transactionRecord.OwnerId);
        }
        if (apiName == 'Loan_Officer__r') {
            return portalUsers.get(transactionRecord.Loan_Officer__c);
        }
        if (apiName == 'Processor__r') {
            return portalUsers.get(transactionRecord.Processor__c);
        }
        throw new BorrowerPortalServiceException('Unsupported borrower portal contact relationship.');
    }

    private static Map<Id, User> selectPortalUsersByIds(Set<Id> userIds) {
        Set<Id> filteredUserIds = new Set<Id>();
        if (userIds != null) {
            filteredUserIds.addAll(userIds);
            filteredUserIds.remove(null);
        }

        if (filteredUserIds.isEmpty()) {
            return new Map<Id, User>();
        }

        return new Map<Id, User>([
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Headshot_URL__c, Title, NMLS__c
            FROM User
            WHERE Id IN :filteredUserIds
        ]);
    }

    private static Set<Id> normalizeUploadedFileIds(List<Id> uploadedFileIds) {
        return resolveContentDocumentIds(
            uploadedFileIds == null ? new Set<Id>() : new Set<Id>(uploadedFileIds)
        );
    }

    private static Set<Id> resolveContentDocumentIds(Set<Id> uploadedFileIds) {
        Set<Id> contentDocumentIds = new Set<Id>();
        Set<Id> contentVersionIds = new Set<Id>();

        for (Id uploadedFileId : uploadedFileIds) {
            if (uploadedFileId == null) {
                continue;
            }

            Schema.SObjectType fileType = uploadedFileId.getSObjectType();
            if (fileType == ContentDocument.SObjectType) {
                contentDocumentIds.add(uploadedFileId);
            } else if (fileType == ContentVersion.SObjectType) {
                contentVersionIds.add(uploadedFileId);
            }
        }

        if (!contentVersionIds.isEmpty()) {
            for (ContentVersion versionRecord : [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :contentVersionIds
            ]) {
                contentDocumentIds.add(versionRecord.ContentDocumentId);
            }
        }

        return contentDocumentIds;
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

    private static void insertConditionLinks(Set<Id> contentDocumentIds, Id conditionId) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty() || conditionId == null) {
            return;
        }
        Set<Id> alreadyLinkedDocumentIds = new Set<Id>();
        for (ContentDocumentLink existingLink : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionId
            AND ContentDocumentId IN :contentDocumentIds
        ]) {
            alreadyLinkedDocumentIds.add(existingLink.ContentDocumentId);
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (Id contentDocumentId : contentDocumentIds) {
            if (alreadyLinkedDocumentIds.contains(contentDocumentId)) {
                continue;
            }
            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = conditionId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        if (!linksToInsert.isEmpty()) {
            Database.insert(linksToInsert, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static GenericUploadContext ensureGenericUploadCondition(Id transactionId) {
        Transaction__c transactionRecord = selectGenericUploadTransaction(transactionId);
        GenericUploadContext context = buildGenericUploadContext(transactionRecord);

        Condition__c existingGenericCondition = selectGenericUploadCondition(transactionId);
        if (existingGenericCondition != null) {
            context.conditionId = existingGenericCondition.Id;
            updateGenericUploadConditionIfNeeded(existingGenericCondition, context.processorId);
            return context;
        }

        Condition__c genericCondition = new Condition__c(
            Transaction__c = transactionId,
            Subject__c = UNASSIGNED_CONDITION_SUBJECT,
            Type__c = GENERIC_UPLOAD_SUBJECT,
            Description__c = UNASSIGNED_CONDITION_SUBJECT,
            Status__c = REVIEW_STATUS,
            Can_Borrower_See__c = true,
            Assigned_To__c = context.processorId
        );
        Database.insert(genericCondition, true, AccessLevel.SYSTEM_MODE);
        context.conditionId = genericCondition.Id;
        return context;
    }

    private static Transaction__c selectGenericUploadTransaction(Id transactionId) {
        return [
            SELECT
                Id,
                Name,
                Borrower_First_Name__c,
                Borrower_Last_Name__c,
                Processor__c,
                Processor__r.Email,
                OwnerId,
                Owner.Email
            FROM Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];
    }

    private static GenericUploadContext buildGenericUploadContext(Transaction__c transactionRecord) {
        GenericUploadContext context = new GenericUploadContext();
        context.transactionId = transactionRecord.Id;
        context.transactionName = transactionRecord.Name;
        context.borrowerName = buildBorrowerName(transactionRecord);
        context.processorId = transactionRecord.Processor__c != null
            ? transactionRecord.Processor__c
            : transactionRecord.OwnerId;
        context.processorEmail = transactionRecord.Processor__c != null
            ? transactionRecord.Processor__r.Email
            : transactionRecord.Owner.Email;
        return context;
    }

    private static Condition__c selectGenericUploadCondition(Id transactionId) {
        List<Condition__c> conditions = [
            SELECT Id, Assigned_To__c, Status__c, Subject__c, Type__c, Description__c, Can_Borrower_See__c
            FROM Condition__c
            WHERE Transaction__c = :transactionId
            AND (
                Subject__c = :UNASSIGNED_CONDITION_SUBJECT
                OR Subject__c = :GENERIC_UPLOAD_SUBJECT
                OR Type__c = :GENERIC_UPLOAD_SUBJECT
            )
            AND Status__c NOT IN ('Approved', 'Cleared')
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return conditions.isEmpty() ? null : conditions[0];
    }

    private static void updateGenericUploadConditionIfNeeded(Condition__c conditionRecord, Id processorId) {
        if (conditionRecord == null) {
            return;
        }

        Condition__c updateRecord = new Condition__c(Id = conditionRecord.Id);
        Boolean needsUpdate = false;
        if (processorId != null && conditionRecord.Assigned_To__c != processorId) {
            updateRecord.Assigned_To__c = processorId;
            needsUpdate = true;
        }
        if (conditionRecord.Status__c != REVIEW_STATUS) {
            updateRecord.Status__c = REVIEW_STATUS;
            needsUpdate = true;
        }
        if (conditionRecord.Subject__c != UNASSIGNED_CONDITION_SUBJECT) {
            updateRecord.Subject__c = UNASSIGNED_CONDITION_SUBJECT;
            needsUpdate = true;
        }
        if (conditionRecord.Description__c != UNASSIGNED_CONDITION_SUBJECT) {
            updateRecord.Description__c = UNASSIGNED_CONDITION_SUBJECT;
            needsUpdate = true;
        }
        if (conditionRecord.Can_Borrower_See__c != true) {
            updateRecord.Can_Borrower_See__c = true;
            needsUpdate = true;
        }

        if (needsUpdate) {
            Database.update(updateRecord, true, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void notifyProcessorOfGenericUpload(GenericUploadContext context, Integer fileCount) {
        if (context == null || String.isBlank(context.processorEmail)) {
            return;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ context.processorEmail });
        email.setSubject('Borrower Portal Document Uploaded - ' + context.transactionName);
        email.setHtmlBody(buildGenericUploadNotificationBody(context, fileCount));
        email.setSaveAsActivity(false);

        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        }
    }

    @TestVisible
    private static String buildGenericUploadNotificationBody(GenericUploadContext context, Integer fileCount) {
        String safeTransactionName = htmlEncode(context.transactionName);
        String safeBorrowerName = htmlEncode(context.borrowerName);
        String transactionUrl = URL.getOrgDomainUrl().toExternalForm()
            + '/lightning/r/Transaction__c/'
            + context.transactionId
            + '/view';
        String safeTransactionUrl = htmlEncode(transactionUrl);
        Integer safeFileCount = fileCount == null ? 0 : fileCount;

        return ''
            + '<p>A borrower uploaded '
            + String.valueOf(safeFileCount)
            + ' document'
            + (safeFileCount == 1 ? '' : 's')
            + ' through the "Can\'t Find Your Condition?" borrower portal upload.</p>'
            + '<p><strong>Transaction:</strong> '
            + safeTransactionName
            + '</p>'
            + '<p><strong>Borrower:</strong> '
            + safeBorrowerName
            + '</p>'
            + '<p>The upload has been attached to the Unassigned condition and filed in the Unassigned folder for review.</p>'
            + '<p><a href="'
            + safeTransactionUrl
            + '">Open Transaction</a></p>';
    }

    private static String htmlEncode(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }

    public class BorrowerPortalServiceException extends Exception {}
}
