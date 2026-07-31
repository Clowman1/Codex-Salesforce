public without sharing class ClosingPortalController {
    
    @AuraEnabled 
    public static String getTransactionStatus(Id recordId) {
        Transaction__c tx = [SELECT Id, Closing_Package_Status__c FROM Transaction__c WHERE Id = :recordId LIMIT 1];
        return tx.Closing_Package_Status__c;
    }
    
    @AuraEnabled
    public static void updateTransactionStatus(Id recordId, String status, String rejectionNotes) {
        Transaction__c tx = [SELECT Id, Closing_Package_Status__c, Closing_Package_Rejection_Notes__c FROM Transaction__c WHERE Id = :recordId LIMIT 1];
        tx.Closing_Package_Status__c = status;
        if (status == 'Rejected') {
            tx.Closing_Package_Rejection_Notes__c = rejectionNotes;
        }
        update tx;
    }
    
    @AuraEnabled
    public static void sendEmail(String recordId, List<String> fileNames) {
        Transaction__c loan = [SELECT Id, Name FROM Transaction__c WHERE Id = :recordId];
        OrgWideEmailAddress owea = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'reachus@reachhomeloans.com'];
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] { 'postclosing@reachhomeloans.com' };
            
        mail.setOrgWideEmailAddressId(owea.Id);
        mail.setToAddresses(toAddresses);
        mail.setSubject('Closing Package Uploaded: ' + loan.Name);
        
        String htmlTemplate = 'Closing Package files were uploaded for ' +
            '<a href="https://reachhomeloans.lightning.force.com/lightning/r/Transaction__c/' + loan.Id + '/view">' + loan.Name + '</a>: ' +
            fileNames.toString();
        
        mail.setHtmlBody(htmlTemplate);
        
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
}