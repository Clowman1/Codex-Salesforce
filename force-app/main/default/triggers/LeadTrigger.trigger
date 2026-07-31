trigger LeadTrigger on Lead (after insert, after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        new LeadSmsOptOutSchMsgTrigHandler().handleAfterUpdate();
    }

    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        new LeadLoanPartnerShareTriggerHandler().handleAfterInsertOrUpdate();
    }
}