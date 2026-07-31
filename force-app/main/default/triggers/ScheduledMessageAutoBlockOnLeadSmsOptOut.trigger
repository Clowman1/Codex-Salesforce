trigger ScheduledMessageAutoBlockOnLeadSmsOptOut on Scheduled_Message__c (before insert) {
    new SchMsgLeadOptOutBlockTrigHandler().handleBeforeInsert();
}