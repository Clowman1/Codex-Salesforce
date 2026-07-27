({
    doInit: function(component, event, helper) {
        helper.loadForm(component);
    },

    handleTransactionNameChange: function(component, event, helper) {
        helper.clearStaleMissingIdError(component);
    },

    handleUploadFinished: function(component, event, helper) {
        var uploadedFiles = component.get("v.uploadedFiles") || [];
        var newFiles = event.getParam("files") || [];
        newFiles.forEach(function(file) {
            uploadedFiles.push({
                name: file.name,
                documentId: file.documentId
            });
        });
        component.set("v.uploadedFiles", uploadedFiles);
        component.set("v.errorMessage", null);
    },

    submitOrder: function(component, event, helper) {
        helper.submitOrder(component);
    },

    closeAction: function(component, event, helper) {
        helper.closeAction();
    }
})
