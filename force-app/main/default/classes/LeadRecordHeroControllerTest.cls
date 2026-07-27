@IsTest
private class LeadRecordHeroControllerTest {
    @IsTest
    static void getSummaryReturnsLeadBannerFields() {
        Account buyerAgent = new Account(Name = 'Sample Buyer Agent');
        insert buyerAgent;

        Lead leadRecord = new Lead(
            FirstName = 'Tomas',
            LastName = 'Reilly',
            Company = 'Tomas Reilly',
            Status = 'New',
            Phone = '555-123-4567',
            Email = 'tomas@example.com',
            LeadSource = 'Personal Referral',
            Rating = 'Warm',
            Loan_Purpose__c = 'Purchase',
            Biz_Dev__c = 'Biz Dev - Olmsted',
            Realtor_Buying_Agent__c = buyerAgent.Id
        );
        insert leadRecord;

        Test.startTest();
        LeadRecordHeroController.LeadSummary summary = LeadRecordHeroController.getSummary(leadRecord.Id);
        Test.stopTest();

        System.assertEquals('Tomas Reilly', summary.name);
        System.assertEquals('555-123-4567', summary.phone);
        System.assertEquals('tomas@example.com', summary.email);
        System.assertEquals('New', summary.status);
        System.assertEquals('Personal Referral', summary.leadSource);
        System.assertEquals('Warm', summary.rating);
        System.assertEquals('Purchase', summary.loanPurpose);
        System.assertEquals('Biz Dev - Olmsted', summary.bizDev);
        System.assertEquals('Sample Buyer Agent', summary.buyersAgentName);
    }
}
