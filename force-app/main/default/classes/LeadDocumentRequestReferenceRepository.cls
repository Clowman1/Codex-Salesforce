public inherited sharing class LeadDocumentRequestReferenceRepository {
    private static LeadDocumentRequestReferenceRepository self;

    public static LeadDocumentRequestReferenceRepository getInstance() {
        if (self == null) {
            self = new LeadDocumentRequestReferenceRepository();
        }
        return self;
    }

    public List<Lead_Document_Request_Reference__c> selectActiveReferences() {
        return [
            SELECT Id, Name, Active__c, Borrower_Label__c, Borrower_Description__c,
                   Category__c, Package__c, Type__c, Condition_Group_Key__c,
                   Loan_Purpose__c, Loan_Type__c, Employment_Type__c, Self_Employment_Type__c,
                   Reference_Id__c, Sort_Order__c, Include_In_Email__c, Can_Borrower_See__c
            FROM Lead_Document_Request_Reference__c
            WHERE Active__c = TRUE
            WITH SYSTEM_MODE
            ORDER BY Type__c ASC, Sort_Order__c ASC NULLS LAST, Borrower_Label__c ASC
        ];
    }

    public List<Lead_Document_Request_Reference__c> selectActiveByTypes(Set<String> referenceTypes) {
        if (referenceTypes == null || referenceTypes.isEmpty()) {
            return new List<Lead_Document_Request_Reference__c>();
        }

        return [
            SELECT Id, Name, Active__c, Borrower_Label__c, Borrower_Description__c,
                   Category__c, Package__c, Type__c, Condition_Group_Key__c,
                   Loan_Purpose__c, Loan_Type__c, Employment_Type__c, Self_Employment_Type__c,
                   Reference_Id__c, Sort_Order__c, Include_In_Email__c, Can_Borrower_See__c
            FROM Lead_Document_Request_Reference__c
            WHERE Active__c = TRUE
            AND Type__c IN :referenceTypes
            WITH SYSTEM_MODE
            ORDER BY Type__c ASC, Sort_Order__c ASC NULLS LAST, Borrower_Label__c ASC
        ];
    }

    public Map<Id, Lead_Document_Request_Reference__c> selectByIds(Set<Id> referenceIds) {
        if (referenceIds == null || referenceIds.isEmpty()) {
            return new Map<Id, Lead_Document_Request_Reference__c>();
        }

        return new Map<Id, Lead_Document_Request_Reference__c>([
            SELECT Id, Name, Active__c, Borrower_Label__c, Borrower_Description__c,
                   Category__c, Package__c, Type__c, Condition_Group_Key__c,
                   Loan_Purpose__c, Loan_Type__c, Employment_Type__c, Self_Employment_Type__c,
                   Reference_Id__c, Sort_Order__c, Include_In_Email__c, Can_Borrower_See__c
            FROM Lead_Document_Request_Reference__c
            WHERE Id IN :referenceIds
            WITH SYSTEM_MODE
        ]);
    }
}