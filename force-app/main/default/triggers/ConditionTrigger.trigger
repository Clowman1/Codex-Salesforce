trigger ConditionTrigger on Condition__c (before update, after insert) {
    TransactionConditionTriggerHandler handler = new TransactionConditionTriggerHandler();

    switch on Trigger.operationType {
        when BEFORE_UPDATE {
            handler.handleBeforeUpdate();
        }
        when AFTER_INSERT {
            handler.handleAfterInsert();
        }
    }

}