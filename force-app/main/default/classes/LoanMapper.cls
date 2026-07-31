public class LoanMapper {
	public class UWM_Insights_Loan {
        public List<UWM_Insights_Mapping__mdt> mapping;
        public UWM_Loan_Info__c modifiedLoan;
        public UWM_Loan_Info__c originalLoan;
        public Map<String, Object> uwmLoan;

        public UWM_Insights_Loan(Map<String, Object> uwmLoan, UWM_Loan_Info__c loan) {
            Map<String, Object> loans = (Map<String, Object>) uwmLoan.get('data');
            List<Object> loanResults = loans == null ? null : (List<Object>) loans.get('Loans');
            if (loanResults == null || loanResults.isEmpty()) {
                this.uwmLoan = new Map<String, Object>{
                    'NoLoanFoundForLoanNumber' => loan == null ? null : loan.uwm_LoanNumber__c
                };
                this.originalLoan = loan;
                this.modifiedLoan = null;
                return;
            }
            uwmLoan = (Map<String, Object>) loanResults[0];
            UWM_Loan_Info__c o = loan;
            UWM_Loan_Info__c newOpp = new UWM_Loan_Info__c(Id = o.Id);
            Boolean hasChanged = false;
            this.uwmLoan = uwmLoan;
            this.originalLoan = loan;
            this.mapping = [SELECT Id, UWM_Field_Name__c, API_Name__c,Datatype__c FROM UWM_Insights_Mapping__mdt where Type__c = 'LoanPipelineUpdate'];
            for (UWM_Insights_Mapping__mdt fieldMapping : mapping) {
                System.debug('my return ' + uwmLoan.get(fieldMapping.UWM_Field_Name__c));
                Object uwmLoanValue = uwmLoan.get(fieldMapping.UWM_Field_Name__c);

                System.debug('filed ' + fieldMapping.UWM_Field_Name__c);
                System.debug('filedId ' + fieldMapping.Id);
                if(fieldMapping.UWM_Field_Name__c.contains('.')) {
                    List<String> nestedObjectStrings = fieldMapping.UWM_Field_Name__c.split('\\.');

                    Object currentObject = uwmLoan;
                    for (String s : nestedObjectStrings) {
                        currentObject = ((Map<String,Object>)currentObject).get(s);
                    }
                    uwmLoanValue = currentObject;
                }
                if (loan.get(fieldMapping.API_Name__c) != uwmLoanValue) { 
                   if (fieldMapping.Datatype__c == 'Date') {
                        String myReturnValueString = (String)uwmLoanValue;
                        Date newValue = null;
                        if(myReturnValueString != null){
                            if(myReturnValueString.contains('T')) {
                                String dateinstance = myReturnValueString.substring(0,10);
                                Date dateValue = date.valueOf(dateinstance);
                                newValue = dateValue;
                            } else {
                                Date parsedDate = Date.parse(myReturnValueString);
                                myReturnValueString = '"'+parsedDate+'"';
                                myReturnValueString = myReturnValueString.substring(1,12);
                                newValue = Date.valueOf(myReturnValueString);
                            }
                        }
                        newOpp.put(fieldMapping.API_Name__c, newValue);
                    }
                    if (fieldMapping.Datatype__c == 'Datetime' && uwmLoanValue != null) {
                        Object newValue ;
                        String myReturnValueString = (String) uwmLoanValue;
                        myReturnValueString = '"' + myReturnValueString + '"';
                        System.debug('fieldMapping from Datetime block: '+fieldMapping);
                        newValue = (DateTime) JSON.deserialize(myReturnValueString, Datetime.class);
                        newOpp.put(fieldMapping.API_Name__c, newValue);
                    }
                    if (fieldMapping.Datatype__c == 'Text') {
                        String newValue = (String) uwmLoanValue;
                        newOpp.put(fieldMapping.API_Name__c, newValue);
                    }
                    if (fieldMapping.Datatype__c == 'Boolean') {
                        if (uwmLoanValue == 1) {
                            newOpp.put(fieldMapping.API_Name__c, true);
                        }if (uwmLoanValue == true) {
                            newOpp.put(fieldMapping.API_Name__c, true);
                        }if (uwmLoanValue == 0) {
                            newOpp.put(fieldMapping.API_Name__c, false);
                        }if (uwmLoanValue == false) {
                            newOpp.put(fieldMapping.API_Name__c, false);
                        }
                    }

                    if (fieldMapping.Datatype__c == 'Decimal') {
                        Double newValue = Double.valueOf(uwmLoanValue);
                        newOpp.put(fieldMapping.API_Name__c, newValue);
                    }
                    if (fieldMapping.Datatype__c == 'Integer') {
                        Integer newValue = Integer.valueOf(uwmLoanValue);
                        newOpp.put(fieldMapping.API_Name__c, newValue);
                    }
                    hasChanged = true;
                }
            }
            if (hasChanged) {
                newOpp.MostRecentPayload__c = JSON.serializePretty(this.uwmLoan); 
                this.modifiedLoan = newOpp;
            }
        }
    }
}