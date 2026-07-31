/**
 * Created by toma on 11/22/2022.
 */

@IsTest
public class UWM_Conditions_Tests {
    private static final String TEST_OPPORTUNITY_NAME = 'Loan NCS Insight Test';
    private static final String TEST_OPPORTUNITY_LOAN_NUMBER = '1522026511';
    private static final String TEST_OPPORTUNITY_UWM_LENDER = 'UWM';
    private static final Date TEST_OPPORTUNITY_CLOSED_DATE = Date.today().addDays(30);

    private static final String TEST_DEFAULT_BRANCH_NAME = 'Default';
    private static final String TEST_A2Z_BRANCH_NAME = 'A2Z';
    private static final String TEST_BRANCH_CLIENT_ID = '5509bb34-fdf5-49c1';
    private static final String TEST_BRANCH_CLIENT_SECRET = 'Yq98Q~m5BYz4.hVwC';

    private static final String ADMIN_PROFILE_NAME = 'System Administrator';
    private static final String CRON_EXP = '0 0 23 * * ?';
    
    @TestSetup
    static void uwmConditionsTestSetup() {
        String testOpportunityStageName = TestDataFactory.getOpportunityStageName();
        List<Transaction__c> opportunities = TestDataFactory.createTransactions(new Map<String,Object>{
            'name' => TEST_OPPORTUNITY_NAME,
            'numberOfRecords' => 1,
            'stageName' => testOpportunityStageName,
            'closeDate' => TEST_OPPORTUNITY_CLOSED_DATE,
            'loanNumber' => TEST_OPPORTUNITY_LOAN_NUMBER
        });
        insert opportunities;

        //opportunities[0].Loan_Number__c = TEST_OPPORTUNITY_LOAN_NUMBER;
        //opportunities[0].Chosen_Lender__c = TEST_OPPORTUNITY_UWM_LENDER;
        RecordType recordType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Business_Account'];
        Account acc = new Account(Name = 'UWM', Type = 'Investor', RecordTypeId = recordType.Id);
        insert acc;
        opportunities[0].Lender_lookup__c = acc.Id;
        opportunities[0].Loan_Number__c  = TEST_OPPORTUNITY_LOAN_NUMBER;
        opportunities[0].Lender_1st__c  = TEST_OPPORTUNITY_UWM_LENDER;
        update opportunities;

        // if flow Create UWM Loan Info is deactivated,
        // create Loan Infos and relate to opportunities
        List<UWM_Loan_Info__c> loanInfos = [
            SELECT Id
            FROM UWM_Loan_Info__c
        ];

        if (loanInfos.isEmpty()) {
            for (Transaction__c opp : opportunities) {
                loanInfos.add(new UWM_Loan_Info__c(
                    Transaction__c = opp.Id,
                    uwm_LoanNumber__c  = TEST_OPPORTUNITY_LOAN_NUMBER
                ));
            }
            System.debug('INSERTING LOAN INFOS');
            insert loanInfos;
        }

        List<UWMBranch__c> branches = TestDataFactory.createUWMBranches(new Map<String,Object>{
            'numberOfRecords' => 1,
            'name' => TEST_DEFAULT_BRANCH_NAME,
            'clientId' => TEST_BRANCH_CLIENT_ID,
            'clientSecret' => TEST_BRANCH_CLIENT_SECRET,
            'isDefault' => true
        });
        insert branches;

        List<UWMBranch__c> a2ZBranches = TestDataFactory.createUWMBranches(new Map<String,Object>{
            'numberOfRecords' => 1,
            'name' => TEST_A2Z_BRANCH_NAME,
            'clientId' => TEST_BRANCH_CLIENT_ID,
            'clientSecret' => TEST_BRANCH_CLIENT_SECRET,
            'isDefault' => false
        });
        insert a2ZBranches;
    }
    
