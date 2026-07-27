({
    submit : function(c,e,h){
        c.find('recordLoader').submit();
    },
    submit2 : function(c,e,h){
        c.find('recordLoader2').submit();
    },
    submit3 : function(c,e,h){
        c.find('recordLoader3').submit();
    },
    navigate : function(c,e,h){
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": c.get('v.condition').data.Id,
            "slideDevName": "detail"
        });
        navEvt.fire();
    },
    reInit : function(c,e,h){
        var compEvent = c.getEvent("conditionUpdated");
        compEvent.fire();
    },
    throwError : function(c,e,h){
        var condition = c.get("v.condition");
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title":  e.getParam("detail"),
            "message": 'Please update the record.',
            "mode" : "dismissible", 
            "type" : "warning",
            "duration" : 3, 
            "messageTemplate": '{0}',
            "messageTemplateData": [
                {
                    url: '/'+condition.data.Id,
                    label: 'Click HERE to update',
                }
            ]
        });
        toastEvent.fire();
    },
});