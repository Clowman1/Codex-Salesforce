public without sharing class IntakeFormController {

    @AuraEnabled 
    public static List<User> getLoanOfficers(String realtorEmail) {
        List<Account> accounts = [SELECT Id FROM Account WHERE PersonEmail = :realtorEmail];
        
        if (accounts.isEmpty()) {
            return new List<User>();
        }
        
        Account account = accounts[0];
        
        Set<Id> userIds = new Set<Id>();
        List<User_To_Account__c> userToAccounts = [SELECT Id, User__c FROM User_To_Account__c WHERE Account__c = :account.Id AND Active__c = TRUE];
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
