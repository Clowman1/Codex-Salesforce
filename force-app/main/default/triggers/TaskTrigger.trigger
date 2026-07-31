trigger TaskTrigger on Task (after insert, after update, after delete) {
	TaskTriggerHandler handler = new TaskTriggerHandler();
	switch on trigger.OperationType {
		when AFTER_INSERT {
			handler.afterInsert(Trigger.new);
		}
		when AFTER_UPDATE {
			handler.afterUpdate(Trigger.new, Trigger.oldMap);
		}
		when AFTER_DELETE {
			handler.afterDelete(Trigger.old);
		}
		when else{}
	}
}