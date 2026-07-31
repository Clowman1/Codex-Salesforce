public with sharing class UserActionController {
    private static final String USER_ACTION_OBJECT = 'User_Action__c';

    @AuraEnabled
    public static void saveUserInteraction(Map<String, Object> params) {
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (!globalDescribe.containsKey(USER_ACTION_OBJECT)) {
                System.debug(LoggingLevel.INFO, 'User action object not available. Params: ' + JSON.serialize(params));
                return;
            }

            Schema.SObjectType actionType = globalDescribe.get(USER_ACTION_OBJECT);
            Map<String, Schema.SObjectField> fieldsMap = actionType.getDescribe().fields.getMap();
            SObject actionRecord = actionType.newSObject();

            putIfPresent(actionRecord, fieldsMap, 'Transaction__c', params.get('transactionId'));
            putIfPresent(actionRecord, fieldsMap, 'Condition__c', params.get('conditionId'));
            putIfPresent(actionRecord, fieldsMap, 'Type__c', params.get('type'));
            putIfPresent(actionRecord, fieldsMap, 'User__c', UserInfo.getUserId());

            Database.insert(actionRecord, true);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error saving user action: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    private static void putIfPresent(SObject target, Map<String, Schema.SObjectField> fieldsMap, String fieldName, Object value) {
        if (value != null && fieldsMap.containsKey(fieldName)) {
            target.put(fieldName, value);
        }
    }
}