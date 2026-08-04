public without sharing class AccountRecordHeroController {
    private static final Set<String> ALLOWED_LOAN_PURPOSES = new Set<String>{ 'Purchase', 'Refinance' };
    private static final List<String> CONSUMER_LEAD_RECORD_TYPES = new List<String>{
        'Consumer_Lead_record_type',
        'Consumer_Under_Contract_Lead_Record_Type',
        'Consumer_Purchase_Refinance'
    };

    @AuraEnabled
    public static Id createPastClientLead(Id accountId, String loanPurpose) {
        if (accountId == null) {
            throw new AuraHandledException('Account is required.');
        }
        if (String.isBlank(loanPurpose) || !ALLOWED_LOAN_PURPOSES.contains(loanPurpose)) {
            throw new AuraHandledException('Choose Purchase or Refinance before creating the Lead.');
        }

        Account accountRecord = [
            SELECT Id, Name, FirstName, LastName, PersonEmail, Phone, PersonMobilePhone,
                First_UTM_Campaign__c, First_UTM_Content__c, First_UTM_Medium__c,
                First_UTM_Source__c, First_UTM_Term__c, Last_UTM_Campaign__c,
                Last_UTM_Content__c, Last_UTM_Medium__c, Last_UTM_Source__c,
                Last_UTM_Term__c, UTM_Content__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        String lastName = String.isBlank(accountRecord.LastName)
            ? accountRecord.Name
            : accountRecord.LastName;
        if (String.isBlank(lastName)) {
            lastName = 'Past Client';
        }

        Lead leadRecord = new Lead(
            RecordTypeId = getConsumerLeadRecordTypeId(),
            Biz_Dev__c = 'Biz Dev - Reach',
            Branch__c = 'Boca Raton',
            Company = String.isBlank(accountRecord.Name) ? lastName : accountRecord.Name,
            Email = accountRecord.PersonEmail,
            FirstName = accountRecord.FirstName,
            First_UTM_Campaign__c = accountRecord.First_UTM_Campaign__c,
            First_UTM_Content__c = accountRecord.First_UTM_Content__c,
            First_UTM_Medium__c = accountRecord.First_UTM_Medium__c,
            First_UTM_Source__c = accountRecord.First_UTM_Source__c,
            First_UTM_Term__c = accountRecord.First_UTM_Term__c,
            LastName = lastName,
            Last_UTM_Campaign__c = accountRecord.Last_UTM_Campaign__c,
            Last_UTM_Content__c = accountRecord.Last_UTM_Content__c,
            Last_UTM_Medium__c = accountRecord.Last_UTM_Medium__c,
            Last_UTM_Source__c = accountRecord.Last_UTM_Source__c,
            Last_UTM_Term__c = accountRecord.Last_UTM_Term__c,
            LeadSource = 'Past Client',
            Loan_Purpose__c = loanPurpose,
            MobilePhone = accountRecord.PersonMobilePhone,
            Phone = accountRecord.Phone,
            UTM_Content__c = accountRecord.UTM_Content__c
        );

        insert leadRecord;
        return leadRecord.Id;
    }

    private static Id getConsumerLeadRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> recordTypesByDeveloperName =
            Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        for (String developerName : CONSUMER_LEAD_RECORD_TYPES) {
            Schema.RecordTypeInfo info = recordTypesByDeveloperName.get(developerName);
            if (info != null) {
                return info.getRecordTypeId();
            }
        }
        throw new AuraHandledException('A Consumer Lead record type could not be found.');
    }
}
