@RestResource(urlMapping='/rc_transcription')
global without sharing class RingSenseWebhook {

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;

        String validationToken = req.headers?.get('Validation-Token');
        if (String.isNotBlank(validationToken)) {
            RestContext.response.addHeader('Validation-Token', validationToken);
            RestContext.response.addHeader('Content-Type', 'application/json');
        }

        RestContext.response.addHeader('Content-Type', 'application/json');

        String body = req.requestBody == null ? '' : req.requestBody.toString();

        if (String.isBlank(body)) {
            RestContext.response.responseBody = Blob.valueOf('{"status":"ok","detail":"empty"}');
            return;
        }

        CallInsightIngestionService.IngestResult result = CallInsightIngestionService.ingestFromRingSensePayload(body);
        if (result.success) {
            RestContext.response.responseBody = Blob.valueOf('{"status":"ok"}');
        } else {
            RestContext.response.responseBody = Blob.valueOf(
                '{"status":"error","message":"' + escapeJson(result.errorMessage == null ? 'ingest_failed' : result.errorMessage) + '"}'
            );
        }
    }

    private static String escapeJson(String raw) {
        if (raw == null) {
            return '';
        }
        return raw.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ').replace('\r', ' ');
    }
}