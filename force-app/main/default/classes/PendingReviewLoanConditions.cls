public with sharing class PendingReviewLoanConditions {
    @AuraEnabled
    public static List<Transaction__c> getLoanConditions() {
        return [
            SELECT Id, Name,
                (
                    SELECT Id, Name, LastModifiedDate
                    FROM Conditions__r
                    WHERE Status__c = 'Review'
                    AND Assigned_To__c = :UserInfo.getUserId()
                )
            FROM Transaction__c
            WHERE Id IN (
                SELECT Transaction__c
                FROM Condition__c
                WHERE Status__c = 'Review'
                AND Assigned_To__c = :UserInfo.getUserId()
            )
            WITH USER_MODE
        ];
    }

    @AuraEnabled
    public static TransactionCondition getCloudFiles(Id conditionId) {
        return TransactionConditionRepository.getInstance().getConditionById(conditionId);
    }
}