    @IsTest
    public static void testCoverage() {
        TransactionConditionTriggerHandler.testCoverage();
        UWMCredentials.testCoverage();
        
        Transaction__c t = [SELECT Id FROM Transaction__C WHERE Name = :(TEST_OPPORTUNITY_NAME + 0)];
        Condition__c c = new Condition__c(Transaction__c = t.id);
        insert c;
        
        TransactionCondition tc = new TransactionCondition(c);
        tc.setStatus(null);
        tc.setIncludedInEmail(false);
        tc.setPersistenceStrategy(new PersistenceStrategy.BasicSave());
        tc.persist();

        System.assertNotEquals(
            null,
            TransactionConditionRepository.getInstance().getConditionById(c.Id)
        );
    }

    @IsTest
    public static void conditionsBatchTest(){
        User adminUser = TestDataFactory.getUserByProfileName(ADMIN_PROFILE_NAME);

        TestDataFactory.SingleRequestMock uwmConditionsCalloutMock = new TestDataFactory.SingleRequestMock
            (200,
             '{"conditionGroups":[{"key":"Underwriter II (PTD)","countItems":4,"uploadedConditionsCount":0,"conditions":[{"id":"0231_911","conditionCategory":"Assets","conditionDescription":"Short funds to close. Document sufficient funds for the closing of this transaction.  Funds required to close total $12,208.67 (plus any unverified POC items) with $2742.97 currently verified. ($0 set aside for required reserves.)****Received non liquid funds .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"2567_774","conditionCategory":"Credit","conditionDescription":"Payments for all mortgage(s) being paid off must be documented monthly, through the disbursement date. Provide documentation to evidence that each payment has been made in the month due .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1443_952","conditionCategory":"Property","conditionDescription":"Solar Panels are leased. Provide lease agreement or power purchase agreement (PPA) between subject property owners and solar company. Agreement to meet guideline requirements for product .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1214_3263","conditionCategory":"Title","conditionDescription":"Title Commitment is expired. Provide an updated commitment or a gap letter .","isConditionUploaded":false,"conditionSatisfactionDate":null}]},{"key":"Underwriter To Obtain And Clear","countItems":2,"uploadedConditionsCount":0,"conditions":[{"id":"2568_775","conditionCategory":"Credit","conditionDescription":"If the loan does not DISBURSE by 12/31, documentation evidencing December payment has been made will be required .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"0571_962","conditionCategory":"Credit","conditionDescription":"Underwriter to approve the change of circumstance requested for Appraised Value From: 325000.00 To: 320000.00 .","isConditionUploaded":false,"conditionSatisfactionDate":null}]},{"key":"Closing (PTF)","countItems":2,"uploadedConditionsCount":0,"conditions":[{"id":"0201_195","conditionCategory":"Correspondent appraisal Ack","conditionDescription":"TC: Borrower(s) to sign the Appraisal/Valuation Acknowledgement form at closing .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1997_241","conditionCategory":"Title-Correspondent","conditionDescription":"TC: Title company to verify Borrower Attestation (UWM Form 1220) is fully completed and executed at closing. If Sections I - IV are not initialed and Section V signed by all borrowers the loan will not be purchased .","isConditionUploaded":false,"conditionSatisfactionDate":null}]}],"clearedConditions":[{"id":"2075_609","conditionCategory":"Appraisal","conditionDescription":"Appraisal on Form 1004 for subject property from an approved AMC. Must also include appraisal in XML format SSRs appraisal invoice and AIR compliance cert (if one of our 5 approved AMCs is not used).","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1574_461","conditionCategory":"Credit","conditionDescription":"Payoff statements to be provided for all mortgages being paid (must reflect that loan is current).","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"0360_891","conditionCategory":"Credit","conditionDescription":"Provide documentation to verify October and November payment has been made in the month due (0x30) for NAVY FCU mortgage.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"0571_942","conditionCategory":"Credit","conditionDescription":"Underwriter to approve the change of circumstance requested for Base Loan Amount From: 260000.00 To: 256000.00.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1859_534","conditionCategory":"Property","conditionDescription":"Title commitment with 12 month chain of title and legal description, verification of current property taxes, closing protection letter and wire instructions.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1669_479","conditionCategory":"(PA) Insurance","conditionDescription":"Processor Assist: HOMEOWNERS INSURANCE: Declaration page or insurance binder with the correct mortgagee clause. Policy must provide sufficient dwelling coverage by meeting one of the following criteria: (1) Cover the lower of the replacement cost or total loan amount; or (2) Terms to show guaranteed full replacement coverage.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"0311_435","conditionCategory":"Appraisal","conditionDescription":"Flood Certification.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"1019_444","conditionCategory":"Borrower","conditionDescription":"Acceptable unexpired picture identification for all borrowers.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"1812_247","conditionCategory":"Income","conditionDescription":"Verbal VOE for borrower(s) from CIGNA LIFE INS to be completed prior to note date.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"0282_62","conditionCategory":"Disclosure","conditionDescription":"1003: Fully executed initial 1003 with correct subject property address, signed and dated by all borrower(s) and loan originator.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0468_1","conditionCategory":"Disclosure","conditionDescription":"For HMDA reporting to be accurate, the interview method must be completed in Section X of the 1003. Please add the proper interview method on the 1003.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0408_112","conditionCategory":"Disclosure","conditionDescription":"Homeownership Counseling Disclosure listing the 10 Homeownership Counseling Agencies near the borrower\\u0027s current primary mailing address that is dated on within 3 days of the earliest signature date on the 1003.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0269_55","conditionCategory":"Disclosure","conditionDescription":"NJ - Addendum to Residential Mortgage Loan Application aka Domestic Partner Disclosure.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0332_83","conditionCategory":"Disclosure","conditionDescription":"NJ - Application Disclosure.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0331_82","conditionCategory":"Disclosure","conditionDescription":"NJ - Choice of Insurer Notice.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0333_84","conditionCategory":"Disclosure","conditionDescription":"NJ - Right to Choose Own Attorney.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0467_2","conditionCategory":"Disclosure","conditionDescription":"Per HMDA requirements only a Face-to-Face application can have Government Monitoring Information (GMI) that is visually observed. Please provide a corrected 1003 with an updated application method or an update noting that the GMI information was not obtained via visual observation.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0426_124","conditionCategory":"Disclosure","conditionDescription":"Provide H-3 Model Disclosure: it should include Credit score, Date, Range of Scores, How Your Score Compares to Others, Key Factors Affecting Credit, and Notice to Home Loan Applicant)/Residential Mortgage Credit Score Disclosure Exception Notice.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0465_144","conditionCategory":"Disclosure","conditionDescription":"Settlement Service Provider List with company name, phone number, and address that matches service types listed in Block C of the LE.  Must be dated within 3 days of the application date.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"}]}',
             new Map<String,String>{'Content-Type' => 'application/json'}
            );
        Test.setMock(HttpCalloutMock.class, uwmConditionsCalloutMock);
        UWMSettings__c queueCheck = new UWMSettings__c(
            CanConditionsQueueRun__c = true,
            Emails_For_Notifications__c = 'test@pulse.com'
        );
        insert queueCheck;

        Test.startTest();
        System.runAs(adminUser) {
            UWM_Conditions_API_Batch.executeBatch();
        }
        Test.stopTest();

        List<Condition__c> loanConditions = [
            SELECT Id
            FROM Condition__c
            WHERE Transaction__r.Name = :(TEST_OPPORTUNITY_NAME + 0) AND Transaction__r.Loan_Number__c = :TEST_OPPORTUNITY_LOAN_NUMBER
        ];

        //Assert.isTrue(!loanConditions.isEmpty(), 'Loan conditions were not upserted');
    }

