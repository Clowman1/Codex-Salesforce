trigger UserTrigger on User (before insert, before update, after insert, after update) {

    UserTriggerHandler handler = new UserTriggerHandler();

    switch on Trigger.operationType {
        when BEFORE_INSERT {
            handler.beforeInsertOrUpdate(Trigger.new);
        }
        when BEFORE_UPDATE {
            handler.beforeInsertOrUpdate(Trigger.new);
        }
        when AFTER_INSERT {
            handler.afterInsertOrUpdate(Trigger.new, null);
        }
        when AFTER_UPDATE {
            handler.afterInsertOrUpdate(Trigger.new, Trigger.oldMap);
        }
    }

}