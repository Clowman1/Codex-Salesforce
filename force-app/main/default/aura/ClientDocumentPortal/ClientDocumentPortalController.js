({
    init: function (component, event, helper) {
		helper.getData(component);
    },

	onRender: function(component) {
		const root = document.querySelector(':root');
		root.style.setProperty('--primary-text-color', component.get('v.primaryTextColor'));
		root.style.setProperty('--secondary-text-color', component.get('v.secondaryTextColor'));
		root.style.setProperty('--primary-color', component.get('v.primaryColor'));
		root.style.setProperty('--brand-color', component.get('v.brandColor'));
		root.style.setProperty('--transparent-brand-color', component.get('v.transparentBrandColor'));
		root.style.setProperty('--your-team-background-image-url', 'url(' + component.get('v.yourTeamBackroundImageUrl') + ')');
	}
});