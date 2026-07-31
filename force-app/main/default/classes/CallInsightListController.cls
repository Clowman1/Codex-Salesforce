public without sharing class CallInsightListController {

    @AuraEnabled
    public static List<Call_Insight__c> getCallInsights(String recordId) {
        
        String whereLocator;
        if (recordId.startsWith('00Q')) {
            whereLocator = 'WHERE Lead__c = :recordId ';
        } else if (recordId.startsWith('001')) {
            whereLocator = 'WHERE Account__c = :recordId ';
        } else {
            whereLocator = 'WHERE Transaction__c = :recordId ';
        } 
        
        return (List<Call_Insight__c>) Database.query(
            'SELECT Id, Name,  Salesforce_User__r.FirstName, Salesforce_User__r.LastName, CreatedDate, AI_Score__c, Direction__c, Duration__c, Title__c, ' +
            'Summary__c, Transcript__c, HighLights__c, Next_Steps__c, ' +
            'Salesforce_User__c, Salesforce_User__r.Name, Recording_Start_DateTime__c ' +
            'FROM Call_Insight__c ' +
             whereLocator + ' ' + 
            'ORDER BY Recording_Start_DateTime__c DESC'
        );
    }
}