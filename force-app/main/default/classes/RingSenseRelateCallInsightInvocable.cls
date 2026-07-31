public with sharing class RingSenseRelateCallInsightInvocable {
    public class Input {
        @InvocableVariable(required=true)
        public Id callInsightId;

        @InvocableVariable(required=true)
        public String recipientPhoneNumber;
    }

    public class Output {
        @InvocableVariable
        public Id leadId;

        @InvocableVariable
        public Id accountId;

        @InvocableVariable
        public Id transactionId;
    }

    @InvocableMethod(label='Resolve RingSense Call Insight Relationships')
    public static List<Output> resolveRelationships(List<Input> inputs) {
        List<Output> outputs = new List<Output>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        Set<String> phoneNumbers = new Set<String>();
        for (Input inputRow : inputs) {
            if (inputRow != null && !String.isBlank(inputRow.recipientPhoneNumber)) {
                phoneNumbers.add(inputRow.recipientPhoneNumber);
            }
        }

        Map<String, Id> leadIdsByPhone = RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(phoneNumbers);
        Map<String, Id> contactIdsByPhone = RingCentralLeadPriorityMatcher.getContactIdsByPhoneNumbers(phoneNumbers);
        Map<Id, Id> accountIdsByContactId = RingCentralLeadPriorityMatcher.getAccountIdsByContactIds(new Set<Id>(contactIdsByPhone.values()));
        Map<Id, Id> transactionByAccountId = RingCentralLeadPriorityMatcher.getMostRecentActiveTransactionByAccountIds(new Set<Id>(accountIdsByContactId.values()));

        for (Input inputRow : inputs) {
            Output outputRow = new Output();
            if (inputRow != null && !String.isBlank(inputRow.recipientPhoneNumber)) {
                String normalized = RingCentralLeadPriorityMatcher.normalizePhoneNumber(inputRow.recipientPhoneNumber);
                outputRow.leadId = leadIdsByPhone.get(normalized);

                Id contactId = contactIdsByPhone.get(normalized);
                outputRow.accountId = accountIdsByContactId.get(contactId);
                outputRow.transactionId = transactionByAccountId.get(outputRow.accountId);
            }
            outputs.add(outputRow);
        }

        return outputs;
    }
}