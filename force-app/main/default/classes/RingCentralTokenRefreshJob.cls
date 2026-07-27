public class RingCentralTokenRefreshJob implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        // Query all users where refresh token is older than 4 days
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id FROM User
            WHERE RingCentral_Refresh_Token_DateTime__c != NULL]
        );
        System.debug(users.size());
        if (users.size() > 0) {
            System.enqueueJob(new RingCentralAuthQueueable(new List<Id>(users.keySet())));
        }
    }
    
    class RingCentralAuthQueueable implements Queueable, Database.AllowsCallouts { 
        private List<Id> userIds;
        private Id currentUserId;
        
        public RingCentralAuthQueueable(List<Id> userIds) {
            this.userIds = userIds;
            this.currentUserId = userIds.remove(0);
        }
        
        public void execute(QueueableContext context) {
            try {
                RingCentralAuthService service = new RingCentralAuthService(currentUserId);
                service.refreshTokens();
                service.commitUpdates();
            } catch (Exception e) {
                // insert new Log__c
            }

            if (userIds.size() > 0 && !Test.isRunningTest()) {
                System.enqueueJob(new RingCentralAuthQueueable(userIds));
            }
        }
    }
}