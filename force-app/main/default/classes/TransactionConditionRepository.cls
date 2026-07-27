@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class TransactionConditionRepository {
    private static TransactionConditionRepository self;
    private static List<String> conditionFields;
    private static final String GENERIC_UPLOAD_SUBJECT = 'Generic Document Portal Upload';

    private static final Set<String> FIELDS_FOR_VIEWER_FUNCTIONALITY = new Set<String>{
        'Id',
        'Name',
        'Status__c',
        'Assigned_To__c',
        'Include_In_Email__c',
        'Can_Borrower_See__c',
        'UWM_Condition_Id__c',
        'Description__c',
        'UWM_Description__c',
        'UW_Notes__c',
        'Type__c'
    };

    private static final Set<String> USER_RELATIONSHIP_FIELDS = new Set<String>{ 'Name', 'Id', 'MediumPhotoUrl' };
    private static final Set<String> DEFAULT_RELATIONSHIP_FIELDS = new Set<String>{ 'Name', 'Id' };
    private static final Set<String> TRANSACTION_RELATIONSHIP_FIELDS = new Set<String>{
        'Id',
        'Borrower_Email__c',
        'Email_Co_Borrower__c',
        'Loan_Number__c',
        'Borrower_First_Name__c',
        'Borrower_Last_Name__c',
        'Property_Address__c',
        'Owner.Email'
    };

    public static TransactionConditionRepository getInstance() {
        if (self == null) {
            self = new TransactionConditionRepository();
        }
        return self;
    }

    private TransactionConditionRepository() {
        initializeConditionFields();
    }

    private static void initializeConditionFields() {
        conditionFields = new List<String>();
        Map<String, SObjectField> conditionFieldMap = Condition__c.SObjectType.getDescribe().fields.getMap();
        conditionFields.addAll(conditionFieldMap.keySet());

        for (String field : TRANSACTION_RELATIONSHIP_FIELDS) {
            conditionFields.add('Transaction__r.' + field);
        }
        for (String field : USER_RELATIONSHIP_FIELDS) {
            conditionFields.add('Assigned_To__r.' + field);
        }
        conditionFields.add(getUnreadConditionCommentsSubquery());
    }

    public List<TransactionCondition> getConditionsRelatedToLoan(Id loanId) {
        String query = 'SELECT ' + String.join(conditionFields, ',') + ' FROM Condition__c WHERE Transaction__c = :loanId';
        List<Condition__c> conditions = (List<Condition__c>) Database.query(query);
        return getContentVersionsByConditionList(wrapConditions(conditions));
    }

    public static List<TransactionCondition> getConditionsByType(Id loanId, String type, List<String> columnFields) {
        Set<String> types = new Set<String>();
        if (String.isBlank(type)) {
            return new List<TransactionCondition>();
        }

        for (String typeName : type.split('[,;]')) {
            String trimmedType = typeName.trim();
            if (String.isNotBlank(trimmedType)) {
                types.add(trimmedType);
            }
        }

        String fieldList = mergeColumnAndFunctionalFields(columnFields);
        String query =
            'SELECT ' +
            fieldList +
            ',' +
            getUnreadConditionCommentsSubquery() +
            ' FROM Condition__c' +
            ' WHERE Transaction__c = :loanId AND Type__c IN :types';

        SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.READABLE, Database.query(query));
        List<Condition__c> conditions = (List<Condition__c>) securityDecision.getRecords();
        return getContentVersionsByConditionList(wrapConditions(conditions));
    }

    public List<TransactionCondition> getConditionsWithResponsibleParty(Id loanId, String responsibleParty) {
        String query =
            'SELECT ' +
            String.join(conditionFields, ',') +
            ' FROM Condition__c WHERE Transaction__c = :loanId' +
            ' AND (Status__c = \'New\' OR Status__c = \'Requested\')';
        if (hasConditionField('Type__c')) {
            query += ' AND Type__c = \'Loan Officer\'';
        }
        if (hasConditionField('Income_Conditions_For__c')) {
            query += ' AND Income_Conditions_For__c = :responsibleParty';
        }
        if (hasConditionField('Include_In_Email__c')) {
            query += ' AND Include_In_Email__c = true';
        } else if (hasConditionField('IncludeInEmail__c')) {
            query += ' AND IncludeInEmail__c = true';
        }
        List<Condition__c> conditions = (List<Condition__c>) Database.query(query);
        return getContentVersionsByConditionList(wrapConditions(conditions));
    }

    public List<TransactionCondition> getConditionsIncludedInEmailByLoanId(Id loanId) {
        String query = 'SELECT ' + String.join(conditionFields, ',') + ' FROM Condition__c WHERE Transaction__c = :loanId';
        if (hasConditionField('Include_In_Email__c')) {
            query += ' AND Include_In_Email__c = true';
        } else if (hasConditionField('IncludeInEmail__c')) {
            query += ' AND IncludeInEmail__c = true';
        }
        List<Condition__c> conditions = (List<Condition__c>) Database.query(query);
        return getContentVersionsByConditionList(wrapConditions(conditions));
    }

    public List<TransactionCondition> getConditionsWithStatusRequestedByLoanId(Id loanId) {
        String requestedStatus = 'Requested';
        String query =
            'SELECT ' +
            String.join(conditionFields, ',') +
            ' FROM Condition__c WHERE Transaction__c = :loanId AND Status__c = :requestedStatus';
        List<Condition__c> conditions = (List<Condition__c>) Database.query(query);
        return getContentVersionsByConditionList(wrapConditions(conditions));
    }

    public TransactionCondition getConditionById(Id conditionId) {
        if (conditionId == null) {
            return null;
        }

        String query = 'SELECT ' + String.join(conditionFields, ',') + ' FROM Condition__c WHERE Id = :conditionId LIMIT 1';
        SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.READABLE, Database.query(query));
        List<Condition__c> conditions = (List<Condition__c>) securityDecision.getRecords();
        if (conditions.isEmpty()) {
            return null;
        }

        List<TransactionCondition> conditionsResponse = getContentVersionsByConditionList(
            new List<TransactionCondition>{ new TransactionCondition(conditions[0]) }
        );
        return conditionsResponse[0];
    }

    public TransactionCondition getActiveGenericUploadConditionByLoanId(Id loanId) {
        if (loanId == null) {
            return null;
        }

        String reviewStatus = 'Review';
        String query =
            'SELECT ' +
            String.join(conditionFields, ',') +
            ' FROM Condition__c' +
            ' WHERE Transaction__c = :loanId' +
            ' AND Status__c = :reviewStatus' +
            ' AND Subject__c = :GENERIC_UPLOAD_SUBJECT' +
            ' ORDER BY CreatedDate DESC LIMIT 1';
        List<Condition__c> conditions = (List<Condition__c>) Database.query(query);
        return conditions.isEmpty() ? null : getContentVersionsByConditionList(wrapConditions(conditions))[0];
    }

    private static String mergeColumnAndFunctionalFields(List<String> columnFields) {
        Set<String> mergedFields = new Set<String>(FIELDS_FOR_VIEWER_FUNCTIONALITY);
        if (columnFields != null && !columnFields.isEmpty()) {
            mergedFields.addAll(columnFields);
        }

        Set<String> directFields = new Set<String>();
        Set<String> validFields = new Set<String>();
        for (String field : mergedFields) {
            if (String.isBlank(field)) {
                continue;
            }
            if (isRelationshipPath(field)) {
                if (isValidRelationshipPath(field)) {
                    validFields.add(field);
                }
            } else if (hasConditionField(field)) {
                directFields.add(field);
                validFields.add(field);
            }
        }

        validFields.addAll(resolveRelationshipFields(directFields));

        return !validFields.isEmpty() ? String.join(new List<String>(validFields), ', ') : 'Id';
    }

    private static Set<String> resolveRelationshipFields(Set<String> fieldNames) {
        Set<String> relationshipFields = new Set<String>();

        for (String fieldName : fieldNames) {
            if (!hasConditionField(fieldName)) {
                continue;
            }

            DescribeFieldResult fieldDescribe = Condition__c.SObjectType.getDescribe().fields.getMap().get(fieldName).getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }

            String relationshipName = fieldDescribe.getRelationshipName();
            if (String.isBlank(relationshipName)) {
                continue;
            }

            Boolean isUserLookup = false;
            for (Schema.SObjectType referenceType : fieldDescribe.getReferenceTo()) {
                if (referenceType == User.SObjectType) {
                    isUserLookup = true;
                    break;
                }
            }
            Set<String> fieldsToAdd = isUserLookup ? USER_RELATIONSHIP_FIELDS : DEFAULT_RELATIONSHIP_FIELDS;
            for (String relationshipField : fieldsToAdd) {
                relationshipFields.add(relationshipName + '.' + relationshipField);
            }
        }

        return relationshipFields;
    }

    private static List<TransactionCondition> wrapConditions(List<Condition__c> conditions) {
        List<TransactionCondition> response = new List<TransactionCondition>();
        for (Condition__c condition : conditions) {
            response.add(new TransactionCondition(condition));
        }
        return response;
    }

    private static List<TransactionCondition> getContentVersionsByConditionList(List<TransactionCondition> conditions) {
        Set<Id> conditionIds = new Set<Id>();
        Map<Id, TransactionCondition> conditionsById = new Map<Id, TransactionCondition>();
        for (TransactionCondition condition : conditions) {
            conditionIds.add(condition.data.Id);
            conditionsById.put(condition.data.Id, condition);
        }
        if (conditionIds.isEmpty()) {
            return conditionsById.values();
        }

        List<ContentDocumentLink> documentLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :conditionIds
            WITH USER_MODE
        ];

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : documentLinks) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        if (contentDocumentIds.isEmpty()) {
            return conditionsById.values();
        }

        List<String> contentVersionFields = new List<String>{ 'Id', 'Title', 'ContentDocumentId', 'FileExtension' };
        Map<String, Schema.SObjectField> contentVersionFieldMap = Schema.SObjectType.ContentVersion.fields.getMap();
        if (contentVersionFieldMap.containsKey('Folder__c')) {
            contentVersionFields.add('Folder__c');
        }
        if (contentVersionFieldMap.containsKey('Condition__c')) {
            contentVersionFields.add('Condition__c');
        }
        String versionQuery =
            'SELECT ' +
            String.join(contentVersionFields, ',') +
            ' FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = TRUE WITH USER_MODE';
        List<ContentVersion> contentVersions = (List<ContentVersion>) Database.query(versionQuery);

        Map<Id, ContentVersion> contentVersionsByDocumentId = new Map<Id, ContentVersion>();
        for (ContentVersion contentVersion : contentVersions) {
            contentVersionsByDocumentId.put(contentVersion.ContentDocumentId, contentVersion);
        }

        for (ContentDocumentLink link : documentLinks) {
            TransactionCondition condition = conditionsById.get(link.LinkedEntityId);
            if (condition.contentVersions == null) {
                condition.contentVersions = new List<ContentVersion>();
            }
            ContentVersion latestVersion = contentVersionsByDocumentId.get(link.ContentDocumentId);
            if (latestVersion != null) {
                condition.contentVersions.add(latestVersion);
            }
        }
        return conditionsById.values();
    }

    private static String getUnreadConditionCommentsSubquery() {
        return ' (SELECT Id, Name, Condition__c, Comment_Text__c, Portal_Comment__c, Public__c, Created_By_Name__c, Read__c, CreatedDate, CreatedById' +
            ' FROM Condition_Comments__r WHERE Read__c = FALSE) ';
    }

    private static Boolean hasConditionField(String fieldApiName) {
        return Schema.SObjectType.Condition__c.fields.getMap().containsKey(fieldApiName);
    }

    private static Boolean isRelationshipPath(String fieldApiName) {
        return fieldApiName != null && fieldApiName.contains('.');
    }

    private static Boolean isValidRelationshipPath(String fieldPath) {
        List<String> pathParts = fieldPath.split('\\.');
        if (pathParts.size() < 2) {
            return false;
        }

        Schema.SObjectType currentType = Condition__c.SObjectType;
        for (Integer i = 0; i < pathParts.size() - 1; i++) {
            DescribeFieldResult relationshipDescribe = getRelationshipDescribe(currentType, pathParts[i]);
            if (relationshipDescribe == null || relationshipDescribe.getReferenceTo().isEmpty()) {
                return false;
            }
            currentType = relationshipDescribe.getReferenceTo()[0];
        }

        return currentType.getDescribe().fields.getMap().containsKey(pathParts[pathParts.size() - 1]);
    }

    private static DescribeFieldResult getRelationshipDescribe(Schema.SObjectType sourceType, String relationshipName) {
        for (SObjectField fieldToken : sourceType.getDescribe().fields.getMap().values()) {
            DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE && fieldDescribe.getRelationshipName() == relationshipName) {
                return fieldDescribe;
            }
        }
        return null;
    }

    public static void upsertLoanConditions(List<Condition__c> loanConditions) {
        if (loanConditions.isEmpty()) {
            return;
        }
        List<String> listOfErrors = new List<String>();
        List<Database.UpsertResult> upsertResultsForLoanConditions = Database.upsert(
            loanConditions,
            Schema.SObjectType.Condition__c.fields.getMap().get('UWM_Condition_Id__c'),
            false,
            AccessLevel.USER_MODE
        );
        for (Database.UpsertResult upsertResult : upsertResultsForLoanConditions) {
            if (!upsertResult.isSuccess()) {
                for (Database.Error err : upsertResult.getErrors()) {
                    listOfErrors.add(
                        'Record id:' +
                        upsertResult.getId() +
                        ', Status code: ' +
                        err.getStatusCode() +
                        ', Error message: ' +
                        err.getMessage() +
                        ', Fields: ' +
                        err.getFields()
                    );
                }
            }
        }
        if (!listOfErrors.isEmpty()) {
            System.debug(
                LoggingLevel.ERROR,
                'There were ' + listOfErrors.size() + ' errors while upserting the loan conditions: ' + String.join(listOfErrors, ', ')
            );
        }
    }

    public static List<Condition__c> getLoanConditions(Map<String, Object> parameters, Map<Id, Loan> oppIdToLoanMap) {
        List<Condition__c> needsToUpsert = new List<Condition__c>();
        UWM_Conditions_API_Res_Model loanConditionsRes;
        try {
            String currentLoanId = (String) parameters.get('currentLoanId');
            String currentLoanNumber = (String) parameters.get('currentLoanNumber');

            if (!oppIdToLoanMap.containsKey(currentLoanId)) {
                return needsToUpsert;
            }

            Loan currentLoan = oppIdToLoanMap.get(currentLoanId);
            UWMConditions_AuthProvider.currentOwnerId = currentLoan.getData().OwnerId;
            loanConditionsRes = UWM_Conditions_Gateway.getLoanConditions(currentLoanNumber);

            List<Condition__c> needToProcessForCurrentLoan = processLoanConditions(loanConditionsRes, currentLoanId, currentLoanNumber);
            if (!needToProcessForCurrentLoan.isEmpty()) {
                needsToUpsert.addAll(needToProcessForCurrentLoan);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'There was a problem while fetching conditions ' + e.getMessage());
            throw e;
        }
        return needsToUpsert;
    }

    public static List<Condition__c> processLoanConditions(
        UWM_Conditions_API_Res_Model payload,
        String currentLoanId,
        String currentLoanNumber
    ) {
        List<String> groupsToInclude = new List<String>();
        List<UWMLoanConditionGroups__mdt> acceptedConditionGroupsMetadata = UWMLoanConditionGroups__mdt.getAll().values();
        for (UWMLoanConditionGroups__mdt conditionGroup : acceptedConditionGroupsMetadata) {
            groupsToInclude.add(conditionGroup.Condition_Group_Key__c);
        }

        Map<String, Condition__c> uwmConditionIdToLoanConditionMap = new Map<String, Condition__c>();
        for (UWM_Conditions_API_Res_Model.Condition clearedCondition : payload.clearedConditions) {
            Condition__c conditionToUpsert = clearedCondition.convertToClientNeed(currentLoanId, currentLoanNumber, 'Cleared');
            checkForDuplicateLoanCondition(uwmConditionIdToLoanConditionMap, conditionToUpsert);
        }

        for (UWM_Conditions_API_Res_Model.ConditionsGroup conditionGroup : payload.conditionGroups) {
            for (UWM_Conditions_API_Res_Model.Condition condition : conditionGroup.conditions) {
                Condition__c conditionToUpsert = condition.convertToClientNeed(currentLoanId, currentLoanNumber, null);
                if (groupsToInclude.isEmpty() || groupsToInclude.contains(conditionToUpsert.Condition_Group_Key__c)) {
                    checkForDuplicateLoanCondition(uwmConditionIdToLoanConditionMap, conditionToUpsert);
                }
            }
        }

        return uwmConditionIdToLoanConditionMap.values();
    }

    private static void checkForDuplicateLoanCondition(Map<String, Condition__c> uwmConditionIdToLoanConditionMap, Condition__c need) {
        if (!uwmConditionIdToLoanConditionMap.containsKey(need.UWM_Condition_Id__c)) {
            uwmConditionIdToLoanConditionMap.put(need.UWM_Condition_Id__c, need);
        }
    }

    public static List<Condition__c> findConditionsNotInRequest(String loanId, List<Condition__c> conditionsInRequest) {
        Map<String, Condition__c> loanConditionMap = new Map<String, Condition__c>();
        if (conditionsInRequest.isEmpty()) {
            return loanConditionMap.values();
        }

        Map<String, Condition__c> conditionsInRequestMap = new Map<String, Condition__c>();
        List<Condition__c> existingConditions = [
            SELECT Id, UWM_Condition_Id__c
            FROM Condition__c
            WHERE Transaction__c = :loanId AND UWM_Condition_Id__c != NULL
            WITH USER_MODE
        ];

        if (existingConditions.isEmpty()) {
            return loanConditionMap.values();
        }

        for (Condition__c condition : conditionsInRequest) {
            conditionsInRequestMap.put(condition.UWM_Condition_Id__c, condition);
        }
        for (Condition__c condition : existingConditions) {
            loanConditionMap.put(condition.UWM_Condition_Id__c, condition);
        }
        for (String uwmConditionId : conditionsInRequestMap.keySet()) {
            if (loanConditionMap.containsKey(uwmConditionId)) {
                loanConditionMap.remove(uwmConditionId);
            }
        }
        return loanConditionMap.values();
    }
}