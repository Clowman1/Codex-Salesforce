@IsTest
private class RingSenseRelateCallInsightInvocableTest {
    @IsTest
    static void testResolveRelationshipsLeadPriorityAndFallback() {
        Account accountWithLead = new Account(Name = 'Account With Lead');
        Account fallbackOnlyAccount = new Account(Name = 'Fallback Only Account');
        insert new List<Account>{ accountWithLead, fallbackOnlyAccount };

        Contact contactWithLeadPhone = new Contact(
            FirstName = 'Lead',
            LastName = 'Contact',
            Phone = '+1 (954) 111-2222',
            AccountId = accountWithLead.Id
        );
        Contact fallbackContact = new Contact(
            FirstName = 'Fallback',
            LastName = 'Contact',
            Phone = '+1 (954) 333-4444',
            AccountId = fallbackOnlyAccount.Id
        );
        insert new List<Contact>{ contactWithLeadPhone, fallbackContact };

        Lead matchingLead = new Lead(
            FirstName = 'Priority',
            LastName = 'Lead',
            MobilePhone = '9541112222'
        );
        insert matchingLead;

        RingSenseRelateCallInsightInvocable.Input leadInput = new RingSenseRelateCallInsightInvocable.Input();
        leadInput.callInsightId = UserInfo.getUserId();
        leadInput.recipientPhoneNumber = '(954) 111-2222';

        RingSenseRelateCallInsightInvocable.Input fallbackInput = new RingSenseRelateCallInsightInvocable.Input();
        fallbackInput.callInsightId = UserInfo.getUserId();
        fallbackInput.recipientPhoneNumber = '(954) 333-4444';

        List<RingSenseRelateCallInsightInvocable.Output> outputRows = RingSenseRelateCallInsightInvocable.resolveRelationships(
            new List<RingSenseRelateCallInsightInvocable.Input>{ leadInput, fallbackInput }
        );

        System.assertEquals(2, outputRows.size());
        System.assertEquals(matchingLead.Id, outputRows[0].leadId);
        System.assertEquals(accountWithLead.Id, outputRows[0].accountId);
        System.assertEquals(null, outputRows[0].transactionId);

        System.assertEquals(null, outputRows[1].leadId);
        System.assertEquals(fallbackOnlyAccount.Id, outputRows[1].accountId);
    }
}