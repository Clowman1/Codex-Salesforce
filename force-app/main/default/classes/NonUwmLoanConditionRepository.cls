public with sharing class NonUwmLoanConditionRepository {
    public List<TransactionCondition__c> selectExistingConditionsByOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            return new List<TransactionCondition__c>();
        }

        return [
            SELECT Id, Name, Description__c, Type__c
            FROM TransactionCondition__c
            WHERE Transaction__c = :opportunityId
            WITH SECURITY_ENFORCED
        ]; 
    }

    public List<ContentVersion> selectLatestContentVersionsByDocumentIds(Set<Id> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return new List<ContentVersion>();
        }

        return [
            SELECT Id, ContentDocumentId, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :contentDocumentIds
        ];
    }

    public List<ContentVersion> selectContentVersionsByIds(Set<Id> contentVersionIds) {
        if (contentVersionIds == null || contentVersionIds.isEmpty()) {
            return new List<ContentVersion>();
        }

        return [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ];
    }

    public OpenAI_Integration_Setting__mdt selectOpenAiSettingByDeveloperName(String developerName) {
        if (String.isBlank(developerName)) {
            return null;
        }

        List<OpenAI_Integration_Setting__mdt> settings = [
            SELECT Request__c, Model__c, Instructions__c
            FROM OpenAI_Integration_Setting__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        return settings.isEmpty() ? null : settings[0];
    }
}