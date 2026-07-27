public with sharing class LeadDocRequestCreateInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;

        @InvocableVariable
        public List<Id> referenceIds;

        @InvocableVariable
        public List<Lead_Document_Request_Reference__c> references;

        @InvocableVariable
        public String name;

        @InvocableVariable
        public String subject;

        @InvocableVariable
        public String description;

        @InvocableVariable
        public String category;

        @InvocableVariable
        public String type;

        @InvocableVariable
        public Boolean includeInEmail;

        @InvocableVariable
        public Boolean canBorrowerSee;
    }

    public class Response {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String userMessage;

        @InvocableVariable
        public String errorCode;

        @InvocableVariable
        public String adminMessage;

        @InvocableVariable
        public List<Id> recordIdsAffected;
    }

    @InvocableMethod(label='Create Lead Document Requests From References')
    public static List<Response> createRequests(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) {
            return responses;
        }

        for (Request request : requests) {
            Response response = new Response();
            response.recordIdsAffected = new List<Id>();
            try {
                List<LeadDocumentRequestService.RequestItem> savedRequests = hasReferenceSelection(request)
                    ? LeadDocumentRequestService.createRequestsFromReferences(
                        request.leadId,
                        collectReferenceIds(request),
                        request.type
                    )
                    : LeadDocumentRequestService.saveRequests(
                        request == null ? null : request.leadId,
                        new List<LeadDocumentRequestService.RequestInput>{ buildManualInput(request) }
                    );
                for (LeadDocumentRequestService.RequestItem savedRequest : savedRequests) {
                    response.recordIdsAffected.add(savedRequest.id);
                }
                response.success = true;
                response.userMessage = 'Lead document requests were created.';
            } catch (Exception ex) {
                response.success = false;
                response.userMessage = ex.getMessage();
                response.errorCode = 'LEAD_DOCUMENT_REFERENCE_CREATE_FAILED';
                response.adminMessage = ex.getTypeName() + ': ' + ex.getMessage();
            }
            responses.add(response);
        }
        return responses;
    }

    private static List<Id> collectReferenceIds(Request request) {
        Set<Id> referenceIds = new Set<Id>();
        if (request == null) {
            return new List<Id>();
        }
        if (request.referenceIds != null) {
            referenceIds.addAll(request.referenceIds);
        }
        if (request.references != null) {
            for (Lead_Document_Request_Reference__c referenceRecord : request.references) {
                if (referenceRecord != null && referenceRecord.Id != null) {
                    referenceIds.add(referenceRecord.Id);
                }
            }
        }
        return new List<Id>(referenceIds);
    }

    private static Boolean hasReferenceSelection(Request request) {
        return request != null
            && ((request.referenceIds != null && !request.referenceIds.isEmpty())
                || (request.references != null && !request.references.isEmpty()));
    }

    private static LeadDocumentRequestService.RequestInput buildManualInput(Request request) {
        LeadDocumentRequestService.RequestInput input = new LeadDocumentRequestService.RequestInput();
        if (request == null) {
            return input;
        }
        input.name = request.name;
        input.subject = String.isBlank(request.subject) ? request.name : request.subject;
        input.description = request.description;
        input.category = request.category;
        input.type = String.isBlank(request.type) ? 'Processor' : request.type;
        input.includeInEmail = request.includeInEmail == null ? true : request.includeInEmail;
        input.canBorrowerSee = request.canBorrowerSee == null ? true : request.canBorrowerSee;
        return input;
    }
}