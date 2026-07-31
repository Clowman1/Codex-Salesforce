public class TranactionController  {
	@AuraEnabled
    public static String clone(String model,String recordId){
        String query = SObjectCloneUtility.generateQueryForModel(model) + ' WHERE Id = \'' +recordId+'\'';
		System.debug('Query: '+query);
        List<Transaction__c> transactionList = Database.query(query);
        if(transactionList.size() > 0){
            SObjectCloneUtility.SObjectClone clone = new SObjectCloneUtility.SObjectClone(transactionList[0],model, new PersistenceStrategy.BasicSave());
            clone.saveRecord();
            return clone.getClonedData().Id;
        }
        else{
            return null;
        }
    }
}