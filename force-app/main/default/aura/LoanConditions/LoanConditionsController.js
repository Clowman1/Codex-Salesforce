({
    init : function(c,e,h){
        let action = c.get('c.getConditionsForLoan');
        action.setParams({loanId : c.get('v.recordId')});
        action.setCallback(this,function(res){
            if(res.getState() == 'SUCCESS'){
                let conditions =  h.processConditions(res.getReturnValue());
                c.set('v.juniorConditions', conditions.juniorConditions);
                c.set('v.borrowerConditions', conditions.borrowerConditions);
                c.set('v.processorConditions', conditions.processorConditions);
            }
        });
        $A.enqueueAction(action);
    },
    addCondition : function(c,e,h){
        var actionAPI = c.find("quickActionAPI");
        var args = {actionName: "Opportunity.Add_Loan_Condition"};
        actionAPI.selectAction(args).then(function(result){
            debugger; 
        }).catch(function(ex){
            debugger;
            if(ex.errors){
                //If the specified action isn't found on the page, show an error message in the my component
            }
        });
    },
    openEmailModal : function(c,e,h){
        var modalBody;
        $A.createComponent("c:ConditionsEmailModal", {recordId : c.get('v.recordId'),shouldShowEmailTemplateOptions:true},
            function(content, status) {
                if (status === "SUCCESS") {
                    modalBody = content;
                    c.find('overlayLib').showCustomModal({
                        header: "Conditions Email",
                        body: modalBody,
                        showCloseButton: true,
                        cssClass: "conditionsEmailModal",
                        closeCallback: function() {
                            console.log('Modal Closed');
                        }
                    })
                }
            }
        );
    }

});