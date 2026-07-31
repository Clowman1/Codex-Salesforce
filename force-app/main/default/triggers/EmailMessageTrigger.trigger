trigger EmailMessageTrigger on EmailMessage (after insert, before insert) {
    if(Trigger.isAfter){        
        EmailMessageTriggerHandler handler = new EmailMessageTriggerHandler();
        handler.afterInsert(Trigger.New);
    }else{
        List<EmailTemplate> closingPackageEmailTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName ='Closing_Instructions_Funding_Authorization_1656379782794'];
        List<EmailTemplate> balancingRequestEmailTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName ='Balancing_Request_1658368757668'];
        Transaction__c transact;
        for(EmailMessage t : Trigger.New){
            if(t.EmailTemplateId == closingPackageEmailTemplate[0].Id){
                transact = LoanRepository.getInstance().getLoanById(t.RelatedToId).getData();
                if(String.isBlank(transact.Closing_Package_One_Drive_Link__c)){
                    t.addError('Please fill in the one drive link prior to sending this email.');
                }
            }
            if(t.EmailTemplateId == balancingRequestEmailTemplate[0].Id){
                transact = LoanRepository.getInstance().getLoanById(t.RelatedToId).getData();
                if(String.isBlank(transact.Balancing_Istructions_OneDrive_Link__c)){
                    t.addError('Please fill in the one drive link prior to sending this email.');
                }
            }
        }
    }
}