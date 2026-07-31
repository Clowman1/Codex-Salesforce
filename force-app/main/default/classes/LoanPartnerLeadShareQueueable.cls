public without sharing class LoanPartnerLeadShareQueueable implements Queueable {
    private final List<LoanPartnerLeadShareService.RelationshipChange> relationshipChanges;
    private final Id lastProcessedLeadId;
    private final Boolean shouldSyncGroupsAndMembers;
    @TestVisible private static Boolean bypassFollowupEnqueueInTests = false;

    public LoanPartnerLeadShareQueueable(
        List<LoanPartnerLeadShareService.RelationshipChange> relationshipChanges,
        Id lastProcessedLeadId,
        Boolean shouldSyncGroupsAndMembers
    ) {
        this.relationshipChanges = relationshipChanges;
        this.lastProcessedLeadId = lastProcessedLeadId;
        this.shouldSyncGroupsAndMembers = shouldSyncGroupsAndMembers;
    }

    public void execute(QueueableContext context) {
        LoanPartnerLeadShareService.QueueableResult result =
            LoanPartnerLeadShareService.processRelationshipChangesChunk(
                relationshipChanges,
                lastProcessedLeadId,
                shouldSyncGroupsAndMembers
            );

        if (
            result != null &&
            result.hasMore == true &&
            !(Test.isRunningTest() && bypassFollowupEnqueueInTests)
        ) {
            System.enqueueJob(new LoanPartnerLeadShareQueueable(
                relationshipChanges,
                result.lastProcessedLeadId,
                false
            ));
        }
    }
}