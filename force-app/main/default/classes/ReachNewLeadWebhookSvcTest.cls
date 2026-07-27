@IsTest
private class ReachNewLeadWebhookSvcTest {
    private static Integer mockCalls = 0;
    private static String mockLastBody;

    private class ZapierMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            mockCalls++;
            mockLastBody = request.getBody();
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"ok":true}');
            return response;
        }
    }

    @IsTest
    static void sendsForQualifyingInsert() {
        Lead leadRecord = createLead(firstAvailableStatus('New'), 'Biz Dev - Reach', 'insert@example.com');

        mockCalls = 0;
        mockLastBody = null;
        ReachNewLeadWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        insert leadRecord;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected one webhook callout on insert.');
        System.assert(mockLastBody.contains('Biz Dev - Reach'));
        System.assert(mockLastBody.contains('New'));

        Lead delivered = [
            SELECT BDR_New_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(true, delivered.BDR_New_Webhook_Sent__c);
    }

    @IsTest
    static void sendsWhenLeadBecomesQualifiedOnUpdate() {
        Lead leadRecord = createLead(firstAvailableStatus('Working'), 'Biz Dev - Reach', 'update@example.com');
        insert leadRecord;

        mockCalls = 0;
        mockLastBody = null;
        ReachNewLeadWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        leadRecord.Status = firstAvailableStatus('New');
        update leadRecord;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected one webhook callout when status changes to New.');
    }

    @IsTest
    static void doesNotSendForNonQualifyingInsertOrResendAfterFirstDelivery() {
        Lead otherBizDevLead = createLead(firstAvailableStatus('New'), 'Biz Dev - Pugh', 'other@example.com');
        Lead leadRecord = createLead(firstAvailableStatus('Working'), 'Biz Dev - Reach', 'again@example.com');
        insert new List<Lead>{ otherBizDevLead, leadRecord };

        mockCalls = 0;
        ReachNewLeadWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        update otherBizDevLead;
        leadRecord.Status = firstAvailableStatus('New');
        update leadRecord;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected only the Biz Dev - Reach lead to send.');

        leadRecord = [
            SELECT Id, Status, BDR_New_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        ReachNewLeadWebhookSvc.enqueuedJobCount = 0;
        leadRecord.Status = alternateAvailableStatus('New');
        update leadRecord;
        leadRecord = [
            SELECT Id, Status, BDR_New_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        leadRecord.Status = firstAvailableStatus('New');
        update leadRecord;

        System.assertEquals(0, ReachNewLeadWebhookSvc.enqueuedJobCount,
            'Expected no second webhook job after the sent flag is true.');
    }

    private static Lead createLead(String status, String bizDev, String emailAddress) {
        return new Lead(
            FirstName = 'Reach',
            LastName = 'Webhook',
            Company = 'Reach Test',
            Email = emailAddress,
            Status = status,
            Biz_Dev__c = bizDev
        );
    }

    private static String firstAvailableStatus(String preferred) {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == preferred) {
                return entry.getValue();
            }
        }
        System.assert(false, 'Expected active Lead Status value: ' + preferred);
        return null;
    }

    private static String alternateAvailableStatus(String disallowed) {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != disallowed) {
                return entry.getValue();
            }
        }
        return disallowed;
    }
}
