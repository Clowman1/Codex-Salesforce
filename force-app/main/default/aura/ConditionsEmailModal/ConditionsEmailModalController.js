({
    doInit: function (c,e,h) {
        h.getEmailSendersHelper(c);
        h.parseEmailTemplateString(c);
    },
    getEmailHtmlBody : function(c,e,h) {
        h.getEmailHtmlBodyHelper(c);
    },
    selectSenderEmailHandler : function(c,e,h) {
        h.selectSenderEmailHelper(c,e);
    },
    sendEmail : function(c,e,h){
        h.sendEmailHelper(c);
    },
    handlePdfUploadFinished : function(c,e,h){
        h.handlePdfUploadFinishedHelper(c,e);
    },
});
