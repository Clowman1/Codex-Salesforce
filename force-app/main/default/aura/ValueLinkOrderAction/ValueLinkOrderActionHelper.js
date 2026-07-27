({
    loadForm: function(component) {
        var recordId = component.get("v.recordId");
        if (!recordId) {
            var helper = this;
            window.setTimeout($A.getCallback(function() {
                recordId = component.get("v.recordId");
                if (recordId) {
                    component.set("v.errorMessage", null);
                    component.set("v.isLoading", true);
                    helper.loadForm(component);
                } else {
                    component.set("v.isLoading", false);
                    if (!component.get("v.transactionName")) {
                        this.setErrorMessage(component, "Missing Transaction Id. Close this window and launch Order Appraisal from the Transaction record again.");
                    }
                }
            }.bind(this)), 250);
            return;
        }
        var action = component.get("c.getOrderActionModel");
        action.setParams({ recordId: recordId });
        action.setCallback(this, function(response) {
            component.set("v.isLoading", false);
            if (response.getState() === "SUCCESS") {
                var model = response.getReturnValue();
                component.set("v.transactionId", model.transactionId || recordId);
                component.set("v.transactionName", model.transactionName);
                component.set("v.errorMessage", null);
                component.set("v.processorOptions", model.processorOptions || []);
                component.set("v.processorUserId1", model.processorUserId1);
                component.set("v.processorUserId2", model.processorUserId2);
                component.set("v.processorUserId3", model.processorUserId3);
                component.set("v.loanType", model.loanType);
                component.set("v.fhaCaseNumber", model.fhaCaseNumber);
                component.set("v.appraisalType", model.appraisalType);
                component.set("v.appraisalTypeOptions", model.appraisalTypeOptions || []);
            } else {
                this.setErrorMessage(component, this.getErrorMessage(response));
            }
        });
        $A.enqueueAction(action);
    },

    submitOrder: function(component) {
        component.set("v.errorMessage", null);
        component.set("v.successMessage", null);

        var uploadedFiles = component.get("v.uploadedFiles") || [];
        var transactionId = component.get("v.transactionId") || component.get("v.recordId");
        var transactionName = component.get("v.transactionName");
        if (!transactionId && !transactionName) {
            this.setErrorMessage(component, "Missing Transaction Id. Close this window and launch Order Appraisal from the Transaction record again.");
            return;
        }
        if (!component.get("v.processorUserId1")) {
            this.setErrorMessage(component, "Processor Contact 1 is required.");
            return;
        }
        if (!component.get("v.appraisalType")) {
            this.setErrorMessage(component, "Appraisal Product is required.");
            return;
        }
        component.set("v.isSubmitting", true);
        component.set("v.successMessage", "Submitting appraisal order to ValueLink...");
        var action = component.get("c.createOrderWithContactValues");
        action.setParams({
            loanId: transactionId || null,
            transactionName: transactionName || null,
            processorUserId1: component.get("v.processorUserId1") || null,
            processorUserId2: component.get("v.processorUserId2") || null,
            processorUserId3: component.get("v.processorUserId3") || null,
            fhaCaseNumber: component.get("v.fhaCaseNumber") || null,
            appraisalType: component.get("v.appraisalType") || null,
            generalComment: component.get("v.generalComment") || null,
            contractContentDocumentIds: uploadedFiles.map(function(file) {
                return file.documentId;
            })
        });
        action.setCallback(this, function(response) {
            component.set("v.isSubmitting", false);
            if (response.getState() === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.successMessage", result.message + (result.orderNumber ? " Order # " + result.orderNumber + "." : ""));
                $A.get("e.force:refreshView").fire();
            } else {
                this.setErrorMessage(component, this.getErrorMessage(response));
            }
        });
        $A.enqueueAction(action);
    },

    closeAction: function() {
        var closeEvent = $A.get("e.force:closeQuickAction");
        if (closeEvent) {
            closeEvent.fire();
        }
    },

    getErrorMessage: function(response) {
        var errors = response.getError();
        if (errors && errors.length) {
            if (errors[0].message) {
                return errors[0].message;
            }
            if (errors[0].pageErrors && errors[0].pageErrors.length) {
                return errors[0].pageErrors[0].message;
            }
        }
        return "Something went wrong while preparing the appraisal order.";
    },

    clearStaleMissingIdError: function(component) {
        var currentError = component.get("v.errorMessage");
        if (this.isMissingIdMessage(currentError) && component.get("v.transactionName")) {
            component.set("v.errorMessage", null);
        }
    },

    setErrorMessage: function(component, message) {
        if (this.isMissingIdMessage(message) && component.get("v.transactionName")) {
            component.set("v.errorMessage", null);
            return;
        }
        component.set("v.errorMessage", message);
    },

    isMissingIdMessage: function(message) {
        return message && message.indexOf("Missing Transaction Id") === 0;
    }
})
