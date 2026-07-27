Savepoint sp = Database.setSavepoint();
List<String> results = new List<String>();

List<Lead> probes = new List<Lead>{
    new Lead(
        FirstName = 'Codex',
        LastName = 'Refi Probe',
        Company = 'Codex Refi Probe',
        Phone = '9999999999',
        Email = 'codex.refi.probe@example.com',
        LeadSource = 'Realtor Referral',
        Loan_Purpose__c = 'Refinance',
        Biz_Dev__c = 'Biz Dev - Reach',
        OwnerId = UserInfo.getUserId(),
        RecordTypeId = '0125x000000KuZLAA0'
    ),
    new Lead(
        FirstName = 'Codex',
        LastName = 'Purchase Probe',
        Company = 'Codex Purchase Probe',
        Phone = '9999999998',
        Email = 'codex.purchase.probe@example.com',
        LeadSource = 'Realtor Referral',
        Loan_Purpose__c = 'Purchase',
        Biz_Dev__c = 'Biz Dev - Reach',
        Realtor_Buying_Agent__c = '001Qi00000GHmqEIAT',
        OwnerId = UserInfo.getUserId(),
        RecordTypeId = '0125x000000KuZLAA0'
    )
};

for (Lead probe : probes) {
    try {
        insert probe;
        results.add(probe.LastName + ': SUCCESS ' + probe.Id);
    } catch (Exception e) {
        results.add(probe.LastName + ': ERROR ' + e.getTypeName() + ': ' + e.getMessage());
    }
}

System.debug('LEAD_INSERT_PROBE_RESULTS ' + String.join(results, ' || '));
Database.rollback(sp);
