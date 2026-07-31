public class UWMLoanInfoRepository {
	private static List<String> LOAN_FIELDS;
    private static UWMLoanInfoRepository self;
    private static List<String> stages = new List<String>{ 'Open', 'Closing','Funding','Processing', 'Submitted', 'Conditionally Approved',
        												   'Re-Submitted', 'Approved','Waiting On Loan Officer',
        												   'TRID Application', 'Submission Form Complete', 'Disclosures Out', 'Pre-Processing' };
    static{
        List<String> fields = new List<String>();
        Set<String> ownerFields = new Set<String>();
        Set<String> excludedUserFields = new Set<String>{'profilephotoid','bannerphotoid', 'userpreferencessendviainternalemailservice'};
        Set<String> relatedAccountFields = new Set<String>();
        List<String> relatedPartnerFields = new List<String>();
        List<String> relatedContactAccount = new List<String>();
        Map<String, SObjectField> oppFieldMap = Schema.getGlobalDescribe().get('UWM_Loan_Info__c').getDescribe().fields.getMap();
        Map<String, SObjectField> accountFieldMap = Schema.getGlobalDescribe().get('Transaction__c').getDescribe().fields.getMap();
        Map<String, SObjectField> userFieldMap = Schema.getGlobalDescribe().get('User').getDescribe().fields.getMap(); 

        for(String fieldName : oppFieldMap.keySet())
        {
            fields.add(fieldName);
        }
        for(String fieldName : accountFieldMap.keySet()){
            relatedAccountFields.add('Transaction__r.' + fieldName);  
        }
        fields.addAll(relatedAccountFields);
        LOAN_FIELDS = fields;
    }
    public static UWMLoanInfoRepository getInstance(){
        if(self==null){
            self = new UWMLoanInfoRepository();
        }
        return self;
    }

    public List<UWM_Loan_Info__c> getUWMLoansByLoanId(string loanId){
        String query = 'SELECT ' + String.join(LOAN_FIELDS,',') + ' FROM UWM_Loan_Info__c WHERE Transaction__c=:loanId';
        List<UWM_Loan_Info__c> loans = (List<UWM_Loan_Info__c>)Database.query(query);
        return loans;
    }
    
    public Map<Id,UWM_Loan_Info__c> getUWMLoanInfosByIds(Set<Id> infoIds){
        String query = 'SELECT ' + String.join(LOAN_FIELDS,',') + ' FROM UWM_Loan_Info__c WHERE Id IN: infoIds';
        Map<Id,UWM_Loan_Info__c> loanMap = new Map<Id,UWM_Loan_Info__c>();
        
        SObjectAccessDecision securityDecision = Security.stripInaccessible(
            AccessType.READABLE,
            Database.query(String.escapeSingleQuotes(query))
        );
        
        List<UWM_Loan_Info__c> infoRecords = (List<UWM_Loan_Info__c>) securityDecision.getRecords();
        if(infoRecords.isEmpty()){
            return loanMap;
        }
        loanMap = new Map<Id,UWM_Loan_Info__c>(infoRecords);
        //System.debug('loan Info Map: ' + loanMap);
        return loanMap;       
    }
    
    public UWM_Loan_Info__c getUWMLoanById(String id){
        String query = 'SELECT ' + String.join(LOAN_FIELDS,',') + ' FROM UWM_Loan_Info__c WHERE Id=:id';
        UWM_Loan_Info__c loanInfo = (UWM_Loan_Info__c)Database.query(query); 
        return loanInfo;
    }
	public UWM_Loan_Info__c getUWMLoanByLoanId(string loanId){
        String query = 'SELECT ' + String.join(LOAN_FIELDS,',') + ' FROM UWM_Loan_Info__c WHERE Id=:loanId';
        List<UWM_Loan_Info__c> loans = (List<UWM_Loan_Info__c>)Database.query(query);
        if(loans.size() == 0){
            return null;
        }
        return loans[0];
    }
    public List<UWM_Loan_Info__c> getActiveLoanPipeline(){
        String query = 'SELECT Id'
                + ' FROM UWM_Loan_Info__c where Transaction__r.Loan_Number__c != null AND Transaction__r.Status__c IN : stages '; 

        List<UWM_Loan_Info__c> deals = (List<UWM_Loan_Info__c>)Database.query(query);
        return deals;
    }
}