({
    init: function(component) {
        component.find('leadFlow').startFlow('New_Lead_Screen_Flow');
    },

    handleStatusChange: function(component, event) {
        var status = event.getParam('status');
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            var nav = $A.get('e.force:navigateToObjectHome');
            nav.setParams({ scope: 'Lead' });
            nav.fire();
        }
    }
});
