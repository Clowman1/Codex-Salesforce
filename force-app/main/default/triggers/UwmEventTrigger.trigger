trigger UwmEventTrigger on UWM_Event__e (after insert) {
    if (Trigger.isInsert) {
        //List<SObject> transactionsToUpdate = new List<SObject>();

        try {
            List<UWM_Insights_Mapping__mdt> metadata = [SELECT Id,API_Name__c,Transaction_Field_API_Name__c,Datatype__c,UWM_Field_Name__c,Convert_Datetime_to_Date__c, (SELECT Id, Input_Value__c, Output_Value__c FROM UWM_Translated_Values__r) FROM UWM_Insights_Mapping__mdt];        
            UwmEventTriggerHandler.handleAfterInsert(
                Trigger.New,
                metadata);            
        } catch(Exception e) {
            insert new Custom_Log__c(Data__c = e.getMessage() + '. Stack trace ' + e.getStackTraceString());
        }
        
        
    }
}