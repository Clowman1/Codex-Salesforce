public class NCS_Checklist {
	private Checklist checklist;
	
	public enum Validation {
		EQUAL, GREATER_THAN, LESS_THAN,
		GREATER_THAN_EQUAL, LESS_THEN_EQUAL, IS_NULL,
		IS_NOT_NULL, CUSTOM, EQUAL_COMPARED,
		GREATER_THAN_COMPARED, GREATER_THAN_EQUAL_COMPARED,
		LESS_THAN_COMPARED, LESS_THAN_EQUAL_COMPARED,
		IS_EQUAL_TO_VALUE,IS_LESS_THAN_VALUE,
		IS_LESS_THAN_OR_EQUAL_VALUE,IS_GREATER_THAN_VALUE,
		IS_GREATER_OR_EQUAL_VALUE
	}
	
	public class Checklist {
		@AuraEnabled
		public String title;
		@AuraEnabled
		public List<ChecklistItem> items;
		@AuraEnabled
		public String objectType;
		@AuraEnabled
		public SObject record;

		public Checklist(ChecklistConfiguration__mdt config, Id recordId) {
			Set<String> fieldsToQuery = new Set<String> ();
			this.title = config.Label;
			this.items = new List<ChecklistItem> ();
			this.objectType = config.SObject__c;
			system.debug('objectType ' + this.objectType);
			for (ChecklistItem__mdt item : config.Checklist_Items__r) {
				if (item.FieldName__c != null) {
					fieldsToQuery.add(item.FieldName__c);
				}
				if (item.CompareToField__c != null) {
					fieldsToQuery.add(item.CompareToField__c);
				}
				if (item.ValidationField__c != null) {
					fieldsToQuery.add(item.ValidationField__c);
				}
			}
			List<String> fields = new List<String> ();
			fields.addAll(fieldsToQuery);
			system.debug('fields ' + fields);
			this.record = queryForRecord(fields, objectType, recordId);
			for (ChecklistItem__mdt item : config.Checklist_Items__r) {
				this.items.add(new ChecklistItem(item, this.record,record.get(item.FieldName__c) == null ? null : String.valueOf(record.get(item.FieldName__c))));
			}
		}
        
		public Checklist(ChecklistConfiguration__mdt config, Id recordId, String relatedRecordField) {
			String queryForRelated = 'SELECT Id, ' + relatedRecordField + ' FROM '+ recordId.getSObjectType().getDescribe().getName()+ ' WHERE Id =: recordId';
            SObject record = (SObject)Database.query(queryForRelated);
            recordId = (String)record.get(relatedRecordField);
            
			Set<String> fieldsToQuery = new Set<String> ();
			this.title = config.Label;
			this.items = new List<ChecklistItem> ();
			this.objectType = config.SObject__c;
			for (ChecklistItem__mdt item : config.Checklist_Items__r) {
				if (item.FieldName__c != null) {
					fieldsToQuery.add(item.FieldName__c);
				}
				if (item.CompareToField__c != null) {
					fieldsToQuery.add(item.CompareToField__c);
				}
				if (item.ValidationField__c != null) {
					fieldsToQuery.add(item.ValidationField__c); 
				}
			}
			List<String> fields = new List<String> ();
			fields.addAll(fieldsToQuery);
			this.record = queryForRecord(fields, objectType, recordId);
			for (ChecklistItem__mdt item : config.Checklist_Items__r) {
				this.items.add(new ChecklistItem(item, this.record,this.record.get(item.FieldName__c) == null ? null : String.valueOf(this.record.get(item.FieldName__c))));
			}
		}
		private SObject queryForRecord(List<String> fields, String objectType, Id recordId) {
            System.debug('this is the record Id: ' + recordId);
			String query = 'SELECT ' + String.join(fields, ',') + ' FROM ' + objectType + ' WHERE Id =: recordId';
			System.debug('this is the query: ' + query);
			return Database.query(query);
		}
	} 

	public class ChecklistItem implements Comparable {
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String fieldName;
		@AuraEnabled
		public String validationField;
		@AuraEnabled
		public String compareToField;
		@AuraEnabled
		public Boolean isReadOnly;
		@AuraEnabled
		public Object validationValue;
		@AuraEnabled
		public Boolean hasValidation;
		@AuraEnabled
		public Boolean isVisible;
		@AuraEnabled
		public Decimal order;
		@AuraEnabled
		public String fieldType;
		@AuraEnabled
		public Validation validationType;
		@AuraEnabled
		public String completedDate;
		
		protected transient Map<String, Validation> validationValueToEnumerationMap = new Map<String, Validation> {
			'Is Equal To' => Validation.EQUAL,
			'Is Equal To Compared Field' => Validation.EQUAL_COMPARED,
			'Is Greater Than' => Validation.GREATER_THAN,
			'Is Greater Than Compared Field' => Validation.GREATER_THAN_COMPARED,
			'Is Greater Than Or Equal To' => Validation.GREATER_THAN_EQUAL,
			'Is Greater Than Or Equal to Compared Field' => Validation.GREATER_THAN_EQUAL_COMPARED,
			'Is Less Than' => Validation.LESS_THAN,
			'Is Less Than Compared Field' => Validation.LESS_THAN_COMPARED,
			'Is Less Than Or Equal To' => Validation.LESS_THEN_EQUAL,
			'Is Less Than Or Equal to Compared Field' => Validation.LESS_THAN_EQUAL_COMPARED,
			'Is Not Null' => Validation.IS_NOT_NULL,
			'Is Null' => Validation.IS_NULL,
			'Is Custom Validation' => Validation.CUSTOM,
			'Is Equal To Value' => Validation.IS_EQUAL_TO_VALUE,
			'Is Less Than Value' => Validation.IS_LESS_THAN_VALUE,
			'Is Less Than Or Equal To Value' => Validation.IS_LESS_THAN_OR_EQUAL_VALUE,
			'Is Greater Than Value' => Validation.IS_GREATER_THAN_VALUE,
			'Is Greater Than Or Equal To Value'=> Validation.IS_GREATER_OR_EQUAL_VALUE
		};
		public ChecklistItem(ChecklistItem__mdt config, SObject record, String completedDate) {
			this.label = config.Label;
			this.isReadOnly = config.IsReadOnly__c;
            this.fieldName = config.FieldName__c;
			this.completedDate = completedDate;
            this.order = config.Order__c;
            this.hasValidation = config.HasValidation__c;
            this.compareToField = config.CompareToField__c;
            this.validationValue = config.ValidationValue__c;
            this.validationField = config.ValidationField__c;
            this.fieldType = this.getFieldType(config.FieldName__c,record.Id.getSObjectType().getDescribe().getName());
            this.isVisible = true;
            if (this.hasValidation) {
                this.validationType = validationValueToEnumerationMap.get(config.ValidationType__c);
                System.debug(this.validationType  + ' yoooo ');
                this.isVisible = validate(record);
				System.debug('is visible ' + this.isVisible);
			}
		}
		private Boolean isEqual(Object field1, Object field2){
			return field1 == field2;
		}
		
		private Boolean isGreaterThan(Object field1, Object field2){
			if(field1 instanceOf Boolean){
				throw new ChecklistException('Boolean can not be compared in Greater Than Validation: ' );
			}else if(field1 instanceOf Date || field1 instanceOf Datetime){
				return (Datetime) field1 > (Datetime) field2;
			}else if(field1 instanceOf Decimal || field1 instanceOf Integer){
				return (Decimal)field1 > (Decimal)field2;
			}
			throw new ChecklistException('FieldType not supported for Greater Than Validation');
		}
		
		private Boolean isLessThan(Object field1, Object field2){
			if(field1 instanceOf Boolean){
				throw new ChecklistException('Boolean can not be compared in Greater Than Validation: ' );
			}else if(field1 instanceOf Date || field1 instanceOf Datetime){
				return (Datetime) field1 < (Datetime) field2;
			}else if(field1 instanceOf Decimal || field1 instanceOf Integer){
				return (Decimal)field1 < (Decimal)field2;
			}
			throw new ChecklistException('FieldType not supported for Greater Than Validation');
		}
		private Boolean isGreaterThanOrEqual(Object field1, Object field2){
			if(field1 instanceOf Boolean){
				throw new ChecklistException('Boolean can not be compared in Greater Than Validation: ' );
			}else if(field1 instanceOf Date || field1 instanceOf Datetime){
				return (Datetime) field1 >= (Datetime) field2;
			}else if(field1 instanceOf Decimal || field1 instanceOf Integer){
				return (Decimal)field1 >= (Decimal)field2;
			}
			throw new ChecklistException('FieldType not supported for Greater Than Validation');
		}
		
		private Boolean isLessThanOrEqual(Object field1, Object field2){
			if(field1 instanceOf Boolean){
				throw new ChecklistException('Boolean can not be compared in Greater Than Validation: ' );
			}else if(field1 instanceOf Date || field1 instanceOf Datetime){
				return (Datetime) field1 <= (Datetime) field2;
			}else if(field1 instanceOf Decimal || field1 instanceOf Integer){
				return (Decimal)field1 <= (Decimal)field2;
			}
			throw new ChecklistException('FieldType not supported for Greater Than Validation');
		}
		private String getFieldType(String fieldName,String objectName){
			
			SObjectType r = ((SObject)(Type.forName('Schema.'+objectName).newInstance())).getSObjectType();
			DescribeSObjectResult d = r.getDescribe();
			System.debug(d.fields.getMap().get(fieldName).getDescribe().getType());
			return String.ValueOf(d.fields.getMap().get(fieldName).getDescribe().getType());
		}
		private String getType(Object o) {
			if(o==null) return '';              // we can't say much about null with our current techniques
			if(o instanceof SObject)            return ((SObject)o).getSObjectType().getDescribe().getName()+'';
			if(o instanceof Boolean)            return 'Boolean';
			if(o instanceof Id)                 return 'Id';
			if(o instanceof String)             return 'String';
			if(o instanceof Blob)               return 'Blob';
			if(o instanceof Date)               return 'Date';
			if(o instanceof Datetime)           return 'Datetime';
			if(o instanceof Time)               return 'Time';
			if(o instanceof String)             return 'String';
			if(o instanceof Integer)            return 'Integer';
			if(o instanceof Long)               return 'Long';
			if(o instanceof Decimal)            return 'Decimal';  // we can't distinguish between decimal and double
			if(o instanceof Double)             return 'Double';   // we can't distinguish between decimal and double
			if(o instanceof List<object>)       return 'List';
			return 'Object';                    // actually we can't detect maps and sets and maps
		}
		
		private Boolean validate(SObject record) {
			if (!hasValidation) {
				return true;
			}
			switch on validationType {
				when EQUAL {
                    System.debug(this.validationField + 'valid');
                    System.debug(record.get(this.validationField) + 'valid');
                    System.debug(this.fieldName + 'field');
                    System.debug(record.get(this.fieldName) + 'field');
					return record.get(this.validationField) == record.get(this.fieldName);
				}
				when EQUAL_COMPARED {
					return record.get(this.validationField) == record.get(this.compareToField);
				}
				when GREATER_THAN {
					return isGreaterThan(record.get(this.validationField), record.get(this.fieldName));
				}
				when GREATER_THAN_COMPARED{
					return isGreaterThan(record.get(this.validationField),(Decimal) record.get(this.compareToField));
				}
				when GREATER_THAN_EQUAL{
					return isGreaterThanOrEqual(record.get(this.validationField), record.get(this.fieldName));
				}
				when GREATER_THAN_EQUAL_COMPARED{
					return isGreaterThanOrEqual(record.get(this.validationField),record.get(this.compareToField));
				}
				when LESS_THAN{
					return isLessThan(record.get(this.validationField), record.get(this.fieldName));
				}
				when LESS_THAN_COMPARED{
					return isLessThan(record.get(this.validationField),(Decimal) record.get(this.compareToField));
				}
				when LESS_THEN_EQUAL{
					return isLessThanOrEqual(record.get(this.validationField), record.get(this.fieldName));
				}
				when LESS_THAN_EQUAL_COMPARED{
					return isLessThanOrEqual(record.get(this.validationField),(Decimal) record.get(this.compareToField));
				}
				when IS_NULL{
					if(record.get(this.validationField) instanceof Boolean){
						return !((Boolean)record.get(this.validationField));
					}
					return record.get(this.validationField) == null;
				}
				when IS_NOT_NULL {
					if(record.get(this.validationField) instanceof Boolean){
						return ((Boolean)record.get(this.validationField));
					}
					return record.get(this.validationField) == null;
				}
				WHEN IS_EQUAL_TO_VALUE{
					return isEqual(record.get(this.validationField), this.validationValue);
				}
				WHEN IS_LESS_THAN_VALUE{
					return isLessThan(record.get(this.validationField), this.validationValue);
				}
				WHEN IS_LESS_THAN_OR_EQUAL_VALUE{
					return isLessThanOrEqual(record.get(this.validationField), this.validationValue);
				}
				WHEN IS_GREATER_THAN_VALUE{
					return isGreaterThan(record.get(this.validationField), this.validationValue);
				}
				WHEN IS_GREATER_OR_EQUAL_VALUE{
					return isGreaterThanOrEqual(record.get(this.validationField), this.validationValue);
				}
				when else {
					return true;
				}
			}
		}

		public Integer compareTo(Object comparedItem) {
			if (!(comparedItem instanceof ChecklistItem)) {
				return - 1;
			}
			if (this.order > ((ChecklistItem) comparedItem).order) {
				return 1;
			} else if (this.order<((ChecklistItem) comparedItem).order) {
				return - 1;
			}
			return 0;
		}

	}
	public static Checklist generateChecklist(String configurationId, String recordId, String relatedFieldId) {
		ChecklistConfiguration__mdt config = [SELECT Id, Label, SObject__c,
												(SELECT Id, Label, CompareToField__c, FieldName__c,
												 HasValidation__c, IsReadOnly__c, Order__c,ValidationValue__c,
												 ValidationField__c, ValidationType__c
												 FROM Checklist_Items__r
												 ORDER BY Order__c) FROM ChecklistConfiguration__mdt
												 WHERE Id =: configurationId];
		return new Checklist(config, recordId, relatedFieldId);
	}
	
	
	public static Checklist generateChecklist(String configurationId, String recordId) {
		ChecklistConfiguration__mdt config = [SELECT Id, Label, SObject__c,
												(SELECT Id, Label, CompareToField__c, FieldName__c,
												 HasValidation__c, IsReadOnly__c, Order__c,ValidationValue__c,
												 ValidationField__c, ValidationType__c
												 FROM Checklist_Items__r
												 ORDER BY Order__c) FROM ChecklistConfiguration__mdt
												 WHERE Id =: configurationId];
		return new Checklist(config, recordId);
	}
	
	class ChecklistException extends Exception{}
}