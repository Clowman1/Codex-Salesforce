/**
 * Created by zeyad on 8/17/2022.
 */

// eslint-disable-next-line no-unused-expressions
({
    init: function (component, event, helper) {
        helper.getFolders(component,event);
        helper.getApplicationFilesLinksHelper(component,event);
        helper.getApplicationConditionsHelper(component,event);
        helper.previewDocHelper(component, event);
    },
    previewDoc: function (component, event, helper) {
        if(event.target.dataset.ignore){
            return;
        }
        helper.previewDocHelper(component, event);
    },
    rejectFormErrorHandler: function (component, event, helper) {
        helper.rejectFormErrorHelper(component, event);
    },
    approve: function (component, event, helper) {
        helper.approveHelper(component);
    },
    approveDocument: function (component, event, helper) {
        helper.approveDocumentHelper(component, event);
    },
    rejectPrompt: function (component, event, helper) {
        if (event && event.getSource) {
            const reviewSelection = helper.parseReviewSelection(event.getSource().get('v.name'));
            if (reviewSelection.contentDocumentId) {
                component.set('v.selectedReviewDocumentId', reviewSelection.contentDocumentId);
                component.set('v.selectedReviewDocumentTitle', event.getSource().get('v.title'));
            }
            component.set('v.updatedConditionDescription', component.get('v.conditionDescription'));
            component.set('v.rejectionReason', null);
            component.set('v.emailBorrower', true);
        }
        component.set('v.showRejectPrompt', true);
        component.set('v.errorMessage', null);
    },
    rejectDocument: function (component, event, helper) {
        helper.rejectDocumentHelper(component);
    },
    cancelReject: function (component) {
        component.set('v.showRejectPrompt', false);
        component.set('v.errorMessage', null);
    },
    closeWindow: function (component, event, helper) {
        helper.successRejectFormHelper(component);
    },
    submitFormHandler: function (component) {
        component.set('v.showSpinner', true);
    },
    editFile : function(component, event, helper){
        helper.editFileHelper(component, event, true);
    },
    uneditFile : function(component, event, helper){
        helper.editFileHelper(component, event, false);
    },
    saveFile : function(component, event, helper){
        helper.saveFileHelper(component, event);
    },
    folderChange: function (component, event, helper) {
        helper.folderChangeHelper(component, event);
    },
    toggleFilesLinksMenuVisibility : function(component, event, helper){
        helper.toggleFilesLinksMenuVisibilityHelper(component, event);
    },
    toggleMenuRemoveRelateVisibility : function(component, event, helper){
        helper.toggleMenuRemoveRelateVisibilityHelper(component, event);
    },
    onSelectFileLink : function(component, event, helper){
        helper.relinkFileHelper(component, event);
    },
    removeCurrentFileLink : function(component, event, helper){
        helper.removeCurrentFileLinkHelper(component, event);
    },
    downloadFiles : function(component,event,helper){
        let files = component.get('v.files');
        let downloadUrl = `/sfc/servlet.shepherd/document/download`;

		for (const file of files) { 
			downloadUrl += '/' + file.ContentDocumentId;
		}
        
        downloadUrl += '?';
        
        window.open(downloadUrl, '_blank');
    }
});
