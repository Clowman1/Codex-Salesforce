@IsTest
public class ValueLinkDataFetchTests {
    
    public class MockHttpResponseGenerator implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            
            String reqBody = req.getBodyAsBlob().toString();
            HttpResponse res = new HttpResponse();
            
            if (reqBody.contains('GetOrderStatus')) {
                res.setBody('<VLOrderStatus><OrderStatusID>6</OrderStatusID><OrderStatusName>Completed</OrderStatusName></VLOrderStatus>');
            } else {
                res.setBody('<ANY><ReportName>ANYBLOBDATA</ReportName><Report>TestFileName</Report></ANY>');
            }
            
            res.setStatusCode(200);
            return res;
        }
    }

    @IsTest static void testFetchQueueable() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Transaction__c t = new Transaction__c();
        insert t;
        
        Appraisal_Order__c o = new Appraisal_Order__c(Loan__c = t.Id, Order_Id__c = 'ORDERID');
        insert o;
        
        Test.startTest();
        ValueLinkDataFetchQueueable.fetchReports(new List<String> { 'ORDERID' });
        Test.stopTest();
    }
    
}