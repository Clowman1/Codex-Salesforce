global with sharing class SendEmailInvocable {
    global class Request {
        @InvocableVariable
        global String fromAddress;

        @InvocableVariable
        global String recordId;

        @InvocableVariable
        global String templateId;

        @InvocableVariable
        global List<String> toAddresses;
    }

    @InvocableMethod(label='Send Email Invocable')
    global static void send(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> outbound = new List<Messaging.SingleEmailMessage>();
        for (Request req : requests) {
            if (req == null || String.isBlank(req.templateId) || String.isBlank(req.recordId) || req.toAddresses == null || req.toAddresses.isEmpty()) {
                continue;
            }

            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(
                (Id) req.templateId,
                UserInfo.getUserId(),
                (Id) req.recordId
            );

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(req.toAddresses);
            mail.setSubject(rendered.getSubject());
            mail.setHtmlBody(processConditionEmailBody(rendered.getHtmlBody(), (Id) req.recordId));
            if (String.isNotBlank(req.fromAddress)) {
                mail.setReplyTo(req.fromAddress);
            }
            mail.setSaveAsActivity(false);
            outbound.add(mail);
        }

        if (!outbound.isEmpty()) {
            Messaging.sendEmail(outbound, false);
        }
    }

    @TestVisible
    private static String processConditionEmailBody(String htmlBody, Id recordId) {
        if (recordId == null || recordId.getSObjectType() != Condition__c.SObjectType) {
            return htmlBody;
        }

        List<Condition__c> conditions = [
            SELECT
                Transaction__c,
                Transaction__r.Portal_Hash_Parameter__c,
                Transaction__r.Processor__r.Name,
                Transaction__r.Processor__r.FirstName,
                Transaction__r.Processor__r.LastName,
                Transaction__r.Processor__r.Title,
                Transaction__r.Processor__r.Phone,
                Transaction__r.Processor__r.MobilePhone,
                Transaction__r.Processor__r.Email,
                Transaction__r.Processor__r.Fax,
                Transaction__r.Processor__r.NMLS__c,
                Transaction__r.Processor__r.Headshot_URL__c
            FROM Condition__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (conditions.isEmpty()) {
            return htmlBody;
        }

        Condition__c conditionRecord = conditions[0];
        String body = replaceBorrowerPortalLinks(
            htmlBody == null ? '' : htmlBody,
            buildBorrowerPortalUrl(conditionRecord)
        );
        if (conditionRecord.Transaction__r?.Processor__r == null) {
            return body;
        }

        String signature = buildProcessorSignature(conditionRecord.Transaction__r.Processor__r);
        if (String.isBlank(signature)) {
            return body;
        }

        Integer bodyCloseIndex = body.toLowerCase().lastIndexOf('</body>');
        if (bodyCloseIndex >= 0) {
            return body.substring(0, bodyCloseIndex) + signature + body.substring(bodyCloseIndex);
        }
        return body + signature;
    }

    @TestVisible
    private static String appendProcessorSignatureForCondition(String htmlBody, Id recordId) {
        return processConditionEmailBody(htmlBody, recordId);
    }

    @TestVisible
    private static String replaceBorrowerPortalLinks(String htmlBody, String borrowerPortalUrl) {
        if (String.isBlank(htmlBody) || String.isBlank(borrowerPortalUrl)) {
            return htmlBody;
        }

        String safeBorrowerPortalUrl = htmlEncode(borrowerPortalUrl);
        String updatedBody = htmlBody.replace(
            'href="https://reachhomeloans.my.site.com/documents"',
            'href="' + safeBorrowerPortalUrl + '"'
        );
        updatedBody = updatedBody.replace(
            'href="https://reachhomeloans.my.site.com/documents/s/?id="',
            'href="' + safeBorrowerPortalUrl + '"'
        );
        return updatedBody;
    }

    private static String buildBorrowerPortalUrl(Condition__c conditionRecord) {
        if (conditionRecord == null || conditionRecord.Transaction__c == null) {
            return null;
        }

        String portalHash = conditionRecord.Transaction__r?.Portal_Hash_Parameter__c;
        if (String.isBlank(portalHash)) {
            portalHash = BorrowerPortalService.encryptTransactionId(conditionRecord.Transaction__c);
            update new Transaction__c(
                Id = conditionRecord.Transaction__c,
                Portal_Hash_Parameter__c = portalHash
            );
        }

        return BorrowerPortalLinkService.buildBorrowerHomeUrl(portalHash);
    }

    @TestVisible
    private static String buildProcessorSignature(User processor) {
        if (processor == null) {
            return '';
        }

        String displayName = processor.Name;
        if (String.isBlank(displayName)) {
            List<String> nameParts = new List<String>();
            if (!String.isBlank(processor.FirstName)) {
                nameParts.add(processor.FirstName);
            }
            if (!String.isBlank(processor.LastName)) {
                nameParts.add(processor.LastName);
            }
            displayName = String.join(nameParts, ' ');
        }
        if (String.isBlank(displayName)) {
            return '';
        }

        String photoUrl = htmlEncode(processor.Headshot_URL__c);
        String title = htmlEncode(processor.Title);
        String phone = htmlEncode(FormattingUtility.formatPhone(processor.Phone));
        String mobilePhone = htmlEncode(FormattingUtility.formatPhone(processor.MobilePhone));
        String fax = htmlEncode(FormattingUtility.formatPhone(processor.Fax));
        String email = htmlEncode(processor.Email);
        String nmls = htmlEncode(processor.NMLS__c);

        List<String> detailLines = new List<String>();
        if (!String.isBlank(title)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">' + title + '</div>');
        }
        if (!String.isBlank(phone)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">Direct: ' + phone + '</div>');
        } else if (!String.isBlank(mobilePhone)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">Mobile: ' + mobilePhone + '</div>');
        }
        if (!String.isBlank(email)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;"><a href="mailto:' + email + '" style="color:#1a2541;text-decoration:none;">' + email + '</a></div>');
        }
        if (!String.isBlank(fax)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">Fax: ' + fax + '</div>');
        }
        if (!String.isBlank(nmls)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">NMLS #' + nmls + '</div>');
        }

        String imageMarkup = String.isBlank(photoUrl)
            ? ''
            : '<td style="padding-right:14px;vertical-align:top;width:82px;">'
                + '<img src="' + photoUrl + '" alt="' + htmlEncode(displayName) + '" width="72" height="72" '
                + 'style="display:block;border-radius:50%;width:72px;height:72px;object-fit:cover;">'
                + '</td>';

        return '<br/><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="font-family:Arial,sans-serif;color:#1f2937;">'
            + '<tr>'
            + imageMarkup
            + '<td style="vertical-align:top;">'
            + '<div style="font-size:15px;line-height:20px;font-weight:bold;color:#1a2541;">' + htmlEncode(displayName) + '</div>'
            + String.join(detailLines, '')
            + '</td>'
            + '</tr>'
            + '</table>';
    }

    private static String htmlEncode(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }
}