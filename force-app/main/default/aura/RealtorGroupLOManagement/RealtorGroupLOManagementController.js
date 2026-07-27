({
    doInit : function(component, event, helper) {
        // Replace these with your actual Flow API names
        var flowNameA = "Preferred_Loan_Officer_Manager";
        var flowNameB = "Preferred_Loan_Officer_Manager_Mass_Delete";

        var flowA = component.find("flowA");
        var flowB = component.find("flowB");

        if (flowA && flowA.startFlow) {
            flowA.startFlow(flowNameA);
        }
        if (flowB && flowB.startFlow) {
            flowB.startFlow(flowNameB);
        }
    }
})