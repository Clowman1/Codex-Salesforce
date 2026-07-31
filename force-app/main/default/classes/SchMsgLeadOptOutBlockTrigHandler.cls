public with sharing class SchMsgLeadOptOutBlockTrigHandler {
    private static final String TYPE_RINGCENTRAL_SMS = 'RingCentral SMS';

    private final List<Scheduled_Message__c> newMessages;

    public SchMsgLeadOptOutBlockTrigHandler() {
        this.newMessages = (List<Scheduled_Message__c>) Trigger.new;
    }

    public void handleBeforeInsert() {
        if (newMessages == null || newMessages.isEmpty()) {
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Scheduled_Message__c m : newMessages) {
            if (m == null || m.Lead__c == null) {
                continue;
            }
            if (m.Type__c != TYPE_RINGCENTRAL_SMS) {
                continue;
            }
            leadIds.add(m.Lead__c);
        }

        if (leadIds.isEmpty()) {
            return;
        }

        Map<Id, Lead> leadsById = LeadRepository.getInstance().selectSmsOptOutByIds(leadIds);
        if (leadsById.isEmpty()) {
            return;
        }

        for (Scheduled_Message__c m : newMessages) {
            if (m == null || m.Lead__c == null || m.Type__c != TYPE_RINGCENTRAL_SMS) {
                continue;
            }
            Lead l = leadsById.get(m.Lead__c);
            if (l != null && l.Opt_Out_from_SMS_Automation__c == true) {
                m.Blocked__c = true;
            }
        }
    }
}