    @IsTest
    public static void invocableUWMConditionsTest(){
        User adminUser = TestDataFactory.getUserByProfileName(ADMIN_PROFILE_NAME);
        TestDataFactory.SingleRequestMock uwmConditionsCalloutMock = new TestDataFactory.SingleRequestMock
            (200,
                '{"conditionGroups":[{"key":"Underwriter II (PTD)","countItems":4,"uploadedConditionsCount":0,"conditions":[{"id":"0231_911","conditionCategory":"Assets","conditionDescription":"Short funds to close. Document sufficient funds for the closing of this transaction.  Funds required to close total $12,208.67 (plus any unverified POC items) with $2742.97 currently verified. ($0 set aside for required reserves.)****Received non liquid funds .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"2567_774","conditionCategory":"Credit","conditionDescription":"Payments for all mortgage(s) being paid off must be documented monthly, through the disbursement date. Provide documentation to evidence that each payment has been made in the month due .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1443_952","conditionCategory":"Property","conditionDescription":"Solar Panels are leased. Provide lease agreement or power purchase agreement (PPA) between subject property owners and solar company. Agreement to meet guideline requirements for product .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1214_3263","conditionCategory":"Title","conditionDescription":"Title Commitment is expired. Provide an updated commitment or a gap letter .","isConditionUploaded":false,"conditionSatisfactionDate":null}]},{"key":"Underwriter To Obtain And Clear","countItems":2,"uploadedConditionsCount":0,"conditions":[{"id":"2568_775","conditionCategory":"Credit","conditionDescription":"If the loan does not DISBURSE by 12/31, documentation evidencing December payment has been made will be required .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"0571_962","conditionCategory":"Credit","conditionDescription":"Underwriter to approve the change of circumstance requested for Appraised Value From: 325000.00 To: 320000.00 .","isConditionUploaded":false,"conditionSatisfactionDate":null}]},{"key":"Closing (PTF)","countItems":2,"uploadedConditionsCount":0,"conditions":[{"id":"0201_195","conditionCategory":"Correspondent appraisal Ack","conditionDescription":"TC: Borrower(s) to sign the Appraisal/Valuation Acknowledgement form at closing .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1997_241","conditionCategory":"Title-Correspondent","conditionDescription":"TC: Title company to verify Borrower Attestation (UWM Form 1220) is fully completed and executed at closing. If Sections I - IV are not initialed and Section V signed by all borrowers the loan will not be purchased .","isConditionUploaded":false,"conditionSatisfactionDate":null}]}],"clearedConditions":[{"id":"2075_609","conditionCategory":"Appraisal","conditionDescription":"Appraisal on Form 1004 for subject property from an approved AMC. Must also include appraisal in XML format SSRs appraisal invoice and AIR compliance cert (if one of our 5 approved AMCs is not used).","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1574_461","conditionCategory":"Credit","conditionDescription":"Payoff statements to be provided for all mortgages being paid (must reflect that loan is current).","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"0360_891","conditionCategory":"Credit","conditionDescription":"Provide documentation to verify October and November payment has been made in the month due (0x30) for NAVY FCU mortgage.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"0571_942","conditionCategory":"Credit","conditionDescription":"Underwriter to approve the change of circumstance requested for Base Loan Amount From: 260000.00 To: 256000.00.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1859_534","conditionCategory":"Property","conditionDescription":"Title commitment with 12 month chain of title and legal description, verification of current property taxes, closing protection letter and wire instructions.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1669_479","conditionCategory":"(PA) Insurance","conditionDescription":"Processor Assist: HOMEOWNERS INSURANCE: Declaration page or insurance binder with the correct mortgagee clause. Policy must provide sufficient dwelling coverage by meeting one of the following criteria: (1) Cover the lower of the replacement cost or total loan amount; or (2) Terms to show guaranteed full replacement coverage.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"0311_435","conditionCategory":"Appraisal","conditionDescription":"Flood Certification.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"1019_444","conditionCategory":"Borrower","conditionDescription":"Acceptable unexpired picture identification for all borrowers.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"1812_247","conditionCategory":"Income","conditionDescription":"Verbal VOE for borrower(s) from CIGNA LIFE INS to be completed prior to note date.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"0282_62","conditionCategory":"Disclosure","conditionDescription":"1003: Fully executed initial 1003 with correct subject property address, signed and dated by all borrower(s) and loan originator.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0468_1","conditionCategory":"Disclosure","conditionDescription":"For HMDA reporting to be accurate, the interview method must be completed in Section X of the 1003. Please add the proper interview method on the 1003.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0408_112","conditionCategory":"Disclosure","conditionDescription":"Homeownership Counseling Disclosure listing the 10 Homeownership Counseling Agencies near the borrower\\u0027s current primary mailing address that is dated on within 3 days of the earliest signature date on the 1003.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0269_55","conditionCategory":"Disclosure","conditionDescription":"NJ - Addendum to Residential Mortgage Loan Application aka Domestic Partner Disclosure.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0332_83","conditionCategory":"Disclosure","conditionDescription":"NJ - Application Disclosure.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0331_82","conditionCategory":"Disclosure","conditionDescription":"NJ - Choice of Insurer Notice.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0333_84","conditionCategory":"Disclosure","conditionDescription":"NJ - Right to Choose Own Attorney.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0467_2","conditionCategory":"Disclosure","conditionDescription":"Per HMDA requirements only a Face-to-Face application can have Government Monitoring Information (GMI) that is visually observed. Please provide a corrected 1003 with an updated application method or an update noting that the GMI information was not obtained via visual observation.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0426_124","conditionCategory":"Disclosure","conditionDescription":"Provide H-3 Model Disclosure: it should include Credit score, Date, Range of Scores, How Your Score Compares to Others, Key Factors Affecting Credit, and Notice to Home Loan Applicant)/Residential Mortgage Credit Score Disclosure Exception Notice.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0465_144","conditionCategory":"Disclosure","conditionDescription":"Settlement Service Provider List with company name, phone number, and address that matches service types listed in Block C of the LE.  Must be dated within 3 days of the application date.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"}]}',
                new Map<String,String>{'Content-Type' => 'application/json'}
            );
        Test.setMock(HttpCalloutMock.class, uwmConditionsCalloutMock);
        UWMSettings__c queueCheck = new UWMSettings__c(CanConditionsQueueRun__c = true);
        insert queueCheck;

        UWM_Loan_Info__c loanInfo = [
            SELECT Id FROM UWM_Loan_Info__c
            WHERE Transaction__r.Name = :(TEST_OPPORTUNITY_NAME + 0) AND Transaction__r.Loan_Number__c = :TEST_OPPORTUNITY_LOAN_NUMBER
            LIMIT 1
        ];

        Test.startTest();
        System.runAs(adminUser) {
            UWM_Conditions_Invocable.pingApiInvocable(new List<Id>{loanInfo.Id});
        }
        Test.stopTest();

        List<Condition__c> loanConditions = [
            SELECT Id
            FROM Condition__c
            WHERE Transaction__r.Name = :(TEST_OPPORTUNITY_NAME + 0) AND Transaction__r.Loan_Number__c = :TEST_OPPORTUNITY_LOAN_NUMBER
        ];

        //Assert.isTrue(!loanConditions.isEmpty(), 'Loan conditions were not upserted');
    }

