@IsTest
private class LeadStatusZapierWebhookServiceTest {
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
    static void sendsWebhookOnceWhenWebsiteLeadLeavesEarlyStatus() {
        String earlyStatus = activeStatus('New', null);
        String qualifyingStatus = activeStatus('Working', earlyContactStatuses());

        Lead leadRecord = new Lead(
            FirstName = 'Website',
            LastName = 'Status',
            Company = 'Reach Test',
            LeadSource = 'Website',
            Status = earlyStatus
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        mockCalls = 0;
        mockLastBody = null;
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        leadRecord.Status = qualifyingStatus;
        update leadRecord;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected one Zapier webhook callout.');
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mockLastBody);
        System.assertEquals('LeadStatusChanged', payload.get('eventType'));
        System.assertEquals('Website', payload.get('leadSource'));
        System.assertEquals(earlyStatus, payload.get('oldStatus'));
        System.assertEquals(qualifyingStatus, payload.get('newStatus'));
        System.assertEquals(String.valueOf(leadRecord.Id), String.valueOf(payload.get('leadId')));

        Lead reloadedLead = [
            SELECT Website_Status_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(true, reloadedLead.Website_Status_Webhook_Sent__c, 'Expected the one-time webhook sent flag to be set after a successful callout.');
    }

    @IsTest
    static void skipsWebsiteLeadWhenStatusDoesNotChange() {
        String earlyStatus = activeStatus('New', null);
        Lead leadRecord = new Lead(
            FirstName = 'Website',
            LastName = 'NoChange',
            Company = 'Reach Test',
            LeadSource = 'Website',
            Status = earlyStatus
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        LeadStatusZapierWebhookService.enqueuedJobCount = 0;

        Test.startTest();
        leadRecord.Email = 'nochange@example.com';
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, LeadStatusZapierWebhookService.enqueuedJobCount, 'Expected no webhook job when Status is unchanged.');
    }

    @IsTest
    static void skipsNonWebsiteLeadStatusChange() {
        String earlyStatus = activeStatus('New', null);
        String qualifyingStatus = activeStatus('Working', earlyContactStatuses());

        Lead leadRecord = new Lead(
            FirstName = 'Referral',
            LastName = 'Status',
            Company = 'Reach Test',
            LeadSource = 'Realtor Referral',
            Status = earlyStatus
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        LeadStatusZapierWebhookService.enqueuedJobCount = 0;

        Test.startTest();
        leadRecord.Status = qualifyingStatus;
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, LeadStatusZapierWebhookService.enqueuedJobCount, 'Expected no webhook job for non-eligible Lead Source.');
    }

    @IsTest
    static void sendsWebhookOnceWhenLinktreeLeadLeavesEarlyStatus() {
        String earlyStatus = activeStatus('New', null);
        String qualifyingStatus = activeStatus('Working', earlyContactStatuses());
        String laterStatus = activeStatus('Application', new Set<String>{ qualifyingStatus });
        String linktreeSource = activeLeadSource('Instagram-Linktree');

        Lead leadRecord = new Lead(
            FirstName = 'Linktree',
            LastName = 'Status',
            Company = 'Reach Test',
            LeadSource = linktreeSource,
            Status = earlyStatus
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        mockCalls = 0;
        mockLastBody = null;
        Test.setMock(HttpCalloutMock.class, new ZapierMock());

        Test.startTest();
        leadRecord.Status = qualifyingStatus;
        update leadRecord;
        leadRecord.Status = laterStatus;
        update leadRecord;
        Test.stopTest();

        System.assertEquals(1, mockCalls, 'Expected one Zapier webhook callout for a Linktree Lead Source.');
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mockLastBody);
        System.assertEquals(linktreeSource, payload.get('leadSource'));
        System.assertEquals(earlyStatus, payload.get('oldStatus'));
        System.assertEquals(qualifyingStatus, payload.get('newStatus'));

        Lead reloadedLead = [
            SELECT Website_Status_Webhook_Sent__c, Linktree_Status_Webhook_Sent__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(false, reloadedLead.Website_Status_Webhook_Sent__c, 'Expected the Website webhook flag to remain false for Linktree sources.');
        System.assertEquals(true, reloadedLead.Linktree_Status_Webhook_Sent__c, 'Expected the Linktree one-time webhook sent flag to be set for Linktree sources.');
    }

    @IsTest
    static void skipsLinktreeLeadAfterWebhookAlreadySent() {
        String earlyStatus = activeStatus('New', null);
        String qualifyingStatus = activeStatus('Working', earlyContactStatuses());
        String linktreeSource = activeLeadSource('Facebook-Linktree');

        Lead leadRecord = new Lead(
            FirstName = 'Linktree',
            LastName = 'AlreadySent',
            Company = 'Reach Test',
            LeadSource = linktreeSource,
            Status = earlyStatus,
            Linktree_Status_Webhook_Sent__c = true
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        LeadStatusZapierWebhookService.enqueuedJobCount = 0;

        Test.startTest();
        leadRecord.Status = qualifyingStatus;
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, LeadStatusZapierWebhookService.enqueuedJobCount, 'Expected no webhook jobs after the Linktree one-time sent flag is already set.');
    }

    @IsTest
    static void skipsWebsiteLeadWhileStillInEarlyStatuses() {
        String earlyStatus = activeStatus('New', null);
        String nextEarlyStatus = activeStatus('Contact Attempt 1', new Set<String>{ earlyStatus });

        Lead leadRecord = new Lead(
            FirstName = 'Website',
            LastName = 'EarlyOnly',
            Company = 'Reach Test',
            LeadSource = 'Website',
            Status = earlyStatus
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        LeadStatusZapierWebhookService.enqueuedJobCount = 0;

        Test.startTest();
        leadRecord.Status = nextEarlyStatus;
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, LeadStatusZapierWebhookService.enqueuedJobCount, 'Expected no webhook job while the Website lead remains in early contact statuses.');
    }

    @IsTest
    static void skipsWebsiteLeadAfterWebhookAlreadySent() {
        String earlyStatus = activeStatus('New', null);
        String qualifyingStatus = activeStatus('Working', earlyContactStatuses());
        String laterStatus = activeStatus('Application', new Set<String>{ qualifyingStatus });

        Lead leadRecord = new Lead(
            FirstName = 'Website',
            LastName = 'AlreadySent',
            Company = 'Reach Test',
            LeadSource = 'Website',
            Status = earlyStatus,
            Website_Status_Webhook_Sent__c = true
        );
        insert leadRecord;

        LeadStatusZapierWebhookService.endpointOverride = 'https://hooks.zapier.com/test';
        LeadStatusZapierWebhookService.enqueuedJobCount = 0;

        Test.startTest();
        leadRecord.Status = qualifyingStatus;
        update leadRecord;
        leadRecord.Status = laterStatus;
        update leadRecord;
        Test.stopTest();

        System.assertEquals(0, LeadStatusZapierWebhookService.enqueuedJobCount, 'Expected no webhook jobs after the one-time sent flag is already set.');
    }

    private static Set<String> earlyContactStatuses() {
        return new Set<String>{
            'New',
            'Contact Attempt 1',
            'Contact Attempt 2',
            'Contact Attempt 3',
            'Contact Attempt 4',
            'Contact Attempt 5'
        };
    }

    private static String activeStatus(String preferredStatus, Set<String> disallowedStatuses) {
        Set<String> disallowed = disallowedStatuses == null ? new Set<String>() : disallowedStatuses;
        String firstAllowedStatus;
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String statusValue = entry.getValue();
            if (statusValue == preferredStatus && !disallowed.contains(statusValue)) {
                return statusValue;
            }
            if (firstAllowedStatus == null && !disallowed.contains(statusValue)) {
                firstAllowedStatus = statusValue;
            }
        }
        System.assertNotEquals(null, firstAllowedStatus, 'Expected an active Lead Status outside of the disallowed set.');
        return firstAllowedStatus;
    }

    private static String activeLeadSource(String preferredSource) {
        for (Schema.PicklistEntry entry : Lead.LeadSource.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == preferredSource) {
                return entry.getValue();
            }
        }
        System.assert(false, 'Expected active Lead Source value: ' + preferredSource);
        return null;
    }
}