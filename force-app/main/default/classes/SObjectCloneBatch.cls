/**
 * Created by c_zjabra on 11/21/2021.
 */
global class SObjectCloneBatch implements Database.Batchable<SObject>, Database.Stateful{
    private String model;
    private String query;
    private Set<Id> idsToUse;
    private Integer numberOfRecordsProcessed = 0, numberOfRecordsWithErrors = 0;
    private final String CLONE_BATCH_DEBUG_MESSAGE = 'Clone batch debug message'; //Label.SObject_Clone_Batch_Debug_Message;
    private final String NO_QUERY_ERROR_MESSAGE = 'No query error message';//Label.SObject_Clone_Batch_No_Query_Error_Message;

    private class SObjectBatchException extends Exception{}

    public class InvocableRequest{
        @InvocableVariable(Description='Provide a WHERE Clause that filters to the specific records you would like cloned' Required=true)
        public String whereClause;
        @InvocableVariable(Description='Provide the DeveloperName of the SObject_Clone_Model__mdt record you would like to use as your base clone model.' Required=true)
        public String modelName;
        @InvocableVariable(Description='Provide the size of batch which you would like to run the clone job for.' Required=true)
        public Integer batchSize;
    }
    @InvocableMethod(Label='SObject Model Clone Batch Job' Category='SObject Clone Utility' Description='Use this action to create a batch job which will clone a specific set of records based on a WHERE clause, for a specific model that has been defined within the Metadata configurations.')
    public static void invokeBatch(List<InvocableRequest> requests){
        for(InvocableRequest request : requests){
            Database.executeBatch(new SObjectCloneBatch(request.modelName, request.whereClause), request.batchSize);
        }
    }
    global SObjectCloneBatch(String model, String whereClause){
        this.model = model;
        this.query = SObjectCloneUtility.generateQueryForModel(model) + ' ' + whereClause;
    }
    global SObjectCloneBatch(String model,Set<Id> appIds){
        this.model = model;
        this.idsToUse = appIds;
        String whereClause = 'WHERE Id IN: idsToUse';
        this.query = SObjectCloneUtility.generateQueryForModel(model) + ' ' + whereClause;
    }
    global Database.QueryLocator start(Database.BatchableContext BC){
        Database.QueryLocator queryLocator;
        try{
            if(String.isBlank(query)){
                throw new SObjectBatchException(NO_QUERY_ERROR_MESSAGE);
            }
            queryLocator = Database.getQueryLocator(query);
        }catch(Exception e){
           System.debug(e.getMessage());
            throw e;
        }finally {
        }
        return queryLocator;
    }
    global void execute(Database.BatchableContext BC, List<SObject> scope)   {
        try{
            PersistenceStrategy.BulkifiedSave bulkSave = new PersistenceStrategy.BulkifiedSave();
            for(SObject obj : scope){
               processRecord(obj, bulkSave);
            }
            bulkSave.flush();
        }catch(Exception e){
			System.debug(e.getMessage());
        }
    }
    global void finish(Database.BatchableContext BC) {
    }

    //@AuraEnabled
    //public static String cloneApplication(String model,String appId){
        //String query = SObjectCloneUtility.generateQueryForModel(model) + ' WHERE Id = \'' +appId +'\'';
        //List<Application__c> applicationList = Database.query(query);
        //if(applicationList.size() > 0){
            //SObjectCloneUtility.SObjectClone clone = new SObjectCloneUtility.SObjectClone(applicationList[0],model, new PersistenceStrategy.BasicSave());
            //clone.saveRecord();
            //return clone.getClonedApplicationData().Id;
        //}
        //else{
            //return null;
        //}
    //}

    private void processRecord(SObject obj, PersistenceStrategy strategy){
        try{
            SObjectCloneUtility.SObjectClone clone = new SObjectCloneUtility.SObjectClone(obj,model, strategy);
            clone.saveRecord();
        }catch(Exception e){
			System.debug(e.getMessage());
            numberOfRecordsWithErrors++;
        }finally{
            numberOfRecordsProcessed++;
        }
    }

}