@IsTest
private class RingCentralLogSMSTestCoverage {
    @IsTest
    static void resolveTaskRelationship_leadWins_andClearsWhatId() {
        String incomingPhone = '+1 (813) 555-2222';
        String normalized = RingCentralLeadPriorityMatcher.normalizePhoneNumber(incomingPhone);

        Id someLeadId = (Id) '00Q000000000000AAA';
        Id someContactId = (Id) '003000000000000AAA';
        Id someWhatId = (Id) 'a00000000000000AAA';

        Map<String, Id> leadMap = new Map<String, Id>{ normalized => someLeadId };
        Map<String, Id> contactMap = new Map<String, Id>{ normalized => someContactId };
        Map<String, Id> whatMap = new Map<String, Id>{ normalized => someWhatId };

        Map<String, Id> resolution = RingCentralLogSMS.resolveTaskRelationship(incomingPhone, leadMap, contactMap, whatMap);
        System.assertEquals(someLeadId, resolution.get('whoId'), 'Lead should be used for WhoId when open lead matches.');
        System.assertEquals(null, resolution.get('whatId'), 'WhatId must be null when lead is matched.');
    }

    @IsTest
    static void resolveTaskRelationship_fallbackToContactAndWhatId() {
        String incomingPhone = '+1 (813) 555-2222';
        String normalized = RingCentralLeadPriorityMatcher.normalizePhoneNumber(incomingPhone);

        Id someContactId = (Id) '003000000000000AAB';
        Id someWhatId = (Id) 'a00000000000000AAB';

        Map<String, Id> resolution = RingCentralLogSMS.resolveTaskRelationship(
            incomingPhone,
            new Map<String, Id>(),
            new Map<String, Id>{ normalized => someContactId },
            new Map<String, Id>{ normalized => someWhatId }
        );
        System.assertEquals(someContactId, resolution.get('whoId'));
        System.assertEquals(someWhatId, resolution.get('whatId'));
    }
}