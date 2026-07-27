({
    getJsonFromUrl: function () {
    const query = location.search.substring(1);
    const result = {};
    query.split("&").forEach(function(part) {
        const item = part.split("=");
        result[item[0]] = decodeURIComponent(item[1]);
    });
    return result;
	},

    onUploadFileCompleted : function(component, response, helper) {
		const condition = component.get('v.condition');
        const state = response.getState();
		let toastTitle;
		let toastType;
		let toastMessage = '';
	
		if (state === "SUCCESS") {
			toastTitle = 'Files were uploaded to condition ' + condition.name + '.';
			toastType = 'success';
			toastMessage = 'Your documents will be reviewed.';
			const updatedCondition = response.getReturnValue();
			updatedCondition.commentCount = condition.commentCount;
			updatedCondition.activeCommentCount = condition.activeCommentCount;
			updatedCondition.hasActiveComments = condition.hasActiveComments;
			component.set('v.condition', updatedCondition);
		} else if (state === "ERROR") {
			console.log('ERROR');
			const errors = response.getError();
			if (errors) {
				if (errors.length && errors[0].message) {
					toastTitle = 'An error occurred while saving the file to loan condition';
					toastType = 'error';
					toastMessage = errors[0].message;
					console.log("Error message: " + errors[0].message);
				}
			} else {
				toastTitle = 'An unknown error occurred while saving the file to loan condition';
				toastType = 'error';
				console.log("Unknown error");
			}
		}

		component.set('v.spinner', false);
		helper.showToast(toastTitle, toastType, toastMessage);
    },

	showToast : function(title, type, message) {
		const toastEvent = $A.get("e.force:showToast");
		toastEvent.setParams({
			"title": title,
			"type" : type,
			"message": message
		});
		toastEvent.fire();
	},
})