    @IsTest
    public static void conditionsScheduleTest(){
        User adminUser = TestDataFactory.getUserByProfileName(ADMIN_PROFILE_NAME);
        TestDataFactory.SingleRequestMock uwmConditionsCalloutMock = new TestDataFactory.SingleRequestMock
            (200,
                '{"conditionGroups":[{"key":"Underwriter II (PTD)","countItems":4,"uploadedConditionsCount":0,"conditions":[{"id":"0231_911","conditionCategory":"Assets","conditionDescription":"Short funds to close. Document sufficient funds for the closing of this transaction.  Funds required to close total $12,208.67 (plus any unverified POC items) with $2742.97 currently verified. ($0 set aside for required reserves.)****Received non liquid funds .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"2567_774","conditionCategory":"Credit","conditionDescription":"Payments for all mortgage(s) being paid off must be documented monthly, through the disbursement date. Provide documentation to evidence that each payment has been made in the month due .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1443_952","conditionCategory":"Property","conditionDescription":"Solar Panels are leased. Provide lease agreement or power purchase agreement (PPA) between subject property owners and solar company. Agreement to meet guideline requirements for product .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1214_3263","conditionCategory":"Title","conditionDescription":"Title Commitment is expired. Provide an updated commitment or a gap letter .","isConditionUploaded":false,"conditionSatisfactionDate":null}]},{"key":"Underwriter To Obtain And Clear","countItems":2,"uploadedConditionsCount":0,"conditions":[{"id":"2568_775","conditionCategory":"Credit","conditionDescription":"If the loan does not DISBURSE by 12/31, documentation evidencing December payment has been made will be required .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"0571_962","conditionCategory":"Credit","conditionDescription":"Underwriter to approve the change of circumstance requested for Appraised Value From: 325000.00 To: 320000.00 .","isConditionUploaded":false,"conditionSatisfactionDate":null}]},{"key":"Closing (PTF)","countItems":2,"uploadedConditionsCount":0,"conditions":[{"id":"0201_195","conditionCategory":"Correspondent appraisal Ack","conditionDescription":"TC: Borrower(s) to sign the Appraisal/Valuation Acknowledgement form at closing .","isConditionUploaded":false,"conditionSatisfactionDate":null},{"id":"1997_241","conditionCategory":"Title-Correspondent","conditionDescription":"TC: Title company to verify Borrower Attestation (UWM Form 1220) is fully completed and executed at closing. If Sections I - IV are not initialed and Section V signed by all borrowers the loan will not be purchased .","isConditionUploaded":false,"conditionSatisfactionDate":null}]}],"clearedConditions":[{"id":"2075_609","conditionCategory":"Appraisal","conditionDescription":"Appraisal on Form 1004 for subject property from an approved AMC. Must also include appraisal in XML format SSRs appraisal invoice and AIR compliance cert (if one of our 5 approved AMCs is not used).","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1574_461","conditionCategory":"Credit","conditionDescription":"Payoff statements to be provided for all mortgages being paid (must reflect that loan is current).","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"0360_891","conditionCategory":"Credit","conditionDescription":"Provide documentation to verify October and November payment has been made in the month due (0x30) for NAVY FCU mortgage.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"0571_942","conditionCategory":"Credit","conditionDescription":"Underwriter to approve the change of circumstance requested for Base Loan Amount From: 260000.00 To: 256000.00.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1859_534","conditionCategory":"Property","conditionDescription":"Title commitment with 12 month chain of title and legal description, verification of current property taxes, closing protection letter and wire instructions.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-12-15T00:00:00"},{"id":"1669_479","conditionCategory":"(PA) Insurance","conditionDescription":"Processor Assist: HOMEOWNERS INSURANCE: Declaration page or insurance binder with the correct mortgagee clause. Policy must provide sufficient dwelling coverage by meeting one of the following criteria: (1) Cover the lower of the replacement cost or total loan amount; or (2) Terms to show guaranteed full replacement coverage.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"0311_435","conditionCategory":"Appraisal","conditionDescription":"Flood Certification.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"1019_444","conditionCategory":"Borrower","conditionDescription":"Acceptable unexpired picture identification for all borrowers.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"1812_247","conditionCategory":"Income","conditionDescription":"Verbal VOE for borrower(s) from CIGNA LIFE INS to be completed prior to note date.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-24T00:00:00"},{"id":"0282_62","conditionCategory":"Disclosure","conditionDescription":"1003: Fully executed initial 1003 with correct subject property address, signed and dated by all borrower(s) and loan originator.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0468_1","conditionCategory":"Disclosure","conditionDescription":"For HMDA reporting to be accurate, the interview method must be completed in Section X of the 1003. Please add the proper interview method on the 1003.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0408_112","conditionCategory":"Disclosure","conditionDescription":"Homeownership Counseling Disclosure listing the 10 Homeownership Counseling Agencies near the borrower\\u0027s current primary mailing address that is dated on within 3 days of the earliest signature date on the 1003.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0269_55","conditionCategory":"Disclosure","conditionDescription":"NJ - Addendum to Residential Mortgage Loan Application aka Domestic Partner Disclosure.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0332_83","conditionCategory":"Disclosure","conditionDescription":"NJ - Application Disclosure.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0331_82","conditionCategory":"Disclosure","conditionDescription":"NJ - Choice of Insurer Notice.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0333_84","conditionCategory":"Disclosure","conditionDescription":"NJ - Right to Choose Own Attorney.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0467_2","conditionCategory":"Disclosure","conditionDescription":"Per HMDA requirements only a Face-to-Face application can have Government Monitoring Information (GMI) that is visually observed. Please provide a corrected 1003 with an updated application method or an update noting that the GMI information was not obtained via visual observation.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0426_124","conditionCategory":"Disclosure","conditionDescription":"Provide H-3 Model Disclosure: it should include Credit score, Date, Range of Scores, How Your Score Compares to Others, Key Factors Affecting Credit, and Notice to Home Loan Applicant)/Residential Mortgage Credit Score Disclosure Exception Notice.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"},{"id":"0465_144","conditionCategory":"Disclosure","conditionDescription":"Settlement Service Provider List with company name, phone number, and address that matches service types listed in Block C of the LE.  Must be dated within 3 days of the application date.","isConditionUploaded":false,"conditionSatisfactionDate":"2020-11-23T00:00:00"}]}',
                new Map<String,String>{'Content-Type' => 'application/json'}
            );
        Test.setMock(HttpCalloutMock.class, uwmConditionsCalloutMock);
        UWMSettings__c queueCheck = new UWMSettings__c(CanConditionsQueueRun__c = true, Emails_For_Notifications__c = 'test@mail.com');
        insert queueCheck;

        Test.startTest();
        System.runAs(adminUser) {
            ScheduleConditions sc = new ScheduleConditions();
            System.schedule('Scheduled Conditions Batch', CRON_EXP, sc);
            sc.execute(null);
        }
        Test.stopTest();

        List<Condition__c> loanConditions = [
            SELECT Id
            FROM Condition__c
            WHERE Transaction__r.Name = :(TEST_OPPORTUNITY_NAME + 0) AND Transaction__r.Loan_Number__c = :TEST_OPPORTUNITY_LOAN_NUMBER
        ];

        //Assert.isTrue(!loanConditions.isEmpty(), 'Loan conditions were not upserted');
    }

