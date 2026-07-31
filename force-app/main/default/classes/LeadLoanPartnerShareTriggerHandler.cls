public without sharing class LeadLoanPartnerShareTriggerHandler {
    private final List<Lead> newLeads;
    private final Map<Id, Lead> oldLeadsById;

    public LeadLoanPartnerShareTriggerHandler() {
        this.newLeads = (List<Lead>) Trigger.new;
        this.oldLeadsById = (Map<Id, Lead>) Trigger.oldMap;
    }

    public void handleAfterInsertOrUpdate() {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        Map<Id, Id> createShareByLeadId = new Map<Id, Id>();
        Map<Id, Id> deleteShareByLeadId = new Map<Id, Id>();

        if (Trigger.isInsert) {
            for (Lead leadRecord : newLeads) {
                if (leadRecord.Loan_Partner__c != null) {
                    createShareByLeadId.put(leadRecord.Id, leadRecord.Loan_Partner__c);
                }
            }
        } else if (Trigger.isUpdate) {
            if (oldLeadsById == null || oldLeadsById.isEmpty()) {
                return;
            }

            for (Lead leadRecord : newLeads) {
                Lead oldLead = oldLeadsById.get(leadRecord.Id);
                if (oldLead == null) {
                    continue;
                }

                Id oldLoanPartnerId = oldLead.Loan_Partner__c;
                Id newLoanPartnerId = leadRecord.Loan_Partner__c;
                if (oldLoanPartnerId == newLoanPartnerId) {
                    continue;
                }

                if (newLoanPartnerId != null) {
                    createShareByLeadId.put(leadRecord.Id, newLoanPartnerId);
                }
                if (oldLoanPartnerId != null) {
                    deleteShareByLeadId.put(leadRecord.Id, oldLoanPartnerId);
                }
            }
        }

        if (createShareByLeadId.isEmpty() && deleteShareByLeadId.isEmpty()) {
            return;
        }

        LoanPartnerLeadShareService.syncLeadShares(createShareByLeadId, deleteShareByLeadId);
    }
}