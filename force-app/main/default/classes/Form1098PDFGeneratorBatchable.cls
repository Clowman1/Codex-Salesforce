public class Form1098PDFGeneratorBatchable implements Database.Batchable<SObject>, Database.Stateful {

    public Form1098PDFGeneratorBatchable(Id transactionId) {
        this.transactionId = transactionId;
    }

    public Form1098PDFGeneratorBatchable() {
        this.transactionId = null;
    }

    // Static fields for your information
    private static final String EMAIL_SUBJECT = 'Your 1098 Mortgage Interest Document from Reach Home Loans';
    private static final String EMAIL_BODY_TEMPLATE = 'Dear {0},\n\n' +
        'I hope this message finds you well.\n\n' +
        'I am reaching out to inform you that your 1098 mortgage interest document is now available. ' +
        'This document details the mortgage interest you paid to Reach Home Loans during the last tax year and is essential for your tax preparation.\n\n' +
        'You can access your document through the following link: {1}. ' +
        'Please review it at your earliest convenience and let me know if you have any questions or need further assistance.\n\n' +
        'Thank you for your attention, and I look forward to hearing from you soon.\n\n' +
        'Best regards.\n';

    // Your static data (update these with your actual information)
    private static final String MY_NAME = 'John Doe';
    private static final String MY_POSITION = 'Mortgage Specialist';
    private static final String MY_COMPANY = 'Reach Home Loans';
    private static final String MY_EMAIL_ADDRESS = 'john.doe@reachhomeloans.com';
    private Id transactionId;
    // Start method to query Transaction__c records where Form_recipient__c is true
    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug('Batch Start Method Invoked');

        String query = 'SELECT Id, Loan_Number__c, Borrower_Last_Name__c, Borrower_First_Name__c, Borr_Email__c FROM Transaction__c';
        if (transactionId != null) {
            query += ' WHERE Id = :transactionId';
        } else {
            query += ' WHERE Form_recipient__c = TRUE';
        }

        return Database.getQueryLocator(query);
    }

    // Execute method to process batches of records
    public void execute(Database.BatchableContext BC, List<Transaction__c> scope) {
        System.debug('Batch Execute Method Invoked with scope size: ' + scope.size());

        List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();
        List<ContentDocumentLink> contentDocumentLinksToInsert = new List<ContentDocumentLink>();
        List<ContentDistribution> contentDistributionsToInsert = new List<ContentDistribution>();
        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Map to track transactions and their ContentDocuments
        Map<Id, Transaction__c> transactionMap = new Map<Id, Transaction__c>();
        for(Transaction__c tr : scope) {
            transactionMap.put(tr.Id, tr);
        }

        // Map to track ContentDocumentId to Transaction__c Id
        Map<Id, Id> contentDocumentIdToTransactionIdMap = new Map<Id, Id>();

        // Step 1: Generate PDFs and create ContentVersions
        for(Transaction__c tr : scope) {
            System.debug('Processing Transaction__c record: ' + tr.Id);

            // Generate PDFs
            Blob pdfBlobA;
            Blob pdfBlobB;

            if(!Test.isRunningTest()) {
                try {
                    // Generate Form A PDF
                    PageReference pdfPageA = Page.Form1098A_page;
                    pdfPageA.getParameters().put('id', tr.Id);
                    pdfBlobA = pdfPageA.getContentAsPDF();
                    System.debug('Generated Form A PDF for Transaction ID: ' + tr.Id);

                    // Generate Form B PDF
                    PageReference pdfPageB = Page.Form1098B_page;
                    pdfPageB.getParameters().put('id', tr.Id);
                    pdfBlobB = pdfPageB.getContentAsPDF();
                    System.debug('Generated Form B PDF for Transaction ID: ' + tr.Id);

                } catch (Exception e) {
                    System.debug('Error generating PDFs for Transaction ID: ' + tr.Id + ', Error: ' + e.getMessage());
                    continue; // Skip this record and proceed to the next
                }
            } else {
                // Use dummy data during testing
                pdfBlobA = Blob.valueOf('Test PDF A');
                pdfBlobB = Blob.valueOf('Test PDF B');
            }

            // Create ContentVersion for Form A
            ContentVersion cvA = new ContentVersion();
            cvA.Title = tr.Borrower_Last_Name__c + ' - ' + tr.Loan_Number__c + ' 1098 Form A';
            cvA.PathOnClient = tr.Borrower_Last_Name__c + '_1098A.pdf';
            cvA.VersionData = pdfBlobA;
            contentVersionsToInsert.add(cvA);

            // Create ContentVersion for Form B
            ContentVersion cvB = new ContentVersion();
            cvB.Title = tr.Borrower_Last_Name__c + ' - ' + tr.Loan_Number__c + ' 1098 Form B';
            cvB.PathOnClient = tr.Borrower_Last_Name__c + '_1098B.pdf';
            cvB.VersionData = pdfBlobB;
            contentVersionsToInsert.add(cvB);

            System.debug('Prepared ContentVersions for Transaction ID: ' + tr.Id);
        }

        // Insert ContentVersion records
        try {
            if (!contentVersionsToInsert.isEmpty()) {
                insert contentVersionsToInsert;
                System.debug('Inserted ContentVersions: ' + contentVersionsToInsert.size());
            }
        } catch (DmlException e) {
            System.debug('Error inserting ContentVersions: ' + e.getMessage());
        }

        // Retrieve ContentDocumentIds for the inserted ContentVersions
        List<ContentDocument> contentDocuments = new List<ContentDocument>();
        try {
            contentDocuments = [SELECT Id, Title, LatestPublishedVersionId
                                FROM ContentDocument
                                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersionsToInsert)];
            System.debug('Retrieved ContentDocuments: ' + contentDocuments.size());
        } catch (Exception e) {
            System.debug('Error retrieving ContentDocuments: ' + e.getMessage());
        }

        Map<String, ContentDocument> titleToContentDocumentMap = new Map<String, ContentDocument>();
        for(ContentDocument cd : contentDocuments) {
            titleToContentDocumentMap.put(cd.Title, cd);
        }

        // Create ContentDocumentLink to associate files with Transaction__c
        for(Transaction__c tr : scope) {
            String titleA = tr.Borrower_Last_Name__c + ' - ' + tr.Loan_Number__c + ' 1098 Form A';
            String titleB = tr.Borrower_Last_Name__c + ' - ' + tr.Loan_Number__c + ' 1098 Form B';

            ContentDocument cdA = titleToContentDocumentMap.get(titleA);
            ContentDocument cdB = titleToContentDocumentMap.get(titleB);

            if(cdA != null) {
                ContentDocumentLink cdlA = new ContentDocumentLink();
                cdlA.ContentDocumentId = cdA.Id;
                cdlA.LinkedEntityId = tr.Id;
                cdlA.ShareType = 'V'; // Viewer
                cdlA.Visibility = 'AllUsers';
                contentDocumentLinksToInsert.add(cdlA);
                // Map ContentDocumentId to Transaction__c Id
                contentDocumentIdToTransactionIdMap.put(cdA.Id, tr.Id);
            }

            if(cdB != null) {
                ContentDocumentLink cdlB = new ContentDocumentLink();
                cdlB.ContentDocumentId = cdB.Id;
                cdlB.LinkedEntityId = tr.Id;
                cdlB.ShareType = 'V'; // Viewer
                cdlB.Visibility = 'AllUsers';
                contentDocumentLinksToInsert.add(cdlB);
                // Map ContentDocumentId to Transaction__c Id
                contentDocumentIdToTransactionIdMap.put(cdB.Id, tr.Id);
            }

            System.debug('Prepared ContentDocumentLinks for Transaction ID: ' + tr.Id);
        }

        // Insert ContentDocumentLink records
        try {
            if (!contentDocumentLinksToInsert.isEmpty()) {
                insert contentDocumentLinksToInsert;
                System.debug('Inserted ContentDocumentLinks: ' + contentDocumentLinksToInsert.size());
            }
        } catch (DmlException e) {
            System.debug('Error inserting ContentDocumentLinks: ' + e.getMessage());
        }

        // Create ContentDistribution for generating public links for Form B
        for(Transaction__c tr : scope) {
            String titleB = tr.Borrower_Last_Name__c + ' - ' + tr.Loan_Number__c + ' 1098 Form B';
            ContentDocument cdB = titleToContentDocumentMap.get(titleB);
            if(cdB == null) {
                System.debug('ContentDocument for Form B not found for Transaction ID: ' + tr.Id);
                continue;
            }

            // Get ContentVersionId
            ContentVersion cvB;
            try {
                cvB = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :cdB.Id ORDER BY VersionNumber DESC LIMIT 1];
            } catch (Exception e) {
                System.debug('Error retrieving ContentVersion for ContentDocumentId: ' + cdB.Id + ', Error: ' + e.getMessage());
                continue;
            }

            // Create ContentDistribution
            ContentDistribution cd = new ContentDistribution();
            cd.Name = tr.Borrower_Last_Name__c + ' - ' + tr.Loan_Number__c + ' 1098 Form B';
            cd.ContentVersionId = cvB.Id;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesLinkLatestVersion = true;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = false;
            cd.PreferencesAllowOriginalDownload = true;
            contentDistributionsToInsert.add(cd);

            System.debug('Prepared ContentDistribution for Transaction ID: ' + tr.Id);
        }

        // Insert ContentDistribution records
        try {
            if (!contentDistributionsToInsert.isEmpty()) {
                insert contentDistributionsToInsert;
                System.debug('Inserted ContentDistributions: ' + contentDistributionsToInsert.size());
            }
        } catch (DmlException e) {
            System.debug('Error inserting ContentDistributions: ' + e.getMessage());
        }

        // Map to store ContentDistribution records by ContentVersionId
        Map<Id, ContentDistribution> cdMap = new Map<Id, ContentDistribution>();
        try {
            for(ContentDistribution cd : [SELECT Id, ContentVersionId, DistributionPublicUrl FROM ContentDistribution WHERE Id IN :contentDistributionsToInsert]) {
                cdMap.put(cd.ContentVersionId, cd);
            }
            System.debug('Retrieved ContentDistributions: ' + cdMap.size());
        } catch (Exception e) {
            System.debug('Error retrieving ContentDistributions: ' + e.getMessage());
        }

        // Prepare Emails with links to Form B
        for(ContentDistribution cd : contentDistributionsToInsert) {
            try {
                ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cd.ContentVersionId LIMIT 1];

                // Use the map to get the Transaction__c Id
                Id transactionId = contentDocumentIdToTransactionIdMap.get(cv.ContentDocumentId);

                if(transactionId == null) {
                    System.debug('Transaction__c record not found for ContentDocumentId: ' + cv.ContentDocumentId);
                    continue;
                }

                Transaction__c tr = transactionMap.get(transactionId);

                if(tr == null) {
                    System.debug('Transaction__c record not found in transactionMap for Id: ' + transactionId);
                    continue;
                }

                // Use the DistributionPublicUrl directly
                String publicUrl = cdMap.get(cd.ContentVersionId).DistributionPublicUrl;
                System.debug('Public URL for Transaction ID ' + tr.Id + ': ' + publicUrl);

                // Personalize client name
                String clientName = String.isNotBlank(tr.Borrower_First_Name__c) ? tr.Borrower_First_Name__c : tr.Borrower_Last_Name__c;

                // Format the email body
                String emailBody = String.format(EMAIL_BODY_TEMPLATE, new List<String>{
                    clientName,
                    publicUrl
                    //, MY_NAME,
                    //MY_POSITION,
                    //MY_COMPANY,
                    //MY_EMAIL_ADDRESS
                });

                // Create the Email message
                if (String.isNotBlank(tr.Borr_Email__c)) {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new String[] { tr.Borr_Email__c });
                    email.setSubject(EMAIL_SUBJECT);
                    email.setPlainTextBody(emailBody);
                    emailsToSend.add(email);
                    email.setReplyTo('admin@reachhomeloans.com');
                    System.debug('Prepared email for Transaction ID: ' + tr.Id);
                } else {
                    System.debug('No email address found for Transaction ID: ' + tr.Id);
                }

                // Update flags
                tr.Form_recipient__c = false;
                tr.Form_Sent__c = true;
                transactionsToUpdate.add(tr);

            } catch (Exception e) {
                System.debug('Error preparing email for ContentDistribution ID: ' + cd.Id + ', Error: ' + e.getMessage());
            }
        }

        // Send all emails
        try {
            if (!emailsToSend.isEmpty()) {
                Messaging.sendEmail(emailsToSend);
                System.debug('Sent emails: ' + emailsToSend.size());
            } else {
                System.debug('No emails to send.');
            }
        } catch (Exception e) {
            System.debug('Error sending emails: ' + e.getMessage());
        }

        // Update Transaction__c records
        try {
            if (!transactionsToUpdate.isEmpty()) {
                update transactionsToUpdate;
                System.debug('Updated Transaction__c records: ' + transactionsToUpdate.size());
            } else {
                System.debug('No Transaction__c records to update.');
            }
        } catch (DmlException e) {
            System.debug('Error updating Transaction__c records: ' + e.getMessage());
        }
    }

    // Finish method (optional)
    public void finish(Database.BatchableContext BC) {
        System.debug('Batch Process Completed.');
    }
}