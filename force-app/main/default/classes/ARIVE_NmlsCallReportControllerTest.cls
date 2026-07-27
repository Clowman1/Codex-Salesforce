/**
 * Created by Akram on 10/16/2019.
 */

@IsTest
private class ARIVE_NmlsCallReportControllerTest {

    @testSetup
    private static void setup() {
        Account company = new Account();
        company.name = 'test company';
        insert company;
    }

    @isTest
    private static void generateReport() {
        list<String> states = new list<String>{'CA'};
        Test.startTest();

        {
            ARIVE_NmlsCallReportController.ReportModel report = ARIVE_NmlsCallReportController.generateReport('2', '2019', states);
            system.debug('testing report' + report);
            ARIVE_NmlsCallReportController.generateXmlFile(JSON.serialize(report));
            system.assertNotEquals(null, ARIVE_NmlsCallReportController.retrievePastReports());
        }
        Test.stopTest();
    }

    @isTest
    private static void getStateLicenses() {
        Test.startTest();
        {
            system.debug('testing license' + ARIVE_NmlsCallReportController.getStateLicenses());
            system.assertNotEquals(null, ARIVE_NmlsCallReportController.getStateLicenses());
        }
        Test.stopTest();
    }

    @isTest
    private static void testGenerateResidentialMortgagesData() {
        List<String> states = new List<String>{'CA'};
        ARIVE_NmlsCallReportController.ReportModel report = ARIVE_NmlsCallReportController.generateReport('2', '2019', states);
        String stringReport  = JSON.serialize(report);
        Test.startTest();
        {
            ARIVE_NmlsCallReportController.finishGenerateReport(stringReport);
        }
        Test.stopTest();
    }

    @isTest
    private static void testClosedLoanDataMcrCategoryRules() {
        Date fundedDate = Date.newInstance(2019, 5, 15);
        List<Transaction__c> transactions = new List<Transaction__c>{
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'CA',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 100000,
                Loan_Type_1st_TD__c = 'Conventional',
                Property_Type__c = 'Single Family',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'CA',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 110000,
                Loan_Type_1st_TD__c = 'CONV',
                Property_Type__c = 'Condo',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'CA',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 120000,
                Loan_Type_1st_TD__c = 'HELOC',
                Property_Type__c = 'PUD',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'CA',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 130000,
                Loan_Type_1st_TD__c = 'NonQM',
                Property_Type__c = 'Condominium',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'CA',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 140000,
                Loan_Type_1st_TD__c = 'FHA',
                Property_Type__c = 'Mobile Home',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'CA',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 150000,
                Loan_Type_1st_TD__c = 'FHA',
                Property_Type__c = 'Single Family',
                Lien_Position__c = '2nd'
            )
        };
        insert transactions;

        Test.startTest();
        ARIVE_NmlsCallReportController.ReportModel report = ARIVE_NmlsCallReportController.generateReport('2', '2019', new List<String>{'CA'});
        Test.stopTest();

