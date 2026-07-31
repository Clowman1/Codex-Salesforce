/**
 * Ingests RingSense webhook payloads into Call_Insight__c.
 * DML for Call_Insight__c and integration logs lives here (webhook stays thin).
 */
public without sharing class CallInsightIngestionService {

    public class IngestResult {
        public Id callInsightId;
        public Boolean success;
        public String errorMessage;
    }

    /**
     * Parses RingSense JSON, builds Call_Insight__c, inserts. Never throws to caller for expected parse gaps;
     * returns result with success=false and logs.
     */
    public static IngestResult ingestFromRingSensePayload(String body) {
        IngestResult result = new IngestResult();
        result.success = false;

        if (String.isBlank(body)) {
            result.errorMessage = 'Empty body';
            insertLogSafe('RingSense Webhook', 'Empty body', null);
            return result;
        }

        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            Map<String, Object> bodyData = (Map<String, Object>) payload.get('body');
            if (bodyData == null) {
                result.errorMessage = 'Missing body node';
                insertLogSafe('RingSense Webhook', 'Missing body node in payload', redactForLog(body));
                return result;
            }

            String callTitle = (String) bodyData.get('title');
            String callDirection = (String) bodyData.get('callDirection');
            String ownerExtensionId = (String) bodyData.get('ownerExtensionId');
            List<Object> speakerList = (List<Object>) bodyData.get('speakerInfo');
            Map<String, Object> insights = (Map<String, Object>) bodyData.get('insights');

            String recipientPhone = resolveRecipientPhone(speakerList, ownerExtensionId);

            String transcript;
            String highlights;
            String summary;
            String nextSteps;
            String bulletedSummary;
            Decimal aiScore = null;

            if (insights != null) {
                transcript = joinInsightTexts((List<Object>) insights.get('Transcript'), 'text');
                highlights = joinInsightTexts((List<Object>) insights.get('Highlights'), 'value');
                summary = joinInsightTexts((List<Object>) insights.get('Summary'), 'value');
                nextSteps = joinInsightTexts((List<Object>) insights.get('NextSteps'), 'value');
                bulletedSummary = joinInsightTexts((List<Object>) insights.get('BulletedSummary'), 'value');

                List<Object> aiList = (List<Object>) insights.get('AIScore');
                if (aiList != null && !aiList.isEmpty()) {
                    Map<String, Object> ai = (Map<String, Object>) aiList[0];
                    if (ai.get('value') != null) {
                        aiScore = Decimal.valueOf(String.valueOf(ai.get('value')));
                    }
                }
            }

            SObject log = Schema.getGlobalDescribe().get('Call_Insight__c').newSObject();
            log.put('Title__c', callTitle);
            log.put('Salesforce_User_Extension_Id__c', ownerExtensionId);
            log.put('Recipient_Phone_Number__c', recipientPhone);
            log.put('Direction__c', callDirection);
            log.put('Transcript__c', transcript);
            log.put('HighLights__c', highlights);
            log.put('Summary__c', summary);
            log.put('Next_Steps__c', nextSteps);
            log.put('Bulleted_Summary__c', bulletedSummary);
            if (aiScore != null) {
                log.put('AI_Score__c', aiScore);
            }

            applyRecordingFields(bodyData, log);

            insert log;
            result.callInsightId = log.Id;
            result.success = true;
            return result;
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            insertLogSafe(
                'RingSense Webhook Error',
                e.getTypeName() + ': ' + e.getMessage() + ' | ' + e.getStackTraceString(),
                redactForLog(body)
            );
            return result;
        }
    }

    private static void applyRecordingFields(Map<String, Object> bodyData, SObject log) {
        try {
            String recordingStartTime = (String) bodyData.get('recordingStartTime');
            if (!String.isBlank(recordingStartTime)) {
                recordingStartTime = recordingStartTime.replace('Z', '');
                recordingStartTime = recordingStartTime.replace('T', ' ');
                Datetime recordingStartTimeDt = Datetime.valueOfGmt(recordingStartTime);
                log.put('Recording_Start_DateTime__c', recordingStartTimeDt);
            }
            Object durObj = bodyData.get('recordingDurationMs');
            if (durObj != null) {
                Long recordingDurationMs = Long.valueOf(String.valueOf(durObj));
                log.put('Duration__c', formatDurationMs(recordingDurationMs));
            }
        } catch (Exception ignore) {
            // optional fields
        }
    }

    /**
     * Resolves external party phone: prefer non-owner extension; else first phone distinct from owner's phone.
     */
    @TestVisible
    private static String resolveRecipientPhone(List<Object> speakerList, String ownerExtensionId) {
        if (speakerList == null || speakerList.isEmpty()) {
            return null;
        }

        String ownerPhoneNorm = null;
        for (Object sp : speakerList) {
            Map<String, Object> s = (Map<String, Object>) sp;
            Object extId = s.get('extensionId');
            String phone = (String) s.get('phoneNumber');
            if (String.isBlank(phone)) {
                continue;
            }
            if (ownerExtensionId != null && extId != null && String.valueOf(extId).equals(ownerExtensionId)) {
                ownerPhoneNorm = normalizePhoneDigits(phone);
                break;
            }
        }

        for (Object sp : speakerList) {
            Map<String, Object> s = (Map<String, Object>) sp;
            Object extId = s.get('extensionId');
            String phone = (String) s.get('phoneNumber');
            if (String.isBlank(phone)) {
                continue;
            }
            if (ownerExtensionId != null && extId != null && String.valueOf(extId).equals(ownerExtensionId)) {
                continue;
            }
            if (ownerExtensionId != null && extId == null) {
                String norm = normalizePhoneDigits(phone);
                if (ownerPhoneNorm != null && norm != null && norm.equals(ownerPhoneNorm)) {
                    continue;
                }
            }
            return phone;
        }

        for (Object sp : speakerList) {
            Map<String, Object> s = (Map<String, Object>) sp;
            String phone = (String) s.get('phoneNumber');
            if (!String.isBlank(phone)) {
                return phone;
            }
        }
        return null;
    }

    private static String normalizePhoneDigits(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        return phone.replaceAll('[^0-9]', '');
    }

    public static String formatDurationMs(Long ms) {
        if (ms == null) {
            return null;
        }
        Long totalSeconds = ms / 1000;
        Long hours = totalSeconds / 3600;
        Long minutes = Math.mod(totalSeconds, 3600) / 60;
        Long seconds = Math.mod(totalSeconds, 60);

        List<String> parts = new List<String>();
        if (hours > 0) {
            parts.add(hours + 'h');
            parts.add(minutes + 'm');
        } else if (minutes > 0) {
            parts.add(minutes + 'm');
        }
        parts.add(seconds + 's');
        return String.join(parts, ' ');
    }

    private static String joinInsightTexts(List<Object> lst, String fieldName) {
        if (lst == null || lst.isEmpty()) {
            return null;
        }

        List<String> formattedLines = new List<String>();
        for (Object obj : lst) {
            Map<String, Object> entry = (Map<String, Object>) obj;
            if (entry.containsKey(fieldName) && entry.get(fieldName) != null) {
                String line = String.valueOf(entry.get(fieldName)).escapeHtml4().trim();
                if (!String.isBlank(line)) {
                    formattedLines.add('&#8226; ' + line);
                }
            }
        }
        if (formattedLines.isEmpty()) {
            return null;
        }
        return String.join(formattedLines, '<br/>');
    }

    private static String redactForLog(String body) {
        if (String.isBlank(body)) {
            return body;
        }
        if (body.length() > 32000) {
            body = body.substring(0, 32000) + '...[truncated]';
        }
        return body.replaceAll('(\\+?1?\\d{10,})', '[phone-redacted]');
    }

    private static void insertLogSafe(String source, String data, String optionalBody) {
        try {
            String payload = data;
            if (!String.isBlank(optionalBody)) {
                payload = (payload == null ? '' : payload + ' | ') + optionalBody;
            }
            if (payload != null && payload.length() > 131072) {
                payload = payload.substring(0, 131000) + '...[truncated]';
            }
            insert new Custom_Log__c(Source__c = source, Data__c = payload);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CallInsightIngestionService: failed to insert Custom_Log__c: ' + e.getMessage());
        }
    }
}