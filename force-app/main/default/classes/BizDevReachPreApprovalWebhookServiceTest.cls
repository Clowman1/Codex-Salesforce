@IsTest
private class BizDevReachPreApprovalWebhookServiceTest {
    private static Integer requestCount = 0;
    private static Map<String, Object> lastPayload;

    @IsTest
    static void sendsOnlyForBizDevReachStatusTransition() {
        Lead qualifyingLead = createLead('New', 'Biz Dev - Reach', 'reach@example.com');
        Lead otherLead = createLead('New', 'Biz Dev - Pugh', 'other@example.com');
        insert new List<Lead>{qualifyingLead, otherLead};

        requestCount = 0;
        lastPayload = null;
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        qualifyingLead.Status = 'Pre-Approval';
        otherLead.Status = 'Pre-Approval';
        update new List<Lead>{qualifyingLead, otherLead};
        Test.stopTest();

        System.assertEquals(1, requestCount);
        System.assertEquals(String.valueOf(qualifyingLead.Id),
            String.valueOf(lastPayload.get('leadId')));
        System.assertEquals('Biz Dev - Reach', lastPayload.get('bizDev'));
        System.assertEquals('New', lastPayload.get('oldStatus'));
        System.assertEquals('Pre-Approval', lastPayload.get('newStatus'));
    }

    @IsTest
    static void doesNotSendWhenStatusDoesNotChangeIntoPreApproval() {
        Lead leadRecord = createLead('Pre-Approval', 'Biz Dev - Reach', 'existing@example.com');
        insert leadRecord;

        requestCount = 0;
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        leadRecord.FirstName = 'Updated';
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, requestCount);
    }

    private static Lead createLead(String status, String bizDev, String emailAddress) {
        return new Lead(
            FirstName = 'Webhook',
            LastName = 'Test',
            Company = 'Reach Home Loans',
            Email = emailAddress,
            Phone = '5555551212',
            LeadSource = 'Past Client',
            Status = status,
            Biz_Dev__c = bizDev,
            Rating = 'Warm',
            Loan_Amount__c = 250000
        );
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            BizDevReachPreApprovalWebhookServiceTest.requestCount++;
            BizDevReachPreApprovalWebhookServiceTest.lastPayload =
                (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"ok":true}');
            return response;
        }
    }
}