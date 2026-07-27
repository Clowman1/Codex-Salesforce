({
    handleSubmit: function(component, event) {
        event.preventDefault();
        component.set('v.isSaving', true);

        var fields = event.getParam('fields');
        fields.RecordTypeId = '012f20000010aScAAI';
        fields.Type__c = 'Realtor Account';
        fields.Group__pc = 'Realtor';
        fields.Is_Realtor__c = true;
        if (fields.PersonMobilePhone && !fields.Phone) {
            fields.Phone = fields.PersonMobilePhone;
        }
        component.find('realtorForm').submit(fields);
    },

    handleSuccess: function(component, event) {
        component.set('v.isSaving', false);
        var toast = $A.get('e.force:showToast');
        toast.setParams({
            title: 'Realtor Partner created',
            message: 'The new Realtor Partner account is ready.',
            type: 'success'
        });
        toast.fire();

        var nav = $A.get('e.force:navigateToSObject');
        nav.setParams({ recordId: event.getParam('response').id });
        nav.fire();
    },

    handleError: function(component) {
        component.set('v.isSaving', false);
    },

    cancel: function() {
        var nav = $A.get('e.force:navigateToObjectHome');
        nav.setParams({ scope: 'Account' });
        nav.fire();
    }
});
