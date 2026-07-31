public with sharing class RingCentralLeadPriorityMatcher {
    // Matches ClientActivityTransactionRouter's definition of a closed-out file, plus 'Suspended'.
    // Calls only route to a transaction that is still being worked.
    private static final Set<String> INACTIVE_TRANSACTION_STATUSES = new Set<String>{
        'Cancelled',
        'Suspended',
        'Lost',
        'PC Review',
        'Post-Closed'
    };

    public class MatchResult {
        public Id leadId;
        public Id contactId;
        public Id accountId;
        public Id transactionId;
    }

    public static String normalizePhoneNumber(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }

        String normalized = phone.replaceAll('[^0-9]', '');
        Integer len = normalized.length();
        return len > 9 ? normalized.substring(len - 9) : normalized;
    }

    public static Map<String, Id> getOpenLeadIdsByPhoneNumbers(Set<String> phoneNumbers) {
        Map<String, Id> leadIdsByPhoneNumber = new Map<String, Id>();
        Set<String> normalizedInput = getNormalizedInput(phoneNumbers);
        if (normalizedInput.isEmpty()) {
            return leadIdsByPhoneNumber;
        }

        Set<String> likePatterns = getLikePatterns(normalizedInput);
        Set<String> rawValues = new Set<String>();
        rawValues.addAll(phoneNumbers);

        // A lead in any Nurture/Nurturing status is not an active lead, so calls must never log
        // against it - they fall through to the Person Account instead. Matched with NOT LIKE
        // rather than a value list because the org carries several spellings of the same status
        // ('Nurturing', 'Nurture - Preapproval', 'Nurture-Pre-Approval', 'Nurtured', ...).
        for (Lead lead : [
            SELECT Id, Phone, MobilePhone, Corrected_Mobile__c, Corrected_Phone__c
            FROM Lead
            WHERE IsConverted = false
            AND (NOT Status LIKE '%Nurtur%')
            AND (
                Phone IN :rawValues
                OR MobilePhone IN :rawValues
                OR Corrected_Mobile__c IN :rawValues
                OR Corrected_Phone__c IN :rawValues
                OR Phone LIKE :likePatterns
                OR MobilePhone LIKE :likePatterns
                OR Corrected_Mobile__c LIKE :likePatterns
                OR Corrected_Phone__c LIKE :likePatterns
            )
            ORDER BY CreatedDate DESC, Id DESC
        ]) {
            addLeadPhone(leadIdsByPhoneNumber, normalizedInput, lead.Phone, lead.Id);
            addLeadPhone(leadIdsByPhoneNumber, normalizedInput, lead.MobilePhone, lead.Id);
            addLeadPhone(leadIdsByPhoneNumber, normalizedInput, lead.Corrected_Phone__c, lead.Id);
            addLeadPhone(leadIdsByPhoneNumber, normalizedInput, lead.Corrected_Mobile__c, lead.Id);
        }

        return leadIdsByPhoneNumber;
    }

    public static Map<String, Id> getContactIdsByPhoneNumbers(Set<String> phoneNumbers) {
        Map<String, Id> contactIdsByPhoneNumber = new Map<String, Id>();
        Set<String> normalizedInput = getNormalizedInput(phoneNumbers);
        if (normalizedInput.isEmpty()) {
            return contactIdsByPhoneNumber;
        }

        Set<String> likePatterns = getLikePatterns(normalizedInput);
        Set<String> rawValues = new Set<String>();
        rawValues.addAll(phoneNumbers);

        for (Contact contact : [
            SELECT Id, Phone, MobilePhone, Corrected_Mobile__c, Corrected_Phone__c
            FROM Contact
            WHERE (
                Phone IN :rawValues
                OR MobilePhone IN :rawValues
                OR Corrected_Mobile__c IN :rawValues
                OR Corrected_Phone__c IN :rawValues
                OR Phone LIKE :likePatterns
                OR MobilePhone LIKE :likePatterns
                OR Corrected_Mobile__c LIKE :likePatterns
                OR Corrected_Phone__c LIKE :likePatterns
            )
            ORDER BY CreatedDate DESC, Id DESC
        ]) {
            addAnyPhone(contactIdsByPhoneNumber, normalizedInput, contact.Phone, contact.Id);
            addAnyPhone(contactIdsByPhoneNumber, normalizedInput, contact.MobilePhone, contact.Id);
            addAnyPhone(contactIdsByPhoneNumber, normalizedInput, contact.Corrected_Phone__c, contact.Id);
            addAnyPhone(contactIdsByPhoneNumber, normalizedInput, contact.Corrected_Mobile__c, contact.Id);
        }

        return contactIdsByPhoneNumber;
    }

    public static Map<String, Id> getTransactionIdsByPhoneNumbers(Set<String> phoneNumbers) {
        Map<String, Id> transactionIdsByPhoneNumber = new Map<String, Id>();
        Set<String> normalizedInput = getNormalizedInput(phoneNumbers);
        if (normalizedInput.isEmpty()) {
            return transactionIdsByPhoneNumber;
        }

        Set<String> likePatterns = getLikePatterns(normalizedInput);
        Set<String> rawValues = new Set<String>();
        rawValues.addAll(phoneNumbers);

        for (Transaction__c transactionRow : [
            SELECT Id,
                Borrowers_Phone__c,
                Borrower_Name__r.Phone,
                Borrower_Name__r.PersonMobilePhone,
                Borrower_Name__r.PersonContact.Corrected_Mobile__c,
                Borrower_Name__r.PersonContact.Corrected_Phone__c
            FROM Transaction__c
            WHERE (
                Borrowers_Phone__c IN :rawValues
                OR Borrowers_Phone__c LIKE :likePatterns
                OR Borrower_Name__r.Phone IN :rawValues
                OR Borrower_Name__r.Phone LIKE :likePatterns
                OR Borrower_Name__r.PersonMobilePhone IN :rawValues
                OR Borrower_Name__r.PersonMobilePhone LIKE :likePatterns
                OR Borrower_Name__r.PersonContact.Corrected_Mobile__c IN :rawValues
                OR Borrower_Name__r.PersonContact.Corrected_Mobile__c LIKE :likePatterns
                OR Borrower_Name__r.PersonContact.Corrected_Phone__c IN :rawValues
                OR Borrower_Name__r.PersonContact.Corrected_Phone__c LIKE :likePatterns
            )
            AND Status__c NOT IN :INACTIVE_TRANSACTION_STATUSES
            ORDER BY CreatedDate DESC, Id DESC
        ]) {
            addAnyPhone(transactionIdsByPhoneNumber, normalizedInput, transactionRow.Borrowers_Phone__c, transactionRow.Id);
            addAnyPhone(transactionIdsByPhoneNumber, normalizedInput, transactionRow.Borrower_Name__r.Phone, transactionRow.Id);
            addAnyPhone(transactionIdsByPhoneNumber, normalizedInput, transactionRow.Borrower_Name__r.PersonMobilePhone, transactionRow.Id);
            addAnyPhone(transactionIdsByPhoneNumber, normalizedInput, transactionRow.Borrower_Name__r.PersonContact.Corrected_Mobile__c, transactionRow.Id);
            addAnyPhone(transactionIdsByPhoneNumber, normalizedInput, transactionRow.Borrower_Name__r.PersonContact.Corrected_Phone__c, transactionRow.Id);
        }

        return transactionIdsByPhoneNumber;
    }

    public static Map<Id, Id> getAccountIdsByContactIds(Set<Id> contactIds) {
        Map<Id, Id> accountIdsByContactId = new Map<Id, Id>();
        if (contactIds == null || contactIds.isEmpty()) {
            return accountIdsByContactId;
        }

        for (Contact contact : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds
        ]) {
            accountIdsByContactId.put(contact.Id, contact.AccountId);
        }
        return accountIdsByContactId;
    }

    public static Map<Id, Id> getMostRecentActiveTransactionByAccountIds(Set<Id> accountIds) {
        Map<Id, Id> transactionByAccountId = new Map<Id, Id>();
        if (accountIds == null || accountIds.isEmpty()) {
            return transactionByAccountId;
        }

        for (Transaction__c transactionRow : [
            SELECT Id, Borrower_Name__c
            FROM Transaction__c
            WHERE Borrower_Name__c IN :accountIds
            AND Status__c NOT IN :INACTIVE_TRANSACTION_STATUSES
            ORDER BY CreatedDate DESC, Id DESC
        ]) {
            if (!transactionByAccountId.containsKey(transactionRow.Borrower_Name__c)) {
                transactionByAccountId.put(transactionRow.Borrower_Name__c, transactionRow.Id);
            }
        }
        return transactionByAccountId;
    }

    private static void addLeadPhone(Map<String, Id> outputMap, Set<String> normalizedInput, String rawPhone, Id recordId) {
        String normalized = normalizePhoneNumber(rawPhone);
        if (String.isBlank(normalized) || !normalizedInput.contains(normalized)) {
            return;
        }
        if (!outputMap.containsKey(normalized)) {
            outputMap.put(normalized, recordId);
        }
    }

    private static void addAnyPhone(Map<String, Id> outputMap, Set<String> normalizedInput, String rawPhone, Id recordId) {
        String normalized = normalizePhoneNumber(rawPhone);
        if (String.isBlank(normalized) || !normalizedInput.contains(normalized)) {
            return;
        }
        if (!outputMap.containsKey(normalized)) {
            outputMap.put(normalized, recordId);
        }
    }

    private static Set<String> getNormalizedInput(Set<String> rawPhoneNumbers) {
        Set<String> normalizedInput = new Set<String>();
        if (rawPhoneNumbers == null || rawPhoneNumbers.isEmpty()) {
            return normalizedInput;
        }

        for (String raw : rawPhoneNumbers) {
            String normalized = normalizePhoneNumber(raw);
            if (!String.isBlank(normalized)) {
                normalizedInput.add(normalized);
            }
        }
        return normalizedInput;
    }

    private static Set<String> getLikePatterns(Set<String> normalizedNumbers) {
        Set<String> likePatterns = new Set<String>();
        for (String normalized : normalizedNumbers) {
            if (String.isBlank(normalized)) {
                continue;
            }

            // Match digits in-order, allowing formatting characters between them.
            // Example normalized "135551111" -> pattern "%1%3%5%5%5%1%1%1%1%"
            String pattern = '%';
            for (Integer i = 0; i < normalized.length(); i++) {
                pattern += normalized.substring(i, i + 1) + '%';
            }
            likePatterns.add(pattern);
        }
        return likePatterns;
    }
}