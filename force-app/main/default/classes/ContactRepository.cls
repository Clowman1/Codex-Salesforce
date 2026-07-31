public with sharing class ContactRepository {
    private static ContactRepository self;

    public static ContactRepository getInstance() {
        if (self == null) {
            self = new ContactRepository();
        }
        return self;
    }

    /**
     * Selects Contacts by email for borrower portal opt-out processing.
     */
    public List<Contact> selectByEmailsForEmailOptOut(Set<String> emails) {
        if (emails == null || emails.isEmpty()) {
            return new List<Contact>();
        }

        return [
            SELECT Id, Email, HasOptedOutOfEmail
            FROM Contact
            WHERE Email IN :emails
            WITH SYSTEM_MODE
        ];
    }
}