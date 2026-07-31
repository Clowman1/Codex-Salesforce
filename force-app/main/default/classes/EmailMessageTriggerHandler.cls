public with sharing class EmailMessageTriggerHandler {
    public class EmailMessageException extends Exception{}
    private PersistenceStrategy.BulkifiedSave loanPersistenceStrategy;
    public void afterInsert(List<EmailMessage> messages){
        this.loanPersistenceStrategy = new PersistenceStrategy.BulkifiedSave();
        processEmailTemplateSends(messages);
        this.loanPersistenceStrategy.flush();
    }
    private void processEmailTemplateSends(List<EmailMessage> messages){
        List<SObject> objectsToUpdate = new List<SObject>();
        for(EmailMessage email : messages){
            EmailTemplateService.EmailTemplateMtd mtd = email.EmailTemplateId == null ? null : EmailTemplateService.getInstance().getEmailTemplateMtdFromTemplateId(email.EmailTemplateId);
            if(mtd != null){
                sObject sObj = Schema.getGlobalDescribe().get(mtd.sObjectType).newSObject();
                System.debug(JSON.serializePretty(email));
                //System.debug(JSON.serializePretty(email.ToIds[0] ));
                String relatedId = getRelatedId(email,mtd);
                if(relatedId == null){
                    throw new EmailTriggerException('This email must be related to a contact or a lead. Pleasee try again. If this error persists, please reach out to your Salesforce support team.');
                }
                sObj.put('Id',relatedId);
                sObj.put(mtd.field,Date.today());
                objectsToUpdate.add(sObj);
            }
        }
        if(objectsToUpdate.size() > 0){
            update objectsToUpdate;
        }
    }
    private String getRelatedId(EmailMessage email,EmailTemplateService.EmailTemplateMtd mtd){
        if(mtd.isRelatedToWho){
            List<EmailMessageRelation> relations = [SELECT Id,RelationId,RelationType FROM EmaiLMessageRelation WHERE EmailMessageId=:email.Id AND RelationType = 'ToAddress'];
            for(EmailMessageRelation relation : relations){
                return relation.RelationId;
            }
            return null;
        }else{
            return email.RelatedToId;
        }
    }
    public class EmailTriggerException extends Exception{}
}