@IsTest
public class LeadThroughputServiceTest {
    @testSetup
    static void setup() {
        // Create 2 users so we can test OwnerId slicing in a seeAllData=false context.
        Profile p;
        try {
            // Prefer the real Loan Officer Profile if present (matches production filtering).
            p = [SELECT Id FROM Profile WHERE Name = 'Loan Officer Profile' LIMIT 1];
        } catch (Exception e) {
            try {
                p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            } catch (Exception e2) {
                // Fallback for orgs where the profile name differs.
                p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            }
        }

        insert new List<User>{
            buildUser('lothru1', 'lo1', p.Id),
            buildUser('lothru2', 'lo2', p.Id)
        };
    }

    @IsTest
    static void calculatesCountsAndPercents_ForToday_WithOwnerAndLeadSourceFilters() {
        User lo1 = [SELECT Id FROM User WHERE Alias = 'lo1' LIMIT 1];
        User lo2 = [SELECT Id FROM User WHERE Alias = 'lo2' LIMIT 1];

        List<String> leadSources = getLeadSourceValues();
        String source1 = leadSources[0];
        String source2 = (leadSources.size() > 1) ? leadSources[1] : leadSources[0];

        // Transactions for converted leads.
        Transaction__c t1 = buildTransaction('T1', Date.today().addDays(-10));
        Transaction__c t2 = buildTransaction('T2', Date.today().addDays(-20));
        insert new List<Transaction__c>{ t1, t2 };

        // Lead A: created today, no pre-approval, no transaction
        Lead leadA = buildLead(lo1.Id, source1, null, null);
        // Lead B: created today, pre-approved today, no transaction
        Lead leadB = buildLead(lo1.Id, source1, Date.today(), null);
        // Lead C: created today, pre-approved today, has post-closed transaction
        Lead leadC = buildLead(lo1.Id, source2, Date.today(), t1.Id);
        // Lead D: created yesterday, pre-approved today, has post-closed transaction, owned by different LO
        Lead leadD = buildLead(lo2.Id, source1, Date.today(), t2.Id);

        insert new List<Lead>{ leadA, leadB, leadC, leadD };

        Test.setCreatedDate(leadA.Id, DateTime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0)));
        Test.setCreatedDate(leadB.Id, DateTime.newInstance(Date.today(), Time.newInstance(11, 0, 0, 0)));
        Test.setCreatedDate(leadC.Id, DateTime.newInstance(Date.today(), Time.newInstance(12, 0, 0, 0)));
        Test.setCreatedDate(leadD.Id, DateTime.newInstance(Date.today().addDays(-1), Time.newInstance(9, 0, 0, 0)));

        System.runAs(lo1) {
            LeadThroughputService.LeadThroughputResponse respAllSources =
                LeadThroughputService.getThroughput('TODAY', lo1.Id, null);

            System.assertEquals(3, respAllSources.newToPreApproval.denominator, 'New total (lo1, today)');
            System.assertEquals(2, respAllSources.newToPreApproval.numerator, 'New -> PreApp numerator');
            System.assertEquals(Decimal.valueOf('66.7'), respAllSources.newToPreApproval.percent, 'New -> PreApp percent');

            System.assertEquals(3, respAllSources.newToPostClosed.denominator, 'New total (lo1, today)');
            System.assertEquals(1, respAllSources.newToPostClosed.numerator, 'New -> PostClosed numerator');
            System.assertEquals(Decimal.valueOf('33.3'), respAllSources.newToPostClosed.percent, 'New -> PostClosed percent');

            System.assertEquals(2, respAllSources.preApprovalToPostClosed.denominator, 'PreApp total (lo1, today)');
            System.assertEquals(1, respAllSources.preApprovalToPostClosed.numerator, 'PreApp -> PostClosed numerator');
            System.assertEquals(Decimal.valueOf('50.0'), respAllSources.preApprovalToPostClosed.percent, 'PreApp -> PostClosed percent');

            LeadThroughputService.LeadThroughputResponse respSource1 =
                LeadThroughputService.getThroughput('TODAY', lo1.Id, source1);

            System.assertEquals(2, respSource1.newToPreApproval.denominator, 'New total filtered by source1');
            System.assertEquals(1, respSource1.newToPreApproval.numerator, 'New -> PreApp numerator filtered by source1');
            System.assertEquals(Decimal.valueOf('50.0'), respSource1.newToPreApproval.percent, 'New -> PreApp percent filtered by source1');

            System.assertEquals(2, respSource1.newToPostClosed.denominator, 'New total filtered by source1');
            System.assertEquals(0, respSource1.newToPostClosed.numerator, 'New -> PostClosed numerator filtered by source1');
            System.assertEquals(Decimal.valueOf('0.0'), respSource1.newToPostClosed.percent, 'New -> PostClosed percent filtered by source1');

            System.assertEquals(1, respSource1.preApprovalToPostClosed.denominator, 'PreApp total filtered by source1');
            System.assertEquals(0, respSource1.preApprovalToPostClosed.numerator, 'PreApp -> PostClosed numerator filtered by source1');
            System.assertEquals(Decimal.valueOf('0.0'), respSource1.preApprovalToPostClosed.percent, 'PreApp -> PostClosed percent filtered by source1');
        }
    }

    @IsTest
    static void returnsZeroPercent_WhenDenominatorIsZero() {
        User lo1 = [SELECT Id FROM User WHERE Alias = 'lo1' LIMIT 1];

        System.runAs(lo1) {
            LeadThroughputService.LeadThroughputResponse resp =
                LeadThroughputService.getThroughput('YESTERDAY', lo1.Id, null);

            System.assertEquals(0, resp.newToPreApproval.denominator);
            System.assertEquals(0, resp.newToPreApproval.percent);
            System.assertEquals(0, resp.newToPostClosed.denominator);
            System.assertEquals(0, resp.newToPostClosed.percent);

            // Trend fields should exist and be numeric (0 vs previous).
            System.assertNotEquals(null, resp.newToPreApprovalWithTrend);
            System.assertNotEquals(null, resp.newToPreApprovalWithTrend.trend);
            System.assertNotEquals(null, resp.timeline);
        }
    }

    @IsTest
    static void controllerIsCovered_AndAllDateRangesExecute() {
        User lo1 = [SELECT Id FROM User WHERE Alias = 'lo1' LIMIT 1];

        System.runAs(lo1) {
            // Ensure controller is exercised (coverage) and service switch branches execute.
            List<String> keys = new List<String>{
                'TODAY', 'YESTERDAY', 'THIS_WEEK', 'LAST_WEEK', 'THIS_MONTH', 'LAST_MONTH', 'YTD'
            };

            for (String key : keys) {
                LeadThroughputService.LeadThroughputResponse resp = LeadThroughputController.getThroughput(key, lo1.Id, null);
                System.assertNotEquals(null, resp);
                System.assertNotEquals(null, resp.startDate);
                System.assertNotEquals(null, resp.endDate);
            }

            // Cover parse fallback path.
            LeadThroughputService.LeadThroughputResponse fallback =
                LeadThroughputController.getThroughput('NOT_A_KEY', lo1.Id, null);
            System.assertEquals(Date.today(), fallback.startDate);
            System.assertEquals(Date.today(), fallback.endDate);

            // Timeline should be <= 7 points and within selected window.
            LeadThroughputService.LeadThroughputResponse ytd =
                LeadThroughputController.getThroughput('YTD', lo1.Id, null);
            System.assert(ytd.timeline.size() <= 7, 'Timeline should be limited to <= 7 days.');
        }
    }

    @IsTest
    static void returnsLoanOfficerOptions_AndBulkThroughputByOwners_Works() {
        User lo1 = [SELECT Id FROM User WHERE Alias = 'lo1' LIMIT 1];
        User lo2 = [SELECT Id FROM User WHERE Alias = 'lo2' LIMIT 1];

        // Simple data: 2 leads for lo1 today, both pre-approved today.
        Lead a = buildLead(lo1.Id, getLeadSourceValues()[0], Date.today(), null);
        Lead b = buildLead(lo1.Id, getLeadSourceValues()[0], Date.today(), null);
        insert new List<Lead>{ a, b };
        Test.setCreatedDate(a.Id, DateTime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0)));
        Test.setCreatedDate(b.Id, DateTime.newInstance(Date.today(), Time.newInstance(11, 0, 0, 0)));

        System.runAs(lo1) {
            List<LeadThroughputService.LookupOption> options =
                LeadThroughputController.getActiveLoanOfficers(50);
            System.assert(options.size() > 0, 'Expected active user options.');

            List<LeadThroughputService.OwnerThroughput> rows =
                LeadThroughputController.getThroughputByOwners('TODAY', null, null, new List<Id>{ lo1.Id, lo2.Id }, null);
            System.assertEquals(2, rows.size(), 'Expected rows for both requested owners.');

            // lo1 should have denom=2 for New -> PreApp
            LeadThroughputService.OwnerThroughput lo1Row;
            for (LeadThroughputService.OwnerThroughput r : rows) {
                if (r.ownerId == lo1.Id) {
                    lo1Row = r;
                }
            }
            System.assertNotEquals(null, lo1Row, 'Expected lo1 row.');
            System.assertEquals(2, lo1Row.newToPreApproval.denominator);
            System.assertEquals(2, lo1Row.newToPreApproval.numerator);
        }
    }

    @IsTest
    static void getThroughputByOwnersV2_supportsQuarterYearUnion_AndCalendarYearBuckets() {
        User lo1 = [SELECT Id FROM User WHERE Alias = 'lo1' LIMIT 1];
        Account buyingAgent = new Account(Name = 'Test Buying Agent');
        insert buyingAgent;

        // Transactions for converted leads.
        Transaction__c t1 = buildTransaction('T_union_1', Date.today().addDays(-5));
        insert t1;

        // Use prior year to ensure Test.setCreatedDate works (cannot set future CreatedDates).
        Integer y = Date.today().year() - 1;
        String q1 = String.valueOf(y) + '-Q1';
        String q2 = String.valueOf(y) + '-Q2';

        // Leads owned by lo1 across multiple quarters (and one outside of union).
        Lead inQ1 = buildLead(lo1.Id, getLeadSourceValues()[0], Date.newInstance(y, 2, 10), null);
        inQ1.Loan_Purpose__c = 'Purchase';
        inQ1.Realtor_Buying_Agent__c = buyingAgent.Id;
        Lead inQ2 = buildLead(lo1.Id, getLeadSourceValues()[0], Date.newInstance(y, 5, 12), t1.Id);
        inQ2.Loan_Purpose__c = 'Refinance';
        Lead outQ3 = buildLead(lo1.Id, getLeadSourceValues()[0], Date.newInstance(y, 8, 1), null);
        outQ3.Loan_Purpose__c = 'Refinance Cash-Out';
        insert new List<Lead>{ inQ1, inQ2, outQ3 };

        Test.setCreatedDate(inQ1.Id, DateTime.newInstance(Date.newInstance(y, 2, 10), Time.newInstance(10, 0, 0, 0)));
        Test.setCreatedDate(inQ2.Id, DateTime.newInstance(Date.newInstance(y, 5, 12), Time.newInstance(10, 0, 0, 0)));
        Test.setCreatedDate(outQ3.Id, DateTime.newInstance(Date.newInstance(y, 8, 1), Time.newInstance(10, 0, 0, 0)));

        System.runAs(lo1) {
            List<LeadThroughputService.OwnerThroughput> rows =
                LeadThroughputController.getThroughputByOwnersV2(
                    'QUARTER_YEAR',
                    new List<String>{ q1, q2 },
                    new List<Id>{ lo1.Id },
                    null,
                    null
                );

            System.assertEquals(1, rows.size(), 'Expected a single owner row for lo1.');
            LeadThroughputService.OwnerThroughput r = rows[0];

            // Denominator for "New -> *" should count only created leads within Q1 or Q2.
            System.assertEquals(2, r.newToPreApproval.denominator, 'Expected union(Q1,Q2) created denom.');

            // Numerator for New -> Pre-Approval counts leads with pre-approval date populated (both inQ1 and inQ2).
            System.assertEquals(2, r.newToPreApproval.numerator);

            // Numerator for New -> Post-Closed counts only the converted lead inQ2.
            System.assertEquals(1, r.newToPostClosed.numerator);

            List<LeadThroughputService.OwnerThroughput> purchaseRows =
                LeadThroughputController.getThroughputByOwnersV2(
                    'QUARTER_YEAR',
                    new List<String>{ q1, q2 },
                    new List<Id>{ lo1.Id },
                    null,
                    'PURCHASE'
                );
            System.assertEquals(1, purchaseRows.size());
            System.assertEquals(1, purchaseRows[0].newToPreApproval.denominator, 'Purchase filter should keep only purchase loans.');

            List<LeadThroughputService.OwnerThroughput> refinanceRows =
                LeadThroughputController.getThroughputByOwnersV2(
                    'QUARTER_YEAR',
                    new List<String>{ q1, q2 },
                    new List<Id>{ lo1.Id },
                    null,
                    'REFINANCE'
                );
            System.assertEquals(1, refinanceRows.size());
            System.assertEquals(1, refinanceRows[0].newToPreApproval.denominator, 'Refinance filter should keep refinance loans.');

            List<LeadThroughputService.OwnerThroughput> bothRows =
                LeadThroughputController.getThroughputByOwnersV2(
                    'QUARTER_YEAR',
                    new List<String>{ q1, q2 },
                    new List<Id>{ lo1.Id },
                    null,
                    'BOTH_PURCHASE_REFINANCE'
                );
            System.assertEquals(1, bothRows.size());
            System.assertEquals(
                2,
                bothRows[0].newToPreApproval.denominator,
                'Combined purchase/refinance filter should include either loan purpose.'
            );
        }

        // Calendar year buckets sanity: Last Year should exclude a lead created this year.
        System.runAs(lo1) {
            List<LeadThroughputService.OwnerThroughput> lastYearRows =
                LeadThroughputController.getThroughputByOwnersV2('LAST_YEAR', null, new List<Id>{ lo1.Id }, null, null);
            System.assertEquals(1, lastYearRows.size());
            System.assertEquals(3, lastYearRows[0].newToPreApproval.denominator, 'Expected created leads last year in this dataset.');
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
            ProfileId = profileId,
            Headshot_URL__c = 'image.jpg'
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