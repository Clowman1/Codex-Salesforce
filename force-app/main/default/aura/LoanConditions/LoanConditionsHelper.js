({
    processConditions: function(conditions){
        let juniorConditions = [], borrowerConditions = [], processorConditions = [], loanOfficerConditions = [];
        for(let condition of conditions){
            if(condition.data.Assigned_Role__c == 'Junior Conditions'){
                juniorConditions.push(condition);
            }else if(condition.data.Assigned_Role__c == 'Processor Conditions'){
                processorConditions.push(condition);
            }else if(condition.data.Assigned_Role__c == 'Borrower Conditions'){
                borrowerConditions.push(condition);
            }else{
                loanOfficerConditions.push(condition);
            } 
        }
        processorConditions.sort(this.sortConditions, this);
        juniorConditions.sort(this.sortConditions, this);
        borrowerConditions.sort(this.sortConditions, this);
        return { borrowerConditions, juniorConditions, processorConditions} ;
    },
    sortConditions : function(x,y, helper){
        let quantifyStatus = function(status){
            return status === 'New' ? 0 : status === 'Requested' ? 1 : 2;
        }
        if(quantifyStatus(x.data.Status__c) > quantifyStatus(y.data.Status__c)){
            return 1;
        }else if(quantifyStatus(x.data.Status__c) < quantifyStatus(y.data.Status__c)){
            return -1;
        }
        return 0;
    },

});