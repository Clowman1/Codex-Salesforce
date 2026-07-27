/**
 * Created by Zeyad Jabra on 8/19/2019.
 */

public with sharing class ARIVE_NmlsCallReportTableController {
    public class Table{
        @AuraEnabled
        public String title;
        @AuraEnabled
        public TableRow[] rows;

        public Table(){
            this.rows = new List<TableRow>();
        }
    }
    public class TableRow{
        @AuraEnabled
        public List<TableField> fields;
        @AuraEnabled
        public String id;

        public TableRow(){
            this.fields = new List<TableField>();
        }
    }
    public class TableField implements Comparable{
        @AuraEnabled
        public Decimal order;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldType;
        @AuraEnabled
        public String modifier;
        @AuraEnabled
        public Object value;

        public Integer compareTo(Object o){
            TableField obj = (TableField)o;
            if(this.order > obj.order){
                return 1;
            }else if(this.order < obj.order){
                return -1;
            }
            return 0;
        }
    }

	/*
    public static Table translateFieldSetToTable(String fieldSetName, Date startDate, Date endDate, String state){
//        Table table = new Table();
//        FieldSet__Mdt mdata;
//        Boolean isLoanOfficer = false;
//        Set<String> nonQmProducts = new Set<String>();
//
//        if(fieldSetName=='AC920' || fieldSetName=='AC930'){
//            for(Non_QM_Product__mdt product : [SELECT Id, Label, Lender__c,Product_Name__c, Active__c FROM Non_QM_Product__mdt WHERE Active__c = true]){
//                nonQmProducts.add(product.Product_Name__c);
//            }
//        }
//
//        if(!fieldSetName.contains('AC')){
//            isLoanOfficer = true;
//            mdata = [SELECT Id,  Query__c, Label, (SELECT Id, Order__c, Api_Name__c, Modifier__c, Display_Name__c, Type__c FROM Fields__r)  FROM FieldSet__Mdt WHERE DeveloperName= 'nmlscr_LO'];
//        }else{
//            fieldSetName = 'nmlscr_' + fieldSetName;
//            mdata = [SELECT Id,  Query__c, Label, (SELECT Id, Order__c, Api_Name__c, Modifier__c, Display_Name__c, Type__c FROM Fields__r)  FROM FieldSet__Mdt WHERE DeveloperName=: fieldSetName];
//        }
//
//        List<SObject> loans = database.query(mdata.Query__c);
//        table.title = mdata.Label;
//        for(Loan__c loan : (List<Loan__c>)loans){
//            TableRow row = new TableRow();
//            for(FieldSetMember__mdt m : mdata.Fields__r){
//                TableField field = new TableField();
//                field.order = m.Order__c;
//                field.label = m.Display_Name__c;
//                field.modifier = m.Modifier__c;
//                field.fieldType = m.Type__c;
//                field.value = getFieldValue(m.Api_Name__c, loan);
//                row.fields.add(field);
//            }
//            row.fields.sort();
//            row.id = loan.Id;
//            table.rows.add(row);
//        }
//        return table;
        return null;
    }
	*/

	 public static Table translateFieldSetToTable(String fieldSetName, Date startDate, Date endDate, String state){
        Table table = new Table();
        NMLS_CR_FieldSet__mdt mdata;
		String queryStr;

		/*
        Set<String> nonQmProducts = new Set<String>();

        if(fieldSetName=='AC920' || fieldSetName=='AC930'){
            for(Non_QM_Product__mdt product : [SELECT Id, Label, Lender__c,Product_Name__c, Active__c FROM Non_QM_Product__mdt WHERE Active__c = true]){
                nonQmProducts.add(product.Product_Name__c);
            }
        }
		*/
		
        if(!fieldSetName.contains('AC')){ 
            mdata = [SELECT Id,  Query__c, Label FROM NMLS_CR_FieldSet__mdt WHERE DeveloperName= 'nmlscr_LO'];
			queryStr = mdata.Query__c.replace('startDate',String.valueOf(startDate)).replace('endDate',String.valueOf(endDate)).replace('state',state).replace('nmlsId',fieldSetName);
        }else{
            fieldSetName = 'nmlscr_' + fieldSetName;
            mdata = [SELECT Id,  Query__c, Label FROM NMLS_CR_FieldSet__mdt WHERE DeveloperName=: fieldSetName];
			queryStr = mdata.Query__c.replace('startDate',String.valueOf(startDate)).replace('endDate',String.valueOf(endDate)).replace('state',state);
        }
		System.debug('fieldSetName ========= '+fieldSetName);
		System.debug('String Query ======== '+queryStr);
        List<SObject> loans = database.query(queryStr);
        table.title = mdata.Label;
        for(Transaction__c loan : (List<Transaction__c>)loans){
            TableRow row = new TableRow();
           
            TableField field = new TableField();
            field.order = 1;
            field.label = 'Transaction Name';
            field.value = loan.Name;
            row.fields.add(field);
            
            TableField field2 = new TableField();
            field2.order = 2;
            field2.label = 'Loan Number';
            field2.value = loan.Loan_Number__c;
            row.fields.add(field2);

			TableField field3 = new TableField();
            field3.order = 3;
            field3.label = 'Loan Officer';
            field3.value = loan.Loan_Officer__r.Name;
            row.fields.add(field3);

			TableField field4 = new TableField();
            field4.order = 4;
            field4.label = 'Loan Amount';
            field4.value = loan.Loan_Amount_1st__c;
            row.fields.add(field4);

			TableField field5 = new TableField();
            field5.order = 5;
            field5.label = 'Trid Date';
            field5.value = loan.TRID_Date__c;
            row.fields.add(field5);

			TableField field6 = new TableField();
            field6.order = 6;
            field6.label = 'Funded Date';
            field6.value = loan.Funding_Date__c;
            row.fields.add(field6);
            
            TableField field7 = new TableField();
            field7.order = 7;
            field7.label = 'Withdrawn Date';
            field7.value = loan.Withdrawn__c;
            row.fields.add(field7);

            row.fields.sort();
            row.id = loan.Id;
            table.rows.add(row);
        }
        return table;
    }

    public static String getFieldValue(String fieldName, SObject subject) {

        if (fieldName.contains('.')) {
            List<String> stringPieces = fieldName.split('\\.');
            String stringPiece = stringPieces.remove(0);
            return getFieldValue(fieldName.substringAfter('.').substringBefore('.'), subject.getSObject(stringPiece));
        }

        return String.valueOf(subject.get(fieldName));
    }
}