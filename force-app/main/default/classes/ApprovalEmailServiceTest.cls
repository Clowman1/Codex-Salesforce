/**
 * Created by Akram on 12/8/2020.
 */
@isTest
public with sharing class ApprovalEmailServiceTest {
    @isTest
    public static void ApprovalServiceSubjectTest(){
        // Create a new email, envelope object
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        email.subject = 'We have your shipment 770294346071.';
        email.fromName = 'test test';
        email.plainTextBody = 'Loan Number: R3123456 Package Type: Initial Disclosure (';
        envelope.fromAddress = 'user@acme.com';

        Messaging.InboundEmail.BinaryAttachment attachment = new Messaging.InboundEmail.BinaryAttachment();
        attachment.body = blob.valueOf('my attachment text');
        attachment.fileName = 'textfileone.pdf';
        attachment.mimeTypeSubType = 'application/pdf';
        email.binaryAttachments = new Messaging.inboundEmail.BinaryAttachment[] { attachment };

        test.startTest();
        // setup controller object
        ApprovalEmailService catcher = new ApprovalEmailService();
        try {
        Messaging.InboundEmailResult result = catcher.handleInboundEmail(email, envelope);
        } catch (Exception e) {}
        test.stopTest();
        //System.assertEquals( result.success  ,false);
    }

}