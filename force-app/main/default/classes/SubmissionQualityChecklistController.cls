public class SubmissionQualityChecklistController {
    @AuraEnabled
    public static List<ChecklistItem__mdt> getChecklistItems() {
        System.debug('hello');
        return [SELECT DeveloperName, Checklist__r.DeveloperName, Custom_Label__c, FieldName__c FROM ChecklistItem__mdt WHERE Checklist__r.DeveloperName = 'Submission_Quality_Checklist' ORDER BY Order__c NULLS LAST];
    }
    
    @AuraEnabled
    public static Map<String, String> getExistingChecklist(Id transactionId) {
        // Collect field names from metadata
        List<ChecklistItem__mdt> items = [
            SELECT FieldName__c FROM ChecklistItem__mdt WHERE Checklist__r.DeveloperName = 'Submission_Quality_Checklist'
        ];
        
        Set<String> fieldNames = new Set<String>();
        for (ChecklistItem__mdt item : items) {
            if (String.isNotBlank(item.FieldName__c)) {
                fieldNames.add(item.FieldName__c);
            }
        }
        
        if (fieldNames.isEmpty()) return new Map<String, String>();
        
        // Build dynamic field list
        String soqlFields = String.join(fieldNames, ',');
        String soql = 'SELECT Id,' + soqlFields + ' FROM Checklist__c WHERE Transaction__c = :transactionId LIMIT 1';
        
        // Query using Database.query
        List<Checklist__c> checklists = (List<Checklist__c>) Database.query(soql);
        
        if (checklists.isEmpty()) {
            return new Map<String, String>();
        }
        
        Checklist__c checklist = checklists[0];
        Map<String, String> results = new Map<String, String>();
        
        for (String field : fieldNames) {
            Object val = checklist.get(field);
            if (val != null) {
                results.put(field, String.valueOf(val));
            }
        }
        System.debug(results);
        return results;
    }
    
    @AuraEnabled
    public static void saveChecklistAnswers(Id transactionId, Map<String, String> answersMap) {
        
        List<ChecklistItem__mdt> items = [
            SELECT FieldName__c FROM ChecklistItem__mdt WHERE Checklist__r.DeveloperName = 'Submission_Quality_Checklist'
        ];
        
        List<Checklist__c> checklists = [SELECT Id FROM Checklist__c WHERE Transaction__c = :transactionId LIMIT 1];
        
        Checklist__c checklist = null;
        if (checklists.isEmpty()) {
            checklist = new Checklist__c();
            checklist.Transaction__c = transactionId;
            insert checklist;
        } else {
            checklist = checklists[0];
        }
        
        Integer yesCount = 0;
        Integer noCount = 0;
        Integer totalAnswered = 0;
        
        for (String fieldApi : answersMap.keySet()) {
            String value = answersMap.get(fieldApi);
            if (Schema.sObjectType.Checklist__c.fields.getMap().containsKey(fieldApi)) {
                checklist.put(fieldApi, value);
            }
            
            if (value == 'Yes') yesCount++;
            else if (value == 'No') noCount++;
            
            if (value != 'N/A' && value != null) totalAnswered++;
        }
        update checklist;
        
        // Stamp summary metrics on Transaction__c
        Transaction__c tx = new Transaction__c(
            Id = transactionId,
            Quality_Checklist_Yes_Count__c  = yesCount,
            Quality_Checklist_No_Count__c  = noCount,
            Quality_Checklist_Percentage_Complete__c  = items.size() > 0 ? ((Decimal) totalAnswered / items.size()) * 100
            : 0
        );

    	update tx;
    }
}