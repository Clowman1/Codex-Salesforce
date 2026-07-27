/**
 * Created by toma on 5/19/2022.
 */

public with sharing class TransactionRepository {
    private static List<String> TRANSACTION_FIELDS;
    private static TransactionRepository self;
    static{
        List<String> fields = new List<String>();
        Set<String> relatedAccountFields = new Set<String>();
        Map<String, SObjectField> oppFieldMap = Schema.getGlobalDescribe().get('Transaction__c').getDescribe().fields.getMap();
        Map<String, SObjectField> accountFieldMap = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
        for(String fieldName : oppFieldMap.keySet())
        {
            fields.add(fieldName);
        }
        for(String fieldName : accountFieldMap.keySet()){
            relatedAccountFields.add('Borrower_Name__r.' + fieldName);
            
        }
        fields.addAll(relatedAccountFields); 
        TRANSACTION_FIELDS = fields;
    }
    public static TransactionRepository getInstance(){
        if(self==null){
            self = new TransactionRepository();
        }
        return self;
    }
    public Transaction__c getTransactionById(String id){
        System.debug('transaction record id: '+id);
        String query = 'SELECT ' + String.join(TRANSACTION_FIELDS, ',') + ' FROM Transaction__c WHERE Id=:id';
        System.debug('transaction query: '+query);
        Transaction__c loan = (Transaction__c)Database.query(query);
        return loan;
    }
    
    public Map<Id, Loan> getTransactionsMapByIds(Set<Id> loanIds) {
        String query = 'SELECT ' + String.join(TRANSACTION_FIELDS, ',')
            + ' FROM Transaction__c where Id IN: loanIds';
        
        Map<Id, Loan> loans = new Map<Id, Loan>();
        for (Transaction__c deal : (List<Transaction__c>) Database.query(query)) {
            loans.put(deal.Id, new Loan(deal));
        }
        return loans;
    }

    public Map<Id, Transaction__c> selectForDpaSecondByIds(Set<Id> transactionIds) {
        if (transactionIds == null || transactionIds.isEmpty()) {
            return new Map<Id, Transaction__c>();
        }

        return new Map<Id, Transaction__c>([
            SELECT
                Id,
                RecordTypeId,
                Status__c,
                Lien_Position__c,
                First_Mortgage__c,
                Second_Mortgage__c,
                Borrower_Name__c,
                Borrower_Name__r.LastName,
                Borrower_Last_Name__c,
                Account__c,
                Property_Address__c,
                Property_City__c,
                Property_State__c,
                Property_Postal_Code__c,
                Property_Unit__c,
                Property_Type__c,
                Purchase_Date__c,
                Appraisal__c,
                Appraised_Value__c,
                Purchase_Price__c,
                Processor__c,
                Closing_Date__c,
                Funding_Date__c,
                Disclosures_Out_Date__c,
                Disclosures_Received_Date__c,
                Rate_Lock_Status__c,
                Rate_Lock_Exp_Date__c,
                Occupancy__c,
                Submission_Form_Date__c,
                Lender_lookup__c,
                Loan_Amount_1st__c,
                Loan_Type_1st_TD__c,
                Loan_Program_1st__c,
                Rate_1st_TD__c
            FROM Transaction__c
            WHERE Id IN :transactionIds
        ]);
    }

    public Map<Id, Transaction__c> selectSecondTransactionsByFirstIds(Set<Id> firstTransactionIds) {
        Map<Id, Transaction__c> firstToSecond = new Map<Id, Transaction__c>();
        if (firstTransactionIds == null || firstTransactionIds.isEmpty()) {
            return firstToSecond;
        }

        for (Transaction__c secondTransaction : [
            SELECT Id, First_Mortgage__c
            FROM Transaction__c
            WHERE First_Mortgage__c IN :firstTransactionIds
        ]) {
            if (!firstToSecond.containsKey(secondTransaction.First_Mortgage__c)) {
                firstToSecond.put(secondTransaction.First_Mortgage__c, secondTransaction);
            }
        }

        return firstToSecond;
    }

    public Map<Id, Transaction__c> selectSecondTransactionNamesByIds(Set<Id> transactionIds) {
        if (transactionIds == null || transactionIds.isEmpty()) {
            return new Map<Id, Transaction__c>();
        }

        return new Map<Id, Transaction__c>([
            SELECT Id, Borrower_Name__r.LastName, Borrower_Last_Name__c, Loan_Number__c, Loan_2nd_TD__c
            FROM Transaction__c
            WHERE Id IN :transactionIds
        ]);
    }
    
    public List<Loan> getUWMLoans(){
        List<Transaction__c> transactions = new List<Transaction__c>();
        
        transactions = [
            SELECT Id, OwnerId, Loan_Number__c
            FROM Transaction__c
            WHERE Lender_lookup__r.Name = 'UWM' AND Loan_Number__c != NULL AND Closed__c = FALSE
        ];
        
        
        List<Loan> loans = new List<Loan>();
        for(Transaction__c deal : transactions){
            Loan openLoan = new Loan(deal);
            loans.add(openLoan);
        }
        return loans;
    }
}
