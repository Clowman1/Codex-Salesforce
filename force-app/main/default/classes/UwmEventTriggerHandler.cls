public class UwmEventTriggerHandler {
    private static final String TRANSACTION_STATUS_FIELD = 'Status__c';
    private static final Set<String> SALESFORCE_MANAGED_STATUSES = new Set<String>{
        'Closing',
        'Funding',
        'PC Review',
        'Post-Closed'
    };

    public static void handleAfterInsert(List<UWM_Event__e> events, List<UWM_Insights_Mapping__mdt> metadata){
        List<SObject> transactionsToUpdate = new List<SObject>(); 
        Set<Id> processedTransactions = new Set<Id>();
        for(UWM_Event__e event : events){            
            UWM_Loan_Info__c info = UWMLoanInfoRepository.getInstance().getUWMLoanById(event.UWM_Loan_Info_ID__c); 
            Transaction__c transact = TransactionRepository.getInstance().getTransactionById(event.Transaction_ID__c); 
            SObject infoObject = (SObject)info;
            SObject transactionObject = (SObject) transact;
            for(UWM_Insights_Mapping__mdt mData : metadata){
                Object val;
                if(mData.Transaction_Field_API_Name__c != null && mData.API_Name__c != null){
                    System.debug(mData.API_Name__c + ' => ' + mData.Transaction_Field_API_Name__c);
                    
                    if(mData.UWM_Translated_Values__r == null || mData.UWM_Translated_Values__r.size() == 0){
                        if(mData.Datatype__c == 'Datetime' && mData.Convert_Datetime_to_Date__c == true){ 
                            Datetime datetimeValue = (Datetime)info.get(mData.API_Name__c);
                            if(datetimeValue != null){
                                System.debug('  Original DateTime: ' + datetimeValue);
                                //String formatDatetime = (Date.newInstance(datetimeValue.year(), datetimeValue.month(),datetimeValue.day())).format();

                                putMappedValue(transactionObject, transact, info, mData.Transaction_Field_API_Name__c, datetimeValue.dateGMT()); //Date.parse(formatDatetime));
                                 System.debug('  Formatted DateTime: ' + datetimeValue.dateGMT());
                            }else{                                                               
                                putMappedValue(transactionObject, transact, info, mData.Transaction_Field_API_Name__c, null);  
                            }
                        }else{ 
                            try {
                                putMappedValue(transactionObject, transact, info, mData.Transaction_Field_API_Name__c, infoObject.get(mData.API_Name__c)); 
                            } catch (Exception e) {
                                throw new UwmEventTriggerHandlerException('Error mapping fields ' + mData.Transaction_Field_API_Name__c + ', ' + mData.API_Name__c + '. Error ' + e.getMessage());
                            }
                            
                        }
                    }               
                    else{
                        for(UWM_Translated_Value__mdt translation : mData.UWM_Translated_Values__r){
                            if(infoObject.get(mData.API_Name__c) == translation.Input_Value__c){
                                val = translation.Output_Value__c; 
                            }
                        }
                        if(val != null || mData.Transaction_Field_API_Name__c == TRANSACTION_STATUS_FIELD){
                            putMappedValue(transactionObject, transact, info, mData.Transaction_Field_API_Name__c, val); 
                        }
                    }
                }
            }            
            
            if (!processedTransactions.contains(transactionObject.Id)) {
                transactionsToUpdate.add(transactionObject);
                processedTransactions.add(transactionObject.Id);
            }

            //transactionsToUpdate.add(transactionObject);             
        }        
        if(transactionsToUpdate.size() > 0){
            update transactionsToUpdate;
        } 
    }
    
    private static void putMappedValue(SObject transactionObject, Transaction__c originalTransaction, UWM_Loan_Info__c info, String fieldApiName, Object mappedValue){
        mappedValue = getDerivedMappedValue(originalTransaction, info, fieldApiName, mappedValue);
        if(!shouldApplyMappedValue(originalTransaction, fieldApiName, mappedValue)){
            return;
        }

        transactionObject.put(fieldApiName, mappedValue);
    }

    private static Object getDerivedMappedValue(Transaction__c originalTransaction, UWM_Loan_Info__c info, String fieldApiName, Object mappedValue){
        if(fieldApiName != TRANSACTION_STATUS_FIELD || originalTransaction == null || info == null){
            return mappedValue;
        }

        if(SALESFORCE_MANAGED_STATUSES.contains(originalTransaction.Status__c)){
            return mappedValue;
        }

        if(String.valueOf(mappedValue) == 'Closing'){
            return 'Closing';
        }

        if(info.uwm_ClearToCloseDate__c != null){
            return 'Approved';
        }

        return mappedValue;
    }

    private static Boolean shouldApplyMappedValue(Transaction__c originalTransaction, String fieldApiName, Object mappedValue){
        if(fieldApiName != TRANSACTION_STATUS_FIELD){
            return true;
        }

        String currentStatus = originalTransaction.Status__c;
        if(SALESFORCE_MANAGED_STATUSES.contains(currentStatus)){
            return false;
        }

        if(mappedValue == null){
            return false;
        }

        String incomingStatus = String.valueOf(mappedValue);
        if(incomingStatus == 'Closing'){
            return true;
        }

        return !SALESFORCE_MANAGED_STATUSES.contains(incomingStatus);
    }

    public class UwmEventTriggerHandlerException extends Exception {}
}
