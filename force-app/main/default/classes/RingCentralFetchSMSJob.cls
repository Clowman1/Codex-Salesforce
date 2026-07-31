// Schedulable Class
public class RingCentralFetchSMSJob implements Schedulable {
    public static void execute(SchedulableContext ctx) {
        DateTime xHourAgo = DateTime.now().addMinutes(-30);
        
        // Fetch users that meet the criteria
        List<User> users = [SELECT Id, RC_Last_Pull_Date__c, Rc_Extension_Id__c 
                            FROM User 
                            WHERE Rc_Extension_Id__c != null 
                            AND (RC_Last_Pull_Date__c = null OR RC_Last_Pull_Date__c <= :xHourAgo)
                            ORDER BY RC_Last_Pull_Date__c ASC NULLS FIRST
                            LIMIT 15];
        
        // Queueable job to process callouts and updates
        if (users.size() > 0) {
            System.enqueueJob(new RingCentralFetchSMSQueueable(users));
        }
    }
    
    public class RingCentralFetchSMSQueueable implements Queueable, Database.AllowsCallouts {
        private List<User> users;
        
        // Constructor to pass users list
        public RingCentralFetchSMSQueueable(List<User> users) {
            this.users = users;
        }
        
        public void execute(QueueableContext context) {
            RingCentralLogSMS.Input inp = new RingCentralLogSMS.Input();
            inp.extensionIds = new List<String>();
            
            // Prepare data for callout
            for (User u : users) {
                inp.extensionIds.add(u.Rc_Extension_Id__c);
            }
            
            // Perform callout if extensionIds are available
            if (!Test.isRunningTest() && inp.extensionIds.size() > 0) {
                RingCentralLogSMS.RingCentralCallSMS(new List<RingCentralLogSMS.Input> { inp });
            }
            
            // Update RC_Last_Pull_Date__c on users
            List<User> usersToUpdate = new List<User>();
            for (User u : users) {
                u.RC_Last_Pull_Date__c = DateTime.now();
                usersToUpdate.add(u);
            }
            
            if (usersToUpdate.size() > 0) {
                update usersToUpdate;
            }
        }
    }
}