@IsTest
public class RingCentralFetchSMSJobTests {
	
    @IsTest static void testJob() {
        
        Test.startTest();
        System.schedule('RingCentral SMS Fetch', '0 0 * * * ?', new RingCentralFetchSMSJob() );
        Test.stopTest();
        
    }
}