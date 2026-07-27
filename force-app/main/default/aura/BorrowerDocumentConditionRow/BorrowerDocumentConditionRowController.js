({
	handleUploadFinished: function(component, event, helper) {
		try {
			component.set('v.spinner', true);
			const filesList = event.getParam("files");
			const condition = component.get('v.condition');
			const versionsIds = [];

			for (const file of filesList) {
				versionsIds.push(file.contentVersionId);
			}

			const action = component.get('c.updateLoanConditionOnFileUpload');
			action.setParams({contentVersionIds: versionsIds, conditionId: condition.id});
			action.setCallback(this, response =>  
				helper.onUploadFileCompleted(component, response, helper)
			);
			$A.enqueueAction(action);
		} catch(e) {
			console.log('e: ' + JSON.stringify(e));
		}
		
	},

    toggleState: function (component, event, helper) {
        component.set('v.isOpen', !component.get('v.isOpen'));
    },

    // function automatic called by aura:waiting event
    showSpinner: function(component, event, helper) {
        // make Spinner attribute true for displaying loading spinner
        component.set("v.spinner", true);
    },

    // function automatic called by aura:doneWaiting event
    hideSpinner : function(component,event,helper){
        // make Spinner attribute to false for hiding loading spinner
        component.set("v.spinner", false);
    }
});