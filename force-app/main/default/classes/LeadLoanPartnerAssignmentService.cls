public without sharing class LeadLoanPartnerAssignmentService {
    @TestVisible private static Map<Id, Id> ownerLoanPartnerOverrides;

    public static void stampFromOwnerAssignments(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        Set<Id> ownerIds = new Set<Id>();
        for (Lead leadRecord : newLeads) {
            if (leadRecord == null || !isUserId(leadRecord.OwnerId)) {
                continue;
            }

            Lead oldLead = oldLeadMap == null ? null : oldLeadMap.get(leadRecord.Id);
            if (oldLead == null || oldLead.OwnerId != leadRecord.OwnerId) {
                ownerIds.add(leadRecord.OwnerId);
            }
        }

        if (ownerIds.isEmpty()) {
            return;
        }

        Map<Id, Id> loanPartnerIdsByOwnerId = loanPartnerIdsByOwnerId(ownerIds);

        for (Lead leadRecord : newLeads) {
            Id ownerLoanPartnerId = loanPartnerIdsByOwnerId.get(leadRecord.OwnerId);
            if (ownerLoanPartnerId == null) {
                continue;
            }
            leadRecord.Loan_Partner__c = ownerLoanPartnerId;
        }
    }

    private static Map<Id, Id> loanPartnerIdsByOwnerId(Set<Id> ownerIds) {
        Map<Id, Id> loanPartnerIdsByOwnerId = new Map<Id, Id>();
        if (Test.isRunningTest() && ownerLoanPartnerOverrides != null) {
            for (Id ownerId : ownerIds) {
                if (ownerLoanPartnerOverrides.containsKey(ownerId)) {
                    loanPartnerIdsByOwnerId.put(ownerId, ownerLoanPartnerOverrides.get(ownerId));
                }
            }
            return loanPartnerIdsByOwnerId;
        }

        for (User ownerUser : [
            SELECT Id, Loan_Partner__c
            FROM User
            WHERE Id IN :ownerIds
        ]) {
            loanPartnerIdsByOwnerId.put(ownerUser.Id, ownerUser.Loan_Partner__c);
        }
        return loanPartnerIdsByOwnerId;
    }

    private static Boolean isUserId(Id ownerId) {
        return ownerId != null && String.valueOf(ownerId).startsWith('005');
    }
}
