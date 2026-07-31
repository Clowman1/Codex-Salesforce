/**
 * @author Andrei Karanko
 * @date 9/1/2023
 * description - This class is used to get the initial loan condition references
 * to create initial loan conditions. It is used in Conditions Creator flow
 */

global with sharing class ReferenceInvocableQuery {
    @InvocableMethod(Label='Get Initial Submission References')
    global static List<Response> getReferences(List<Request> requests){
        List<Response> responses = new List<Response>();

        Map<String, List<Transaction_Condition_Reference__c>> typeToConditionReferencesMap = getAllConditionReferencesWithAllTypesFromRequests(requests);
        if (typeToConditionReferencesMap.isEmpty()){
            return responses;
        }

        // loop through requests
        // for each request, get the list of condition references from the map
        for(Request req: requests){
            if(!typeToConditionReferencesMap.containsKey(req.type)){
                continue;
            }
            Response res = new Response();
            List<Transaction_Condition_Reference__c> conditionReferences = typeToConditionReferencesMap.get(req.type);
            List<Transaction_Condition_Reference__c> matchingConditionReferences = assessReferences(req, conditionReferences);
            if (!matchingConditionReferences.isEmpty()){
                res.conditions = matchingConditionReferences;
                responses.add(res);
            }
        }

        return responses;
    }

    private static Map<String, List<Transaction_Condition_Reference__c>> getAllConditionReferencesWithAllTypesFromRequests(List<Request> requests){
        // first get all the types from the requests
        Set<String> types = new Set<String>();
        for(Request req: requests){
            types.add(req.type);
        }

        // get all condition references that have all the types from the requests
        // this is to avoid having to query for each type in a loop
        List<Transaction_Condition_Reference__c> conditionsWithAllTypesFromRequest = [
            SELECT Id, Loan_Purpose__c, Employment_Type__c,Self_Employment_Type__c, Type__c, Borrower_Label__c, Borrower_Description__c, Loan_Type__c
            FROM Transaction_Condition_Reference__c
            WHERE Type__c IN :types
            WITH USER_MODE
        ];

        // loop through condition references with all types from request
        // to create a map with type as key and list of condition references as value
        Map<String, List<Transaction_Condition_Reference__c>> typeToConditionReferencesMap = new Map<String, List<Transaction_Condition_Reference__c>>();
        for(Transaction_Condition_Reference__c conditionReference: conditionsWithAllTypesFromRequest){
            if(!typeToConditionReferencesMap.containsKey(conditionReference.Type__c)){
                typeToConditionReferencesMap.put(conditionReference.Type__c, new List<Transaction_Condition_Reference__c>());
            }
            typeToConditionReferencesMap.get(conditionReference.Type__c).add(conditionReference);
        }
        return typeToConditionReferencesMap;
    }

    private static List<Transaction_Condition_Reference__c> assessReferences(Request req, List<Transaction_Condition_Reference__c> conditionReferences) {
        List<Transaction_Condition_Reference__c> matchingConditionReferences = new List<Transaction_Condition_Reference__c>();
        for(Transaction_Condition_Reference__c conditionReference: conditionReferences){
            if (isConditionMatch(req, conditionReference)) {
                matchingConditionReferences.add(conditionReference);
            }
        }
        return matchingConditionReferences;
    }

    private static Boolean isConditionMatch(Request req, Transaction_Condition_Reference__c conditionReference) {
        if (conditionReference.Loan_Purpose__c != null && !conditionReference.Loan_Purpose__c.contains(req.loanPurpose)) {
            return false;
        }
        if (conditionReference.Loan_Type__c != null && !conditionReference.Loan_Type__c.contains(req.loanType)) {
            return false;
        }
        if (req.employmentType != 'Self Employed') {
            if (conditionReference.Employment_Type__c != null && !conditionReference.Employment_Type__c.contains(req.employmentType)) {
                return false;
            }
        } else {
            if (conditionReference.Employment_Type__c != null && conditionReference.Employment_Type__c != 'Self Employed') {
                return false;
            }
            if (conditionReference.Self_Employment_Type__c != null && !conditionReference.Self_Employment_Type__c.contains(req.selfEmploymentType)) {
                return false;
            }
        }

        return true;
    }

    global class Response{
        @InvocableVariable
        global List<Transaction_Condition_Reference__c> conditions;
    }
    global class Request{
        @InvocableVariable
        global String loanType;
        @InvocableVariable
        global String loanPurpose;
        @InvocableVariable
        global String employmentType;
        @InvocableVariable
        global String selfEmploymentType;
        @InvocableVariable
        global String type;
    }
}