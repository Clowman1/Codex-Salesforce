({
    getEmailHtmlBodyHelper: function(component) {
        try {
            const action = component.get('c.getHtmlForTemplate');
            action.setParams({
                loanId: component.get('v.recordId'),
                templateName: component.get('v.templateId')
            });
            action.setCallback(this, function (res) {
                if(res.getState() === 'SUCCESS'){
                    try {
                        const body = res.getReturnValue().htmlBody;
                        const startMarker = '<span class="container"></span>';
                        const endMarker = '<span class="end-container"></span>';
                        const startIndex = body.indexOf(startMarker);
                        const endIndex = body.lastIndexOf(endMarker);
                        const hasEditableMarkers = startIndex >= 0 && endIndex > startIndex;
                        const sectionOne = hasEditableMarkers ? body.substring(0, startIndex) : '';
                        const bodySection = hasEditableMarkers ? body.substring(startIndex, endIndex) : body;
                        const lastSection = hasEditableMarkers ? body.substring(endIndex, body.length) : '';
                        component.set('v.emailSubjectLine',res.getReturnValue().subject);
                        component.set('v.sectionOneHtml',sectionOne);
                        component.set('v.lastSectionHtml',lastSection);
                        component.set('v.email', bodySection);
                    } catch (e) {
                        this.showToast('Error in parsing email template body', 'error', 'Error');
                        console.log('error in parsing email template body in Conditions Viewer component', e);
                    }
                }
            });
            $A.enqueueAction(action);
        } catch (e) {
            console.log('error in get email html body helper in Conditions Viewer component', e);
        }
    },
    parseEmailTemplateString: function(component) {
        try {
            const emailTemplates = component.get('v.emailTemplates');
            if (!emailTemplates) {
                return;
            }

            component.set('v.emailTemplatesParsed', JSON.parse(emailTemplates));
        } catch (e) {
            console.log('error in parsing email template names in Conditions Viewer component', e);
        }
    },
    sendEmailHelper: function(component) {
        try {
            const conditionType = component.get('v.conditionType');
            const sectionOneOfHtml = component.get('v.sectionOneHtml');
            const bodySectionOfHtml = this.getCurrentEmailBody(component);
            const lastSectionOfHtml = component.get('v.lastSectionHtml');
            const recordId = component.get('v.recordId');

            const senderEmail = component.get('v.senderEmail');
            const emailToAddresses = this.getBorrowerAndCoBorrowerEmail(component);
            const subject = component.find('subjectLine').get('v.value');
            const htmlBody = sectionOneOfHtml + bodySectionOfHtml + lastSectionOfHtml;
            const action = component.get('c.sendConditionsEmail');
            const ccAddresses = this.validateEmail(component,component.get('v.ccAddresses'));
            const bccAddresses = this.validateEmail(component,component.get('v.bccAddresses'));
            const ccAddressEmailList = this.validateEmail(component,component.get('v.ccAddresses')).emailList;
            const bccAddressEmailList = this.validateEmail(component,component.get('v.bccAddresses')).emailList;
            const attachmentContentVersionIds = this.getSelectedAttachmentVersionIds(component);

            if(!ccAddresses.isValid || !bccAddresses.isValid) {
                return
            }

            action.setParams({
                parameters: {
                    recordId,
                    conditionType,
                    templateName: component.get('v.templateId'),
                    subject,
                    htmlBody,
                    emailToAddresses,
                    senderEmail,
                    ccAddressEmailList,
                    bccAddressEmailList,
                    attachmentContentVersionIds
                }
            });
            action.setCallback(this,function(res){
                if(res.getState() === 'SUCCESS') {
                    component.find('overlayLib2').notifyClose();
                    let appEvent = $A.get("e.c:RefreshEvent");
                    appEvent.fire();
                    this.showToast('Email has been sent','success');
                } else {
                    console.log(res.getError());
                    let errorMsg = res.getError()[0].message;
                    if (errorMsg.includes('The from address does not match a verified Sender Identity.') ||
                        errorMsg.includes('The from object must be provided for every email send.') ||
                        errorMsg.includes('The from email does not contain a valid address.')) {
                        this.showToast('Please enter a valid sender.', 'error', 'Error');
                    } else if(errorMsg.includes('The to array is required for all personalization objects')) {
                        this.showToast('Please pick a valid recipient to send to.', 'error', 'Error');
                    } else if (errorMsg.includes('There was an error retrieving the current user email')) {
                        this.showToast('There was an error retrieving the current user email', 'error', 'Error');
                    } else {
                        this.showToast('Uh oh an error occurred, please try again later.', 'error', 'Error');
                    }
                }
            });
            $A.enqueueAction(action);
        } catch (e) {
            console.log('error in send email helper in Conditions Viewer component', e);
        }
    },
    getCurrentEmailBody: function(component) {
        const editor = component.find('emailBodyEditor');
        if (editor) {
            const liveValue = editor.get('v.value');
            component.set('v.email', liveValue);
            return liveValue;
        }
        return component.get('v.email');
    },
    getPdfAttachmentsHelper: function(component, contentDocumentIds) {
        try {
            const action = component.get('c.getPdfAttachmentsForContentDocuments');
            component.set('v.isLoadingAttachments', true);
            action.setParams({
                contentDocumentIds
            });
            action.setCallback(this, function(res) {
                component.set('v.isLoadingAttachments', false);
                if (res.getState() === 'SUCCESS') {
                    const existingAttachments = component.get('v.pdfAttachments') || [];
                    component.set('v.pdfAttachments', existingAttachments.concat(res.getReturnValue() || []));
                } else {
                    this.showToast('Unable to attach uploaded PDF.', 'error', 'Error');
                    console.log('error loading PDF attachments in Conditions Email Modal', res.getError());
                }
            });
            $A.enqueueAction(action);
        } catch (e) {
            component.set('v.isLoadingAttachments', false);
            console.log('error in get PDF attachments helper in Conditions Email Modal component', e);
        }
    },
    handlePdfUploadFinishedHelper: function(component, event) {
        const uploadedFiles = event.getParam('files') || [];
        const contentDocumentIds = uploadedFiles
            .map((file) => file.documentId)
            .filter((documentId) => !!documentId);

        if (contentDocumentIds.length === 0) {
            this.showToast('PDF upload finished, but no attachment ID was returned.', 'error', 'Error');
            return;
        }

        this.showToast(
            uploadedFiles.length === 1 ? 'PDF uploaded and attached to this email.' : 'PDFs uploaded and attached to this email.',
            'success',
            'Uploaded'
        );
        this.getPdfAttachmentsHelper(component, contentDocumentIds);
    },
    getSelectedAttachmentVersionIds: function(component) {
        return (component.get('v.pdfAttachments') || [])
            .map((attachment) => attachment.contentVersionId)
            .filter((versionId) => !!versionId);
    },
    validateEmail: function (component, additionalEmails) {
        let emailList = [];
        if (additionalEmails) {
            let splitAdditionalEmails = additionalEmails.split(/[,;]+/);
            for (const element of splitAdditionalEmails) {
                let trimmedEmails = element.trim();
                if (this.validateEmailRegex(trimmedEmails)) {
                    emailList.push(trimmedEmails);
                } else {
                    this.showToast(trimmedEmails + " is not a valid email.", "error", "Error")
                    return {isValid: false, emailList: emailList};
                }

            }
            return {isValid: true, emailList: emailList}
        }
        return {isValid: true, emailList: emailList};
    },

    validateEmailRegex: function(email) {
        let regex = /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
        return regex.test(String(email).toLowerCase());
    },

    getEmailSendersHelper: function(component) {
        try {
            const recordId = component.get('v.recordId');
            const className = component.get('v.emailSendersClassAPIName');
            if (!className) {
                return;
            }

            const action = component.get(`c.getEmailSenders`);
            action.setParams({
                parameters: {
                    recordId,
                    className
                }
            });
            action.setCallback(this, function (res) {
                if (res.getState() === 'SUCCESS') {
                    const emailSenders = res.getReturnValue();
                    if (emailSenders) {
                        component.set('v.emailSenders', emailSenders);
                    }
                } else if (res.getState() === 'ERROR') {
                    this.showToast(
                        'Error in getting email senders from provided class. ' +
                        'The email will be sent from a current user email address.',
                        'error',
                        'Error'
                    );
                    console.log('error in get Email Senders apex method in Conditions Email Modal component', res.getError());
                }

            });
            $A.enqueueAction(action);
        } catch (e) {
            console.log('error in get Email Senders helper in Conditions Email Modal component', e);
        }
    },
    selectSenderEmailHelper: function(component, event) {
        try {
            const senderEmail = event.getSource().get('v.value');
            component.set('v.senderEmail', senderEmail);
        } catch (e) {
            console.log('error in select sender email helper in Conditions Email Modal component', e);
        }
    },
    showToast : function(message, type, title) {
        const toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title: title,
            mode: 'dismissible',
            message: message,
            type: type
        });
        toastEvent.fire();
    },
    getBorrowerAndCoBorrowerEmail : function(c) {
        let emailsToSend = [];
        try {
            if(c.get('v.application.Borrower_Email__c') != null){
                if(c.find('sendToBorrower').get('v.checked')){
                    emailsToSend.push(c.get('v.application.Borrower_Email__c'));
                }
            }
            if(c.get('v.application.Email_Co_Borrower__c') != null){
                if(c.find('sendToCoBorrower').get('v.checked')){
                    emailsToSend.push(c.get('v.application.Email_Co_Borrower__c'));
                }
            }
            if(c.get('v.application.Owner.Email') != null){
                if(c.find('sendToLoanOfficer').get('v.checked')){
                    emailsToSend.push(c.get('v.application.Owner.Email'));
                }
            }
        } catch (e) {
            console.log('error in get borrower email in Conditions Viewer component', e);
        }
        return emailsToSend;
    },
});
