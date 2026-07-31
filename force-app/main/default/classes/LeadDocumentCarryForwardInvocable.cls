public with sharing class LeadDocumentCarryForwardInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String userMessage;
        @InvocableVariable public String errorCode;
        @InvocableVariable public String adminMessage;
        @InvocableVariable public List<Id> recordIdsAffected;
        @InvocableVariable public List<String> errors;
    }

    @InvocableMethod(
        label='Carry Forward Lead Document Requests'
        description='Converts Lead-stage document requests and uploaded files into Transaction conditions after Lead conversion.'
    )
    public static List<Result> carryForward(List<Request> requests) {
        Set<Id> leadIds = new Set<Id>();
        if (requests != null) {
            for (Request request : requests) {
                if (request != null && request.leadId != null) {
                    leadIds.add(request.leadId);
                }
            }
        }

        Result result = new Result();
        result.recordIdsAffected = new List<Id>(leadIds);
        result.errors = new List<String>();

        try {
            LeadDocumentCarryForwardService.carryForward(leadIds);
            result.success = true;
            result.userMessage = 'Lead document requests carried forward.';
            result.errorCode = null;
            result.adminMessage = null;
        } catch (Exception ex) {
            result.success = false;
            result.userMessage = 'Lead document requests could not be carried forward.';
            result.errorCode = 'LEAD_DOCUMENT_CARRY_FORWARD_FAILED';
            result.adminMessage = ex.getTypeName() + ': ' + ex.getMessage();
            result.errors.add(result.adminMessage);
        }

        return new List<Result>{ result };
    }
}