/**
 * Public borrower opt-out requests must be able to update matching Lead/Contact
 * records without depending on the caller having object-level access.
 */
public without sharing class BorrowerPortalOptOutService {
    public static void optOutByEmail(String email) {
        Set<String> normalizedEmails = normalizeEmails(email);
        if (normalizedEmails.isEmpty()) {
            throw new AuraHandledException('No email param');
        }

        List<Contact> contactsToUpdate = ContactRepository.getInstance().selectByEmailsForEmailOptOut(normalizedEmails);
        List<Lead> leadsToUpdate = LeadRepository.getInstance().selectByEmailsForEmailOptOut(normalizedEmails);

        List<SObject> recordsToUpdate = new List<SObject>();

        for (Contact contactRecord : contactsToUpdate) {
            if (!contactRecord.HasOptedOutOfEmail) {
                contactRecord.HasOptedOutOfEmail = true;
                recordsToUpdate.add(contactRecord);
            }
        }

        for (Lead leadRecord : leadsToUpdate) {
            if (!leadRecord.HasOptedOutOfEmail) {
                leadRecord.HasOptedOutOfEmail = true;
                recordsToUpdate.add(leadRecord);
            }
        }

        if (recordsToUpdate.isEmpty()) {
            return;
        }

        List<Database.SaveResult> saveResults =
            Database.update(recordsToUpdate, false, System.AccessLevel.SYSTEM_MODE);

        List<String> errors = new List<String>();
        for (Database.SaveResult saveResult : saveResults) {
            if (!saveResult.isSuccess()) {
                for (Database.Error saveError : saveResult.getErrors()) {
                    errors.add(saveError.getMessage());
                }
            }
        }

        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, ' '));
        }
    }

    private static Set<String> normalizeEmails(String email) {
        Set<String> normalizedEmails = new Set<String>();
        if (!String.isBlank(email)) {
            normalizedEmails.add(email.trim());
        }
        return normalizedEmails;
    }
}