// Schedulable Class
public class RingCentralFetchCallJob implements Schedulable {
    public static void execute(SchedulableContext ctx) {
        System.enqueueJob(new RingCentralFetchCallQueueable());
    }
    
    public class RingCentralFetchCallQueueable implements Queueable, Database.AllowsCallouts {
        public void execute(QueueableContext context) {
            GetRingCentralCallLog.GetRingCentralCallLog();
        }
    }
}