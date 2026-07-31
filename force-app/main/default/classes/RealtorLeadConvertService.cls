public with sharing class RealtorLeadConvertService {
    private static final String REALTOR_RECORD_TYPE_DEVELOPER_NAME = 'Realtor_Lead_record_type';
    private static final String GROUP_REALTOR_VALUE = 'Realtor';
    private static final String LOG_SOURCE = 'Realtor Lead Convert';
    private static final String ORG_WIDE_FROM_ADDRESS = 'reachus@reachhomeloans.com';

    @TestVisible
    private static Boolean forceConvertedAccountLinkFailureForTest = false;
    @TestVisible
    private static Boolean forceUnhandledExceptionForTest = false;
    @TestVisible
    private static Boolean forceMissingRequiredFieldsForTest = false;

    public class ConvertResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String userMessage;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String adminMessage;
        @AuraEnabled public List<Id> recordIdsAffected;
        @AuraEnabled public List<String> errors;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Boolean usedFollowUpFallback;
    }

    private class LinkOutcome {
        public Boolean success;
        public Boolean usedFallback;
        public String errorMessage;
    }

    private class RealtorLeadConvertException extends Exception {}

    public static ConvertResponse convertLead(Id leadId) {
        ConvertResponse response = initResponse();
        try {
            if (Test.isRunningTest() && forceUnhandledExceptionForTest) {
                throw new RealtorLeadConvertException('Simulated unhandled exception.');
            }

            Lead leadRecord = LeadRepository.getInstance().selectForRealtorConvert(leadId);
            if (leadRecord == null) {
                return fail(
                    response,
                    'NOT_ELIGIBLE',
                    'This Lead was not found or you do not have access to it.',
                    'Lead selector returned no records for Id=' + String.valueOf(leadId),
                    leadId,
                    null,
                    false
                );
            }

            String eligibilityError = getEligibilityError(leadRecord);
            if (eligibilityError != null) {
                return fail(
                    response,
                    'NOT_ELIGIBLE',
                    eligibilityError,
                    'Lead not eligible for Realtor convert action. LeadId=' + String.valueOf(leadRecord.Id),
                    leadRecord.Id,
                    null,
                    false
                );
            }

            List<String> missingFields = getMissingRequiredFields(leadRecord);
            if (!missingFields.isEmpty()) {
                return fail(
                    response,
                    'MISSING_REQUIRED_FIELDS',
                    'Missing required fields: ' + String.join(missingFields, ', ') + '. Update the Lead and try again.',
                    'Missing required fields on Lead.Id=' + String.valueOf(leadRecord.Id) + ': ' + String.join(missingFields, ', '),
                    leadRecord.Id,
                    null,
                    false
                );
            }

            PersonAccountRepository personAccountRepository = new PersonAccountRepository();
            Account linkedOrCreatedAccount = null;
            Boolean isDuplicateLink = false;

            if (String.isNotBlank(leadRecord.Email)) {
                linkedOrCreatedAccount = personAccountRepository.selectPersonAccountByEmail(leadRecord.Email);
                isDuplicateLink = linkedOrCreatedAccount != null;
            }

            if (linkedOrCreatedAccount == null) {
                Id personAccountRecordTypeId = personAccountRepository.selectPersonAccountRecordTypeId();
                if (personAccountRecordTypeId == null) {
                    return fail(
                        response,
                        'CREATE_FAILED',
                        'Unable to create the Person Account because the PersonAccount record type was not found.',
                        'RecordType lookup failed for Account.PersonAccount.',
                        leadRecord.Id,
                        null,
                        true
                    );
                }

                Account personAccountToInsert = buildPersonAccountForLead(leadRecord, personAccountRecordTypeId);
                Account creatableAccount = stripToCreatable(personAccountToInsert);
                Database.SaveResult accountInsertResult = Database.insert(creatableAccount, false);
                if (!accountInsertResult.isSuccess()) {
                    return fail(
                        response,
                        'CREATE_FAILED',
                        'Could not create the Person Account. Please review required fields and validation rules.',
                        'Account insert failed: ' + collectSaveResultErrors(accountInsertResult),
                        leadRecord.Id,
                        null,
                        true
                    );
                }
                linkedOrCreatedAccount = personAccountRepository.selectPersonAccountById(accountInsertResult.getId());
                if (linkedOrCreatedAccount == null) {
                    linkedOrCreatedAccount = new Account(Id = accountInsertResult.getId(), Name = buildDisplayName(leadRecord));
                }
            }

            LinkOutcome linkOutcome = linkLeadToAccount(leadRecord.Id, linkedOrCreatedAccount.Id);
            if (!linkOutcome.success) {
                return fail(
                    response,
                    'LINK_FAILED',
                    'The account was found/created but the Lead could not be linked. Contact support.',
                    linkOutcome.errorMessage,
                    leadRecord.Id,
                    linkedOrCreatedAccount.Id,
                    true
                );
            }

            response.success = true;
            response.errorCode = null;
            response.userMessage = isDuplicateLink
                ? 'Linked to existing Person Account.'
                : 'Person Account created and linked successfully.';
            response.adminMessage = null;
            response.accountId = linkedOrCreatedAccount.Id;
            response.accountName = linkedOrCreatedAccount.Name;
            response.usedFollowUpFallback = linkOutcome.usedFallback;
            response.recordIdsAffected = new List<Id>{ leadRecord.Id, linkedOrCreatedAccount.Id };
            response.errors = new List<String>();
            return response;
        } catch (Exception e) {
            return fail(
                response,
                'UNEXPECTED_ERROR',
                'An unexpected error occurred while converting this Realtor Lead.',
                'Unhandled exception: ' + e.getMessage() + '\n' + e.getStackTraceString(),
                leadId,
                null,
                true
            );
        }
    }

    private static ConvertResponse initResponse() {
        ConvertResponse response = new ConvertResponse();
        response.success = false;
        response.userMessage = null;
        response.errorCode = null;
        response.adminMessage = null;
        response.recordIdsAffected = new List<Id>();
        response.errors = new List<String>();
        response.accountId = null;
        response.accountName = null;
        response.usedFollowUpFallback = false;
        return response;
    }

    private static ConvertResponse fail(
        ConvertResponse response,
        String errorCode,
        String userMessage,
        String adminMessage,
        Id leadId,
        Id accountId,
        Boolean shouldNotify
    ) {
        response.success = false;
        response.errorCode = errorCode;
        response.userMessage = userMessage;
        response.adminMessage = adminMessage;
        response.errors = String.isBlank(adminMessage) ? new List<String>() : new List<String>{ adminMessage };
        response.recordIdsAffected = new List<Id>();
        if (leadId != null) {
            response.recordIdsAffected.add(leadId);
        }
        if (accountId != null) {
            response.recordIdsAffected.add(accountId);
            response.accountId = accountId;
        }

        if (shouldNotify) {
            logError(adminMessage, leadId);
            notifyDevOnError(errorCode, userMessage, adminMessage, leadId, accountId);
        }
        return response;
    }

    private static String getEligibilityError(Lead leadRecord) {
        if (leadRecord == null) {
            return 'Lead record is required.';
        }
        if (leadRecord.RecordType == null || leadRecord.RecordType.DeveloperName != REALTOR_RECORD_TYPE_DEVELOPER_NAME) {
            return 'This action is available only for Realtor Leads.';
        }
        if (leadRecord.IsConverted) {
            return 'This Lead is already converted.';
        }
        if (leadRecord.ConvertedAccountId != null || leadRecord.Follow_Up_Account__c != null) {
            return 'This Lead is already linked to an Account.';
        }
        return null;
    }

    private static List<String> getMissingRequiredFields(Lead leadRecord) {
        if (Test.isRunningTest() && forceMissingRequiredFieldsForTest) {
            return new List<String>{ 'Name', 'LastName' };
        }

        List<String> missingFields = new List<String>();
        String fullName = ((leadRecord.FirstName == null ? '' : leadRecord.FirstName) + ' ' +
                          (leadRecord.LastName == null ? '' : leadRecord.LastName)).trim();

        if (String.isBlank(fullName)) {
            missingFields.add('Name');
        }
        if (String.isBlank(leadRecord.LastName)) {
            missingFields.add('LastName');
        }
        return missingFields;
    }

    private static Account buildPersonAccountForLead(Lead leadRecord, Id personAccountRecordTypeId) {
        Account accountRecord = new Account();
        accountRecord.RecordTypeId = personAccountRecordTypeId;
        accountRecord.OwnerId = leadRecord.OwnerId;
        accountRecord.FirstName = leadRecord.FirstName;
        accountRecord.LastName = leadRecord.LastName;
        accountRecord.PersonEmail = leadRecord.Email;
        accountRecord.PersonMobilePhone = leadRecord.MobilePhone;
        accountRecord.Phone = leadRecord.Phone;
        accountRecord.PersonLeadSource = leadRecord.LeadSource;
        accountRecord.Website = leadRecord.Website;
        accountRecord.Description = leadRecord.Description;
        accountRecord.BillingStreet = leadRecord.Street;
        accountRecord.BillingCity = leadRecord.City;
        accountRecord.BillingState = leadRecord.State;
        accountRecord.BillingPostalCode = leadRecord.PostalCode;
        accountRecord.BillingCountry = leadRecord.Country;

        if (String.isNotBlank(leadRecord.Title)) {
            accountRecord.PersonTitle = leadRecord.Title;
        } else if (String.isNotBlank(leadRecord.Company)) {
            accountRecord.PersonTitle = leadRecord.Company;
        }

        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Realtor_lead__c')) {
            accountRecord.put('Realtor_lead__c', leadRecord.Id);
        }
        if (accountFields.containsKey('Group__pc')) {
            accountRecord.put('Group__pc', GROUP_REALTOR_VALUE);
        }
        if (accountFields.containsKey('Realtor_Group__c')) {
            accountRecord.put('Realtor_Group__c', leadRecord.Realtor_Group__c);
        }
        if (accountFields.containsKey('Status__pc') && String.isNotBlank(leadRecord.Status)) {
            accountRecord.put('Status__pc', leadRecord.Status);
        }
        return accountRecord;
    }

    private static Account stripToCreatable(Account accountRecord) {
        SObjectAccessDecision accessDecision = Security.stripInaccessible(
            System.AccessType.CREATABLE,
            new List<SObject>{ accountRecord }
        );
        return (Account)accessDecision.getRecords()[0];
    }

    private static LinkOutcome linkLeadToAccount(Id leadId, Id accountId) {
        LinkOutcome outcome = new LinkOutcome();
        outcome.success = false;
        outcome.usedFallback = false;
        outcome.errorMessage = null;

        String convertedAccountFailure = null;

        if (!(Test.isRunningTest() && forceConvertedAccountLinkFailureForTest)) {
            try {
                Lead convertedLinkUpdate = new Lead(Id = leadId);
                convertedLinkUpdate.put('ConvertedAccountId', accountId);
                Database.SaveResult convertedLinkResult = Database.update(convertedLinkUpdate, false);
                if (convertedLinkResult.isSuccess()) {
                    outcome.success = true;
                    return outcome;
                }
                convertedAccountFailure = collectSaveResultErrors(convertedLinkResult);
            } catch (Exception e) {
                convertedAccountFailure = e.getMessage();
            }
        } else {
            convertedAccountFailure = 'Simulated ConvertedAccountId update failure for test.';
        }

        if (!Schema.SObjectType.Lead.fields.Follow_Up_Account__c.isUpdateable()) {
            outcome.errorMessage = 'ConvertedAccountId update failed and Follow_Up_Account__c is not updateable. ' +
                'ConvertedAccountId error: ' + convertedAccountFailure;
            return outcome;
        }

        try {
            Lead followUpLinkUpdate = new Lead(
                Id = leadId,
                Follow_Up_Account__c = accountId
            );
            Database.SaveResult followUpLinkResult = Database.update(followUpLinkUpdate, false);
            if (followUpLinkResult.isSuccess()) {
                outcome.success = true;
                outcome.usedFallback = true;
                return outcome;
            }
            outcome.errorMessage = 'Follow_Up_Account__c fallback update failed: ' + collectSaveResultErrors(followUpLinkResult) +
                '. ConvertedAccountId error: ' + convertedAccountFailure;
            return outcome;
        } catch (Exception e) {
            outcome.errorMessage = 'Follow_Up_Account__c fallback exception: ' + e.getMessage() +
                '. ConvertedAccountId error: ' + convertedAccountFailure;
            return outcome;
        }
    }

    private static String collectSaveResultErrors(Database.SaveResult saveResult) {
        if (saveResult == null || saveResult.isSuccess()) {
            return null;
        }

        List<String> messages = new List<String>();
        for (Database.Error dbError : saveResult.getErrors()) {
            messages.add(String.valueOf(dbError.getStatusCode()) + ': ' + dbError.getMessage());
        }
        return String.join(messages, '; ');
    }

    private static String buildDisplayName(Lead leadRecord) {
        String fullName = ((leadRecord.FirstName == null ? '' : leadRecord.FirstName) + ' ' +
                           (leadRecord.LastName == null ? '' : leadRecord.LastName)).trim();
        return String.isBlank(fullName) ? 'Person Account' : fullName;
    }

    private static void logError(String message, Id leadId) {
        try {
            Custom_Log__c logRecord = new Custom_Log__c();
            logRecord.Source__c = LOG_SOURCE;
            logRecord.Data__c = message;
            if (leadId != null) {
                logRecord.Lead__c = leadId;
            }
            insert logRecord;
        } catch (Exception ignore) {
            System.debug('Failed to insert Custom_Log__c for Realtor Lead Convert: ' + ignore.getMessage());
        }
    }

    private static void notifyDevOnError(
        String errorCode,
        String userMessage,
        String adminMessage,
        Id leadId,
        Id accountId
    ) {
        try {
            Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
            emailMessage.setToAddresses(new List<String>{ 'development@nimbuscloudsolutions.com' });
            emailMessage.setSubject('ERROR: ' + LOG_SOURCE + ' [' + errorCode + ']');

            String body = 'Operation: Realtor Lead Convert' +
                '\nError code: ' + String.valueOf(errorCode) +
                '\nLead Id: ' + String.valueOf(leadId) +
                '\nAccount Id: ' + String.valueOf(accountId) +
                '\nUser message: ' + String.valueOf(userMessage) +
                '\nAdmin message: ' + String.valueOf(adminMessage);
            emailMessage.setPlainTextBody(body);

            Id orgWideEmailAddressId = LeadStagnantAlertRepo.selectOrgWideEmailAddressId(ORG_WIDE_FROM_ADDRESS);
            if (orgWideEmailAddressId != null) {
                emailMessage.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ emailMessage });
        } catch (Exception ignore) {
            System.debug('Failed to notify development@nimbuscloudsolutions.com: ' + ignore.getMessage());
        }
    }
}