    @IsTest
    public static void invocableUWMConditionsLogsErrorsToCustomLog(){
        User adminUser = TestDataFactory.getUserByProfileName(ADMIN_PROFILE_NAME);
        Test.setMock(
            HttpCalloutMock.class,
            new TestDataFactory.SingleRequestMock(
                400,
                '{"errors":{"LoanNumber":["Invalid loan number."]}}',
                new Map<String,String>{'Content-Type' => 'application/json'}
            )
        );

        UWM_Loan_Info__c loanInfo = [
            SELECT Id, Transaction__c
            FROM UWM_Loan_Info__c
            WHERE Transaction__r.Name = :(TEST_OPPORTUNITY_NAME + 0) AND Transaction__r.Loan_Number__c = :TEST_OPPORTUNITY_LOAN_NUMBER
            LIMIT 1
        ];

        Test.startTest();
        System.runAs(adminUser) {
            UWM_Conditions_Invocable.pingApiInvocable(new List<Id>{ loanInfo.Id });
        }
        Test.stopTest();

        List<Custom_Log__c> logs = [
            SELECT Id, Source__c, Data__c
            FROM Custom_Log__c
            WHERE Source__c = 'UWM Conditions Invocable'
        ];

        System.assertEquals(1, logs.size(), 'Expected one invocable error log');
        System.assert(logs[0].Data__c.contains(String.valueOf(loanInfo.Id)), 'Log should include the loan info record id');
    }

