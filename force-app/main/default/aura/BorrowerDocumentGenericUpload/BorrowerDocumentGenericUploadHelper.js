({
	processGenericUpload : function(component, event) {
		const files = event.getParam('files') || [];
		const contentDocumentIds = files
			.map(file => file.documentId)
			.filter(documentId => !!documentId);

		if (!contentDocumentIds.length) {
			this.showToast(null, 'warning', 'No files were uploaded.');
			return;
		}

		component.set('v.spinner', true);
		const action = component.get('c.sendGenericDocumentPlatformEvents');
		action.setParams({
			contentDocumentIds: contentDocumentIds,
			recordId: component.get('v.recordId')
		});
		action.setCallback(this, response => {
			component.set('v.spinner', false);
			if (response.getState() === 'SUCCESS') {
				this.showToast(null, 'success', 'Files were successfully uploaded!');
				return;
			}

			const errors = response.getError();
			const message = errors && errors.length && errors[0].message
				? errors[0].message
				: 'The files uploaded, but the review notification could not be created.';
			this.showToast('Upload Needs Review', 'error', message);
		});
		$A.enqueueAction(action);
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
});
