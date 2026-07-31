@IsTest
public class CallLogDataExtractionTests {
    @IsTest static void testCoverage() {
        Test.startTest();
        CallLogDataExtractionFlowHelper.testCoverage();
        ChatGPTService.testCoverage();
        Test.stopTest(); 
    }
}