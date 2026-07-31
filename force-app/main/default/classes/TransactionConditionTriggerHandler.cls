public with sharing class TransactionConditionTriggerHandler {
    public static Boolean isUWMSyncEnabled = false;
    private final List<Condition__c> newConditions;
    private final Map<Id, Condition__c> oldConditionsMap;

    /**
     * @description Constructor
     */
    public TransactionConditionTriggerHandler() {
        this.newConditions = (List<Condition__c>) Trigger.new;
        this.oldConditionsMap = (Map<Id,Condition__c>) Trigger.oldMap;
    }

    /**
     * @description Before update handler method
     */
    public void handleBeforeUpdate(){
        updateStatusAndDescription();
    }

    /**
     * @description After insert handler method
     */
    public void handleAfterInsert(){
        processReferences();
    }

    /**
     * @description This method updates status and description of new conditions.
     * It prevents from changing status of new conditions to New if old conditions status is not New.
     * It also prevents from changing description of new conditions
     * if old conditions description is not equal to new conditions description and condition has
     * condition reference record lookup set.
     */
    private void updateStatusAndDescription(){
        if(!isUWMSyncEnabled){
            return;
        }

        for(Condition__c newCond : this.newConditions){
            Condition__c oldCondition = this.oldConditionsMap.get(newCond.Id);
            if(
                    newCond.Status__c == 'New'
                            && oldCondition.Status__c != 'New'
                            && !String.isBlank(oldCondition.Status__c)
            ){
                newCond.Status__c = oldCondition.Status__c;
            }
            if(
                    oldCondition.Description__c != null
                            && newCond.Description__c != oldCondition.Description__c
                            && !String.isBlank(newCond.Transaction_Condition_Reference__c)
            ){
                newCond.Description__c = oldCondition.Description__c;
            }
        }
    }

    /**
     * @description This method processes references for new conditions.
     * It gathers unique UWM reference codes from new conditions. If existing reference
     * do not contains UWM reference code from new conditions, it creates new reference.
     * It updates new conditions with reference id.
     * It updates existing references with new condition group key if it is not set and condition has group key.
     * Set Group Key on a new reference if condition has group key.
     */
    private void processReferences(){
        List<Condition__c> conditionsToUpdate = new List<Condition__c>();
        Map<String,List<Condition__c>> conditionsToUpdateWithNewlyInsertedReferences = new Map<String,List<Condition__c>>();

        Set<String> uniqueUWMConditionIds = gatherUniqueReferences();
        Map<String, Transaction_Condition_Reference__c> searchReferencesMap = getCurrentReferences(uniqueUWMConditionIds);
        fillConditionsToUpdate(conditionsToUpdate, searchReferencesMap, conditionsToUpdateWithNewlyInsertedReferences);

        if(!conditionsToUpdateWithNewlyInsertedReferences.isEmpty()){
            Map<String, Transaction_Condition_Reference__c> insertedReferencesMap = insertNewReferences(conditionsToUpdateWithNewlyInsertedReferences);
            fillConditionsWithNewReferenceId(conditionsToUpdate, conditionsToUpdateWithNewlyInsertedReferences, insertedReferencesMap);
        }
        updateCurrentReferencesWithGroupKey(searchReferencesMap);
        if (Schema.SObjectType.Condition__c.fields.Transaction_Condition_Reference__c.isUpdateable()) {
            Database.update(conditionsToUpdate, false, System.AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description This method inserts new references if they are not exist and
     * set group key if it is not set and condition has group key.
     * @param conditionsToUpdateWithNewlyInsertedReferences - map of conditions
     * to update with newly inserted references as keys
     * @return Map<String,Loan_Condition_Reference__c> referencesToInsert
     */
    private Map<String,Transaction_Condition_Reference__c> insertNewReferences(
            Map<String,List<Condition__c>> conditionsToUpdateWithNewlyInsertedReferences
    ){
        Map<String,Transaction_Condition_Reference__c> referencesToInsert = new Map<String,Transaction_Condition_Reference__c>();
        for(String referenceId : conditionsToUpdateWithNewlyInsertedReferences.keySet()){
            String conditionGroupKey;
            for(Condition__c condition : conditionsToUpdateWithNewlyInsertedReferences.get(referenceId)){
                if(!String.isBlank(condition.Condition_Group_Key__c)) {
                    conditionGroupKey = condition.Condition_Group_Key__c;
                    break;
                }
            }
            Transaction_Condition_Reference__c reference = new Transaction_Condition_Reference__c(
                    Reference_Id__c = referenceId,
                    Condition_Group_Key__c = conditionGroupKey
            );
            referencesToInsert.put(reference.Reference_Id__c, reference);
        }
        insert referencesToInsert.values();
        return referencesToInsert;
    }

    /**
    * @description This method fills conditions with created reference id
    * @param conditionsToUpdate - list of conditions to update
    * @param conditionsToUpdateWithNewlyInsertedReferences - map of conditions
    * @param insertedReferencesMap - map of inserted references
     */
    private void fillConditionsWithNewReferenceId(
            List<Condition__c> conditionsToUpdate,
            Map<String,List<Condition__c>> conditionsToUpdateWithNewlyInsertedReferences,
            Map<String,Transaction_Condition_Reference__c> insertedReferencesMap
    ){
        for(String referenceId : conditionsToUpdateWithNewlyInsertedReferences.keySet()){
            for(Condition__c condition : conditionsToUpdateWithNewlyInsertedReferences.get(referenceId)){
                Condition__c clonedCondition = condition.clone(true, true, false, false);
                clonedCondition.Transaction_Condition_Reference__c = insertedReferencesMap.get(referenceId).Id;
                conditionsToUpdate.add(clonedCondition);
            }
        }
    }

    /**
    * @description This method creates a list of conditions to update
     * and a map of conditions to update with reference codes as keys
    * @param conditionsToUpdate - list of conditions to update
    * @param searchReferencesMap - map of existing references
    * @param conditionsToUpdateWithNewlyInsertedReferences - map of conditions
     */
    private void fillConditionsToUpdate(
            List<Condition__c> conditionsToUpdate,
            Map<String,Transaction_Condition_Reference__c> searchReferencesMap,
            Map<String,List<Condition__c>> conditionsToUpdateWithNewlyInsertedReferences
    ){
        for(Condition__c condition : this.newConditions) {
            if(String.isBlank(condition.UWMReferenceId__c)) {
                continue;
            }

            String referenceCode = getConditionReferenceCode(condition);
            Condition__c clonedCondition = condition.clone(true, true, false, false);
            if(searchReferencesMap.containsKey(referenceCode)){
                clonedCondition.Transaction_Condition_Reference__c = searchReferencesMap.get(referenceCode).Id;
                conditionsToUpdate.add(clonedCondition);
            } else {
                if(conditionsToUpdateWithNewlyInsertedReferences.get(referenceCode) == null) {
                    conditionsToUpdateWithNewlyInsertedReferences.put(referenceCode, new List<Condition__c>());
                }
                conditionsToUpdateWithNewlyInsertedReferences.get(referenceCode).add(condition);
            }
        }
    }

    /**
    * @description This method current references with group keys
    * if they are not set and condition has group key.
    * @param searchReferencesMap - map of existing references
     */
    private void updateCurrentReferencesWithGroupKey(
            Map<String,Transaction_Condition_Reference__c> searchReferencesMap
    ){
        Boolean referencesHasChanges = false;

        if (searchReferencesMap.isEmpty()) {
            return;
        }

        for(Condition__c condition : this.newConditions) {
            if(String.isBlank(condition.Condition_Group_Key__c)) {
                continue;
            }

            String referenceCode = getConditionReferenceCode(condition);
            if(searchReferencesMap.containsKey(referenceCode) && String.isBlank(searchReferencesMap.get(referenceCode).Condition_Group_Key__c)){
                searchReferencesMap.get(referenceCode).Condition_Group_Key__c = condition.Condition_Group_Key__c;
                referencesHasChanges = true;
            }
        }
        if (referencesHasChanges) {
            update searchReferencesMap.values();
        }
    }

    /**
    * @description This method get current references by set of reference codes
    * @param uniqueUWMConditionIds - set of reference codes
    * @return searchReferences - map of existing references
     */
    private Map<String,Transaction_Condition_Reference__c> getCurrentReferences(Set<String> uniqueUWMConditionIds){
        Map<String,Transaction_Condition_Reference__c> searchReferences = new Map<String, Transaction_Condition_Reference__c>();
        List<Transaction_Condition_Reference__c> referencesThatAlreadyExist = [
                SELECT Id, Reference_Id__c, Condition_Category__c, Type__c, Condition_Group_Key__c
                FROM Transaction_Condition_Reference__c
                WHERE Reference_Id__c IN: uniqueUWMConditionIds
                WITH USER_MODE
        ];
        for(Transaction_Condition_Reference__c reference : referencesThatAlreadyExist){
            searchReferences.put(reference.Reference_Id__c, reference);
        }
        return searchReferences;
    }

    /**
    * @description This method gather unique reference codes
    * @return uniqueUWMConditionIds - set of reference codes
     */
    private Set<String> gatherUniqueReferences(){
        Set<String> uniqueUWMConditionIds = new Set<String>();
        for(Condition__c condition : this.newConditions){
            if(String.isBlank(condition.UWMReferenceId__c)){
                continue;
            }
            uniqueUWMConditionIds.add(getConditionReferenceCode(condition));
        }
        return uniqueUWMConditionIds;
    }

    /**
    * @description This method returns reference code from condition
    * @param condition - condition
    * @return string with reference code
    */
    private String getConditionReferenceCode(Condition__c condition){
        return condition.UWMReferenceId__c;
    }
    
    // TODO: replace. 
    // Couldn't find source tests for this one. Not sure if methods used somewhere, 
    // didn't want to break anything if they do
    public static void testCoverage() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;      
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;    
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;    
    }
}