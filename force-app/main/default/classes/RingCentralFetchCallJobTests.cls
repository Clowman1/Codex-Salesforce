@IsTest
public class RingCentralFetchCallJobTests {
    
    @IsTest static void testJob() {
        Test.startTest();
        Id jobId = System.schedule('RingCentral Call Fetch', '0 0 * * * ?', new RingCentralFetchCallJob());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduled job id should be returned.');
        CronTrigger ct = [SELECT Id, State, CronJobDetail.Name FROM CronTrigger WHERE Id = :jobId LIMIT 1];
        System.assertEquals('RingCentral Call Fetch', ct.CronJobDetail.Name);
    }
    
}