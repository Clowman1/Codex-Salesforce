@IsTest
private class ConsumerWebinarWebhookTest {
    private static Integer mockCalls;
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

    @TestSetup
    static void setUpData() {
        insert new List<Lead>{
            new Lead(FirstName = 'Consumer', LastName = 'Qualifying', Company = 'Test', LeadSource = 'Consumer Webinar', Status = firstAvailableStatus('New')),
            new Lead(FirstName = 'Consumer', LastName = 'Early', Company = 'Test', LeadSource = 'Consumer Webinar', Status = firstAvailableStatus('New')),
            new Lead(FirstName = 'Other', LastName = 'Source', Company = 'Test', LeadSource = otherAvailableLeadSource(), Status = firstAvailableStatus('New')),
            new Lead(FirstName = 'Consumer', LastName = 'AlreadySent', Company = 'Test', LeadSource = 'Consumer Webinar', Status = firstAvailableStatus('New'))
        };
    }

    @IsTest
    static void sendsOnlyForTheFirstQualifyingConsumerWebinarStatusChange() {
        Lead qualifying = [SELECT Id, Status, Consumer_Webinar_Contacted_Webhook_Sent__c FROM Lead WHERE LastName = 'Qualifying' LIMIT 1];
        qualifying.Status = firstNonEarlyStatus();

        mockCalls = 0;
        Test.setMock(HttpCalloutMock.class, new ZapierMock());
        Test.startTest();
        update qualifying;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'The dedicated Consumer Webinar webhook should send once.');
        System.assert(mockLastBody.contains('Consumer Webinar'));
        Lead delivered = [SELECT Consumer_Webinar_Contacted_Webhook_Sent__c FROM Lead WHERE Id = :qualifying.Id];
        System.assertEquals(true, delivered.Consumer_Webinar_Contacted_Webhook_Sent__c);
    }

    @IsTest
    static void doesNotSendForEarlyStatusesOrOtherLeadSources() {
        List<Lead> leads = [SELECT Id, Status FROM Lead WHERE LastName IN ('Early', 'Source')];
        for (Lead lead : leads) {
            lead.Status = firstAvailableStatus('Contact Attempt 1');
        }

        mockCalls = 0;
        Test.setMock(HttpCalloutMock.class, new ZapierMock());
        Test.startTest();
        update leads;
        Test.stopTest();

        System.assertEquals(0, mockCalls, 'Early statuses and non-Consumer Webinar sources must not send.');
    }

    @IsTest
    static void doesNotSendAgainAfterTheFirstDelivery() {
        Lead lead = [SELECT Id, Status FROM Lead WHERE LastName = 'AlreadySent' LIMIT 1];
        lead.Status = firstNonEarlyStatus();

        mockCalls = 0;
        Test.setMock(HttpCalloutMock.class, new ZapierMock());
        Test.startTest();
        update lead;
        Test.stopTest();

        lead = [SELECT Id, Status FROM Lead WHERE Id = :lead.Id];
        lead.Status = alternateNonEarlyStatus(lead.Status);
        update lead;

        System.assertEquals(1, mockCalls, 'Later status changes must not resend the Consumer Webinar webhook.');
    }

    private static String firstAvailableStatus(String preferred) {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == preferred) {
                return entry.getValue();
            }
        }
        return Lead.Status.getDescribe().getPicklistValues()[0].getValue();
    }

    private static String firstNonEarlyStatus() {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !isEarlyStatus(entry.getValue())) {
                return entry.getValue();
            }
        }
        System.assert(false, 'The org must have at least one non-early Lead Status value.');
        return null;
    }

    private static String alternateNonEarlyStatus(String currentStatus) {
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != currentStatus && !isEarlyStatus(entry.getValue())) {
                return entry.getValue();
            }
        }
        return currentStatus;
    }

    private static Boolean isEarlyStatus(String status) {
        return new Set<String>{
            'New',
            'Contact Attempt 1',
            'Contact Attempt 2',
            'Contact Attempt 3',
            'Contact Attempt 4',
            'Contact Attempt 5'
        }.contains(status);
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