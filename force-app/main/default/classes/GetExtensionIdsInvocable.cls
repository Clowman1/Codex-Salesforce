global with sharing class GetExtensionIdsInvocable {
    @InvocableMethod(Label='Get Extension Ids for RingCentral')
    global static List<Result> getExtentionIds(){

        List<Result> results = new List<Result>();
        Result result = new Result();
        List<User> users = [SELECT Rc_Extension_Id__c FROM User WHERE Rc_Extension_Id__c != null];
        for(User u : users){
            result.extensionIds.add(u.Rc_Extension_Id__c);
        }
        results.add(result);
        return results;
    }

    global class Result {
        @InvocableVariable
        global List<String> extensionIds = new List<String>();
    }
}