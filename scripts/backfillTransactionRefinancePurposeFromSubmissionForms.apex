Map<Id, Submission_Form__c> latestSubmissionByTransaction = new Map<Id, Submission_Form__c>();

for (Submission_Form__c submissionForm : [
    SELECT Id, Transaction__c, Refinance_Purpose__c, CreatedDate
    FROM Submission_Form__c
    WHERE Transaction__c != null
    AND Refinance_Purpose__c != null
    ORDER BY Transaction__c, CreatedDate DESC
    LIMIT 10000
]) {
    if (!latestSubmissionByTransaction.containsKey(submissionForm.Transaction__c)) {
        latestSubmissionByTransaction.put(submissionForm.Transaction__c, submissionForm);
    }
}

List<Transaction__c> updates = new List<Transaction__c>();
for (Transaction__c transactionRecord : [
    SELECT Id, Refinance_Purpose__c, Refinance_Purpose_Picklist__c
    FROM Transaction__c
    WHERE Id IN :latestSubmissionByTransaction.keySet()
]) {
    String refinancePurpose = latestSubmissionByTransaction.get(transactionRecord.Id).Refinance_Purpose__c;
    if (
        transactionRecord.Refinance_Purpose_Picklist__c != refinancePurpose ||
        transactionRecord.Refinance_Purpose__c != refinancePurpose
    ) {
        updates.add(new Transaction__c(
            Id = transactionRecord.Id,
            Refinance_Purpose__c = refinancePurpose,
            Refinance_Purpose_Picklist__c = refinancePurpose
        ));
    }
}

if (!updates.isEmpty()) {
    update updates;
}

System.debug('Backfilled transaction refinance purpose from submission forms: ' + updates.size());
