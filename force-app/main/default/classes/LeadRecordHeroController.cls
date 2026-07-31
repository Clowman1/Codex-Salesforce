public with sharing class LeadRecordHeroController {
    @AuraEnabled(cacheable=true)
    public static LeadSummary getSummary(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Lead record id is required.');
        }

        Lead leadRecord = [
            SELECT Id, Name, Phone, Email, Status, LeadSource, Rating, Loan_Purpose__c,
                Owner.Name, Loan_Partner__r.Name, Biz_Dev__c, Realtor_Buying_Agent__r.Name
            FROM Lead
            WHERE Id = :recordId
            LIMIT 1
        ];

        LeadSummary summary = new LeadSummary();
        summary.name = leadRecord.Name;
        summary.phone = leadRecord.Phone;
        summary.email = leadRecord.Email;
        summary.status = leadRecord.Status;
        summary.leadSource = leadRecord.LeadSource;
        summary.rating = leadRecord.Rating;
        summary.loanPurpose = leadRecord.Loan_Purpose__c;
        summary.ownerName = leadRecord.Owner != null ? leadRecord.Owner.Name : null;
        summary.loanPartnerName = leadRecord.Loan_Partner__r != null ? leadRecord.Loan_Partner__r.Name : null;
        summary.bizDev = leadRecord.Biz_Dev__c;
        summary.buyersAgentName = leadRecord.Realtor_Buying_Agent__r != null ? leadRecord.Realtor_Buying_Agent__r.Name : null;
        return summary;
    }

    public class LeadSummary {
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String status;
        @AuraEnabled public String leadSource;
        @AuraEnabled public String rating;
        @AuraEnabled public String loanPurpose;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String loanPartnerName;
        @AuraEnabled public String bizDev;
        @AuraEnabled public String buyersAgentName;
    }
}