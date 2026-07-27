@IsTest
private class ConsumerWebinarDocsWebhookSvcTest {
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
    static void sendsOnlyForFirstTransitionToDocumentsRequested() {
        Lead qualifyingLead = createLead(firstAvailableStatus('Working'), 'Consumer Webinar', 'qualifying@example.com');
        Lead otherSourceLead = createLead(firstAvailableStatus('Working'), otherAvailableLeadSource(), 'other@example.com');
        insert new List<Lead>{ qualifyingLead, otherSourceLead };

        mockCalls = 0;
        mockLastBody = null;
        ConsumerWebinarDocsWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        qualifyingLead.Status = firstAvailableStatus('Documents Requested');
        otherSourceLead.Status = firstAvailableStatus('Documents Requested');
        update new List<Lead>{ qualifyingLead, otherSourceLead };
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected one webhook callout for Consumer Webinar.');
        System.assert(mockLastBody.contains('Consumer Webinar'));
        System.assert(mockLastBody.contains('Documents Requested'));

        Lead delivered = [
            SELECT CW_Docs_Req_Webhook_Sent__c
            FROM Lead
            WHERE Id = :qualifyingLead.Id
        ];
        System.assertEquals(true, delivered.CW_Docs_Req_Webhook_Sent__c);
    }

    @IsTest
    static void doesNotSendWhenStatusDoesNotChangeIntoDocumentsRequested() {
        Lead leadRecord = createLead(firstAvailableStatus('Documents Requested'), 'Consumer Webinar', 'existing@example.com');
        insert leadRecord;

        mockCalls = 0;
        ConsumerWebinarDocsWebhookSvc.enqueuedJobCount = 0;
        ConsumerWebinarDocsWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        leadRecord.FirstName = 'Updated';
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, mockCalls, 'Expected no webhook when status was already Documents Requested.');
        System.assertEquals(0, ConsumerWebinarDocsWebhookSvc.enqueuedJobCount);
    }

    @IsTest
    static void doesNotSendAgainAfterFirstDelivery() {
        Lead leadRecord = createLead(firstAvailableStatus('Working'), 'Consumer Webinar', 'again@example.com');
        insert leadRecord;

        mockCalls = 0;
        ConsumerWebinarDocsWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        leadRecord.Status = firstAvailableStatus('Documents Requested');
        update leadRecord;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected the initial Documents Requested webhook to send once.');

        leadRecord = [
            SELECT Id, Status, CW_Docs_Req_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        ConsumerWebinarDocsWebhookSvc.enqueuedJobCount = 0;
        leadRecord.Status = alternateAvailableStatus('Documents Requested');
        update leadRecord;
        leadRecord = [
            SELECT Id, Status, CW_Docs_Req_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        leadRecord.Status = firstAvailableStatus('Documents Requested');
        update leadRecord;

        System.assertEquals(0, ConsumerWebinarDocsWebhookSvc.enqueuedJobCount,
            'Expected no second webhook job after the sent flag is already true.');
    }

    private static Lead createLead(String status, String leadSource, String emailAddress) {
        return new Lead(
            FirstName = 'Consumer',
            LastName = 'Webhook',
            Company = 'Reach Test',
            Email = emailAddress,
            LeadSource = leadSource,
            Status = status
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

    private static String otherAvailableLeadSource() {
        for (Schema.PicklistEntry entry : Lead.LeadSource.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != 'Consumer Webinar') {
                return entry.getValue();
            }
        }
        return 'Other';
    }
}
