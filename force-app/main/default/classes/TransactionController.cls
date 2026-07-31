public class TransactionController  {
	@AuraEnabled
    public static String clone(String model,String recordId){
        String query = SObjectCloneUtility.generateQueryForModel(model) + ' WHERE Id = \'' +recordId+'\'';
		System.debug('Query: '+query);
        List<Transaction__c> transactionList = Database.query(query);
        if(transactionList.size() > 0){
            SObjectCloneUtility.SObjectClone clone = new SObjectCloneUtility.SObjectClone(transactionList[0],model, new PersistenceStrategy.BasicSave());
            clone.saveRecord();
			clearArriveId(recordId);
            String clonedTransactionId = clone.getClonedData().Id;
            updateTransactionIdOnLead(recordId, clonedTransactionId);
            return clonedTransactionId;
        }
        else{
            return null;
        }
    }
	public static void clearArriveId(String recordId){
		Transaction__c t = [SELECT Id,AriveId__c FROM Transaction__c WHERE Id =: recordId];
		if(t.AriveId__c != null || !String.isBlank(t.AriveId__c)){
			t.AriveId__c = '';
			update t;
		}
	}
    
    public static void updateTransactionIdOnLead(String oldRecordId, String newRecordId) {
        List<Lead> leads = [SELECT Id, Pre_Approval_Date__c, Converted_Transaction_ID__c FROM Lead 
                            WHERE Converted_Transaction_ID__c = :oldRecordId AND Pre_Approval_Date__c != NULL];
        
        if (leads.isEmpty()) {
            return;
        }        
        
        for (Lead l : leads) {
            l.Converted_Transaction_ID__c = newRecordId;
        }
        
        update leads;
    }
}