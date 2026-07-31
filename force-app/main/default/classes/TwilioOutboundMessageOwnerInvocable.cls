/**
 * Thin Flow adapter: reassigns outbound-api Twilio messages from Automated Process to Transaction editor.
 */
public with sharing class TwilioOutboundMessageOwnerInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id twilioMessageId;
    }

    public class Response {
        @InvocableVariable
        public Boolean success;
    }

    @InvocableMethod(
        label='Reassign Twilio Outbound Message Owner'
        description='When Automated Process owns an outbound-api message tied to a Transaction, set Owner to Transaction.LastModifiedById.'
    )
    public static List<Response> reassign(List<Request> requests) {
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
            TwilioMessageRelationshipService.reassignOutboundOwnerByMessageIds(ids);
        }
        for (Request req : requests) {
            Response r = new Response();
            r.success = req != null && req.twilioMessageId != null;
            out.add(r);
        }
        return out;
    }
}