public with sharing class LeadDocumentRequestReferenceInvocable {
    public class QueryRequest {
        @InvocableVariable
        public String referenceType;

        @InvocableVariable
        public String loanType;

        @InvocableVariable
        public String loanPurpose;

        @InvocableVariable
        public String employmentType;

        @InvocableVariable
        public String selfEmploymentType;
    }

    public class QueryResponse {
        @InvocableVariable
        public List<Lead_Document_Request_Reference__c> references;
    }

    @InvocableMethod(label='Get Lead Document Request References')
    public static List<QueryResponse> getReferences(List<QueryRequest> requests) {
        Set<String> referenceTypes = new Set<String>();
        if (requests != null) {
            for (QueryRequest request : requests) {
                if (request != null && String.isNotBlank(request.referenceType)) {
                    for (String referenceType : request.referenceType.split(';')) {
                        if (String.isNotBlank(referenceType)) {
                            referenceTypes.add(referenceType.trim());
                        }
                    }
                }
            }
        }

        List<Lead_Document_Request_Reference__c> references = referenceTypes.isEmpty()
            ? LeadDocumentRequestReferenceRepository.getInstance().selectActiveReferences()
            : LeadDocumentRequestReferenceRepository.getInstance().selectActiveByTypes(referenceTypes);

        QueryResponse response = new QueryResponse();
        response.references = filterReferences(requests, references);
        return new List<QueryResponse>{ response };
    }

    private static List<Lead_Document_Request_Reference__c> filterReferences(
        List<QueryRequest> requests,
        List<Lead_Document_Request_Reference__c> references
    ) {
        if (requests == null || requests.isEmpty()) {
            return references;
        }
        QueryRequest request = requests[0];
        List<Lead_Document_Request_Reference__c> matchingReferences = new List<Lead_Document_Request_Reference__c>();
        for (Lead_Document_Request_Reference__c referenceRecord : references) {
            if (matches(request, referenceRecord)) {
                matchingReferences.add(referenceRecord);
            }
        }
        return matchingReferences;
    }

    private static Boolean matches(QueryRequest request, Lead_Document_Request_Reference__c referenceRecord) {
        if (request == null) {
            return true;
        }
        if (!matchesMultiPicklist(referenceRecord.Loan_Purpose__c, request.loanPurpose)) {
            return false;
        }
        if (!matchesMultiPicklist(referenceRecord.Loan_Type__c, request.loanType)) {
            return false;
        }
        if (request.employmentType != 'Self Employed') {
            return matchesMultiPicklist(referenceRecord.Employment_Type__c, request.employmentType);
        }
        return matchesMultiPicklist(referenceRecord.Employment_Type__c, request.employmentType)
            && matchesMultiPicklist(referenceRecord.Self_Employment_Type__c, request.selfEmploymentType);
    }

    private static Boolean matchesMultiPicklist(String configuredValues, String selectedValue) {
        if (String.isBlank(configuredValues) || String.isBlank(selectedValue)) {
            return true;
        }
        return configuredValues.split(';').contains(selectedValue);
    }
}