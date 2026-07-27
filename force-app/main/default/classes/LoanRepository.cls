/**
 * Created by zeyad on 7/13/2020.
 */


public with sharing class LoanRepository {
    private static List<String> LOAN_FIELDS;
    private static LoanRepository self;
    static{
        List<String> fields = new List<String>();
        Set<String> ownerFields = new Set<String>();
        Set<String> excludedUserFields = new Set<String>{
                'profilephotoid','bannerphotoid', 'userpreferencessendviainternalemailservice', 'companyname', 'division',
                'department', 'street', 'city', 'state', 'postalcode', 'country', 'latitude', 'longitude', 'geocodeaccuracy',
                'address', 'emailpreferencesautobcc', 'emailpreferencesautobccstayintouch', 'emailpreferencesstayintouchreminder',
                'senderemail' , 'sendername', 'sign', 'signature', 'stayintouchsubject', 'stayintouchsignature', 'stayintouchnote',
                'fax', 'mobilephone', 'communitynickname', 'badgetext', 'timezonesidkey'

        };
        Set<String> relatedAccountFields = new Set<String>();
        List<String> relatedPartnerFields = new List<String>();
        List<String> relatedContactAccount = new List<String>();
        Map<String, SObjectField> transactionFieldMap = Schema.getGlobalDescribe().get('Transaction__c').getDescribe().fields.getMap();
        Map<String, SObjectField> accountFieldMap = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        Map<String, SObjectField> userFieldMap = Schema.getGlobalDescribe().get('User').getDescribe().fields.getMap();
        for(String fieldName : transactionFieldMap.keySet())
        {
            fields.add(fieldName);
        }
        for(String fieldName : accountFieldMap.keySet()){
            relatedAccountFields.add('Borrower_Name__r.' + fieldName);
        }
        for(String fieldName : userFieldMap.keySet()){
            if(!excludedUserFields.contains(fieldName)){
//                ownerFields.add('Owner.'+fieldName);
            }
        }
        fields.addAll(ownerFields);
        fields.addAll(relatedAccountFields);

        LOAN_FIELDS = fields;
    }
    public static LoanRepository getInstance(){
        if(self==null){
            self = new LoanRepository();
        }
        return self;
    }
    
    public Map<Id, Loan> getLoanMapByIds(Set<Id> loanIds){
        String query = 'SELECT ' + String.join(LOAN_FIELDS, ',')
                + ' FROM Transaction__c where Id IN: loanIds';
        Map<Id, Loan> loans = new Map<Id, Loan>();
        for(Transaction__c deal :  (List<Transaction__c>)Database.query(query)){
            loans.put(deal.Id, new Loan(deal));
        }
        return loans;
    }

    public Loan getLoanById(String loanId){
        String query = 'SELECT ' + String.join(LOAN_FIELDS, ',') + ',Owner.Email'
                + ' FROM Transaction__c WHERE Id=:loanId';
        Transaction__c deal = (Transaction__c)Database.query(query);
        system.debug(new Loan(deal));
        return new Loan(deal);
    }

    public Loan getLoanForBorrowerPortalById(Id loanId) {
        if (loanId == null) {
            return null;
        }

        String query = buildBorrowerPortalQuery()
            + ' WHERE Id = :loanId LIMIT 1';
        List<Transaction__c> deals = Database.query(query);
        return deals.isEmpty() ? null : new Loan(deals[0]);
    }

    public Loan getFirstLoanWithPortalHash() {
        String query = buildBorrowerPortalQuery()
            + ' WHERE Portal_Hash_Parameter__c != NULL LIMIT 1';
        List<Transaction__c> deals = Database.query(query);
        return deals.isEmpty() ? null : new Loan(deals[0]);
    }

    public List<Transaction__c> selectTransactionsByIds(Set<Id> transactionIds) {
        if (transactionIds == null || transactionIds.isEmpty()) {
            return new List<Transaction__c>();
        }

        return [
            SELECT Id, Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id IN :transactionIds
        ];
    }

    public Database.QueryLocator getBorrowerPortalHashRefreshScope() {
        return Database.getQueryLocator([
            SELECT Id
            FROM Transaction__c
            WHERE Portal_Hash_Parameter__c != NULL
        ]);
    }
    
    public Loan getLoanByFedexTrackingNumber(String fedexNumber){
        String query = 'SELECT ' + String.join(LOAN_FIELDS, ',') + ',Owner.Email'
                + ' FROM Transaction__c WHERE FedexTrackingNumber__c=:fedexNumber';
        Transaction__c deal = (Transaction__c)Database.query(query);
        system.debug(new Loan(deal));
        return new Loan(deal);
    }

    private String buildBorrowerPortalQuery() {
        return 'SELECT ' + String.join(LOAN_FIELDS, ',') + ' FROM Transaction__c';
    }

}