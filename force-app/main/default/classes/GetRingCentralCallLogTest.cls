@IsTest
private class GetRingCentralCallLogTest {
    private class RingCentralCallLogMock implements HttpCalloutMock {
        private final String callDirection;
        private final String ownerExtensionId;
        private final String otherPartyPhone;

        RingCentralCallLogMock(String callDirection, String ownerExtensionId, String otherPartyPhone) {
            this.callDirection = callDirection;
            this.ownerExtensionId = ownerExtensionId;
            this.otherPartyPhone = otherPartyPhone;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint != null && endpoint.contains('/restapi/oauth/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"ACCESS_TOKEN","token_type":"bearer"}');
                return res;
            }

            if (endpoint != null && endpoint.contains('/restapi/v1.0/account/~/call-log')) {
                res.setStatusCode(200);

                // IMPORTANT: response uses "from" because RingCentralApi consumer replaces "from" -> "fromObj"
                // before deserialization.
                String body =
                    '{' +
                        '"records":[' +
                            '{' +
                                '"id":"rc-record-1",' +
                                '"result":"Accepted",' +
                                '"direction":"' + callDirection + '",' +
                                '"startTime":"2026-02-01T00:00:00.000Z",' +
                                '"to":{' +
                                    '"phoneNumber":"+1 (813) 555-0000",' +
                                    '"name":"SF User",' +
                                    '"extensionId":"' + ownerExtensionId + '"' +
                                '},' +
                                '"from":{' +
                                    '"phoneNumber":"' + otherPartyPhone + '",' +
                                    '"name":"Borrower",' +
                                    '"extensionId":"999"' +
                                '}' +
                            '}' +
                        '],' +
                        '"navigation":{}' +
                    '}';

                res.setBody(body);
                return res;
            }

            res.setStatusCode(404);
            res.setBody('{"error":"unexpected endpoint"}');
            return res;
        }
    }

    private static String pickNonCancelledStatus() {
        Set<String> disallowed = new Set<String>{ 'Cancelled', 'Suspended' };
        for (Schema.PicklistEntry pe : Transaction__c.Status__c.getDescribe().getPicklistValues()) {
            if (pe.isActive() && !disallowed.contains(pe.getValue())) {
                return pe.getValue();
            }
        }
        return 'Active';
    }

    @IsTest
    static void createTaskFromCallRecord_returnsNull_whenUserCannotBeResolved() {
        RingCentralApi_Models.Records rec = new RingCentralApi_Models.Records();
        rec.id = 'rc-record-1';
        rec.direction = 'Inbound';
        rec.to = new RingCentralApi_Models.To();
        rec.to.extensionId = null; // forces getUserIdFromCallRecord() => null
        rec.to.phoneNumber = '+1 (813) 555-1111';
        rec.to.name = 'RC User';
        rec.fromObj = new RingCentralApi_Models.FromObj();
        rec.fromObj.phoneNumber = '+1 (813) 555-2222';
        rec.fromObj.name = 'Borrower';

        Task taskRow = GetRingCentralCallLog.createTaskFromCallRecord(
            rec,
            new Map<String, User>(),
            new Map<String, Id>(),
            new Map<String, Id>(),
            new Map<String, Id>()
        );

        System.assertEquals(null, taskRow, 'When SF user cannot be resolved, we must skip Task creation.');
    }

    @IsTest
    static void createTaskFromCallRecord_returnsNull_andCoversOutboundLogMissingUser() {
        RingCentralApi_Models.Records rec = new RingCentralApi_Models.Records();
        rec.id = 'rc-record-2';
        rec.direction = 'Outbound';
        rec.to = new RingCentralApi_Models.To();
        rec.to.phoneNumber = '+1 (813) 555-1111';
        rec.to.name = 'Borrower';
        rec.fromObj = new RingCentralApi_Models.FromObj();
        rec.fromObj.extensionId = ''; // blank forces getUserIdFromCallRecord() => null
        rec.fromObj.phoneNumber = '+1 (813) 555-9999';
        rec.fromObj.name = 'RC User';

        Task taskRow = GetRingCentralCallLog.createTaskFromCallRecord(
            rec,
            new Map<String, User>(),
            new Map<String, Id>(),
            new Map<String, Id>(),
            new Map<String, Id>()
        );

        System.assertEquals(null, taskRow);
    }

    @IsTest
    static void createTasksForUser_endToEnd_leadPriority_setsWhoId_andClearsWhatId() {
        // Setup: an open lead (lead must win and clear WhatId)
        String otherPartyPhone = '+1 (813) 555-2222';
        Lead leadRow = new Lead(FirstName = 'Test', LastName = 'Lead', MobilePhone = '8135552222');
        insert leadRow;

        // User mapping: we don't need to insert a real User record for this path
        // because createTasksForUser uses the passed map only.
        String extId = '101';
        Id fakeUserId = (Id) '005000000000000AAA';
        User fakeUser = new User(Id = fakeUserId, Phone = '8135550000', Rc_Extension_Id__c = extId);
        Map<String, User> usersMap = new Map<String, User>{ extId => fakeUser };

        Test.setMock(HttpCalloutMock.class, new RingCentralCallLogMock('Inbound', extId, otherPartyPhone));

        Test.startTest();
        List<Task> tasks = GetRingCentralCallLog.createTasksForUser(usersMap, null, '2026-02-01T00:00:00.000Z', 'DUMMY_JWT');
        Test.stopTest();

        System.assertEquals(1, tasks.size(), 'Expected one Task from mocked call log response.');
        Task t = tasks[0];

        System.assertEquals('rc-record-1', t.rcsfl__CALL_UNIQUE_ID__c);
        System.assertEquals(fakeUserId, t.OwnerId, 'Owner must be the resolved SF user.');

        // Requirement: when open Lead matches, WhoId = Lead and WhatId = null
        System.assertEquals(leadRow.Id, t.WhoId, 'Lead must be related when open lead matches by phone.');
        System.assertEquals(null, t.WhatId, 'WhatId must be cleared when lead is matched.');

        System.assertEquals('Completed', t.Status);
        System.assertEquals('Call', t.InteractionType__c);
    }
}