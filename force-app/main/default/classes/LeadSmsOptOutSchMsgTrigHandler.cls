public with sharing class LeadSmsOptOutSchMsgTrigHandler {
    private final List<Lead> newLeads;
    private final Map<Id, Lead> oldLeadsById;

    public LeadSmsOptOutSchMsgTrigHandler() {
        this.newLeads = (List<Lead>) Trigger.new;
        this.oldLeadsById = (Map<Id, Lead>) Trigger.oldMap;
    }

    public void handleAfterUpdate() {
        if (newLeads == null || newLeads.isEmpty() || oldLeadsById == null || oldLeadsById.isEmpty()) {
            return;
        }

        Set<Id> leadIdsOptedOut = new Set<Id>();
        Set<Id> leadIdsOptedIn = new Set<Id>();

        for (Lead l : newLeads) {
            Lead oldLead = oldLeadsById.get(l.Id);
            if (oldLead == null) {
                continue;
            }

            Boolean oldVal = oldLead.Opt_Out_from_SMS_Automation__c;
            Boolean newVal = l.Opt_Out_from_SMS_Automation__c;

            if (oldVal == newVal) {
                continue;
            }

            if (newVal == true) {
                leadIdsOptedOut.add(l.Id);
            } else {
                leadIdsOptedIn.add(l.Id);
            }
        }

        if (leadIdsOptedOut.isEmpty() && leadIdsOptedIn.isEmpty()) {
            return;
        }

        LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(leadIdsOptedOut, leadIdsOptedIn);
    }
}