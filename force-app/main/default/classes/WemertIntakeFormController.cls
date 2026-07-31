public without sharing class WemertIntakeFormController {

    @AuraEnabled
    public static List<Account> getRealtorAccounts() {
        return [SELECT Id, Name, FirstName, LastName FROM Account WHERE Realtor_Group__c = 'Wemert Group'];
    }
    
    @AuraEnabled 
    public static List<User> getLoanOfficers(String accountId) {
        
        Set<Id> userIds = new Set<Id>();
        List<User_To_Account__c> userToAccounts = [SELECT Id, User__c FROM User_To_Account__c WHERE Account__c = :accountId AND Active__c = TRUE];
        for (User_To_Account__c uta : userToAccounts) {
            userIds.add(uta.User__c);
        }
        
        return [
            SELECT Id, Name, FirstName, LastName, Phone, Email, Headshot_URL__c
            FROM User
            WHERE Id IN :userIds
            AND IsActive = TRUE
            ORDER BY Name
        ];
    }
}