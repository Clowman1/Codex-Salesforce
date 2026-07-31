@IsTest
private class RingSenseWebhookTest {

    private static void prepRestContext(String body, Map<String, String> headers) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/rc_transcription';
        req.httpMethod = 'POST';
        req.requestBody = body == null ? null : Blob.valueOf(body);
        if (headers != null) {
            for (String k : headers.keySet()) {
                req.headers.put(k, headers.get(k));
            }
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void webhook_empty_body_returns_ok_empty() {
        prepRestContext('', null);
        Test.startTest();
        RingSenseWebhook.handleWebhook();
        Test.stopTest();
        String resp = RestContext.response.responseBody.toString();
        System.assert(resp.contains('"status":"ok"'), 'Expected ok for empty body, got: ' + resp);
        System.assert(resp.contains('"detail":"empty"'), 'Expected empty detail: ' + resp);
    }

    @IsTest
    static void webhook_validation_token_header_is_echoed() {
        prepRestContext('', new Map<String, String>{ 'Validation-Token' => 'abc-123' });
        Test.startTest();
        RingSenseWebhook.handleWebhook();
        Test.stopTest();
        System.assertEquals('abc-123', RestContext.response.headers.get('Validation-Token'));
        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
    }

    @IsTest
    static void webhook_invalid_json_returns_error_status() {
        prepRestContext('this is not json', null);
        Test.startTest();
        RingSenseWebhook.handleWebhook();
        Test.stopTest();
        String resp = RestContext.response.responseBody.toString();
        System.assert(resp.contains('"status":"error"'), 'Expected error status, got: ' + resp);
        System.assert(resp.contains('"message":'), 'Expected message field: ' + resp);
    }

    @IsTest
    static void webhook_missing_body_node_returns_error() {
        prepRestContext('{"eventType":"x"}', null);
        Test.startTest();
        RingSenseWebhook.handleWebhook();
        Test.stopTest();
        String resp = RestContext.response.responseBody.toString();
        System.assert(resp.contains('"status":"error"'), 'Expected error status, got: ' + resp);
    }

    @IsTest
    static void testWebhook() {
        // Sample JSON payload (shortened but valid)
        String jsonBody = '{' +
            '"body": {' +
                '"callDirection": "Outbound",' +
                '"ownerExtensionId": "63521941008",' +
                '"speakerInfo": [' +
                    '{"extensionId": "63521941008", "phoneNumber": "+13213042004"},' +
                    '{"extensionId": null, "phoneNumber": "+18135175526"}' +
                '],' +
                '"insights": {' +
                    '"Transcript": [{"text": "Hello"}],' +
                    '"Highlights": [{"value": "highlight"}],' +
                    '"Summary": [{"value": "summary"}],' +
                    '"NextSteps": [{"value": "next"}],' +
                    '"BulletedSummary": [{"value": "bullet"}],' +
                    '"AIScore": [{"value": "8"}]' +
                '}' +
            '}' +
        '}';

        // Simulate REST request
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/rc_transcription';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Integer before = [SELECT COUNT() FROM Call_Insight__c];

        RingSenseWebhook.handleWebhook();

        System.assertEquals(
            before + 1,
            [SELECT COUNT() FROM Call_Insight__c],
            'Expected one Call Insight inserted'
        );
        Call_Insight__c ci = [
            SELECT Recipient_Phone_Number__c, AI_Score__c
            FROM Call_Insight__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('+18135175526', ci.Recipient_Phone_Number__c);
        System.assertEquals(8, ci.AI_Score__c);
        System.assert(RestContext.response.responseBody != null);
    }
}