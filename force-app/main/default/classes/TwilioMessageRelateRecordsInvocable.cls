/**
 * Thin Flow adapter: relates TwilioSF__Message__c to Account / Transaction.
 */
public with sharing class TwilioMessageRelateRecordsInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id twilioMessageId;
    }

    public class Response {
        @InvocableVariable
        public Boolean success;
    }

    @InvocableMethod(
        label='Relate Twilio Message To Transaction'
        description='Stamps Twilio SF parent / account / contact from Lead conversion or phone match.'
    )
    public static List<Response> relate(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        Set<Id> ids = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.twilioMessageId != null) {
                ids.add(req.twilioMessageId);
            }
        }
        if (!ids.isEmpty()) {
            TwilioMessageRelationshipService.relateByMessageIds(ids);
        }
        for (Request req : requests) {
            Response r = new Response();
            r.success = req != null && req.twilioMessageId != null;
            out.add(r);
        }
        return out;
    }
}