    @IsTest
    public static void batchUWMConditionsLogsErrorsToCustomLog(){
        Transaction__c firstTransaction = [
            SELECT Id
            FROM Transaction__c
            WHERE Name = :(TEST_OPPORTUNITY_NAME + 0)
            LIMIT 1
        ];
        List<Transaction__c> secondTransactions = TestDataFactory.createTransactions(new Map<String,Object>{
            'name' => 'Second Batch Log Test',
            'numberOfRecords' => 1,
            'stageName' => TestDataFactory.getOpportunityStageName(),
            'closeDate' => TEST_OPPORTUNITY_CLOSED_DATE,
            'loanNumber' => '9999999999'
        });
        insert secondTransactions;
        Transaction__c secondTransaction = secondTransactions[0];

        UWM_Conditions_API_Batch batch = new UWM_Conditions_API_Batch();
        batch.addErrorLog(buildLoggingException('first batch error'), firstTransaction.Id);
        batch.addErrorLog(buildLoggingException('second batch error'), secondTransaction.Id);

        Test.startTest();
        batch.flushLogs();
        Test.stopTest();

        List<Custom_Log__c> logs = [
            SELECT Id, Source__c, Data__c
            FROM Custom_Log__c
            WHERE Source__c = 'UWM Conditions Batch'
        ];

        System.assertEquals(2, logs.size(), 'Expected one batch error log per buffered error');
        for (Id transactionId : new List<Id>{ firstTransaction.Id, secondTransaction.Id }) {
            Boolean matchingLogFound = false;
            for (Custom_Log__c logRecord : logs) {
                if (logRecord.Data__c.contains(String.valueOf(transactionId))) {
                    matchingLogFound = true;
                    break;
                }
            }
            System.assert(matchingLogFound, 'Expected a batch error log for transaction ' + transactionId);
        }
    }

