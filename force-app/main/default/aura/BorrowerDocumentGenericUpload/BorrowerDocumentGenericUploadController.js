({
	handleUploadFinished: function(component, event, helper) {
		helper.processGenericUpload(component, event);
	},

	onRender: function(component, event, helper) {
		const wrapper = document.querySelector('.generic-upload-wrapper');
		wrapper.style.setProperty('--title-text-color', component.get('v.titleTextColor'));
	}
});
