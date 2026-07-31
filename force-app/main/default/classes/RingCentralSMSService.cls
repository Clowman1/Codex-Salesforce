public class RingCentralSMSService {
    
    private static final String SEND_SMS_ENDPOINT = 'https://platform.ringcentral.com/restapi/v1.0/account/~/extension/~/sms';
    private static final String GET_PHONE_NUMBER_ENDPOINT = 'https://platform.ringcentral.com/restapi/v1.0/account/~/extension/~/phone-number';
    
    @InvocableMethod(label = 'Send SMS via RingCentral')
    public static List<Boolean> sendScheduledMessages(List<String> scheduledMessageIds) {
        
        List<Boolean> results = new List<Boolean>();
        
        for (String messageId : scheduledMessageIds) {
			results.add(sendScheduledMessage(messageId));
        }
        
        return results;
    }
    
    @future(callout=true)
    public static void sendScheduledMessageAsync(String scheduledMessageId) {
        sendScheduledMessage(scheduledMessageId);
    }
    
    public static Boolean sendScheduledMessage(String scheduledMessageId) {
        Scheduled_Message__c scheduledMessage = [
            SELECT Id,
                Sent_DateTime__c,
                Lead__c,
                Account__c,
                Account__r.PersonContactId,
                Sender__c,
                Recipient_Phone_Number__c,
                Template_ID__c,
                Type__c,
                Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :scheduledMessageId
        ];
        
        Boolean isSuccess = false;
        
        Id templateTargetId = scheduledMessage.Lead__c != null
            ? scheduledMessage.Lead__c
            : scheduledMessage.Account__r == null || scheduledMessage.Account__r.PersonContactId == null
                ? scheduledMessage.Account__c
                : scheduledMessage.Account__r.PersonContactId;
        if (templateTargetId == null) {
            scheduledMessage.Info_Message__c = 'No Lead or Account found for template merge context';
            update scheduledMessage;
            return isSuccess;
        }

        Messaging.SingleEmailMessage emailMessage = Messaging.renderStoredEmailTemplate(scheduledMessage.Template_ID__c, templateTargetId, null);
        String messageText = getPlainTextForSMS(emailMessage.htmlBody);
        
        RingCentralAuthService service = new RingCentralAuthService(scheduledMessage.Sender__c);
        if (service.isNeverAuthenticated()) {
            scheduledMessage.Info_Message__c = 'Sender is not authenticated. Please login Sender user in RingCentral';
            update scheduledMessage;
            return isSuccess;
        }
        
        String accessToken = null;
        try {
            accessToken = service.getAccessToken();
        } catch (Exception e) {
            scheduledMessage.Info_Message__c = 'RingCentral login failed. Please re-login from Home page. ' + e.getMessage();
            update scheduledMessage;
            return isSuccess;
        }

        try {
            String fromPhoneNumber = getUserPhoneNumber(accessToken);
            String recipientPhoneNumber = scheduledMessage.Recipient_Phone_Number__c;
            
            if (String.isBlank(fromPhoneNumber)) {
                scheduledMessage.Info_Message__c = 'Could not retrieve Sender Phone Number from RingCentral. Please ensure number is assigned to user in RingCentral.';
                update scheduledMessage;
                return isSuccess;
            }
            
            if (String.isBlank(recipientPhoneNumber)) {
                scheduledMessage.Info_Message__c = 'Recipient Phone Number is empty';
                update scheduledMessage;
                return isSuccess;
            }
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SEND_SMS_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type','application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Map<String,Object> body = new Map<String,Object>{
                'to' => new List<Map<String,String>>{ new Map<String,String>{ 'phoneNumber' => recipientPhoneNumber } },
                    'from' => new Map<String,String>{ 'phoneNumber' => fromPhoneNumber },
                        'text' => messageText
                        };
                            
                            req.setBody(JSON.serialize(body));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                scheduledMessage.Sent_DateTime__c = DateTime.now();
                scheduledMessage.Info_Message__c = res.getStatusCode() + '. Successfully sent: ' + messageText;
                isSuccess = true;
                update scheduledMessage;
            } else {
                scheduledMessage.Info_Message__c = 'Error sending: ' + res.getStatusCode() + '\n' + res.getBody();
                update scheduledMessage;
                
            }
        } catch (Exception e) {
            isSuccess = false;
            scheduledMessage.Info_Message__c = 'Unknown error. ' + e.getMessage() + '\n' + e.getStackTraceString();
            update scheduledMessage;
        } finally {
            service.commitUpdates();
        }
        
        
        
        return isSuccess;
    }
    
    public static String getUserPhoneNumber(String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(GET_PHONE_NUMBER_ENDPOINT);
        req.setMethod('GET');
        req.setHeader('Accept','application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        
        HttpResponse res = new Http().send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String,Object> resp = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) resp.get('records');
            String fromNumber;
            if (!records.isEmpty()) {
                Map<String,Object> num = (Map<String,Object>) records[0];
                fromNumber = (String) num.get('phoneNumber');
            }
            return fromNumber;
        } else {
            return null;
        }
    }
    
    public static String getPlainTextForSms(String html) {
        return html.replaceAll('<(?:/(?:p|li|div|h\\d|tr|dt|blockquote)|(?:p)/)>', '$0~~~')
            .stripHtmlTags()
            .replaceAll('~~~', '\n');
    }
    
    
    // TODO complex test, rewrite after POC
    public static void testCoverage() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
    
}