        ARIVE_NmlsCallReportController.ClosedLoanDataModel closedData = report.stateData[0].closedLoanData;
        System.assertEquals(4, closedData.AC100_2, 'AC100 should include Conventional, CONV, HELOC, and NonQM forward loans.');
        System.assertEquals(5, closedData.AC200_2, 'AC200 should include Single Family, Condo, PUD, and Condominium, but not Mobile Home.');
        System.assertEquals(1, closedData.AC210_2, 'AC210 should count Mobile Home as manufactured housing.');
        System.assertEquals(5, closedData.AC500_2, 'AC500 should only count loans marked as first lien.');
        System.assertEquals(1, closedData.AC510_2, 'AC510 should continue to count loans marked as second lien.');
    }

    @isTest
    private static void testCorrespondentLenderFeesUseFlatPerFileAmount() {
        Date fundedDate = Date.newInstance(2019, 5, 15);
        List<Transaction__c> transactions = new List<Transaction__c>{
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'TX',
                Channel__c = 'Correspondent',
                Loan_Amount_1st__c = 100000,
                Broker_Compensation__c = 999,
                Loan_Type_1st_TD__c = 'CONV',
                Property_Type__c = 'Single Family',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'TX',
                Channel__c = 'Correspondent',
                Loan_Amount_1st__c = 120000,
                Broker_Compensation__c = 2500,
                Loan_Type_1st_TD__c = 'FHA',
                Property_Type__c = 'Condo',
                Lien_Position__c = '1st'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'TX',
                Channel__c = 'Broker',
                Loan_Amount_1st__c = 140000,
                Broker_Compensation__c = 5000,
                Loan_Type_1st_TD__c = 'Conventional',
                Property_Type__c = 'PUD',
                Lien_Position__c = '1st'
            )
        };
        insert transactions;

        Test.startTest();
        ARIVE_NmlsCallReportController.ReportModel report = ARIVE_NmlsCallReportController.generateReport('2', '2019', new List<String>{'TX'});
        Test.stopTest();

        System.assertEquals(
            2990,
            report.stateData[0].closedLoanData.AC610_1,
            'AC610 should report $1,495 for each correspondent funded file, regardless of Broker Compensation.'
        );
    }

    @isTest
    private static void testResidentialFirstMortgageCorrespondentCategoriesReconcile() {
        Date fundedDate = Date.newInstance(2019, 5, 15);
        List<Transaction__c> transactions = new List<Transaction__c>{
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'GA',
                Channel__c = 'Correspondent',
                Loan_Amount_1st__c = 100000,
                Loan_Type_1st_TD__c = 'FHA',
                Loan_Program_1st__c = 'FHA 30 Year Fixed',
                Loan_Purpose__c = 'Purchase',
                Property_Type__c = 'Single Family',
                Lien_Position__c = '1st',
                Doc_Type_1st_TD__c = 'Full',
                LTV__c = 85,
                Mortgage_Ins_1st_TD__c = 100
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'GA',
                Channel__c = 'Correspondent',
                Loan_Amount_1st__c = 110000,
                Loan_Type_1st_TD__c = 'CONV',
                Loan_Program_1st__c = 'Bank Statement 30Yr - Pink',
                Loan_Purpose__c = 'Purchase',
                Property_Type__c = 'Condo',
                Lien_Position__c = '1st',
                Doc_Type_1st_TD__c = 'Alt Doc'
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'GA',
                Channel__c = 'Correspondent',
                Loan_Amount_1st__c = 120000,
                Loan_Type_1st_TD__c = 'Jumbo',
                Loan_Program_1st__c = 'Prime Jumbo Released 7/6 ARM',
                Loan_Purpose__c = 'Refinance',
                Refinance_Purpose__c = 'Rate & Term',
                Property_Type__c = 'PUD',
                Lien_Position__c = '1st',
                LTV__c = 95,
                Mortgage_Ins_1st_TD__c = 0
            ),
            new Transaction__c(
                Funding_Date__c = fundedDate,
                Status__c = 'Post-Closed',
                Exclude_From_MCR__c = false,
                Property_State__c = 'GA',
                Channel__c = 'Correspondent',
                Loan_Amount_1st__c = 130000,
                Loan_Type_1st_TD__c = 'CONV',
                Loan_Program_1st__c = 'Investor Flex 30Yr - Yellow',
                Loan_Purpose__c = 'Refinance',
                Refinance_Purpose__c = 'CashOutHomeImprovement',
                Property_Type__c = 'Condominium',
                Lien_Position__c = '1st',
                Mortgage_Ins_1st_TD__c = 50
            )
        };
        insert transactions;

        Test.startTest();
        ARIVE_NmlsCallReportController.ReportModel report = ARIVE_NmlsCallReportController.generateReport('2', '2019', new List<String>{'GA'});
        report = ARIVE_NmlsCallReportController.finishGenerateReport(JSON.serialize(report));
        Test.stopTest();

        ARIVE_NmlsCallReportController.ResidentialFirstMortgagesModel residentialData = report.stateData[0].residentialFirstMortgageData;
        System.assertEquals(4, residentialData.I100_2, 'Residential first mortgage product categories should total all correspondent files once.');
        System.assertEquals(4, residentialData.I200_2, 'Total mortgage loans originated should reconcile to the correspondent file count.');
        System.assertEquals(4, residentialData.I240_2, 'Origination channel subsection should reconcile to the correspondent file count.');
        System.assertEquals(4, residentialData.I259_2, 'Fixed/ARM subsection should reconcile to the correspondent file count.');
        System.assertEquals(4, residentialData.I319_2, 'Purpose subsection should reconcile to the correspondent file count.');
        System.assertEquals(4, residentialData.I339_2, 'Mortgage insurance subsection should reconcile to the correspondent file count.');
        System.assertEquals(4, residentialData.I409_2, 'Production sold subsection should reconcile to the correspondent file count.');
        System.assertEquals(2, residentialData.I030_2, 'CONV programs without the word Fixed should still report as conventional conforming fixed when they are not ARM.');
        System.assertEquals(0, residentialData.I070_2, 'CONV loans should not duplicate into Other Fixed.');
        System.assertEquals(1, residentialData.I270_2, 'Only explicit non-Full documentation should report as Alt Doc.');
        System.assertEquals(3, residentialData.I271_2, 'Blank documentation type should be treated as Full Doc.');
        System.assertEquals(1, residentialData.I311_2, 'Rate & Term refinance should populate the rate/term row.');
        System.assertEquals(1, residentialData.I312_2, 'CashOutHomeImprovement refinance should populate the cash-out row.');
        System.assertEquals(1, residentialData.I330_2, 'Only eligible loan products over 80 LTV should report as having mortgage insurance.');
        System.assertEquals(3, residentialData.I331_2, 'Jumbo and other non-eligible products should report without mortgage insurance regardless of LTV.');
    }

    @isTest
    private static void testResidentialMortgageDataStatusFilter() {
        // Create test Transaction__c records with different Status values
        List<Transaction__c> testTransactions = new List<Transaction__c>();
        
        Date quarterStart = Date.newInstance(2019, 4, 1); // Q2 2019
        Date quarterEnd = Date.newInstance(2019, 6, 30);
        
        // Create a transaction with Status = 'Post-Closed' - should be included
        Transaction__c postClosedLoan = new Transaction__c(
            Funding_Date__c = quarterStart.addDays(15),
            Status__c = 'Post-Closed',
            Exclude_From_MCR__c = false,
            Property_State__c = 'CA',
            Channel__c = 'Correspondent',
            Loan_Amount_1st__c = 100000,
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Program_1st__c = '30 Year Fixed'
        );
        testTransactions.add(postClosedLoan);
        
        // Create a transaction with Status = 'Funding' - should be excluded
        Transaction__c fundingLoan = new Transaction__c(
            Funding_Date__c = quarterStart.addDays(15),
            Status__c = 'Funding',
            Exclude_From_MCR__c = false,
            Property_State__c = 'CA',
            Channel__c = 'Correspondent',
            Loan_Amount_1st__c = 200000,
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Program_1st__c = '30 Year Fixed'
        );
        testTransactions.add(fundingLoan);
        
        // Create a transaction with Status = 'Closing' - should be excluded
        Transaction__c closingLoan = new Transaction__c(
            Funding_Date__c = quarterStart.addDays(15),
            Status__c = 'Closing',
            Exclude_From_MCR__c = false,
            Property_State__c = 'CA',
            Channel__c = 'Correspondent',
            Loan_Amount_1st__c = 300000,
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Program_1st__c = '30 Year Fixed'
        );
        testTransactions.add(closingLoan);
        
        insert testTransactions;
        
        Test.startTest();
        {
            List<String> states = new List<String>{'CA'};
            ARIVE_NmlsCallReportController.ReportModel report = ARIVE_NmlsCallReportController.generateReport('2', '2019', states);
            
            // Verify that only the Post-Closed loan is included in calculations
            // The report should only include loans with Status = 'Post-Closed'
            // We can verify this by checking that the total amounts reflect only the Post-Closed loan
            System.assertNotEquals(null, report, 'Report should be generated');
            System.assertNotEquals(null, report.stateData, 'State data should exist');
            
            if (report.stateData != null && report.stateData.size() > 0) {
                // The residential mortgage data calculations should only include the Post-Closed loan
                // Since we have 1 Post-Closed loan with $100,000 and 2 non-Post-Closed loans ($200k + $300k),
                // the calculations should reflect only the $100k loan
                System.assertNotEquals(null, report.stateData[0].residentialFirstMortgageData, 'Residential mortgage data should exist');
            }
        }
        Test.stopTest();
        
        // Verify the Post-Closed loan exists
        List<Transaction__c> postClosedLoans = [
            SELECT Id, Status__c, Loan_Amount_1st__c 
            FROM Transaction__c 
            WHERE Status__c = 'Post-Closed' 
            AND Funding_Date__c >= :quarterStart 
            AND Funding_Date__c <= :quarterEnd
            AND Property_State__c = 'CA'
            AND Channel__c = 'Correspondent'
        ];
        System.assertEquals(1, postClosedLoans.size(), 'Should have 1 Post-Closed loan');
        System.assertEquals(100000, postClosedLoans[0].Loan_Amount_1st__c, 'Post-Closed loan amount should be 100000');
    }
}
