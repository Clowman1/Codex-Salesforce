@IsTest
public class LeadThroughputDrilldownServiceTest {
    @testSetup
    static void setup() {
        Profile p;
        try {
            p = [SELECT Id FROM Profile WHERE Name = 'Loan Officer Profile' LIMIT 1];
        } catch (Exception e) {
            try {
                p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            } catch (Exception e2) {
                p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            }
        }

        insert buildUser('lothruD1', 'ld1', p.Id);
    }

    @IsTest
    static void drilldown_returnsNumeratorOnly_AndUsesBasisDate() {
        User lo1 = [SELECT Id FROM User WHERE Alias = 'ld1' LIMIT 1];
        Account buyingAgent = new Account(Name = 'Test Buying Agent Drilldown');
        insert buyingAgent;

        Integer y = Date.today().year();
        Integer q = ((Date.today().month() - 1) / 3) + 1;
        String qKey = String.valueOf(y) + '-Q' + String.valueOf(q);

        Transaction__c t1 = buildTransaction('TD1', Date.today().addDays(-10));
        insert t1;

        // New -> Pre-Approval numerator: pre-approval populated (regardless of post-closed).
        Lead preOnly = buildLead(lo1.Id, getLeadSourceValues()[0], Date.today(), null);
        preOnly.Loan_Purpose__c = 'Purchase';
        preOnly.Realtor_Buying_Agent__c = buyingAgent.Id;
        Lead postClosed = buildLead(lo1.Id, getLeadSourceValues()[0], Date.today(), t1.Id);
        postClosed.Loan_Purpose__c = 'Refinance';
        insert new List<Lead>{ preOnly, postClosed };

        Test.setCreatedDate(preOnly.Id, DateTime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0)));
        Test.setCreatedDate(postClosed.Id, DateTime.newInstance(Date.today().addDays(-1), Time.newInstance(10, 0, 0, 0)));

        System.runAs(lo1) {
            LeadThroughputDrilldownService.DrilldownResponse postClosedResp =
                LeadThroughputController.getTileDrilldown(
                    'QUARTER_YEAR',
                    new List<String>{ qKey },
                    lo1.Id,
                    null,
                    null,
                    'NEW_TO_POST_CLOSED',
                    25,
                    1
                );

            System.assertEquals(1, postClosedResp.totalCount, 'Expected numerator-only post-closed rows.');
            System.assertEquals(1, postClosedResp.rows.size());
            System.assertEquals(postClosed.Id, postClosedResp.rows[0].recordId);
            System.assertEquals(t1.Id, postClosedResp.rows[0].transactionId, 'Post-closed rows should include transaction id.');
            System.assertNotEquals(null, postClosedResp.rows[0].basisDateTime, 'CreatedDate basis should be present.');

            LeadThroughputDrilldownService.DrilldownResponse purchaseFilteredPostClosedResp =
                LeadThroughputController.getTileDrilldown(
                    'QUARTER_YEAR',
                    new List<String>{ qKey },
                    lo1.Id,
                    null,
                    'PURCHASE',
                    'NEW_TO_POST_CLOSED',
                    25,
                    1
                );
            System.assertEquals(
                0,
                purchaseFilteredPostClosedResp.totalCount,
                'Purchase filter should exclude refinance post-closed rows.'
            );

            // Pre-Approval -> Post-Closed still shows Lead CreatedDate in the modal.
            Lead pc2 = buildLead(lo1.Id, getLeadSourceValues()[0], Date.today().addDays(-2), t1.Id);
            pc2.Loan_Purpose__c = 'Purchase';
            pc2.Realtor_Buying_Agent__c = buyingAgent.Id;
            Lead pc3 = buildLead(lo1.Id, getLeadSourceValues()[0], Date.today().addDays(-1), t1.Id);
            pc3.Loan_Purpose__c = 'Refinance';
            insert new List<Lead>{ pc2, pc3 };

            // Created dates don't matter for this tile's timeframe basis; set them anyway for determinism.
            Test.setCreatedDate(pc2.Id, DateTime.newInstance(Date.today().addDays(-5), Time.newInstance(10, 0, 0, 0)));
            Test.setCreatedDate(pc3.Id, DateTime.newInstance(Date.today().addDays(-6), Time.newInstance(10, 0, 0, 0)));

            LeadThroughputDrilldownService.DrilldownResponse preToPostResp =
                LeadThroughputController.getTileDrilldown(
                    'QUARTER_YEAR',
                    new List<String>{ qKey },
                    lo1.Id,
                    null,
                    null,
                    'PRE_APPROVAL_TO_POST_CLOSED',
                    25,
                    1
                );

            System.assertEquals(3, preToPostResp.totalCount, 'Expected only numerator rows (post-closed + pre-approved in window).');
            System.assertEquals(3, preToPostResp.rows.size());

            // Sort order for this tile is by pre-approval date DESC, so pc3 appears before pc2.
            System.assertEquals(pc3.Id, preToPostResp.rows[1].recordId);
            System.assertEquals(
                DateTime.newInstance(Date.today().addDays(-6), Time.newInstance(10, 0, 0, 0)),
                preToPostResp.rows[1].basisDateTime
            );
        }
    }

    // ---- helpers ----
    private static User buildUser(String usernamePrefix, String alias, Id profileId) {
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        return new User(
            Username = usernamePrefix + '.' + unique + '@example.com',
            Email = usernamePrefix + '@example.com',
            LastName = 'TestUser',
            Alias = alias,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId
        );
    }

    private static Lead buildLead(Id ownerId, String leadSource, Date preApprovalDate, Id convertedTransactionId) {
        Lead l = new Lead();
        l.FirstName = 'Test';
        l.LastName = 'Lead';
        l.Company = 'Test Company';
        l.OwnerId = ownerId;
        l.LeadSource = leadSource;
        l.Pre_Approval_Date__c = preApprovalDate;
        l.Converted_Transaction_ID__c = convertedTransactionId;
        return l;
    }

    private static Transaction__c buildTransaction(String name, Date postClosedDate) {
        Transaction__c t = new Transaction__c();
        t.Name = name;
        t.Loan_Number__c = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        t.Status__c = TestDataFactory.getOpportunityStageName();
        t.Post_Closed_Date__c = postClosedDate;
        return t;
    }

    private static List<String> getLeadSourceValues() {
        Schema.DescribeFieldResult d = Lead.LeadSource.getDescribe();
        List<Schema.PicklistEntry> entries = d.getPicklistValues();
        List<String> values = new List<String>();
        for (Schema.PicklistEntry e : entries) {
            if (e.isActive()) {
                values.add(e.getValue());
            }
        }
        System.assert(values.size() > 0, 'Expected at least one active LeadSource value in this org.');
        return values;
    }
}