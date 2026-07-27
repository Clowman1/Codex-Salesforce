({
    createTitleAgent: function(component) {
        component.set("v.errorMessage", null);

        var fields = component.find("requiredField");
        if (!Array.isArray(fields)) {
            fields = [fields];
        }

        var isValid = fields.reduce(function(validSoFar, field) {
            field.reportValidity();
            return validSoFar && field.checkValidity();
        }, true);

        if (!isValid) {
            return;
        }

        component.set("v.isSaving", true);

        var action = component.get("c.createTitleAgentAccount");
        action.setParams({
            accountName: component.get("v.titleAgentName"),
            phoneNumber: component.get("v.phoneNumber"),
            email: component.get("v.emailAddress")
        });

        action.setCallback(this, function(response) {
            component.set("v.isSaving", false);

            var state = response.getState();
            if (state === "SUCCESS") {
                this.showToast("Title Agent created", "The Title Agent account is ready.", "success");
                this.closeAction();
                return;
            }

            var message = "Unable to create the Title Agent account. Please try again.";
            var errors = response.getError();
            if (errors && errors.length && errors[0].message) {
                message = errors[0].message;
            }
            component.set("v.errorMessage", message);
        });

        $A.enqueueAction(action);
    },

    closeAction: function() {
        $A.get("e.force:closeQuickAction").fire();
    },

    showToast: function(title, message, variant) {
        var toast = $A.get("e.force:showToast");
        if (toast) {
            toast.setParams({
                title: title,
                message: message,
                type: variant
            });
            toast.fire();
        }
    }
})
