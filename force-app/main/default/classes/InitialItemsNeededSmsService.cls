public without sharing class InitialItemsNeededSmsService {
    private static final String INITIAL_ITEMS_TEMPLATE = 'Initial_Items_Needed';
    private static final String INITIAL_ITEMS_SUBJECT_PREFIX = 'Conditional Approval for Your Mortgage';
    private static final String SMS_TEMPLATE = 'Initial_Items_Needed_SMS';
    private static final String MESSAGE_TYPE = 'RingCentral SMS';
    private static final String CAMPAIGN_TYPE = 'Initial Conditions Message';
    private static final String EXECUTION_FLOW = 'Conditions_Initial_Items_Needed_SMS';
    private static Set<String> enqueuedTransactionIds = new Set<String>();

    public static void enqueueFromEmailMessages(List<EmailMessage> emailMessages) {
        if (emailMessages == null || emailMessages.isEmpty()) {
            return;
        }

        for (EmailMessage emailMessage : emailMessages) {
            if (!isInitialItemsBorrowerEmail(emailMessage)) {
                continue;
            }

            enqueueIfApplicable(
                String.valueOf(emailMessage.RelatedToId),
                INITIAL_ITEMS_TEMPLATE,
                parseEmailAddresses(emailMessage.ToAddress)
            );
        }
    }

    public static void enqueueIfApplicable(String transactionId, String templateName, List<Object> emailToAddresses) {
        if (String.isBlank(transactionId) || templateName != INITIAL_ITEMS_TEMPLATE) {
            return;
        }
        if (enqueuedTransactionIds.contains(transactionId)) {
            return;
        }

        List<Transaction__c> transactions = [
            SELECT Id, Borrower_Email__c
            FROM Transaction__c
            WHERE Id = :transactionId
            WITH USER_MODE
            LIMIT 1
        ];
        if (transactions.isEmpty() || !borrowerReceivedEmail(transactions[0].Borrower_Email__c, emailToAddresses)) {
            return;
        }

        enqueuedTransactionIds.add(transactionId);
        sendAsync(transactionId);
    }

    @future(callout=true)
    private static void sendAsync(String transactionId) {
        createAndSend(transactionId);
    }

    @TestVisible
    private static void createAndSend(String transactionId) {
        if (String.isBlank(transactionId)) {
            return;
        }

        List<Transaction__c> transactions = [
            SELECT Id,
                Name,
                Processor__c,
                Borrowers_Phone__c,
                Account__c,
                Account__r.PersonMobilePhone,
                Account__r.Phone,
                Account__r.SMS_Opt_Out__c,
                Borrower_Name__c,
                Borrower_Name__r.PersonMobilePhone,
                Borrower_Name__r.Phone,
                Borrower_Name__r.SMS_Opt_Out__c
            FROM Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];
        if (transactions.isEmpty()) {
            return;
        }

        Transaction__c transactionRecord = transactions[0];
        Id borrowerAccountId = transactionRecord.Borrower_Name__c != null
            ? transactionRecord.Borrower_Name__c
            : transactionRecord.Account__c;
        Boolean isOptedOut = transactionRecord.Borrower_Name__c != null
            ? transactionRecord.Borrower_Name__r.SMS_Opt_Out__c
            : transactionRecord.Account__r != null && transactionRecord.Account__r.SMS_Opt_Out__c;
        String recipientPhone = firstNonBlank(new List<String>{
            transactionRecord.Borrower_Name__r == null ? null : transactionRecord.Borrower_Name__r.PersonMobilePhone,
            transactionRecord.Account__r == null ? null : transactionRecord.Account__r.PersonMobilePhone,
            transactionRecord.Borrowers_Phone__c,
            transactionRecord.Borrower_Name__r == null ? null : transactionRecord.Borrower_Name__r.Phone,
            transactionRecord.Account__r == null ? null : transactionRecord.Account__r.Phone
        });

        Scheduled_Message__c message = new Scheduled_Message__c(
            Account__c = borrowerAccountId,
            Campaign_Type__c = CAMPAIGN_TYPE,
            Execution_Flow__c = EXECUTION_FLOW,
            Recipient_Phone_Number__c = recipientPhone,
            Scheduled_Send_DateTime__c = System.now(),
            Sender__c = transactionRecord.Processor__c,
            Template_ID__c = getSmsTemplateId(),
            Type__c = MESSAGE_TYPE
        );

        if (borrowerAccountId == null) {
            message.Blocked__c = true;
            message.Info_Message__c = 'Blocked. No borrower Account found for Transaction ' + transactionRecord.Name;
            insert message;
            return;
        }
        if (transactionRecord.Processor__c == null) {
            message.Blocked__c = true;
            message.Info_Message__c = 'Blocked. No Processor set for Transaction ' + transactionRecord.Name;
            insert message;
            return;
        }
        if (isOptedOut) {
            message.Blocked__c = true;
            message.Info_Message__c = 'Blocked. Borrower Account is opted out of SMS';
            insert message;
            return;
        }
        if (String.isBlank(recipientPhone)) {
            message.Blocked__c = true;
            message.Info_Message__c = 'Blocked. No borrower phone number found for Transaction ' + transactionRecord.Name;
            insert message;
            return;
        }
        if (String.isBlank(message.Template_ID__c)) {
            message.Blocked__c = true;
            message.Info_Message__c = 'Blocked. Initial Items Needed SMS template was not found';
            insert message;
            return;
        }

        insert message;
        if (!Test.isRunningTest()) {
            System.enqueueJob(new SendScheduledMessageJob(message.Id));
        }
    }

    private class SendScheduledMessageJob implements Queueable, Database.AllowsCallouts {
        private Id messageId;

        private SendScheduledMessageJob(Id messageId) {
            this.messageId = messageId;
        }

        public void execute(QueueableContext context) {
            RingCentralSMSService.sendScheduledMessage(messageId);
        }
    }

    private static Boolean borrowerReceivedEmail(String borrowerEmail, List<Object> emailToAddresses) {
        if (String.isBlank(borrowerEmail) || emailToAddresses == null || emailToAddresses.isEmpty()) {
            return false;
        }

        for (Object addressObj : emailToAddresses) {
            if (addressObj != null && borrowerEmail.equalsIgnoreCase(String.valueOf(addressObj))) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isInitialItemsBorrowerEmail(EmailMessage emailMessage) {
        return emailMessage != null
            && emailMessage.Incoming == false
            && emailMessage.RelatedToId != null
            && String.valueOf(emailMessage.RelatedToId).startsWith(Transaction__c.SObjectType.getDescribe().getKeyPrefix())
            && String.isNotBlank(emailMessage.ToAddress)
            && isInitialItemsSubject(emailMessage.Subject);
    }

    private static Boolean isInitialItemsSubject(String subject) {
        if (String.isBlank(subject)) {
            return false;
        }

        String configuredSubject = new TemplateFinder().getEmailTemplateSubject(INITIAL_ITEMS_TEMPLATE);
        if (String.isNotBlank(configuredSubject)) {
            return subject.trim().equalsIgnoreCase(configuredSubject.trim())
                || subject.trim().startsWith(INITIAL_ITEMS_SUBJECT_PREFIX);
        }

        return subject.trim().startsWith(INITIAL_ITEMS_SUBJECT_PREFIX);
    }

    private static List<Object> parseEmailAddresses(String addresses) {
        List<Object> parsedAddresses = new List<Object>();
        if (String.isBlank(addresses)) {
            return parsedAddresses;
        }

        for (String address : addresses.split('[,;]')) {
            String normalizedAddress = normalizeEmailAddress(address);
            if (String.isNotBlank(normalizedAddress)) {
                parsedAddresses.add(normalizedAddress);
            }
        }
        return parsedAddresses;
    }

    private static String normalizeEmailAddress(String address) {
        if (String.isBlank(address)) {
            return null;
        }

        String trimmedAddress = address.trim();
        Integer openBracketIndex = trimmedAddress.indexOf('<');
        Integer closeBracketIndex = trimmedAddress.indexOf('>');
        if (openBracketIndex >= 0 && closeBracketIndex > openBracketIndex) {
            return trimmedAddress.substring(openBracketIndex + 1, closeBracketIndex).trim();
        }
        return trimmedAddress;
    }

    private static String getSmsTemplateId() {
        return new TemplateFinder().getSmsTemplateId(SMS_TEMPLATE);
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private without sharing class TemplateFinder {
        private String getEmailTemplateSubject(String templateDeveloperName) {
            List<EmailTemplate> templates = [
                SELECT Subject
                FROM EmailTemplate
                WHERE DeveloperName = :templateDeveloperName
                LIMIT 1
            ];
            return templates.isEmpty() ? null : templates[0].Subject;
        }

        private String getSmsTemplateId(String templateDeveloperName) {
            List<EmailTemplate> templates = [
                SELECT Id
                FROM EmailTemplate
                WHERE DeveloperName = :templateDeveloperName
                LIMIT 1
            ];
            return templates.isEmpty() ? null : templates[0].Id;
        }
    }
}