public with sharing class TransactionCondition extends PersistentObject {
    @AuraEnabled
    public Condition__c data;

    @AuraEnabled
    public List<ContentVersion> contentVersions;

    public TransactionCondition(Condition__c data) {
        this.data = data;
    }

    public void setStatus(String status) {
        this.data.Status__c = status;
    }

    public void setIncludedInEmail(Boolean isIncluded) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('Condition__c').getDescribe().fields.getMap();
        if (fieldMap.containsKey('Include_In_Email__c')) {
            this.data.put('Include_In_Email__c', isIncluded);
        }
        if (fieldMap.containsKey('IncludeInEmail__c')) {
            this.data.put('IncludeInEmail__c', isIncluded);
        }
    }

    public override void persist() {
        if (!Schema.SObjectType.Condition__c.isUpdateable() || !Schema.SObjectType.Condition__c.isCreateable()) {
            return;
        }
        if (this.getPersistenceStrategy() == null) {
            Database.upsert(this.data, true, AccessLevel.USER_MODE);
        } else {
            this.getPersistenceStrategy().persist(data);
        }
    }
}