public with sharing class SObjectCloneUtility {
    private static Map<String,SObject_Clone_Model__mdt> modelsByLabel;
    private static String QUERY_BASE = 'SELECT {0} FROM {1}';
    static{
        modelsByLabel = new Map<String,SObject_Clone_Model__mdt>();
        for(SObject_Clone_Model__mdt model : [SELECT Id, DeveloperName,Object__c, (SELECT Id, Field_Name__c, Value__c FROM Default_Values__r), (SELECT Id, DeveloperName,Object_Field_Name__c,Target_Field_Name__c FROM Fields__r) FROM SObject_Clone_Model__mdt]){
            modelsByLabel.put(model.DeveloperName, model);
        }
    }
    private interface Relatable{
        SObjectFieldRelationBase getRelationship();
    }
    private interface TargetsField{
        String getTargetFieldName();
    }
    public virtual class SObjectClone{
        private SObject data;
        private SObject objectToClone;
        private PersistenceStrategy strategy;
        private SObject_Clone_Model__mdt model;
        private List<SObjectCloneField> fields = new List<SObjectCloneField>();
        public SObjectClone(SObject objectToClone, String modelName, PersistenceStrategy strategy){
            setPersistenceStrategy(strategy);
            createBaseClone(objectToClone);
            setModel(modelName);
            applyValues();
        }
        private void setPersistenceStrategy(PersistenceStrategy strategy){
            this.strategy = strategy;
        }
        private void setModel(String modelName){
            this.model = modelsByLabel.get(modelName);
            for(SObject_Clone_Field__mdt field : this.model.Fields__r){
                this.fields.add(new SObjectCloneField(field.Target_Field_Name__c, field.Object_Field_Name__c));
            }
        }
        private void createBaseClone(SObject objectToClone){
            this.objectToClone = objectToClone;
            this.data = objectToClone.getSObjectType().newSObject();
        }
        private void applyValues(){
            applyMappedValues();
            applyDefaultValues();
        }
        private void applyMappedValues(){
            if(fields.isEmpty()) return;
            for(SObjectCloneField field : this.fields){
			System.debug(+field.objectFieldName + '============' +field.extractValue(objectToClone));
				if(field.objectFieldName == 'Name'){
					this.data.put(field.objectFieldName, String.valueOf(field.extractValue(objectToClone)));
				}else{
					this.data.put(field.objectFieldName, field.extractValue(objectToClone));
				}
            }
        }
        private void applyDefaultValues(){
            if(this.model.Default_Values__r.isEmpty()) return;
            for(SObject_Clone_Default_Value__mdt defaultValue : this.model.Default_Values__r){
                this.data.put(defaultValue.Field_Name__c, defaultValue.Value__c);
            }
        }
        public virtual void saveRecord(){
            if(strategy == null){
                this.strategy = new PersistenceStrategy.BasicSave();
            }
            strategy.persist(this.data);
        }
        public SObject getClonedData(){
            return this.data;
        }

    }
    private abstract class SObjectFieldRelationBase implements Relatable, TargetsField{
        private String targetFieldApiName;
        private SObjectFieldRelationBase relationship;
        private SObjectFieldRelationBase(String targetFieldApiName){
            setTargetField(targetFieldApiName);
            if(hasRelationship()){
                this.relationship = createRelationship();
            }
        }
        private Object extractValue(SObject relatedObject){
            if(hasRelationship()){
                String objectNameToTraverse = getRelationship().getRelatedEntityReference();
                SObject traversedObject = (SObject)relatedObject.getSObject(objectNameToTraverse);
                return getRelationship().extractValue(traversedObject);
            }else{
                return relatedObject.get(getTargetFieldName());
            }
        }
        private abstract SObjectFieldRelationBase createRelationship();
        private Boolean hasRelationship(){
            return this.targetFieldApiName.contains('.');
        }
        private virtual String getRelatedEntityReference(){
            if(hasRelationship()){
                return this.targetFieldApiName.substringBefore('.');
            }
            return null;
        }
        public SObjectFieldRelationBase getRelationship(){
            return this.relationship;
        }
        public String getTargetFieldName(){
            return this.targetFieldApiName;
        }
        private abstract void setTargetField(String targetFieldName);

    }
    private class SObjectCloneField extends SObjectFieldRelationBase{
        private String objectFieldName; //Primary_Contact_Name__c;
        private SObjectCloneField(String targetFieldApiName, String applicationApiName){
            super(targetFieldApiName);
            this.objectFieldName = applicationApiName;
        }
        private override SObjectFieldRelationBase createRelationship(){
            return new SObjectFieldRelation(this.targetFieldApiName);
        }
        private override void setTargetField(String targetFieldName){
            this.targetFieldApiName = targetFieldName;
        }
    }
    private class SObjectFieldRelation extends SObjectFieldRelationBase{
        private String parentListApiName;
        private SObjectFieldRelation(String targetField){
            super(targetField);
            this.parentListApiName = targetField.substringBefore('.');
        }
        private override void setTargetField(String targetField){
            this.targetFieldApiName = targetField.substringAfter('.');
        }
        private override String getRelatedEntityReference(){
            return this.parentListApiName;
        }
        private override SObjectFieldRelationBase createRelationship(){
            return new SObjectFieldRelation(this.targetFieldApiName.substringAfter('.'));
        }
    }
    public static String generateQueryForModel(String modelName){
        SObject_Clone_Model__mdt model = modelsByLabel.get(modelName);
        Set<String> fieldsToAdd = new Set<String>();
        for(SObject_Clone_Field__mdt field : model.Fields__r){
            fieldsToAdd.add(field.Target_Field_Name__c);
            fieldsToAdd.add(field.Object_Field_Name__c);
        }
        for(SObject_Clone_Default_Value__mdt defaultValue : model.Default_Values__r){
            fieldsToAdd.add(defaultValue.Field_Name__c);
        }
        String fields = String.join(new List<String>(fieldsToAdd), ', ');
        String query = String.format(QUERY_BASE, new List<String>{fields, model.Object__c});
        return query;
    }
}