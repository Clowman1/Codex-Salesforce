trigger LeadLoanPartnerAssignment on Lead (before insert, before update) {
    LeadLoanPartnerAssignmentService.stampFromOwnerAssignments(
        Trigger.new,
        Trigger.isInsert ? null : Trigger.oldMap
    );
}