    @IsTest
    public static void testUWMConditionsAuth(){
        User adminUser = TestDataFactory.getUserByProfileName(ADMIN_PROFILE_NAME);
        User testUser;
        System.runAs(adminUser) {
            // creating a test user to test not default branch
            testUser = TestDataFactory.createUser(new Map<String,Object>{
                'profileName' => 'Standard User',
                'userName' => 'testuser2308@pulse.com',
                'email' => 'standarduser@pulse.com',
                'lastName' => 'TestName'
            });
            testUser.UWMBranch__c = [SELECT Id FROM UWMBranch__c WHERE Name = :(TEST_A2Z_BRANCH_NAME + 0) LIMIT 1].Id;
            insert testUser;
        }
        UWMConditions_AuthProvider auth = new UWMConditions_AuthProvider();
        UWMConditions_AuthProvider.currentOwnerId = testUser.Id;
        System.assertEquals('UWM_InsightsAuthSettings__mdt', auth.getCustomMetadataType());

        Test.startTest();
        System.runAs(adminUser) {
            Test.setMock(HttpCalloutMock.class, new TestDataFactory.AuthMock());
            Map<String,String> queryParams = new Map<String,String>();
            queryParams.put('code','code');
            queryParams.put('state','999');
            Map<String,String> headers = new Map<String, String>();
            headers.put('Authorization','123abc');
            headers.put('Accept','*/*');
            headers.put('Content-Type', 'application/x-www-form-urlencoded');
            String payload = 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion='+EncodingUtil.urlEncode('123abc','UTF-8');
            Auth.AuthProviderCallbackState cbState = new Auth.AuthProviderCallbackState(headers,payload,queryParams);
            auth.handleCallback(new Map<String,String>{
                'ClientSecret__c'=> 'ABC'
            }, cbState);
            auth.refresh(queryParams, '123abc');
        }
        Test.stopTest();
    }

    private static Exception buildLoggingException(String message) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:UWMConditions/test');
        request.setMethod('GET');

        HttpResponse response = new HttpResponse();
        response.setStatusCode(400);
        response.setBody('{"errors":{"LoanNumber":["' + message + '"]}}');

        return new RestApiConsumer.HttpException(request, response, message);
    }
}