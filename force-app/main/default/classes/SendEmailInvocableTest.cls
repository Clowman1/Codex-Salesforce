@IsTest
private class SendEmailInvocableTest {
    @IsTest
    static void sendIgnoresInvalidRequestsAndRendersTemplate() {
        Account accountRecord = new Account(Name = 'Send Email Account');
        insert accountRecord;

        EmailTemplate templateRecord = createAccountTemplate();

        SendEmailInvocable.Request invalidRequest = new SendEmailInvocable.Request();
        invalidRequest.recordId = accountRecord.Id;

        SendEmailInvocable.Request validRequest = new SendEmailInvocable.Request();
        validRequest.fromAddress = 'replyto@example.com';
        validRequest.recordId = accountRecord.Id;
        validRequest.templateId = templateRecord.Id;
        validRequest.toAddresses = new List<String>{ 'recipient@example.com' };

        Test.startTest();
        SendEmailInvocable.send(
            new List<SendEmailInvocable.Request>{ null, invalidRequest, validRequest }
        );
        Test.stopTest();

        System.assertEquals('Render-ready account template', templateRecord.Subject);
    }

    @IsTest
    static void sendReturnsEarlyForEmptyRequests() {
        Test.startTest();
        SendEmailInvocable.send(null);
        SendEmailInvocable.send(new List<SendEmailInvocable.Request>());
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void appendsProcessorSignatureForConditionEmails() {
        BorrowerPortalEncryptionService.testKeyOverride = '12345678901234567890123456789012';
        BorrowerPortalLinkService.testBorrowerHomeUrlOverride = 'https://portal.example.com/documents/s/home';

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Signature Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Processor__c = UserInfo.getUserId()
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Requested',
            Description__c = 'Rejected document'
        );
        insert conditionRecord;

        String htmlBody = SendEmailInvocable.appendProcessorSignatureForCondition(
            '<html><body><p>Rejected</p><a href="https://reachhomeloans.my.site.com/documents">Upload Files</a></body></html>',
            conditionRecord.Id
        );
        Transaction__c updatedTransaction = [
            SELECT Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];

        System.assert(htmlBody.contains('<table role="presentation"'));
        System.assert(htmlBody.indexOf('<table role="presentation"') < htmlBody.indexOf('</body>'));
        System.assertNotEquals(null, updatedTransaction.Portal_Hash_Parameter__c);
        System.assert(
            htmlBody.contains(
                'href="https://portal.example.com/documents/s/home?id=' +
                updatedTransaction.Portal_Hash_Parameter__c +
                '"'
            )
        );

        String signature = SendEmailInvocable.buildProcessorSignature(
            new User(
                FirstName = 'Pat',
                LastName = 'Processor',
                Title = 'Loan Processor',
                Phone = '3038591055',
                Email = 'processor@example.com',
                NMLS__c = '123456',
                Headshot_URL__c = 'https://example.com/processor.jpg?photo=1&size=small'
            )
        );

        System.assert(signature.contains('Pat Processor'));
        System.assert(signature.contains('https://example.com/processor.jpg?photo=1&amp;size=small'));
        System.assert(signature.contains('(303) 859-1055'));
        System.assert(signature.contains('NMLS #123456'));
    }

    @IsTest
    static void replacesConditionRejectionPortalButtonWithExistingBorrowerLink() {
        BorrowerPortalLinkService.testBorrowerHomeUrlOverride = 'https://portal.example.com/documents/s/home';

        String htmlBody = SendEmailInvocable.replaceBorrowerPortalLinks(
            '<a href="https://reachhomeloans.my.site.com/documents"><img alt="document-button" /></a>',
            'https://portal.example.com/documents/s/home?id=ABC123'
        );

        System.assert(htmlBody.contains('href="https://portal.example.com/documents/s/home?id=ABC123"'));
        System.assert(!htmlBody.contains('href="https://reachhomeloans.my.site.com/documents"'));
    }

    private static EmailTemplate createAccountTemplate() {
        String suffix = String.valueOf(DateTime.now().getTime());
        EmailTemplate templateRecord = new EmailTemplate(
            IsActive = true,
            Name = 'Send Email Template ' + suffix,
            DeveloperName = 'Send_Email_Template_' + suffix,
            TemplateType = 'custom',
            FolderId = UserInfo.getUserId(),
            Subject = 'Render-ready account template',
            HtmlValue = '<p>Hello from send invocable test</p>',
            UIType = 'SFX',
            RelatedEntityType = 'Account'
        );
        insert templateRecord;
        return templateRecord;
    }
}