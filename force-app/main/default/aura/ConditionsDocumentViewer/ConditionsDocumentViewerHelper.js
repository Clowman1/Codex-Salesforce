/**
 * Created by zeyad on 8/17/2022.
 */

// eslint-disable-next-line no-unused-expressions
({
    FILE_EXTENSION: {
        IMAGE: ['jpg', 'jpeg', 'png']
    },
    getFolders: function(component, event) {
        let action = component.get('c.getDefaultFolders');
        action.setCallback(this, function(response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    component.set('v.folders', response.getReturnValue());
                }
            }
        );
        $A.enqueueAction(action);
    },
    previewDocHelper: function(component, event) {
        try {
            const files = component.get('v.files');
            let fileExtension;
            let filePath;
            let title;
            if (event.currentTarget) {
                const fileItemIndex = event.currentTarget.dataset.identifier;
                if (fileItemIndex) {
                    fileExtension = files[fileItemIndex].FileExtension.toLowerCase();
                    filePath = this.createFileLink(files[fileItemIndex].ContentDocumentId);
                    title = files[fileItemIndex].Title;
                    component.set('v.dataIdentifier', Number.parseInt(fileItemIndex));
                }
            } else {
                fileExtension = files[0].FileExtension.toLowerCase();
                filePath = this.createFileLink(files[0].ContentDocumentId);
                title = files[0].Title;
            }
            const isImage = this.FILE_EXTENSION.IMAGE.includes(fileExtension);
            component.set('v.isImage', isImage);
            component.set('v.filePath', filePath);
            component.set('v.fileTitle', title);
        } catch ({ message }) {
            console.log('error in preview doc helper in Conditions Document Viewer', message);
        }
    },
    saveFileHelper: function(component, event) {
        try {
            const files = component.get('v.files') || [];
            if (event.currentTarget) {
                const fileItemIndex = event.currentTarget.dataset.identifier;
                const file = files[fileItemIndex];
                const helper = this;
                let action = component.get('c.updateConditionFileDetails');
                action.setParams({
                    contentDocumentId: file.ContentDocumentId,
                    title: file.Title,
                    folder: file.Folder__c
                });
                action.setCallback(this, function(response) {
                    component.set('v.showSpinner', false);
                    if (response.getState() === 'SUCCESS') {
                        file.isEditable = false;
                        files[fileItemIndex] = file;
                        component.set('v.files', files);
                        if (component.get('v.dataIdentifier') === Number.parseInt(fileItemIndex)) {
                            component.set('v.fileTitle', file.Title);
                        }
                        component.set('v.errorMessage', null);
                        const appEvent = $A.get('e.c:RefreshEvent');
                        if (appEvent) {
                            appEvent.fire();
                        }
                    } else if (response.getState() === 'ERROR') {
                        helper.setServerError(component, response);
                    }
                });
                $A.enqueueAction(action);
                component.set('v.showSpinner', true);
            }
        } catch ({ message }) {
            console.log('error in update doc helper in Conditions Document Viewer', message);
        }
    },
    createFileLink: function(fileId) {
        const fileBaseUrl = '/sfc/servlet.shepherd/document/download/';
        return fileBaseUrl + fileId;
    },
    approveHelper: function(component) {
        try {
            component.set('v.showSpinner', true);
            const conditionId = component.get('v.conditionId');
            const action = component.get('c.approveCondition');
            action.setParams({
                recordId: conditionId
            });
            action.setCallback(this, function(res) {
                if (res.getState() === 'SUCCESS') {
                    component.set('v.showSpinner', false);
                    const appEvent = $A.get('e.c:ConditionsInit');
                    appEvent.setParams({
                        condition: res.getReturnValue()
                    });
                    appEvent.fire();
                    component.find('overlayLib').notifyClose();
                } else if (res.getState() === 'ERROR') {
                    component.set('v.showSpinner', false);
                }
            });
            $A.enqueueAction(action);
        } catch ({ message }) {
            console.log('error in approve condition helper in Conditions Document Viewer', message);
        }
    },
    approveDocumentHelper: function(component, event) {
        try {
            const reviewSelection = this.parseReviewSelection(event.getSource().get('v.name'));
            const contentDocumentId = reviewSelection.contentDocumentId;
            const fileItemIndex = reviewSelection.fileItemIndex;
            const conditionId = component.get('v.conditionId');
            const action = component.get('c.approveConditionDocument');
            const helper = this;
            component.set('v.showSpinner', true);
            action.setParams({
                recordId: conditionId,
                contentDocumentId: contentDocumentId,
                approveConditionWhenNoPending: !component.get('v.hasRejectedDocumentInReviewSession')
            });
            action.setCallback(this, function(res) {
                component.set('v.showSpinner', false);
                if (res.getState() === 'SUCCESS') {
                    helper.removeReviewedFileByDocumentId(component, contentDocumentId, fileItemIndex);
                    helper.fireConditionRefresh(res.getReturnValue());
                } else if (res.getState() === 'ERROR') {
                    helper.setServerError(component, res);
                }
            });
            $A.enqueueAction(action);
        } catch ({ message }) {
            component.set('v.showSpinner', false);
            console.log('error in approve document helper in Conditions Document Viewer', message);
        }
    },
    parseReviewSelection: function(value) {
        if (!value) {
            return {
                contentDocumentId: null,
                fileItemIndex: -1
            };
        }
        const parts = value.split('|');
        return {
            contentDocumentId: parts[0],
            fileItemIndex: Number.parseInt(parts[1])
        };
    },
    rejectDocumentHelper: function(component) {
        try {
            const rejectionReason = component.get('v.rejectionReason');
            if (!rejectionReason || !rejectionReason.trim()) {
                component.set('v.errorMessage', 'Please enter a rejection comment.');
                return;
            }

            const conditionId = component.get('v.conditionId');
            const contentDocumentId = component.get('v.selectedReviewDocumentId');
            const files = component.get('v.files') || [];
            let fileItemIndex = -1;
            for (let i = 0; i < files.length; i++) {
                if (files[i].ContentDocumentId === contentDocumentId) {
                    fileItemIndex = i;
                    break;
                }
            }
            const action = component.get('c.rejectConditionDocument');
            const helper = this;
            component.set('v.showSpinner', true);
            action.setParams({
                recordId: conditionId,
                contentDocumentId: contentDocumentId,
                rejectionReason: rejectionReason,
                emailBorrower: component.get('v.emailBorrower'),
                updatedConditionDescription: component.get('v.updatedConditionDescription')
            });
            action.setCallback(this, function(res) {
                component.set('v.showSpinner', false);
                if (res.getState() === 'SUCCESS') {
                    component.set('v.showRejectPrompt', false);
                    component.set('v.errorMessage', null);
                    component.set('v.hasRejectedDocumentInReviewSession', true);
                    component.set('v.conditionDescription', component.get('v.updatedConditionDescription'));
                    helper.removeReviewedFileByDocumentId(component, contentDocumentId, fileItemIndex);
                    helper.fireConditionRefresh(res.getReturnValue());
                } else if (res.getState() === 'ERROR') {
                    helper.setServerError(component, res);
                }
            });
            $A.enqueueAction(action);
        } catch ({ message }) {
            component.set('v.showSpinner', false);
            console.log('error in reject document helper in Conditions Document Viewer', message);
        }
    },
    removeReviewedFileByDocumentId: function(component, contentDocumentId, fallbackIndex) {
        const files = component.get('v.files') || [];
        let fileItemIndex = files.findIndex(function(file) {
            return file.ContentDocumentId === contentDocumentId;
        });
        if (fileItemIndex < 0) {
            fileItemIndex = fallbackIndex;
        }
        this.removeReviewedFile(component, fileItemIndex);
    },
    removeReviewedFile: function(component, fileItemIndex) {
        const files = component.get('v.files') || [];
        if (fileItemIndex >= 0) {
            files.splice(fileItemIndex, 1);
        }
        component.set('v.files', files);

        if (files.length === 0) {
            component.find('overlayLib').notifyClose();
            return;
        }

        const nextIndex = Math.max(0, Math.min(fileItemIndex, files.length - 1));
        const nextFile = files[nextIndex];
        const nextFileExtension = nextFile.FileExtension ? nextFile.FileExtension.toLowerCase() : '';
        component.set('v.dataIdentifier', nextIndex);
        component.set('v.filePath', this.createFileLink(nextFile.ContentDocumentId));
        component.set('v.fileTitle', nextFile.Title);
        component.set('v.isImage', this.FILE_EXTENSION.IMAGE.includes(nextFileExtension));
    },
    fireConditionRefresh: function(condition) {
        const conditionEvent = $A.get('e.c:ConditionsInit');
        if (conditionEvent && condition) {
            conditionEvent.setParams({ condition: condition });
            conditionEvent.fire();
        }
        const refreshEvent = $A.get('e.c:RefreshEvent');
        if (refreshEvent) {
            refreshEvent.fire();
        }
    },
    setServerError: function(component, response) {
        const errors = response.getError();
        const message = errors && errors[0] && errors[0].message
            ? errors[0].message
            : 'Document review failed. Please try again.';
        component.set('v.errorMessage', message);
    },
    successRejectFormHelper: function(component) {
        try {
            component.set('v.showSpinner', false);
            component.find('overlayLib').notifyClose();
            const appEvent = $A.get('e.c:RefreshEvent');
            appEvent.fire();
        } catch ({ message }) {
            console.log('error in success reject form helper in Conditions Document Viewer', message);
        }
    },
    rejectFormErrorHelper: function(component, event) {
        try {
            component.set('v.showSpinner', false);
            if (
                event
                    .getParam('detail')
                    .toLowerCase()
                    .includes('templateId is not a valid EmailTemplate ID'.toLowerCase())
            ) {
                component.set(
                    'v.errorMessage',
                    'Please put a valid email template API Name in Conditions custom settings ' +
                    'or deselect send Email Reject Note to Borrower'
                );
            }
        } catch ({ message }) {
            console.log('error in reject form error helper in Conditions Document Viewer', message);
        }
    },
    editFileHelper: function(component, event, value) {
        try {
            const files = component.get('v.files');
            if (event.currentTarget) {
                const fileItemIndex = event.currentTarget.dataset.identifier;
                files[fileItemIndex].isEditable = value;
                component.set('v.files', files);
            }
        } catch ({ message }) {
            console.log('error in preview doc helper in Conditions Document Viewer', message);
        }
    },
    folderChangeHelper: function(component, event){
        let fileItemIndex = event.getSource().get("v.title")
        const files = component.get('v.files');
        files[fileItemIndex].Folder__c = event.getSource().get('v.value');
        component.set('v.files', files);
    },
    toggleMenuRemoveRelateVisibilityHelper : function(component, event){

        const previousToggled = component.get('v.ddMenuRemoveRelateToggledPrevious');
        const ddIndex = event.currentTarget.dataset.index;

        let ddMenuRemoveRelate;
        if(previousToggled && previousToggled !== ddIndex){
            let ddMenuRemoveRelatePrevious = document.getElementById(previousToggled);
            $A.util.removeClass(ddMenuRemoveRelatePrevious,'slds-is-open');
            
            ddMenuRemoveRelate = document.getElementById(ddIndex);
            $A.util.addClass(ddMenuRemoveRelate,'slds-is-open');
        } else {
            ddMenuRemoveRelate = document.getElementById(ddIndex);
            $A.util.toggleClass(ddMenuRemoveRelate,'slds-is-open');
        }

        component.set('v.ddMenuRemoveRelateToggledPrevious', ddIndex);
    },
    removeCurrentFileLinkHelper : function(component, event){
        try {
            if (event.currentTarget) {
                let files = component.get('v.files');
                let fileItemIndex = event.currentTarget.dataset.identifier;

                const action = component.get('c.relinkFileOnCondition');
                action.setParams({
                    recordId: event.currentTarget.dataset.id,
                    contentDocumentId: event.currentTarget.dataset.contentdocid,
                    isLinked: true
                });
                action.setCallback(this, function (res) {
                    if (res.getState() === 'SUCCESS') {
                        files.splice(fileItemIndex, 1);
                        component.set('v.files', files);  

                        if(files[fileItemIndex]){
                            let fileExtension = files[fileItemIndex].FileExtension.toLowerCase();
                            let filePath = this.createFileLink(files[fileItemIndex].ContentDocumentId);
                            let title = files[fileItemIndex].Title;

                            const isImage = this.FILE_EXTENSION.IMAGE.includes(fileExtension);
                            component.set('v.isImage', isImage);
                            component.set('v.filePath', filePath);
                            component.set('v.fileTitle', title);
                        } else {
                            component.set('v.isImage', false);
                            component.set('v.filePath', null);
                            component.set('v.fileTitle', null);                            
                        }

                        const appEvent = $A.get('e.c:RefreshEvent');
                        appEvent.fire();                      
                    } else if (res.getState() === 'ERROR') {
                        component.set('v.showSpinner', false);
                    }
                });
                $A.enqueueAction(action);
                this.previewDocHelper(component, event);
            }
        } catch ({ message }) {
            console.log('error in preview doc helper in Conditions Document Viewer', message);
        }
    },
    toggleFilesLinksMenuVisibilityHelper : function(component, event){
        
        if (event.currentTarget) {
            this.checkIfApplicationConditionsLindked(component, event);

            let ddDocsTitle = document.getElementById('all-docs-section-title');
            let ddDocsSection = document.getElementById('all-docs-section');
            let ddRelaterTitle = document.getElementById('conditions-relater-section-title');
            let ddRelaterGoback = document.getElementById('conditions-relater-goback');
            let ddRelaterSection = document.getElementById('conditions-relater-section');

            $A.util.toggleClass(ddDocsTitle,'slds-hide');
            $A.util.toggleClass(ddDocsSection, 'slds-hide');
            $A.util.toggleClass(ddRelaterTitle, 'slds-hide');
            $A.util.toggleClass(ddRelaterGoback, 'slds-hide');
            $A.util.toggleClass(ddRelaterSection, 'slds-hide');
        }
    },
    relinkFileHelper: function(component, event) {        
        try {
            component.set('v.showSpinner', true);
            if (event.currentTarget) {

                const contentdocid = component.get('v.selectedFileToRelinkId');
                const action = component.get('c.relinkFileOnCondition');
                action.setParams({
                    recordId: event.currentTarget.dataset.id,
                    contentDocumentId: contentdocid,
                    isLinked: event.currentTarget.dataset.linked
                });
                action.setCallback(this, function(res) {
                    if (res.getState() === 'SUCCESS') {
                        const appEvent = $A.get('e.c:RefreshEvent');
                        appEvent.fire();
                    } else if (res.getState() === 'ERROR') {
                        component.set('v.showSpinner', false);
                    }
                });
                $A.enqueueAction(action);
                this.checkIfApplicationConditionsLindked(component, event);
            }
        } catch ({ message }) {
            console.log('error in unlink condition helper in Conditions Document Viewer', message);
        }        
    },
    getApplicationFilesLinksHelper: function(component, event) {
        let action = component.get('c.getApplicationFilesLinks');
        action.setParams({
            applicationId: component.get('v.applicationId')
        });
        action.setCallback(this, function(response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    component.set('v.applicationFilesLinks', response.getReturnValue());
                }
            }
        );
        $A.enqueueAction(action);
    },
    getApplicationConditionsHelper: function(component, event) {
        let action = component.get('c.getApplicationConditions');
        action.setParams({
            applicationId: component.get('v.applicationId')
        });
        action.setCallback(this, function(response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    component.set('v.applicationConditions', response.getReturnValue());
                    const appEvent = $A.get('e.c:RefreshEvent');
                    appEvent.fire();
                }
            }
        );
        $A.enqueueAction(action);
    },
    checkIfApplicationConditionsLindked: function(component, event) {
        if (event.currentTarget) {
            if (event.currentTarget.dataset.id) {

                let cdId;

                if(event.currentTarget.dataset.contentdocid){
                    cdId = event.currentTarget.dataset.contentdocid;
                    component.set('v.selectedFileToRelinkId', event.currentTarget.dataset.contentdocid);
                } else {
                    cdId = event.currentTarget.dataset.id;
                    component.set('v.selectedFileToRelinkId', event.currentTarget.dataset.id);
                }
                
                let action = component.get('c.checkApplicationConditions');
                action.setParams({
                    applicationId: component.get('v.applicationId'),
                    contentDocId: cdId
                });
                action.setCallback(this, function(response) {
                        let state = response.getState();
                        if (state === 'SUCCESS') {
                            
                            component.set('v.linkedApplicationConditions', response.getReturnValue());
                        }
                    }
                );
                $A.enqueueAction(action);

            }
        }
    },
});
