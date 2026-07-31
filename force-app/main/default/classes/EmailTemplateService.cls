/**
 * Created by zeyad on 10/20/2020.
 */

public with sharing class EmailTemplateService {
    private static EmailTemplateService self;
    private List<EmailTemplateConfiguration__mdt> configurations;
    private Map<String, EmailTemplateConfiguration__mdt> templateIdToConfigurationMap = new Map<String, EmailTemplateConfiguration__mdt>();
    public EmailTemplateService(){
        configurations = [SELECT Id, TemplateId__c,Is_Related_To_Who_Id__c, Object__c, FieldToUpdate__c FROM EmailTemplateConfiguration__mdt];
        for(EmailTemplateConfiguration__mdt config : configurations){
            templateIdToConfigurationMap.put(config.TemplateId__c, config);
        }
    }
    public class EmailTemplateMtd{
        public String field;
        public String templateId;
        public String sObjectType;
        public Boolean isRelatedToWho = false;
    }
    public String getFieldToUpdateFromTemplateId(String templateId){
        system.debug(templateIdToConfigurationMap);
        return templateIdToConfigurationMap.get(templateId) == null ? null : templateIdToConfigurationMap.get(templateId).FieldToUpdate__c;
    }
    public EmailTemplateMtd getEmailTemplateMtdFromTemplateId(String templateId){
        EmailTemplateConfiguration__mdt template = templateIdToConfigurationMap.get(templateId) == null ? null : templateIdToConfigurationMap.get(templateId);
        EmailTemplateMtd mtd;
        if(template != null){
            mtd = new EmailTemplateMtd();
            mtd.field = template.FieldToUpdate__c;
            mtd.templateId = templateId;
            mtd.SObjectType = template.Object__c;
            mtd.isRelatedToWho = template.Is_Related_To_Who_ID__c;
        }
        return mtd;
    }

    public static EmailTemplateService getInstance(){
        if(self == null){
            self = new EmailTemplateService();
        }
        return self;
    }
}