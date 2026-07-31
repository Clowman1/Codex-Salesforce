/**
 * Created by toma on 11/9/2022.
 */

public with sharing class UWM_Conditions_API_Res_Model {
    public List<ConditionsGroup> conditionGroups;
    public List<Condition> clearedConditions;
    public class Condition{
        public String id; //UWM_Id__c
        public String conditionCategory; //Category__c
        public String conditionDescription; //UWM_Description__c
        public Boolean isConditionUploaded; //?? Uploaded__c
        public Datetime conditionSatisfactionDate;//?? Sat_date__c
        public String conditionGroup;//Group++c
        public String displayValueId;

        public Condition__c  convertToClientNeed(String loanId, String loanNumber, String conditionType){
            String uwNotes;
            String conditionsStatus;
            if(this.conditionDescription.contains('*')){
                uwNotes = this.conditionDescription.split('\\*+')[1];
            }
            if(!String.isBlank(conditionType) && conditionType == 'Cleared'){
                conditionsStatus = 'Cleared';
            } else {
                conditionsStatus = this.isConditionUploaded ? 'Submitted' : 'New';
            }
            return new Condition__c (
                UWM_Condition_Id__c = this.id,
                Status__c = conditionsStatus,
                UWM_Description__c = this.conditionDescription,
                Description__c = this.conditionDescription,
                UW_Notes__c = uwNotes != null ? uwNotes : '',
                Is_Condition_Uploaded__c = this.isConditionUploaded,
                Condition_Satisfaction_Date__c = this.conditionSatisfactionDate,
                Completed_Date__c  = this.conditionSatisfactionDate?.date(),
                Condition_Group_Key__c = this.conditionGroup,
                Category__c = this.conditionCategory,
                Transaction__c  = loanId,
                UWMReferenceId__c = this.displayValueId
            );
        }
    }
    public class ConditionsGroup{
        public String key;
        public Integer countItems;
        public Integer uploadedConditionsCount;
        public List<Condition> conditions;
    }

    public void flatten(){
        for(ConditionsGroup condGroup : conditionGroups){
            for(Condition condition : condGroup.conditions){
                condition.conditionGroup = condGroup.key;
            }
        }
    }
}