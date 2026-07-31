@IsTest
private class CallInsightIngestionServiceTest {
    @IsTest
    static void ingest_without_insights_creates_call_insight() {
        String jsonBody =
            '{' +
            '"body": {' +
            '"callDirection": "Inbound",' +
            '"ownerExtensionId": "63521941008",' +
            '"recordingStartTime": "2026-04-21T15:30:00.000Z",' +
            '"recordingDurationMs": 90000' +
            '}' +
            '}';

        Test.startTest();
        CallInsightIngestionService.IngestResult r = CallInsightIngestionService.ingestFromRingSensePayload(jsonBody);
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertNotEquals(null, r.callInsightId);

        Call_Insight__c ci = [
            SELECT Id, Direction__c, Recording_Start_DateTime__c, Duration__c, Transcript__c, Summary__c
            FROM Call_Insight__c
            WHERE Id = :r.callInsightId
        ];
        System.assertEquals('Inbound', ci.Direction__c);
        System.assertEquals(null, ci.Transcript__c);
        System.assertEquals(null, ci.Summary__c);
        System.assertEquals('1m 30s', ci.Duration__c);
    }

    @IsTest
    static void ingest_sets_recipient_from_speaker_list() {
        String jsonBody =
            '{' +
            '"body": {' +
            '"callDirection": "Outbound",' +
            '"ownerExtensionId": "63521941008",' +
            '"speakerInfo": [' +
            '{"extensionId": "63521941008", "phoneNumber": "+13213042004"},' +
            '{"extensionId": null, "phoneNumber": "+18135175526"}' +
            '],' +
            '"insights": {"Transcript": [{"text": "Hi"}]}' +
            '}' +
            '}';

        CallInsightIngestionService.IngestResult r = CallInsightIngestionService.ingestFromRingSensePayload(jsonBody);
        System.assertEquals(true, r.success);

        Call_Insight__c ci = [SELECT Recipient_Phone_Number__c FROM Call_Insight__c WHERE Id = :r.callInsightId];
        System.assertEquals('+18135175526', ci.Recipient_Phone_Number__c);
    }

    @IsTest
    static void format_duration_ms_formats_correctly() {
        System.assertEquals(null, CallInsightIngestionService.formatDurationMs(null));
        System.assertEquals('0s', CallInsightIngestionService.formatDurationMs(0L));
        System.assertEquals('45s', CallInsightIngestionService.formatDurationMs(45000L));
        System.assertEquals('2m 15s', CallInsightIngestionService.formatDurationMs(135000L));
        System.assertEquals('1h 0m 0s', CallInsightIngestionService.formatDurationMs(3600000L));
        System.assertEquals('1h 30m 15s', CallInsightIngestionService.formatDurationMs(5415000L));
    }

    @IsTest
    static void ingest_with_empty_body_returns_error_and_logs() {
        Test.startTest();
        CallInsightIngestionService.IngestResult r = CallInsightIngestionService.ingestFromRingSensePayload('');
        Test.stopTest();
        System.assertEquals(false, r.success);
        System.assertEquals('Empty body', r.errorMessage);
        List<Custom_Log__c> logs = [SELECT Id, Source__c FROM Custom_Log__c WHERE Source__c = 'RingSense Webhook'];
        System.assertEquals(1, logs.size(), 'Expected Custom_Log__c written for empty body');
    }

    @IsTest
    static void ingest_with_missing_body_node_returns_error_and_logs() {
        Test.startTest();
        CallInsightIngestionService.IngestResult r =
            CallInsightIngestionService.ingestFromRingSensePayload('{"eventType":"x"}');
        Test.stopTest();
        System.assertEquals(false, r.success);
        System.assert(r.errorMessage.contains('Missing body node'), r.errorMessage);
        List<Custom_Log__c> logs = [SELECT Id FROM Custom_Log__c WHERE Source__c = 'RingSense Webhook'];
        System.assertEquals(1, logs.size(), 'Expected Custom_Log__c written for missing body node');
    }

    @IsTest
    static void ingest_with_malformed_json_catches_and_logs_error() {
        Test.startTest();
        CallInsightIngestionService.IngestResult r =
            CallInsightIngestionService.ingestFromRingSensePayload('not json at all');
        Test.stopTest();
        System.assertEquals(false, r.success);
        System.assertNotEquals(null, r.errorMessage);
        List<Custom_Log__c> logs = [SELECT Id, Data__c FROM Custom_Log__c WHERE Source__c = 'RingSense Webhook Error'];
        System.assertEquals(1, logs.size(), 'Expected Custom_Log__c written for thrown exception');
    }

    @IsTest
    static void ingest_phone_redaction_in_log_masks_digits() {
        // Force the `Missing body node` branch with a phone in the raw body to exercise redactForLog.
        Test.startTest();
        CallInsightIngestionService.ingestFromRingSensePayload('{"eventType":"x","phone":"+18135550001"}');
        Test.stopTest();
        Custom_Log__c log = [SELECT Data__c FROM Custom_Log__c WHERE Source__c = 'RingSense Webhook' LIMIT 1];
        System.assert(log.Data__c != null && log.Data__c.contains('[phone-redacted]'),
            'Expected redaction of phone in log payload, got: ' + log.Data__c);
    }

    @IsTest
    static void ingest_recipient_when_owner_phone_same_as_recipient_picks_non_owner() {
        // Owner extension speaker + a non-identified speaker sharing owner's phone digits should still
        // skip to the next distinct phone, exercising the normalizePhoneDigits fallback.
        String jsonBody =
            '{' +
            '"body": {' +
            '"callDirection": "Outbound",' +
            '"ownerExtensionId": "55510",' +
            '"speakerInfo": [' +
            '{"extensionId": "55510", "phoneNumber": "+14155550001"},' +
            '{"extensionId": null, "phoneNumber": "+14155550001"},' +
            '{"extensionId": null, "phoneNumber": "+18135550002"}' +
            ']' +
            '}' +
            '}';
        CallInsightIngestionService.IngestResult r = CallInsightIngestionService.ingestFromRingSensePayload(jsonBody);
        System.assertEquals(true, r.success);
        Call_Insight__c ci = [SELECT Recipient_Phone_Number__c FROM Call_Insight__c WHERE Id = :r.callInsightId];
        System.assertEquals('+18135550002', ci.Recipient_Phone_Number__c,
            'Expected to skip speaker that shares owner phone digits');
    }

    @IsTest
    static void ingest_with_recording_start_and_bad_duration_is_resilient() {
        // Valid recordingStartTime + non-numeric recordingDurationMs should still insert thanks to applyRecordingFields catch.
        String jsonBody =
            '{' +
            '"body": {' +
            '"callDirection": "Inbound",' +
            '"ownerExtensionId": "55510",' +
            '"recordingStartTime": "2026-04-21T15:30:00.000Z",' +
            '"recordingDurationMs": "not-a-number"' +
            '}' +
            '}';
        CallInsightIngestionService.IngestResult r = CallInsightIngestionService.ingestFromRingSensePayload(jsonBody);
        System.assertEquals(true, r.success, 'applyRecordingFields catch should swallow bad duration');
        Call_Insight__c ci = [
            SELECT Recording_Start_DateTime__c, Duration__c FROM Call_Insight__c WHERE Id = :r.callInsightId
        ];
        System.assertNotEquals(null, ci.Recording_Start_DateTime__c);
        System.assertEquals(null, ci.Duration__c);
    }
}