/**
 * Created by Zeyad Jabra on 8/13/2019.
 */

public with sharing class ARIVE_NmlsCallReportController {

    private static final String NON_QM_PRODUCT_NAME = 'NonQM';
    private static final String CORRESPONDENT_CHANNEL_NAME = 'Correspondent';
    private static final Decimal CORRESPONDENT_LENDER_FEE = 1495;
    private static final List<String> CONVENTIONAL_FORWARD_LOAN_TYPES = new List<String>{'Conventional', 'CONV', 'Jumbo', 'HELOC', NON_QM_PRODUCT_NAME};
    private static final List<String> ONE_TO_FOUR_FAMILY_PROPERTY_TYPES = new List<String>{'Single Family', 'Condominium', 'Town House', '1 Unit', '2-4 Units', 'PUD', 'Other', 'Condo'};
    private static final List<String> MANUFACTURED_PROPERTY_TYPES = new List<String>{'Manufactured Home', 'Mobile Home'};
    private static final List<String> GOVERNMENT_LOAN_TYPES = new List<String>{'FHA', 'VA', 'FarmersHomeAdministration', 'FSA/RHS', 'USDA'};
    private static final List<String> CONVENTIONAL_CONFORMING_LOAN_TYPES = new List<String>{'Conventional', 'CONV'};
    private static final List<String> MORTGAGE_INSURANCE_ELIGIBLE_LOAN_TYPES = new List<String>{'Conventional', 'CONV', 'FHA', 'FarmersHomeAdministration', 'FSA/RHS', 'USDA'};
    private static final List<String> NON_CONFORMING_LOAN_TYPES = new List<String>{'Jumbo'};
    private static final List<String> CASH_OUT_REFINANCE_PURPOSES = new List<String>{'Cash Out Refinance', 'Cash-Out Refinance', 'CashOutHomeImprovement', 'Cash Out Home Improvement'};
    private static final List<String> RATE_TERM_REFINANCE_PURPOSES = new List<String>{'Rate & Term', 'Rate and Term', 'Rate/Term', 'VA Interest Rate Reduction'};

    public class ReportModel {
        @AuraEnabled
        public UserInfoModel user;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public DateTime endDateTime;
        @AuraEnabled
        public String quarter;
        @AuraEnabled
        public String year;
        @AuraEnabled
        public List<StateModel> stateData;
        @AuraEnabled
        public List<StateOptionModel> stateOptions;
        @AuraEnabled
        public List<String> states;

        public ReportModel(String quarter, String year, String[] states) {
            Date startDate = Date.newInstance(Integer.valueOf(year), (Integer.valueOf(quarter) - 1) * 3 + 1,1);
            Date endDate = startDate.addMonths(3).addDays(-1);
            System.debug(startDate);
            System.debug(endDate);
            System.debug(states);
            this.startDate = startDate;
            this.endDate = endDate;
            this.endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 999));
            this.quarter = quarter;
            this.year = year;
            this.stateData = new List<StateModel>();
            this.stateOptions = new List<StateOptionModel>();
            for (String state : states) {
                this.stateData.add(new StateModel(state));
                this.stateOptions.add(new StateOptionModel(state));
            }
            this.user = new UserInfoModel();
            this.states = states;
            generateApplicationData();
            generateClosedLoanData();
            generateRevenueData();
            generateMloData();
        }
        public void generateApplicationData() {
            generateApplicationsInProcess();
            generateApplicationsReceived();
            generateApplicationsApprovedNotAccepted();
            generateApplicationsDenied();
            generateApplicationsWithdrawn();
            generateFilesClosedForIncompleteness();
            generatePreapprovalRequestsDenied();
            generatePreapprovalRequestsApprovedNotAccepted();
            generateLoansClosedAndFunded();
            generateApplicationsInProcessAtEnd();
            setApplicationDataTotals();
        }
        public void setApplicationDataTotals(){
            for(StateModel state : stateData){
                state.applicationData.setTotalRowApplicationPipeline();
                state.applicationData.setTotalRowApplicationPipelineResults();
            }
        }
        public void generateApplicationsInProcess() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>([
                    SELECT Property_State__c Id, Count(Id) countOfLoans, Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE TRID_Date__c < :startDate
                    AND (
                            (Funding_Date__c >= :startDate
                            OR Withdrawn__c >= :startDate)
                            OR
                            (Funding_Date__c = NULL
                            AND Withdrawn__c = NULL)
                    )
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]);
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setApplicationsInProcess((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateApplicationsReceived() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE TRID_Date__c >= :startDate AND TRID_Date__c < :endDate.addDays(1)
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setApplicationsRecieved((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateApplicationsApprovedNotAccepted() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Withdrawn__c >= :startDate AND Withdrawn__c <= :endDateTime
                    AND Withdrawn_Reason__c = 'Approved But Not Accepted'
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setApplicationsApprovedButNotAccepted((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateApplicationsDenied() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Withdrawn__c >= :startDate AND Withdrawn__c <= :endDateTime
                    AND Withdrawn_Reason__c IN ('App Denied')
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setApplicationsDenied((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateApplicationsWithdrawn() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Withdrawn__c >= :startDate AND Withdrawn__c <= :endDateTime
                    AND Withdrawn_Reason__c IN ('App Withdrawn By Borrower', 'App Rescinded By Borrower')
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setApplicationsWithdrawn((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateFilesClosedForIncompleteness() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Withdrawn__c >= :startDate AND Withdrawn__c <= :endDateTime
                    AND Withdrawn_Reason__c = 'File Closed For Incompleteness'
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setFileClosedForIncompleteness((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generatePreapprovalRequestsDenied() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Withdrawn__c >= :startDate AND Withdrawn__c <= :endDateTime
                    AND Withdrawn_Reason__c = 'Pre-Approval Denied'
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setPreapprovalRequestsDenied((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generatePreapprovalRequestsApprovedNotAccepted() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Withdrawn__c >= :startDate AND Withdrawn__c <= :endDateTime
                    AND Withdrawn_Reason__c = 'Pre-Approval Approved But Not Accepted'
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setPreapprovalRequestsApprovedNotAccepted((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateLoansClosedAndFunded() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate AND Withdrawn__c = NULL
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != NULL
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setLoansClosedAndFunded((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        public void generateApplicationsInProcessAtEnd() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE TRID_Date__c < :endDate.addDays(1) 
                	AND (Funding_Date__c > :endDate OR Funding_Date__c = NULL) AND (Withdrawn__c > :endDateTime OR Withdrawn__c = NULL)
                	AND (Post_Closed_Date__c > :endDate OR Post_Closed_Date__c = NULL)
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != NULL
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.applicationData.setApplicationsInProcessAtEnd((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }

        public void generateClosedLoanData() {
//            Set<String> NonQmProducts = new Set<String>();
//            for(Non_QM_Product__mdt product : [SELECT Id, Label, Lender__c, Product_Name__c, Active__c FROM Non_QM_Product__mdt WHERE Active__c = true]){
//                NonQmProducts.add(product.Product_Name__c);
//            }
            generateConventional();
            generateConventionalForCorrespondent();
            generateFhaIssued();
            generateFhaIssuedForCorrespondent();
            generateVaGuarunteed();
            generateVaGuarunteedForCorrespondent();
            generateFsaRhaGuarunteed();
            generateFsaRhaGuarunteedForCorrespondent();
            generateOneToFourFamilyDwelling();
            generateOneToFourFamilyDwellingForCorrespondent();
            generateManufcaturedHousing();
            generateManufcaturedHousingForCorrespondent();
            generateMultifamilyDwelling();
            generateMultifamilyDwellingForCorrespondent();
            generateHomePurchase();
            generateHomePurchaseForCorrespondent();
            generateHomeImprovement();
            generateHomeImprovementForCorrespondent();
            generateRefinancing();
            generateRefinancingForCorrespondent();
            generateFirstLien();
            generateFirstLienForCorrespondent();
            generateSubordinateLien();
            generateSubordinateLienForCorrespondent();
            generateNotSecured();
            generateNotSecuredForCorrespondent();
            generateBrokerFeesCollected();
            generateLenderFeesCollected();
//            generateProprietary();
//            generateReverseHomePurchase();
//            generateReverseOther();
//            generateReverseBrokerFeesCollected();
            generateQualifiedMortgage();
            generateQualifiedMortgageForCorrespondent();
            generateNonQualifiedMortgage();
            generateNonQualifiedMortgageForCorrespondent();
//            generateNotSubjectToQualifiedMortgage();
            generateTotalLoansBrokeredByCompany();
            generateTotalLoansFundedByCompany();
            calculateClosedTotals();
        }

        public void calculateClosedTotals(){
            for(StateModel state : stateData){
                state.closedLoanData.setTotalRowLoanTypeForwardMortgages();
                state.closedLoanData.setTotalRowLoanTypeForwardMortgagesForCorrespondent();
                state.closedLoanData.setTotalRowPropertyTypeForwardMortgage();
                state.closedLoanData.setTotalRowPropertyTypeForwardMortgageForCorrespondent();
                state.closedLoanData.setTotalRowPurposeForwardMortgage();
                state.closedLoanData.setTotalRowPurposeForwardMortgageForCorrespondent();
                state.closedLoanData.setTotalRowLienStatusForwardMortgage();
                state.closedLoanData.setTotalRowLienStatusForwardMortgageForCorrespondent();
//                state.closedLoanData.setTotalRowLoanTypeReverseMortgage();
//                state.closedLoanData.setTotalRowPurposeReverseMortgage();
                state.closedLoanData.setTotalRowQM_NonQM();
                state.closedLoanData.setTotalRowQM_NonQMForCorrespondent();
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:

        Loan Type is Conventional and Funded (date)
        is within the fiscal quarter the report is being generated for "*/
        public void generateConventional() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c IN :CONVENTIONAL_FORWARD_LOAN_TYPES AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setConventional((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:

        Loan Type is Conventional, Funded (date) and Channel is Correspondent
        is within the fiscal quarter the report is being generated for "*/
        public void generateConventionalForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c IN :CONVENTIONAL_FORWARD_LOAN_TYPES AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setConventionalForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        Loan Type is FHA and Funded (date)
        is within the fiscal quarter the report is being generated for "*/
        public void generateFhaIssued() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c= 'FHA' AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setFHA((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        Loan Type is FHA, Channel is Correspondent, and Funded (date)
        is within the fiscal quarter the report is being generated for "*/
        public void generateFhaIssuedForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c = 'FHA' AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setFHAForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Type is VA and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateVaGuarunteed() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c= 'VA' AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setVA((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Type is VA, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateVaGuarunteedForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c = 'VA' AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setVAForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Type is USDA and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateFsaRhaGuarunteed() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c = 'FSA/RHS' AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setFsaRsaGuarunteed((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Type is FSA/RHS, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateFsaRhaGuarunteedForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c = 'FSA/RHS' AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setFsaRsaGuarunteedForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Property Type is not ""Manufactured/Single-wide"" or ""Manufactured/Double-wide"" or ""Multi Family Home"" and Units is between 1 and 4 inclusive and Funded (date)
        //is within the fiscal quarter the report is being generated for*/
        public void generateOneToFourFamilyDwelling() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Property_Type__c IN :ONE_TO_FOUR_FAMILY_PROPERTY_TYPES AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setOneToFourDwelling((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Property Type is One to Four Family Dwelling, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for*/
        public void generateOneToFourFamilyDwellingForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Property_Type__c IN :ONE_TO_FOUR_FAMILY_PROPERTY_TYPES AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setOneToFourDwellingForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Property Type is ""Manufactured/Single-wide"" or ""Manufactured/Double-wide"" and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateManufcaturedHousing() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Property_Type__c IN :MANUFACTURED_PROPERTY_TYPES AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setManufacturedHousing((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Property Type is Manufactured Housing, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateManufcaturedHousingForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Property_Type__c IN :MANUFACTURED_PROPERTY_TYPES AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setManufacturedHousingForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Property Type is ""Multi Family Home""and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateMultifamilyDwelling() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Property_Type__c IN ('4-10 Units', '10+ Units') AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setMultifamilyDwelling((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Property Type is Multifamily Dwelling, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateMultifamilyDwellingForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Property_Type__c IN ('4-10 Units', '10+ Units') AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setMultifamilyDwellingForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Mortgage Purpose is Purchase and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateHomePurchase() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'Purchase' AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setHomePurchase((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Mortgage Purpose is Purchase, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateHomePurchaseForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'Purchase' AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setHomePurchaseForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Purpose of Refinance is equal to ""Cash-Out Home Improvement"" and Funded (date)
        //is are within the fiscal quarter the report is being generated for*/
        public void generateHomeImprovement() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Refinance_Purpose__c = 'Home Improvement' AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setHomeImprovement((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Purpose of Refinance is Home Improvement, Channel is Correspondent, and Funded (date)
        //is are within the fiscal quarter the report is being generated for*/
        public void generateHomeImprovementForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Refinance_Purpose__c = 'Home Improvement' AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setHomeImprovementForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Mortgage Purpose is Refinance and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateRefinancing() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'Refinance' AND Refinance_Purpose__c != 'Home Improvement'
                    AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setRefinancing((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Mortgage Purpose is Refinance, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateRefinancingForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'Refinance' AND Refinance_Purpose__c  != 'Home Improvement'
                    AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setRefinancingForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is 1st and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateFirstLien() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = '1st' AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                system.debug(result);
                if (result != null) {
                    state.closedLoanData.setFirstLien((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is 1st or NUll, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is being generated for "*/
        public void generateFirstLienForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = '1st' AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                system.debug(result);
                if (result != null) {
                    state.closedLoanData.setFirstLienForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is not 1st or NULL/Blank and Funded (date) is within the fiscal quarter the report is being generated for "*/
        public void generateSubordinateLien() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = '2nd' AND Lien_Position__c != NULL AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setSubordinate((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is 2nd and not NULL/Blank, Channel is Correspondent, and Funded (date) is within the fiscal quarter the report is being generated for "*/
        public void generateSubordinateLienForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = '2nd' AND Lien_Position__c != NULL AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setSubordinateForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is not secured which considered NULL"*/
        public void generateNotSecured() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = NULL AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setNotSecured((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is NULL/Blank, Channel is Correspondent, and Funded (date) is within the fiscal quarter the report is being generated for "*/
        public void generateNotSecuredForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = NULL AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setNotSecuredForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is not secured which considered NULL"*/
        public void generateBrokerFeesCollected() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Sum(Broker_Compensation__c) BrokerFeesCollected
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c != :CORRESPONDENT_CHANNEL_NAME AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setBrokerFeesCollected(
                            (Decimal) result.get('BrokerFeesCollected')
                    );
                }
            }
        }
        public void generateLenderFeesCollected() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c = :CORRESPONDENT_CHANNEL_NAME AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    Decimal correspondentFileCount = Decimal.valueOf(String.valueOf(result.get('countOfLoans')));
                    state.closedLoanData.setLenderFeesCollected(
                            correspondentFileCount * CORRESPONDENT_LENDER_FEE
                    );
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Program type is Reverse Mortgage. Reverse mortgages are all grouped into Proprietary/Other"*/
//        public void generateProprietary() {
//            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
//            [
//                    SELECT Property_State__c Id,
//                            Count(Id) countOfLoans,
//                            Sum(Loan_Amount_1st__c) totalAmount
//                    FROM Transaction__c
//                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
//                    AND Loan_Program_1st__c = 'Reverse Mortgage'
//                    AND Property_State__c IN:this.states AND Property_State__c != null
//                    GROUP BY Property_State__c
//            ]
//            );
//            for (StateModel state : stateData) {
//                AggregateResult result = (AggregateResult) results.get(state.stateCode);
//                if (result != null) {
//                    state.closedLoanData.setProprietary((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
//                }
//            }
//        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Program type is Reverse Mortgage and Transaction Type is Purchase"*/
//        public void generateReverseHomePurchase() {
//            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
//            [
//                    SELECT Property_State__c Id,
//                            Count(Id) countOfLoans,
//                            Sum(Loan_Amount_1st__c) totalAmount
//                    FROM Transaction__c
//                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
//                    AND Loan_Program_1st__c = 'Reverse Mortgage' AND TransactionType__c  = 'Purchase'
//                    AND Property_State__c IN:this.states AND Property_State__c != null
//                    GROUP BY Property_State__c
//            ]
//            );
//            for (StateModel state : stateData) {
//                AggregateResult result = (AggregateResult) results.get(state.stateCode);
//                if (result != null) {
//                    state.closedLoanData.setReverseHomePurchase((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
//                }
//            }
//        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Program type is Reverse Mortgage and Transaction Type is not purchase"*/
//        public void generateReverseOther() {
//            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
//            [
//                    SELECT Property_State__c Id,
//                            Count(Id) countOfLoans,
//                            Sum(Loan_Amount_1st__c) totalAmount
//                    FROM Transaction__c
//                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
//                    AND Loan_Program_1st__c = 'Reverse Mortgage' AND TransactionType__c  != 'Purchase'
//                    AND Property_State__c IN:this.states AND Property_State__c != null
//                    GROUP BY Property_State__c
//            ]
//            );
//            for (StateModel state : stateData) {
//                AggregateResult result = (AggregateResult) results.get(state.stateCode);
//                if (result != null) {
//                    state.closedLoanData.setReverseOther((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
//                }
//            }
//        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Lien Position is not secured which considered NULL"*/
//        public void generateReverseBrokerFeesCollected() {
//            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
//            [
//                    SELECT Property_State__c Id,
//                            Sum(Broker_Compensation__c) totalLoanRevenue
//                    FROM Transaction__c
//                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
//                    AND Loan_Program_1st__c = 'Reverse Mortgage'
//                    AND Property_State__c IN:this.states AND Property_State__c != null
//                    GROUP BY Property_State__c
//            ]
//            );
//            for (StateModel state : stateData) {
//                AggregateResult result = (AggregateResult) results.get(state.stateCode);
//                if (result != null) {
//                    state.closedLoanData.setReverseBrokerFeesCollected(
//                            (Decimal) result.get('totalLoanRevenue')
//                    );
//                }
//            }
//        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Program Name does not appear in the Non-QM Products list that ARIVE internally manages and Funded (date)
        //is within the fiscal quarter the report is being generated for         /*/
        public void generateQualifiedMortgage() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c != :NON_QM_PRODUCT_NAME AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setQualifiedMortgage((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Program Name does not appear in the Non-QM Products list that ARIVE internally manages and Funded (date)
        //is within the fiscal quarter the report is being generated for         /*/
        public void generateQualifiedMortgageForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c != :NON_QM_PRODUCT_NAME AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setQualifiedMortgageForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum of the max of the Total Loan Revenue and Final Broker Compensation for all loans where:
        //
        //Funded (date)
        //is within the fiscal quarter the report is generated for*/
        public void generateNonQualifiedMortgage() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c = :NON_QM_PRODUCT_NAME AND Channel__c != :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setNonQualifiedMortgage((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum of the max of the Total Loan Revenue and Final Broker Compensation for all loans where:
        //
        //Product Name is Non-QM, Channel is Correspondent, and Funded (date)
        //is within the fiscal quarter the report is generated for*/
        public void generateNonQualifiedMortgageForCorrespondent() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c = :NON_QM_PRODUCT_NAME AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setNonQualifiedMortgageForCorrespondent((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum of the max of the Total Loan Revenue and Final Broker Compensation for all loans where:
        //
        //Funded (date)
        //is within the fiscal quarter the report is generated for*/
//        public void generateNotSubjectToQualifiedMortgage() {
//            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
//            [
//                    SELECT Property_State__c Id,
//                            Count(Id) countOfLoans,
//                            Sum(Loan_Amount_1st__c) totalAmount
//                    FROM Transaction__c
//                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
//                    AND Loan_Program_1st__c = 'DSCR'
//                    AND Property_State__c IN:this.states AND Property_State__c != null
//                    GROUP BY Property_State__c
//            ]
//            );
//            for (StateModel state : stateData) {
//                AggregateResult result = (AggregateResult) results.get(state.stateCode);
//                if (result != null) {
//                    state.closedLoanData.setNotSubjectToQualifiedMortgage((Decimal) result.get('totalAmount'), (Decimal) result.get('countOfLoans'));
//                }
//            }
//        }

        public void generateTotalLoansBrokeredByCompany() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c != :CORRESPONDENT_CHANNEL_NAME AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setTotalLoansBrokeredByCompany((Decimal) result.get('countOfLoans'));
                }
            }

        }

        public void generateTotalLoansFundedByCompany() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c = :CORRESPONDENT_CHANNEL_NAME AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.closedLoanData.setTotalLoansFundedByCompany((Decimal) result.get('countOfLoans'));
                }
            }

        }

        public void generateRevenueData() {
            generateGrossRevenue();
        }
        /*Process to sum the Total Loan Amount for all loans where:
        //
        //Loan Program Name appears in the Non-QM Products list that ARIVE internally manages and Funded (date)
        //is within the fiscal quarter the report is being generated or*/
        public void generateGrossRevenue() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Sum(Gross_Compensation__c) totalLoanRevenue
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.revenueData.setGrossRevenue(
                            (Decimal) result.get('totalLoanRevenue')
                    );
                }
            }
        }
        /*For all unique indiviudal users holding a license in the state the report is being run for and
         belonging to the company the report is being run for, sum the total loan amount where
         Closed (date) and Funded (date) are within the quarter the report is being run for */
        public void generateMloData() {
            List<AggregateResult> results = new List<AggregateResult>(
            [
                    SELECT Property_State__c Id, NMLS_ID__c nmlsId,
                            count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                	AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    AND NMLS_ID__c != null
                    GROUP BY Property_State__c, NMLS_ID__c
            ]
            );
            Map<String, List<AggregateResult>> aggregateResultMap = new Map<String, List<AggregateResult>>();
            for(AggregateResult result : results){
                if(aggregateResultMap.containsKey((String)result.get('Id'))){
                    List<AggregateResult> tempResults = (List<AggregateResult>)aggregateResultMap.get((string)result.get('Id'));
                    tempResults.add(result);
                    aggregateResultMap.put((String)result.get('Id'), tempResults);
                }else{
                    aggregateResultMap.put((String)result.get('Id'), new List<AggregateResult>{result});
                }
            }
            
            for (StateModel state : stateData) {
                List<AggregateResult> stateList = (List<AggregateResult>) aggregateResultMap.get(state.stateCode);
                if (stateList != null && stateList.size() > 0) {
                    for(AggregateResult res : stateList){
                        
                        state.loanOriginatorData.add(new MloDataModel( (String) res.get('nmlsId'), (Decimal) res.get('totalAmount'), (Decimal) res.get('countOfLoans')));
                        
                    }
                }
            }
        }

        public void generateResidentialFirstMortgagesData() {
            generateGovernmentFixed(); //
            generateGovernmentARM();
            generateConventionalConformingFixed();
            generateConventionalConformingARM();
            generateConventionalNonConformingFixed();
            generateConventionalNonConformingARM();
            generateOtherFixed();
            generateOtherARM();
            generateClosedEndSecondMortgages();
            generateHELOCS();
            generateConstruction();
            generateRetail();
            generateWholesaleBrokered();
            generateFixedRate();
            generateARM();
            generateJumbo();
            generateNonJumbo();
            generateAltDoc();
            generateFullDoc();
            generateInterestOnly();
            generateNotInterestOnly();
            generateOptionARMS();
            generateNotOptionARMS();
            generateLoansWithPrepaymentPenalties();
            generateLoansWithoutPrepaymentPenalties();
            generatePurchase();
            generateRefinanceRateTerm();
            generateCashOutRefinances();
            generateRefinanceOtherUnknown();
            generateLoansWithMortgageInsurance();
            generateLoansWithoutMortgageInsurance();
            generateLoansWithPiggybackSeconds();
            generateLoansWithoutPiggybackSeconds();
            generateLoansWithLTVEqualOrLessThan60();
            generateLoansWithLTVBetween60And70();
            generateLoansWithLTVBetween70And80();
            generateLoansWithLTVBetween80And90();
            generateLoansWithLTVBetween90And100();
            generateLoansWithLTVGreaterThan100();
            generateWeightedAverageLTV();
            generateWeightedAverageCLTV();
            generateWeightedAverageCouponAtOrigination();
            generateProductionSoldToOthersNonAffiliate();
            calculateResidentialFirstMortgagesTotals();
            //generateAvgDaysInWarehouse();
            //generateProductionWarehousedInExcessOf90Days();
        }

        public void calculateResidentialFirstMortgagesTotals(){
            for(StateModel state : stateData){
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgages();
                state.residentialFirstMortgageData.setTotalOtherMortgages();
                state.residentialFirstMortgageData.setTotalMortgageLoansOriginated();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom210To230();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom250To251();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom260To261();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom270To271();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom280To281();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom290To291();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom300To301();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom310To314();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom330To331();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom340To341();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom370To375();
                state.residentialFirstMortgageData.setTotalResidentialFirstMortgagesFrom400To405();
                state.residentialFirstMortgageData.setProductionSoldServicingReleased();
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are guaranteed or insured by the government(FHA/VA/RHS) and amortization type is fixed"*/
        public void generateGovernmentFixed() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c IN :GOVERNMENT_LOAN_TYPES
                    AND (Loan_Program_1st__c = NULL OR (NOT(Loan_Program_1st__c LIKE '%ARM%'))) AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            System.debug(results);
            System.debug(stateData);
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                System.debug(result);
                if (result != null) {
                    state.residentialFirstMortgageData.setGovernmentFixed(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }

        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are guaranteed or insured by the government(FHA/VA/RHS) and amortization type is ARM"*/
        public void generateGovernmentARM() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c IN :GOVERNMENT_LOAN_TYPES
                    AND Loan_Program_1st__c LIKE '%ARM%' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setGovernmentARM(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, amortization type is fixed, and loan type is conforming"*/
        public void generateConventionalConformingFixed() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Program_1st__c = NULL OR (NOT(Loan_Program_1st__c LIKE '%ARM%')))
                    AND Loan_Type_1st_TD__c IN :CONVENTIONAL_CONFORMING_LOAN_TYPES
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setConventionalConformingFixed(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, amortization type is ARM, and loan type is conforming"*/
        public void generateConventionalConformingARM() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c LIKE '%ARM%'
                    AND Loan_Type_1st_TD__c IN :CONVENTIONAL_CONFORMING_LOAN_TYPES
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setConventionalConformingARM(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, amortization type is fixed and loan type is Jumbo"*/
        public void generateConventionalNonConformingFixed() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Program_1st__c = NULL OR (NOT(Loan_Program_1st__c LIKE '%ARM%')))
                    AND Loan_Type_1st_TD__c IN :NON_CONFORMING_LOAN_TYPES AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setConventionalNonConformingFixed(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, amortization type is ARM and loan type is Jumbo"*/
        public void generateConventionalNonConformingARM() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c LIKE '%ARM%'
                    AND Loan_Type_1st_TD__c IN :NON_CONFORMING_LOAN_TYPES AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setConventionalNonConformingARM(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, amortization type is Fixed, and loan type is other"*/
        public void generateOtherFixed() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Program_1st__c = NULL OR (NOT(Loan_Program_1st__c LIKE '%ARM%')))
                    AND Loan_Type_1st_TD__c NOT IN ('Jumbo', 'Conventional', 'CONV', 'FHA', 'VA', 'FarmersHomeAdministration', 'FSA/RHS', 'USDA')
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setOtherFixed(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, amortization type is ARM, and loan type is other"*/
        public void generateOtherARM() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c LIKE '%ARM%'
                    AND Loan_Type_1st_TD__c NOT IN ('Jumbo', 'Conventional', 'CONV', 'FHA', 'VA', 'FarmersHomeAdministration', 'FSA/RHS', 'USDA')
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setOtherARM(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }

        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, program is HE-LOAN"*/
        public void generateClosedEndSecondMortgages() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Lien_Position__c = '2nd'
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setClosedEndSecondMortgages(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }

        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, mortgage applied for is HELOC"*/
        public void generateHELOCS() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'HELOC'
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setHELOCs(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, program is reverse"*/
        public void generateReverse() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c = 'Reverse Mortgage'
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setReverse(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, mortgage applied for is construction"*/
        public void generateConstruction() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Program_1st__c LIKE '%CONST%' OR Loan_Program_1st__c LIKE '%OTC%')
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setConstruction(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and not included above."*/
        public void generateOtherResidential() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (NOT(Loan_Program_1st__c LIKE '%Bank Statement%' OR Loan_Program_1st__c LIKE '%Investor Flex%'))
                    AND Lien_Position__c != '2nd' AND Loan_Purpose__c != 'HELOC'
                    AND Loan_Program_1st__c != 'Reverse Mortgage' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setOtherResidential(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and compensation type is correspondent."*/
        public void generateRetail() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c =:CORRESPONDENT_CHANNEL_NAME AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setRetail(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and compensation type is not correspondent or broker."*/
        public void generateTableFunded() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c NOT IN ('Correspondent', 'Broker') AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setTableFunded(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and compensation type is broker."*/
        public void generateWholesaleBrokered() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Channel__c = 'Broker' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setWholesalesBrokered(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and amortization type is fixed"*/
        public void generateFixedRate() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Program_1st__c = NULL OR (NOT(Loan_Program_1st__c LIKE '%ARM%')))
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setFixedRate(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and amortization type is ARM"*/
        public void generateARM() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c LIKE '%ARM%'
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setARM(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and loan is jumbo"*/
        public void generateJumbo() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Type_1st_TD__c = 'Jumbo' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setJumbo(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and loan is not jumbo"*/
        public void generateNonJumbo() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Type_1st_TD__c = NULL OR Loan_Type_1st_TD__c != 'Jumbo') AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setNonJumbo(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and loan is jumbo"*/
        public void generateAltDoc() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            COUNT(Id) countOfLoans,
                            SUM(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Doc_Type_1st_TD__c != NULL AND Doc_Type_1st_TD__c != 'Full' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setAltDoc(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and loan is not jumbo"*/
        public void generateFullDoc() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            COUNT(Id) countOfLoans,
                            SUM(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Doc_Type_1st_TD__c = NULL OR Doc_Type_1st_TD__c = 'Full') AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setFullDoc(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }

        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and amortization type interest only"*/
        public void generateInterestOnly() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c LIKE '%Interest Only%' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setInterestOnly(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and amortization type is not interest only"*/
        public void generateNotInterestOnly() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Loan_Program_1st__c = NULL OR (NOT(Loan_Program_1st__c LIKE '%Interest Only%'))) AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setNotInterestOnly(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and program contains ARM or HELOC"*/
        public void generateOptionARMS() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Program_1st__c = 'Option ARM' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setOptionARMs(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and program contains ARM or HELOC"*/
        public void generateNotOptionARMS() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                      AND (Loan_Program_1st__c = NULL OR Loan_Program_1st__c != 'Option ARM')
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setNotOptionARMs(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and has prepayment penalties"*/
        public void generateLoansWithPrepaymentPenalties() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                      AND Prepayment_Penalty__c = 'Yes'
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithPrepaymentPenalties(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and does not have prepayment penalties"*/
        public void generateLoansWithoutPrepaymentPenalties() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (Prepayment_Penalty__c = NULL OR Prepayment_Penalty__c != 'Yes') AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithoutPrepaymentPenalties(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and closed loan purpose is purchase"*/
        public void generatePurchase() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'Purchase' AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setPurchase(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, closed loan purpose is refinance and refinance purpose is either rate term or rate-term"*/
        public void generateRefinanceRateTerm() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND ((Loan_Purpose__c = 'Refinance' AND Refinance_Purpose__c IN :RATE_TERM_REFINANCE_PURPOSES) OR Loan_Purpose__c = 'Refinance Rate & Term') AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN :this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setRefinanceRateTerm(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, closed loan purpose is refinance, and refinance purpose is Cash Out or Cash-Out"*/
        public void generateCashOutRefinances() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND ((Loan_Purpose__c = 'Refinance' AND Refinance_Purpose__c IN :CASH_OUT_REFINANCE_PURPOSES) OR Loan_Purpose__c = 'Refinance Cash-Out') AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setCashOutRefinance(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, closed loan purpose is refinance, refinance purpose is restructure"*/
        public void generateRefinanceRestructure() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                     AND Loan_Purpose__c = 'Refinance'
                    AND Refinance_Purpose__c LIKE '%RESTRUCTURE%'
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setRefinanceRestructure(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, closed loan purpose is refinance, and refinance purpose is none of the above."*/
        public void generateRefinanceOtherUnknown() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Loan_Purpose__c = 'Refinance'
                    AND (Refinance_Purpose__c = NULL OR (Refinance_Purpose__c NOT IN :RATE_TERM_REFINANCE_PURPOSES AND Refinance_Purpose__c NOT IN :CASH_OUT_REFINANCE_PURPOSES))
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setRefinanceOtherUnknown(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
      //
      //Residential loans have LTV over 80% and are MI-eligible loan products"*/
        public void generateLoansWithMortgageInsurance() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND LTV__c > 80
                    AND Loan_Type_1st_TD__c IN :MORTGAGE_INSURANCE_ELIGIBLE_LOAN_TYPES
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithMortgageInsurance(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
     //
     //Residential loans are not classified as having mortgage insurance"*/
        public void generateLoansWithoutMortgageInsurance() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND (LTV__c <= 80 OR LTV__c = NULL OR Loan_Type_1st_TD__c = NULL OR Loan_Type_1st_TD__c NOT IN :MORTGAGE_INSURANCE_ELIGIBLE_LOAN_TYPES)
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithoutMortgageInsurance(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
     //
     //Residential loans are for 1 to 4 units, loan type is not HELOC, and has piggyback seconds."*/
        public void generateLoansWithPiggybackSeconds() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Has_Piggyback_Seconds__c = TRUE AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithPiggybackSeconds(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
     //
     //Residential loans are for 1 to 4 units, and does not have piggyback seconds"*/
        public void generateLoansWithoutPiggybackSeconds() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                     AND Has_Piggyback_Seconds__c = FALSE
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithoutPiggybackSeconds(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and LTV is less than or equal to 60%"*/
        public void generateLoansWithLTVEqualOrLessThan60() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                     AND LTV__c <= 60
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithLTVEqualOrLessThan60(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and LTV is greater than 60% but less than or equal to 70%"*/
        public void generateLoansWithLTVBetween60And70() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND LTV__c > 60 AND LTV__c <= 70
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithLTVBetween60And70(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and LTV is greater than 70% but less than or equal to 80%"*/
        public void generateLoansWithLTVBetween70And80() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND LTV__c > 70 AND LTV__c <= 80
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithLTVBetween70And80(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and LTV is 80% but less than or equal to 90%"*/
        public void generateLoansWithLTVBetween80And90() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND LTV__c > 80 AND LTV__c <= 90
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithLTVBetween80And90(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and LTV is greater than 90% but less than or equal to 100%"*/
        public void generateLoansWithLTVBetween90And100() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND LTV__c > 90 AND LTV__c <= 100
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithLTVBetween90And100(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and greater than 100%"*/
        public void generateLoansWithLTVGreaterThan100() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                     AND LTV__c > 100
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithLTVGreaterThan100(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }

        //Calculating Weighted Average of LTV on First Mortgages Only
        public void generateWeightedAverageLTV() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            AVG(LTV__c) LTVLoansCollected
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setWeightedAverageLTV(
                            (Decimal) result.get('LTVLoansCollected')
                    );
                }
            }
        }
        //Calculating Weighted Average of CLTV on First Mortgages Only
        public void generateWeightedAverageCLTV() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            AVG(LTV__c) CLTVLoansCollected
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setWeightedAverageCLTV(
                            (Decimal) result.get('CLTVLoansCollected')
                    );
                }
            }
        }
        //Calculating Weighted Average of Interest Rate on First Mortgages Only
        public void generateWeightedAverageCouponAtOrigination() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            AVG(Interest_Rate__c) InterestRateLoansCollected
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setWeightedAverageCouponAtOrigination(
                            (Decimal) result.get('InterestRateLoansCollected')
                    );
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
        //
        //Residential loans are for 1 to 4 units, and compensation type is correspondent."*/
        public void generateProductionSoldToOthersNonAffiliate() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                     AND Channel__c =: CORRESPONDENT_CHANNEL_NAME
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null AND Channel__c = :CORRESPONDENT_CHANNEL_NAME
                    AND Status__c = 'Post-Closed'
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setLoansWithProductionSoldToOthersNonAffiliate(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
        //Calculating Weighted Average of days between funded date and wire ordered date on First Mortgages Only
        public void generateAvgDaysInWarehouse() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            AVG(Days_In_Warehouse__c) daysInWarehouse
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                    
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setAvgDaysInWarehouse(
                            (Decimal) result.get('daysInWarehouse')
                    );
                }
            }
        }
        /*"Process to sum the Total Loan Amount for all loans where:
       //
       //Residential loans are for 1 to 4 units, and days between funded date and wire ordered date is over 90"*/
        public void generateProductionWarehousedInExcessOf90Days() {
            Map<String, AggregateResult> results = new Map<String, AggregateResult>(
            [
                    SELECT Property_State__c Id,
                            Count(Id) countOfLoans,
                            Sum(Loan_Amount_1st__c) totalAmount
                    FROM Transaction__c
                    WHERE Funding_Date__c >= :startDate AND Funding_Date__c <= :endDate
                     AND Days_Over_90__c = 1
                    AND Exclude_From_MCR__c = FALSE
                    AND Property_State__c IN:this.states AND Property_State__c != null
                    GROUP BY Property_State__c
            ]
            );
            for (StateModel state : stateData) {
                AggregateResult result = (AggregateResult) results.get(state.stateCode);
                if (result != null) {
                    state.residentialFirstMortgageData.setProductionWarehousedInExcessOf90Days(result.get('totalAmount') != null ? (Decimal) result.get('totalAmount') : 0 , (Decimal) result.get('countOfLoans'));
                }
            }
        }
    }

    public class StateModel {
        @AuraEnabled
        public String stateCode;
        @AuraEnabled
        public ApplicationDataModel applicationData;
        @AuraEnabled
        public ClosedLoanDataModel closedLoanData;
        @AuraEnabled
        public ResidentialFirstMortgagesModel residentialFirstMortgageData;
        @AuraEnabled
        public RevenueDataModel revenueData;
        @AuraEnabled
        public List<MloDataModel> loanOriginatorData;

        public StateModel(String stateCode) {
            this.stateCode = stateCode;
            applicationData = new ApplicationDataModel();
            closedLoanData = new ClosedLoanDataModel();
            residentialFirstMortgageData = new ResidentialFirstMortgagesModel();
            revenueData = new RevenueDataModel();
            loanOriginatorData = new List<MloDataModel>();
        }
    }
    public class ApplicationDataModel {
        @AuraEnabled
        public Decimal
                AC010_1, AC010_2, AC010_3,
                AC020_1, AC020_2, AC020_3,
                AC030_1, AC030_2, AC030_3,
                AC040_1, AC040_2, AC040_3,
                AC050_1, AC050_2, AC050_3,
                AC060_1, AC060_2, AC060_3,
                AC062_1, AC062_2, AC062_3,
                AC064_1, AC064_2, AC064_3,
                AC065_1,
                AC066_1, AC066_2, AC066_3,
                AC070_1, AC070_2, AC070_3,
                AC080_1, AC080_2, AC080_3,
                AC090_1, AC090_2, AC090_3;
        public ApplicationDataModel() {
            AC010_1 = 0;
            AC010_2 = 0;
            AC010_3 = 0;
            AC020_1 = 0;
            AC020_2 = 0;
            AC020_3 = 0;
            AC030_1 = 0;
            AC030_2 = 0;
            AC030_3 = 0;
            AC040_1 = 0;
            AC040_2 = 0;
            AC040_3 = 0;
            AC050_1 = 0;
            AC050_2 = 0;
            AC050_3 = 0;
            AC060_1 = 0;
            AC060_2 = 0;
            AC060_3 = 0;
            AC062_1 = 0;
            AC062_2 = 0;
            AC062_3 = 0;
            AC064_1 = 0;
            AC064_2 = 0;
            AC064_3 = 0;
            AC065_1 = 0;
            AC066_1 = 0;
            AC066_2 = 0;
            AC066_3 = 0;
            AC070_1 = 0;
            AC070_2 = 0;
            AC070_3 = 0;
            AC080_1 = 0;
            AC080_2 = 0;
            AC080_3 = 0;
            AC090_1 = 0;
            AC090_2 = 0;
            AC090_3 = 0;
        }
        public void setApplicationsInProcess(Decimal amount, Decimal count) {
            this.AC010_1 = amount; this.AC010_2 = count; this.AC010_3 = Math.roundToLong(amount / count);
        }
        public void setApplicationsRecieved(Decimal amount, Decimal count) {
            this.AC020_1 = amount; this.AC020_2 = count; this.AC020_3 = Math.roundToLong(amount / count);
        }
        public void setApplicationsApprovedButNotAccepted(Decimal amount, Decimal count) {
            this.AC030_1 = amount; this.AC030_2 = count; this.AC030_3 = Math.roundToLong(amount / count);
        }
        public void setApplicationsDenied(Decimal Amount, Decimal count) {
            this.AC040_1 = amount; this.AC040_2 = count; this.AC040_3 = Math.roundToLong(amount / count);
        }
        public void setApplicationsWithdrawn(Decimal amount, Decimal count) {
            this.AC050_1 = amount;this.AC050_2 = count; this.AC050_3 = Math.roundToLong(amount / count);
        }
        public void setFileClosedForIncompleteness(Decimal amount, Decimal count) {
            this.AC060_1 = amount;this.AC060_2 = count; this.AC060_3 = Math.roundToLong(amount / count);
        }
        public void setPreapprovalRequestsDenied(Decimal amount, Decimal count) {
            this.AC062_1 = amount;this.AC062_2 = count; this.AC062_3 = Math.roundToLong(amount / count);
        }
        public void setPreapprovalRequestsApprovedNotAccepted(Decimal amount, Decimal count) {
            this.AC064_1 = amount;this.AC064_2 = count; this.AC064_3 = Math.roundToLong(amount / count);
        }
        public void setNetChangesInApplicationAmount(Decimal amount) {
            this.AC065_1 = amount;
        }
        public void setLoansClosedAndFunded(Decimal amount, Decimal count) {
            this.AC070_1 = amount;this.AC070_2 = count;  this.AC070_3 = Math.roundToLong(amount / count);
        }
        public void setApplicationsInProcessAtEnd(Decimal amount, Decimal count) {
            this.AC080_1 = amount;this.AC080_2 = count;  this.AC080_3 = Math.roundToLong(amount / count);
        }

        //AC066
        public void setTotalRowApplicationPipeline() {
            Decimal amount = this.AC010_1 + this.AC020_1 - this.AC030_1 - this.AC040_1 - this.AC050_1 - this.AC060_1 - this.AC062_1 - this.AC064_1 + this.AC065_1;
            Decimal count = this.AC010_2 + this.AC020_2 - this.AC030_2 - this.AC040_2 - this.AC050_2 - this.AC060_2 - this.AC062_2 - this.AC064_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC066_1 = amount;
            this.AC066_2 = count;
            this.AC066_3 = average;
        }

        //AC090
        public void setTotalRowApplicationPipelineResults() {
            Decimal amount = this.AC070_1 + this.AC080_1;
            Decimal count = this.AC070_2 + this.AC080_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC090_1 = amount;
            this.AC090_2 = count;
            this.AC090_3 = average;
        }

        // public void setApplicationsInProcess(Decimal amount, Decimal count){this.AC080_1=amount; this.AC080_2=count;}
    }
    public class ClosedLoanDataModel {
        @AuraEnabled
        public Decimal
                AC100_1, AC100_2, AC100_SUM_1_2,
                AC100_3, AC100_4, AC100_SUM_3_4,
                AC110_1, AC110_2, AC110_SUM_1_2,
                AC110_3, AC110_4, AC110_SUM_3_4,
                AC120_1, AC120_2, AC120_SUM_1_2,
                AC120_3, AC120_4, AC120_SUM_3_4,
                AC130_1, AC130_2, AC130_SUM_1_2,
                AC130_3, AC130_4, AC130_SUM_3_4,
                AC190_1, AC190_2, AC190_SUM_1_2,
                AC190_3, AC190_4, AC190_SUM_3_4,
                AC200_1, AC200_2, AC200_SUM_1_2,
                AC200_3, AC200_4, AC200_SUM_3_4,
                AC210_1, AC210_2, AC210_SUM_1_2,
                AC210_3, AC210_4, AC210_SUM_3_4,
                AC220_1, AC220_2, AC220_SUM_1_2,
                AC220_3, AC220_4, AC220_SUM_3_4,
                AC290_1, AC290_2, AC290_SUM_1_2,
                AC290_3, AC290_4, AC290_SUM_3_4,
                AC300_1, AC300_2, AC300_SUM_1_2,
                AC300_3, AC300_4, AC300_SUM_3_4,
                AC310_1, AC310_2, AC310_SUM_1_2,
                AC310_3, AC310_4, AC310_SUM_3_4,
                AC320_1, AC320_2, AC320_SUM_1_2,
                AC320_3, AC320_4, AC320_SUM_3_4,
                AC390_1, AC390_2, AC390_SUM_1_2,
                AC390_3, AC390_4, AC390_SUM_3_4,
                AC400_1, AC400_2, AC400_SUM_1_2,
                AC400_3, AC400_4, AC400_SUM_3_4,
                AC500_1, AC500_2, AC500_SUM_1_2,
                AC500_3, AC500_4, AC500_SUM_3_4,
                AC510_1, AC510_2, AC510_SUM_1_2,
                AC510_3, AC510_4, AC510_SUM_3_4,
                AC520_1, AC520_2, AC520_SUM_1_2,
                AC520_3, AC520_4, AC520_SUM_3_4,
                AC590_1, AC590_2, AC590_SUM_1_2,
                AC590_3, AC590_4, AC590_SUM_3_4,
                AC600_1,
                AC610_1,
                AC620_1,
                AC630_1,
                AC700_1, AC700_2, AC700_SUM_1_2,
                AC700_3, AC700_4, AC700_SUM_3_4,
                AC710_1, AC710_2, AC710_SUM_1_2,
                AC710_3, AC710_4, AC710_SUM_3_4,
                AC720_1, AC720_2, AC720_SUM_1_2,
                AC720_3, AC720_4, AC720_SUM_3_4,
                AC790_1, AC790_2, AC790_SUM_1_2,
                AC790_3, AC790_4, AC790_SUM_3_4,
                AC800_1, AC800_2, AC800_SUM_1_2,
                AC800_3, AC800_4, AC800_SUM_3_4,
                AC810_1, AC810_2, AC810_SUM_1_2,
                AC810_3, AC810_4, AC810_SUM_3_4,
                AC890_1, AC890_2, AC890_SUM_1_2,
                AC890_3, AC890_4, AC890_SUM_3_4,
                AC900_2,
                AC910_2,
                AC920_1, AC920_2, AC920_SUM_1_2,
                AC920_3, AC920_4, AC920_SUM_3_4,
                AC930_1, AC930_2, AC930_SUM_1_2,
                AC930_3, AC930_4, AC930_SUM_3_4,
                AC940_1, AC940_2, AC940_SUM_1_2,
                AC940_3, AC940_4, AC940_SUM_3_4,
                AC990_1, AC990_2, AC990_SUM_1_2,
                AC990_3, AC990_4, AC990_SUM_3_4,
                AC1000_1, AC1000_2;
        public ClosedLoanDataModel() {
            AC100_1 = 0;
            AC100_2 = 0;
            AC100_SUM_1_2 = 0;
            AC100_3 = 0;
            AC100_4 = 0;
            AC100_SUM_3_4 = 0;
            AC110_1 = 0;
            AC110_2 = 0;
            AC110_SUM_1_2 = 0;
            AC110_3 = 0;
            AC110_4 = 0;
            AC110_SUM_3_4 = 0;
            AC120_1 = 0;
            AC120_2 = 0;
            AC120_SUM_1_2 = 0;
            AC120_3 = 0;
            AC120_4 = 0;
            AC120_SUM_3_4 = 0;
            AC130_1 = 0;
            AC130_2 = 0;
            AC130_SUM_1_2 = 0;
            AC130_3 = 0;
            AC130_4 = 0;
            AC130_SUM_3_4 = 0;
            AC190_1 = 0;
            AC190_2 = 0;
            AC190_SUM_1_2 = 0;
            AC190_3 = 0;
            AC190_4 = 0;
            AC190_SUM_3_4 = 0;
            AC200_1 = 0;
            AC200_2 = 0;
            AC200_SUM_1_2 = 0;
            AC200_3 = 0;
            AC200_4 = 0;
            AC200_SUM_3_4 = 0;
            AC210_1 = 0;
            AC210_2 = 0;
            AC210_SUM_1_2 = 0;
            AC210_3 = 0;
            AC210_4 = 0;
            AC210_SUM_3_4 = 0;
            AC220_1 = 0;
            AC220_2 = 0;
            AC220_SUM_1_2 = 0;
            AC220_3 = 0;
            AC220_4 = 0;
            AC220_SUM_3_4 = 0;
            AC290_1 = 0;
            AC290_2 = 0;
            AC290_SUM_1_2 = 0;
            AC290_3 = 0;
            AC290_4 = 0;
            AC290_SUM_3_4 = 0;
            AC300_1 = 0;
            AC300_2 = 0;
            AC300_SUM_1_2 = 0;
            AC300_3 = 0;
            AC300_4 = 0;
            AC300_SUM_3_4 = 0;
            AC310_1 = 0;
            AC310_2 = 0;
            AC310_SUM_1_2 = 0;
            AC310_3 = 0;
            AC310_4 = 0;
            AC310_SUM_3_4 = 0;
            AC320_1 = 0;
            AC320_2 = 0;
            AC320_SUM_1_2 = 0;
            AC320_3 = 0;
            AC320_4 = 0;
            AC320_SUM_3_4 = 0;
            AC390_1 = 0;
            AC390_2 = 0;
            AC390_SUM_1_2 = 0;
            AC390_3 = 0;
            AC390_4 = 0;
            AC390_SUM_3_4 = 0;
            AC400_1 = 0;
            AC400_2 = 0;
            AC400_SUM_1_2 = 0;
            AC400_3 = 0;
            AC400_4 = 0;
            AC400_SUM_3_4 = 0;
            AC500_1 = 0;
            AC500_2 = 0;
            AC500_SUM_1_2 = 0;
            AC500_3 = 0;
            AC500_4 = 0;
            AC500_SUM_3_4 = 0;
            AC510_1 = 0;
            AC510_2 = 0;
            AC510_SUM_1_2 = 0;
            AC510_3 = 0;
            AC510_4 = 0;
            AC510_SUM_3_4 = 0;
            AC520_1 = 0;
            AC520_2 = 0;
            AC520_SUM_1_2 = 0;
            AC520_3 = 0;
            AC520_4 = 0;
            AC520_SUM_3_4 = 0;
            AC590_1 = 0;
            AC590_2 = 0;
            AC590_SUM_1_2 = 0;
            AC590_3 = 0;
            AC590_4 = 0;
            AC590_SUM_3_4 = 0;
            AC600_1 = 0;
            AC610_1 = 0;
            AC700_1 = 0;
            AC700_2 = 0;
            AC700_SUM_1_2 = 0;
            AC700_3 = 0;
            AC700_4 = 0;
            AC700_SUM_3_4 = 0;
            AC710_1 = 0;
            AC710_2 = 0;
            AC710_SUM_1_2 = 0;
            AC710_3 = 0;
            AC710_4 = 0;
            AC710_SUM_3_4 = 0;
            AC720_1 = 0;
            AC720_2 = 0;
            AC720_SUM_1_2= 0;
            AC720_3 = 0;
            AC720_4 = 0;
            AC720_SUM_3_4= 0;
            AC790_1 = 0;
            AC790_2 = 0;
            AC790_SUM_1_2 = 0;
            AC790_3 = 0;
            AC790_4 = 0;
            AC790_SUM_3_4 = 0;
            AC800_1 = 0;
            AC800_2 = 0;
            AC800_SUM_1_2 = 0;
            AC800_3 = 0;
            AC800_4 = 0;
            AC800_SUM_3_4 = 0;
            AC810_1 = 0;
            AC810_2 = 0;
            AC810_SUM_1_2 = 0;
            AC810_3 = 0;
            AC810_4 = 0;
            AC810_SUM_3_4 = 0;
            AC890_1 = 0;
            AC890_2 = 0;
            AC890_SUM_1_2 = 0;
            AC890_3 = 0;
            AC890_4 = 0;
            AC890_SUM_3_4 = 0;
            AC620_1 = 0;
            AC630_1 = 0;
            AC900_2 = 0;
            AC910_2 = 0;
            AC920_1 = 0;
            AC920_2 = 0;
            AC920_SUM_1_2 = 0;
            AC920_3 = 0;
            AC920_4 = 0;
            AC920_SUM_3_4 = 0;
            AC930_1 = 0;
            AC930_2 = 0;
            AC930_SUM_1_2 = 0;
            AC930_3 = 0;
            AC930_4 = 0;
            AC930_SUM_3_4 = 0;
            AC940_1 = 0;
            AC940_2 = 0;
            AC940_SUM_1_2 = 0;
            AC940_3 = 0;
            AC940_4 = 0;
            AC940_SUM_3_4 = 0;
            AC990_1 = 0;
            AC990_2 = 0;
            AC990_SUM_1_2 = 0;
            AC990_3 = 0;
            AC990_4 = 0;
            AC990_SUM_3_4 = 0;
            AC1000_1 = 0;
            AC1000_2 = 0;
        }
        public void setConventional(Decimal amount, Decimal count) {
            this.AC100_1 = amount; this.AC100_2 = count; this.AC100_SUM_1_2 = amount / count;
        }
        public void setConventionalForCorrespondent(Decimal amount, Decimal count) {
            this.AC100_3 = amount; this.AC100_4 = count; this.AC100_SUM_3_4 = amount / count;
        }
        public void setFHA(Decimal amount, Decimal count) {
            this.AC110_1 = amount; this.AC110_2 = count; this.AC110_SUM_1_2 = amount / count;
        }
        public void setFHAForCorrespondent(Decimal amount, Decimal count) {
            this.AC110_3 = amount; this.AC110_4 = count; this.AC110_SUM_3_4 = amount / count;
        }
        public void setVA(Decimal amount, Decimal count) {
            this.AC120_1 = amount;this.AC120_2 = count; this.AC120_SUM_1_2 = amount / count;
        }
        public void setVAForCorrespondent(Decimal amount, Decimal count) {
            this.AC120_3 = amount;this.AC120_4 = count; this.AC120_SUM_3_4 = amount / count;
        }
        public void setFsaRsaGuarunteed(Decimal amount, Decimal count) {
            this.AC130_1 = amount;this.AC130_2 = count; this.AC130_SUM_1_2 = amount / count;
        }
        public void setFsaRsaGuarunteedForCorrespondent(Decimal amount, Decimal count) {
            this.AC130_3 = amount;this.AC130_4 = count; this.AC130_SUM_3_4 = amount / count;
        }
        public void setOneToFourDwelling(Decimal amount, Decimal count) {
            this.AC200_1 = amount;this.AC200_2 = count; this.AC200_SUM_1_2 = amount / count;
        }
        public void setOneToFourDwellingForCorrespondent(Decimal amount, Decimal count) {
            this.AC200_3 = amount;this.AC200_4 = count; this.AC200_SUM_3_4 = amount / count;
        }
        public void setManufacturedHousing(Decimal amount, Decimal count) {
            this.AC210_1 = amount;this.AC210_2 = count; this.AC210_SUM_1_2 = amount / count;
        }
        public void setManufacturedHousingForCorrespondent(Decimal amount, Decimal count) {
            this.AC210_3 = amount;this.AC210_4 = count; this.AC210_SUM_3_4 = amount / count;
        }
        public void setMultifamilyDwelling(Decimal amount, Decimal count) {
            this.AC220_1 = amount;this.AC220_2 = count; this.AC220_SUM_1_2 = amount / count;
        }
        public void setMultifamilyDwellingForCorrespondent(Decimal amount, Decimal count) {
            this.AC220_3 = amount;this.AC220_4 = count; this.AC220_SUM_3_4 = amount / count;
        }
        public void setHomePurchase(Decimal amount, Decimal count) {
            this.AC300_1 = amount;this.AC300_2 = count; this.AC300_SUM_1_2 = amount / count;
        }
        public void setHomePurchaseForCorrespondent(Decimal amount, Decimal count) {
            this.AC300_3 = amount;this.AC300_4 = count; this.AC300_SUM_3_4 = amount / count;
        }
        public void setHomeImprovement(Decimal amount, Decimal count) {
            this.AC310_1 = amount;this.AC310_2 = count; this.AC310_SUM_1_2 = amount / count;
        }
        public void setHomeImprovementForCorrespondent(Decimal amount, Decimal count) {
            this.AC310_3 = amount;this.AC310_4 = count; this.AC310_SUM_3_4 = amount / count;
        }
        public void setRefinancing(Decimal amount, Decimal count) {
            this.AC320_1 = amount;this.AC320_2 = count; this.AC320_SUM_1_2 = amount / count;
        }
        public void setRefinancingForCorrespondent(Decimal amount, Decimal count) {
            this.AC320_3 = amount;this.AC320_4 = count; this.AC320_SUM_3_4 = amount / count;
        }
//        public void setHOEPA(Decimal amount, Decimal count) {
//            this.AC400_1 = amount;this.AC400_2 = count; this.AC400_3 = amount / count;
//        }
        public void setFirstLien(Decimal amount, Decimal count) {
            this.AC500_1 = amount;this.AC500_2 = count; this.AC500_SUM_1_2 = amount / count;
        }
        public void setFirstLienForCorrespondent(Decimal amount, Decimal count) {
            this.AC500_3 = amount;this.AC500_4 = count; this.AC500_SUM_3_4 = amount / count;
        }
        public void setSubordinate(Decimal amount, Decimal count) {
            this.AC510_1 = amount;this.AC510_2 = count; this.AC510_SUM_1_2 = amount / count;
        }
        public void setSubordinateForCorrespondent(Decimal amount, Decimal count) {
            this.AC510_3 = amount;this.AC510_4 = count; this.AC510_SUM_3_4 = amount / count;
        }
        public void setNotSecured(Decimal amount, Decimal count) {
            this.AC520_1 = amount;this.AC520_2 = count; this.AC520_SUM_1_2 = amount / count;
        }
        public void setNotSecuredForCorrespondent(Decimal amount, Decimal count) {
            this.AC520_3 = amount;this.AC520_4 = count; this.AC520_SUM_3_4 = amount / count;
        }
        public void setBrokerFeesCollected(Decimal amount) {
            this.AC600_1 = amount;
        }
        public void setLenderFeesCollected(Decimal amount) {
            this.AC610_1 = amount;
        }
//        public void setHecmStandard(Decimal amount, Decimal count) {
//            this.AC700_1 = amount;this.AC700_2 = count; this.AC700_3 = amount / count;
//        }
//        public void setHecmSaver(Decimal amount, Decimal count) {
//            this.AC710_1 = amount; this.AC710_2 = count; this.AC710_3 = amount / count;
//        }
//        public void setProprietary(Decimal amount, Decimal count) {
//            this.AC720_1 = amount;this.AC720_2 = count; this.AC720_3 = amount / count;
//        }
//        public void setReverseHomePurchase(Decimal amount, Decimal count) {
//            this.AC800_1 = amount; this.AC800_2 = count; this.AC800_3 = amount / count;
//        }
//        public void setReverseOther(Decimal amount, Decimal count) {
//            this.AC810_1 = amount;this.AC810_2 = count; this.AC810_3 = amount / count;
//        }

//        public void setReverseBrokerFeesCollected(Decimal amount) {
//            this.AC620_1 = amount;
//        }
        public void setTotalLoansBrokeredByCompany(Decimal count) {
            this.AC900_2 = count;
        }
        public void setTotalLoansFundedByCompany(Decimal count) {
            this.AC910_2 = count;
        }
        public void setQualifiedMortgage(Decimal amount, Decimal count) {
            this.AC920_1 = amount; this.AC920_2 = count;this.AC920_SUM_1_2 = amount / count;
        }
        public void setQualifiedMortgageForCorrespondent(Decimal amount, Decimal count) {
            this.AC920_3 = amount; this.AC920_4 = count;this.AC920_SUM_3_4 = amount / count;
        }
        public void setNonQualifiedMortgage(Decimal amount, Decimal count) {
            this.AC930_1 = amount; this.AC930_2 = count;this.AC930_SUM_1_2 = amount / count;
        }
        public void setNonQualifiedMortgageForCorrespondent(Decimal amount, Decimal count) {
            this.AC930_3 = amount; this.AC930_4 = count;this.AC930_SUM_3_4 = amount / count;
        }
//        public void setNotSubjectToQualifiedMortgage(Decimal amount, Decimal count) {
//            this.AC940_1 = amount;this.AC940_2 = count;this.AC940_3 = amount / count;
//        }
//        public void setLoansMadeAndAssigned(Decimal amount, Decimal count) {
//            this.AC1000_1 = amount;this.AC1000_2 = count;
//        }

        //AC190
        public void setTotalRowLoanTypeForwardMortgages() {
            Decimal amount = this.AC100_1 + this.AC110_1 + this.AC120_1 + this.AC130_1;
            Decimal count = this.AC100_2 + this.AC110_2 + this.AC120_2 + this.AC130_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC190_1 = amount;
            this.AC190_2 = count;
            this.AC190_SUM_1_2 = average;
        }

        //AC190 Correspondent
        public void setTotalRowLoanTypeForwardMortgagesForCorrespondent() {
            Decimal amount = this.AC100_3 + this.AC110_3 + this.AC120_3 + this.AC130_3;
            Decimal count = this.AC100_4 + this.AC110_4 + this.AC120_4 + this.AC130_4;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC190_3 = amount;
            this.AC190_4 = count;
            this.AC190_SUM_3_4 = average;
        }

        //AC290
        public void setTotalRowPropertyTypeForwardMortgage() {
            Decimal amount = this.AC200_1 + this.AC210_1 + this.AC220_1;
            Decimal count = this.AC200_2 + this.AC210_2 + this.AC220_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC290_1 = amount;
            this.AC290_2 = count;
            this.AC290_SUM_1_2 = average;
        }
        //AC290 Correspondent
        public void setTotalRowPropertyTypeForwardMortgageForCorrespondent() {
            Decimal amount = this.AC200_3 + this.AC210_3 + this.AC220_3;
            Decimal count = this.AC200_4 + this.AC210_4 + this.AC220_4;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC290_3 = amount;
            this.AC290_4 = count;
            this.AC290_SUM_3_4 = average;
        }

        //AC390
        public void setTotalRowPurposeForwardMortgage() {
            Decimal amount = this.AC300_1 + this.AC310_1 + this.AC320_1;
            Decimal count = this.AC300_2 + this.AC310_2 + this.AC320_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC390_1 = amount;
            this.AC390_2 = count;
            this.AC390_SUM_1_2 = average;
        }
        //AC390 Correspondent
        public void setTotalRowPurposeForwardMortgageForCorrespondent() {
            Decimal amount = this.AC300_3 + this.AC310_3 + this.AC320_3;
            Decimal count = this.AC300_4 + this.AC310_4 + this.AC320_4;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC390_3 = amount;
            this.AC390_4 = count;
            this.AC390_SUM_3_4 = average;
        }

        //AC590
        public void setTotalRowLienStatusForwardMortgage() {
            Decimal amount = this.AC500_1 + this.AC510_1 + this.AC520_1;
            Decimal count = this.AC500_2 + this.AC510_2 + this.AC520_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC590_1 = amount;
            this.AC590_2 = count;
            this.AC590_SUM_1_2 = average;
        }

        //AC590 Correspondent
        public void setTotalRowLienStatusForwardMortgageForCorrespondent() {
            Decimal amount = this.AC500_3 + this.AC510_3 + this.AC520_3;
            Decimal count = this.AC500_4 + this.AC510_4 + this.AC520_4;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC590_3 = amount;
            this.AC590_4 = count;
            this.AC590_SUM_3_4 = average;
        }

        //AC790
//        public void setTotalRowLoanTypeReverseMortgage() {
//            Decimal amount = this.AC700_1 + this.AC710_1 + this.AC720_1;
//            Decimal count = this.AC700_2 + this.AC710_2 + this.AC720_2;
//            Decimal average = count == 0 ? 0 : amount/count;
//
//            this.AC790_1 = amount;
//            this.AC790_2 = count;
//            this.AC790_3 = average;
//        }

        //AC890
//        public void setTotalRowPurposeReverseMortgage() {
//            Decimal amount = this.AC800_1 + this.AC810_1;
//            Decimal count = this.AC800_2 + this.AC810_2;
//            Decimal average = count == 0 ? 0 : amount/count;
//
//            this.AC890_1 = amount;
//            this.AC890_2 = count;
//            this.AC890_3 = average;
//        }

        //AC990
        public void setTotalRowQM_NonQM() {
            Decimal amount = this.AC920_1 + this.AC930_1 + this.AC940_1;
            Decimal count = this.AC920_2 + this.AC930_2 + this.AC940_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC990_1 = amount;
            this.AC990_2 = count;
            this.AC990_SUM_1_2 = average;
        }
        //AC990
        public void setTotalRowQM_NonQMForCorrespondent() {
            Decimal amount = this.AC920_3 + this.AC930_3 + this.AC940_3;
            Decimal count = this.AC920_4 + this.AC930_4 + this.AC940_4;
            Decimal average = count == 0 ? 0 : amount/count;

            this.AC990_3 = amount;
            this.AC990_4 = count;
            this.AC990_SUM_3_4 = average;
        }
    }
    public class ResidentialFirstMortgagesModel {
        @AuraEnabled
        public Decimal
                I010_1, I010_2, I010_3,
                I020_1, I020_2, I020_3,
                I030_1, I030_2, I030_3,
                I040_1, I040_2, I040_3,
                I050_1, I050_2, I050_3,
                I060_1, I060_2, I060_3,
                I070_1, I070_2, I070_3,
                I080_1, I080_2, I080_3,
                I100_1, I100_2, I100_3,
                I110_1, I110_2, I110_3,
                I120_1, I120_2, I120_3,
                I130_1, I130_2, I130_3,
                I140_1, I140_2, I140_3,
                I170_1, I170_2, I170_3,
                I180_1, I180_2, I180_3,
                I200_1, I200_2, I200_3,
                I210_1, I210_2, I210_3,
                I220_1, I220_2, I220_3,
                I230_1, I230_2, I230_3,
                I240_1, I240_2, I240_3,
                I250_1, I250_2, I250_3,
                I251_1, I251_2, I251_3,
                I259_1, I259_2, I259_3,
                I260_1, I260_2, I260_3,
                I261_1, I261_2, I261_3,
                I269_1, I269_2, I269_3,
                I270_1, I270_2, I270_3,
                I271_1, I271_2, I271_3,
                I279_1, I279_2, I279_3,
                I280_1, I280_2, I280_3,
                I281_1, I281_2, I281_3,
                I289_1, I289_2, I289_3,
                I290_1, I290_2, I290_3,
                I291_1, I291_2, I291_3,
                I299_1, I299_2, I299_3,
                I300_1, I300_2, I300_3,
                I301_1, I301_2, I301_3,
                I309_1, I309_2, I309_3,
                I310_1, I310_2, I310_3,
                I311_1, I311_2, I311_3,
                I312_1, I312_2, I312_3,
                I313_1, I313_2, I313_3,
                I314_1, I314_2, I314_3,
                I319_1, I319_2, I319_3,
                I330_1, I330_2, I330_3,
                I331_1, I331_2, I331_3,
                I339_1, I339_2, I339_3,
                I340_1, I340_2, I340_3,
                I341_1, I341_2, I341_3,
                I349_1, I349_2, I349_3,
                I370_1, I370_2, I370_3,
                I371_1, I371_2, I371_3,
                I372_1, I372_2, I372_3,
                I373_1, I373_2, I373_3,
                I374_1, I374_2, I374_3,
                I375_1, I375_2, I375_3,
                I379_1, I379_2, I379_3,
                I380_2,
                I385_2,
                I390_2,
                I400_1, I400_2, I400_3,
                I401_1, I401_2, I401_3,
                I402_1, I402_2, I402_3,
                I404_1, I404_2, I404_3,
                I405_1, I405_2, I405_3,
                I409_1, I409_2, I409_3,
                I410_1, I410_2, I410_3,
                I421_1, I421_2, I421_3,
                I430_2,
                I450_2,
                I460_1, I460_2, I460_3;


        public ResidentialFirstMortgagesModel() {
            I010_1 = 0;
            I010_2 = 0;
            I010_3 = 0;
            I020_1 = 0;
            I020_2 = 0;
            I020_3 = 0;
            I030_1 = 0;
            I030_2 = 0;
            I030_3 = 0;
            I040_1 = 0;
            I040_2 = 0;
            I040_3 = 0;
            I050_1 = 0;
            I050_2 = 0;
            I050_3 = 0;
            I060_1 = 0;
            I060_2 = 0;
            I060_3 = 0;
            I070_1 = 0;
            I070_2 = 0;
            I070_3 = 0;
            I080_1 = 0;
            I080_2 = 0;
            I080_3 = 0;
            I100_1 = 0;
            I100_2 = 0;
            I100_3 = 0;
            I110_1 = 0;
            I110_2 = 0;
            I110_3 = 0;
            I120_1 = 0;
            I120_2 = 0;
            I120_3 = 0;
            I130_1 = 0;
            I130_2 = 0;
            I130_3 = 0;
            I140_1 = 0;
            I140_2 = 0;
            I140_3 = 0;
            I170_1 = 0;
            I170_2 = 0;
            I170_3 = 0;
            I180_1 = 0;
            I180_2 = 0;
            I180_3 = 0;
            I200_1 = 0;
            I200_2 = 0;
            I200_3 = 0;
            I210_1 = 0;
            I210_2 = 0;
            I210_3 = 0;
            I220_1 = 0;
            I220_2 = 0;
            I220_3 = 0;
            I230_1 = 0;
            I230_2 = 0;
            I230_3 = 0;
            I240_1 = 0;
            I240_2 = 0;
            I240_3 = 0;
            I250_1 = 0;
            I250_2 = 0;
            I250_3 = 0;
            I251_1 = 0;
            I251_2 = 0;
            I251_3 = 0;
            I259_1 = 0;
            I259_2 = 0;
            I259_3 = 0;
            I260_1 = 0;
            I260_2 = 0;
            I260_3 = 0;
            I261_1 = 0;
            I261_2 = 0;
            I261_3 = 0;
            I269_1 = 0;
            I269_2 = 0;
            I269_3 = 0;
            I270_1 = 0;
            I270_2 = 0;
            I270_3 = 0;
            I271_1 = 0;
            I271_2 = 0;
            I271_3 = 0;
            I279_1 = 0;
            I279_2 = 0;
            I279_3 = 0;
            I280_1 = 0;
            I280_2 = 0;
            I280_3 = 0;
            I281_1 = 0;
            I281_2 = 0;
            I281_3 = 0;
            I289_1 = 0;
            I289_2 = 0;
            I289_3 = 0;
            I290_1 = 0;
            I290_2 = 0;
            I290_3 = 0;
            I291_1 = 0;
            I291_2 = 0;
            I291_3 = 0;
            I299_1 = 0;
            I299_2 = 0;
            I299_3 = 0;
            I300_1 = 0;
            I300_2 = 0;
            I300_3 = 0;
            I301_1 = 0;
            I301_2 = 0;
            I301_3 = 0;
            I309_1 = 0;
            I309_2 = 0;
            I309_3 = 0;
            I310_1 = 0;
            I310_2 = 0;
            I310_3 = 0;
            I311_1 = 0;
            I311_2 = 0;
            I311_3 = 0;
            I312_1 = 0;
            I312_2 = 0;
            I312_3 = 0;
            I313_1 = 0;
            I313_2 = 0;
            I313_3 = 0;
            I314_1 = 0;
            I314_2 = 0;
            I314_3 = 0;
            I319_1 = 0;
            I319_2 = 0;
            I319_3 = 0;
            I330_1 = 0;
            I330_2 = 0;
            I330_3 = 0;
            I331_1 = 0;
            I331_2 = 0;
            I331_3 = 0;
            I339_1 = 0;
            I339_2 = 0;
            I339_3 = 0;
            I340_1 = 0;
            I340_2 = 0;
            I340_3 = 0;
            I341_1 = 0;
            I341_2 = 0;
            I341_3 = 0;
            I349_1 = 0;
            I349_2 = 0;
            I349_3 = 0;
            I370_1 = 0;
            I370_2 = 0;
            I370_3 = 0;
            I371_1 = 0;
            I371_2 = 0;
            I371_3 = 0;
            I372_1 = 0;
            I372_2 = 0;
            I372_3 = 0;
            I373_1 = 0;
            I373_2 = 0;
            I373_3 = 0;
            I374_1 = 0;
            I374_2 = 0;
            I374_3 = 0;
            I375_1 = 0;
            I375_2 = 0;
            I375_3 = 0;
            I379_1 = 0;
            I379_2 = 0;
            I379_3 = 0;
            I380_2 = 0;
            I385_2 = 0;
            I390_2 = 0;
            I400_1 = 0;
            I400_2 = 0;
            I400_3 = 0;
            I401_1 = 0;
            I401_2 = 0;
            I401_3 = 0;
            I402_1 = 0;
            I402_2 = 0;
            I402_3 = 0;
            I404_1 = 0;
            I404_2 = 0;
            I404_3 = 0;
            I405_1 = 0;
            I405_2 = 0;
            I405_3 = 0;
            I409_1 = 0;
            I409_2 = 0;
            I409_3 = 0;
            I410_1 = 0;
            I410_2 = 0;
            I410_3 = 0;
            I421_1 = 0;
            I421_2 = 0;
            I421_3 = 0;
            I430_2 = 0;
            I450_2 = 3;
            I460_1 = 0;
            I460_2 = 0;
            I460_3 = 0;
        }
        public void setGovernmentFixed(Decimal amount, Decimal count) {
            System.debug('Calculating I010 (Government Fixed)');
			System.debug(amount);
            System.debug(count);
            this.I010_1 = amount;this.I010_2 = count;this.I010_3 = amount / count;
            System.debug(this.I010_1);
            System.debug(this.I010_2);
            System.debug(this.I010_3);
        }
        public void setGovernmentARM(Decimal amount, Decimal count) {
            this.I020_1 = amount; this.I020_2 = count; this.I020_3 = amount / count;
        }
        public void setConventionalConformingFixed(Decimal amount, Decimal count) {
            this.I030_1 = amount; this.I030_2 = count; this.I030_3 = amount / count;
        }
        public void setConventionalConformingARM(Decimal amount, Decimal count) {
            this.I040_1 = amount; this.I040_2 = count; this.I040_3 = amount / count;
        }
        public void setConventionalNonConformingFixed(Decimal amount, Decimal count) {
            this.I050_1 = amount; this.I050_2 = count; this.I050_3 = amount / count;
        }
        public void setConventionalNonConformingARM(Decimal amount, Decimal count) {
            this.I060_1 = amount; this.I060_2 = count; this.I060_3 = amount / count;
        }
        public void setOtherFixed(Decimal amount, Decimal count) {
            this.I070_1 = amount; this.I070_2 = count; this.I070_3 = amount / count;
        }
        public void setOtherARM(Decimal amount, Decimal count) {
            this.I080_1 = amount; this.I080_2 = count; this.I080_3 = amount / count;
        }
        public void setClosedEndSecondMortgages(Decimal amount, Decimal count) {
            this.I110_1 = amount; this.I110_2 = count; this.I110_3 = amount / count;
        }
        public void setHELOCs(Decimal amount, Decimal count) {
            this.I120_1 = amount; this.I120_2 = count; this.I120_3 = amount / count;
        }
        public void setReverse(Decimal amount, Decimal count) {
            this.I130_1 = amount; this.I130_2 = count; this.I130_3 = amount / count;
        }
        public void setConstruction(Decimal amount, Decimal count) {
            this.I140_1 = amount; this.I140_2 = count; this.I140_3 = amount / count;
        }
        public void setOtherResidential(Decimal amount, Decimal count) {
            this.I170_1 = amount; this.I170_2 = count; this.I170_3 = amount / count;
        }
        public void setRetail(Decimal amount, Decimal count) {
            this.I210_1 = amount; this.I210_2 = count; this.I210_3 = amount / count;
        }
        public void setTableFunded(Decimal amount, Decimal count) {
            this.I220_1 = amount; this.I220_2 = count; this.I220_3 = amount / count;
        }
        public void setWholesalesBrokered(Decimal amount, Decimal count) {
            this.I230_1 = amount; this.I230_2 = count; this.I230_3 = amount / count;
        }
        public void setFixedRate(Decimal amount, Decimal count) {
            this.I250_1 = amount; this.I250_2 = count; this.I250_3 = amount / count;
        }
        public void setARM(Decimal amount, Decimal count) {
            this.I251_1 = amount; this.I251_2 = count; this.I251_3 = amount / count;
        }
        public void setJumbo(Decimal amount, Decimal count) {
            this.I260_1 = amount; this.I260_2 = count; this.I260_3 = amount / count;
        }
        public void setNonJumbo(Decimal amount, Decimal count) {
            this.I261_1 = amount; this.I261_2 = count; this.I261_3 = amount / count;
        }
        public void setAltDoc(Decimal amount, Decimal count) {
            this.I270_1 = amount; this.I270_2 = count; this.I270_3 = amount / count;
        }
        public void setFullDoc(Decimal amount, Decimal count) {
            this.I271_1 = amount; this.I271_2 = count; this.I271_3 = amount / count;
        }
        public void setInterestOnly(Decimal amount, Decimal count) {
            this.I280_1 = amount; this.I280_2 = count; this.I280_3 = amount / count;
        }
        public void setNotInterestOnly(Decimal amount, Decimal count) {
            this.I281_1 = amount; this.I281_2 = count; this.I281_3 = amount / count;
        }
        public void setOptionARMs(Decimal amount, Decimal count) {
            this.I290_1 = amount; this.I290_2 = count; this.I290_3 = amount / count;
        }
        public void setNotOptionARMs(Decimal amount, Decimal count) {
            this.I291_1 = amount; this.I291_2 = count; this.I291_3 = amount / count;
        }
        public void setLoansWithPrepaymentPenalties(Decimal amount, Decimal count) {
            this.I300_1 = amount; this.I300_2 = count; this.I300_3 = amount / count;
        }
        public void setLoansWithoutPrepaymentPenalties(Decimal amount, Decimal count) {
            this.I301_1 = amount; this.I301_2 = count; this.I301_3 = amount / count;
        }
        public void setPurchase(Decimal amount, Decimal count) {
            this.I310_1 = amount; this.I310_2 = count; this.I310_3 = amount / count;
        }
        public void setRefinanceRateTerm(Decimal amount, Decimal count) {
            this.I311_1 = amount; this.I311_2 = count; this.I311_3 = amount / count;
        }
        public void setCashOutRefinance(Decimal amount, Decimal count) {
            this.I312_1 = amount; this.I312_2 = count; this.I312_3 = amount / count;
        }
        public void setRefinanceRestructure(Decimal amount, Decimal count) {
            this.I313_1 = amount; this.I313_2 = count; this.I313_3 = amount / count;
        }
        public void setRefinanceOtherUnknown(Decimal amount, Decimal count) {
            this.I314_1 = amount; this.I314_2 = count; this.I314_3 = amount / count;
        }
        public void setLoansWithMortgageInsurance(Decimal amount, Decimal count) {
            this.I330_1 = amount; this.I330_2 = count; this.I330_3 = amount / count;
        }
        public void setLoansWithoutMortgageInsurance(Decimal amount, Decimal count) {
            this.I331_1 = amount; this.I331_2 = count; this.I331_3 = amount / count;
        }
        public void setLoansWithPiggybackSeconds(Decimal amount, Decimal count) {
            this.I340_1 = amount; this.I340_2 = count; this.I340_3 = amount / count;
        }
        public void setLoansWithoutPiggybackSeconds(Decimal amount, Decimal count) {
            this.I341_1 = amount; this.I341_2 = count; this.I341_3 = amount / count;
        }
        public void setLoansWithLTVEqualOrLessThan60(Decimal amount, Decimal count) {
            this.I370_1 = amount; this.I370_2 = count; this.I370_3 = amount / count;
        }
        public void setLoansWithLTVBetween60And70(Decimal amount, Decimal count) {
            this.I371_1 = amount; this.I371_2 = count; this.I371_3 = amount / count;
        }
        public void setLoansWithLTVBetween70And80(Decimal amount, Decimal count) {
            this.I372_1 = amount; this.I372_2 = count; this.I372_3 = amount / count;
        }
        public void setLoansWithLTVBetween80And90(Decimal amount, Decimal count) {
            this.I373_1 = amount; this.I373_2 = count; this.I373_3 = amount / count;
        }
        public void setLoansWithLTVBetween90And100(Decimal amount, Decimal count) {
            this.I374_1 = amount; this.I374_2 = count; this.I374_3 = amount / count;
        }
        public void setLoansWithLTVGreaterThan100(Decimal amount, Decimal count) {
            this.I375_1 = amount; this.I375_2 = count; this.I375_3 = amount / count;
        }
        public void setWeightedAverageLTV(Decimal count) {
            this.I380_2 = count;
        }
        public void setWeightedAverageCLTV(Decimal count) {
            this.I385_2 = count;
        }
        public void setWeightedAverageCouponAtOrigination(Decimal count) {
            this.I390_2 = count;
        }
        public void setLoansWithProductionSoldToOthersNonAffiliate(Decimal amount, Decimal count) {
            this.I401_1 = amount; this.I401_2 = count; this.I401_3 = amount / count;
        }
        public void setAvgDaysInWarehouse(Decimal count) {
            this.I450_2 = count;
        }
        public void setProductionWarehousedInExcessOf90Days(Decimal amount, Decimal count) {
            this.I460_1 = amount; this.I460_2 = count; this.I460_3 = amount / count;
        }

        //I100
        public void setTotalResidentialFirstMortgages() {
            Decimal amount = this.I010_1 + this.I020_1 + this.I030_1 + this.I040_1 + this.I050_1  + this.I060_1 + this.I070_1 + this.I080_1;
            Decimal count = this.I010_2 + this.I020_2 + this.I030_2 + this.I040_2 + this.I050_2  + this.I060_2 + this.I070_2 + this.I080_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I100_1 = amount;
            this.I100_2 = count;
            this.I100_3 = average;
        }

        //I180
        public void setTotalOtherMortgages() {
            Decimal amount = this.I110_1 + this.I120_1 + this.I130_1 + this.I140_1 + this.I170_1;
            Decimal count = this.I110_2 + this.I120_2 + this.I130_2 + this.I140_2 + this.I170_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I180_1 = amount;
            this.I180_2 = count;
            this.I180_3 = average;
        }

        //I200
        public void setTotalMortgageLoansOriginated() {
            Decimal amount = this.I100_1 + this.I180_1;
            Decimal count = this.I100_2 + this.I180_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I200_1 = amount;
            this.I200_2 = count;
            this.I200_3 = average;
        }

        //I240
        public void setTotalResidentialFirstMortgagesFrom210To230() {
            Decimal amount = this.I210_1 + this.I220_1 + this.I230_1;
            Decimal count = this.I210_2 + this.I220_2 + this.I230_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I240_1 = amount;
            this.I240_2 = count;
            this.I240_3 = average;
        }

        //I259
        public void setTotalResidentialFirstMortgagesFrom250To251() {
            Decimal amount = this.I250_1 + this.I251_1;
            Decimal count = this.I250_2 + this.I251_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I259_1 = amount;
            this.I259_2 = count;
            this.I259_3 = average;
        }

        //I269
        public void setTotalResidentialFirstMortgagesFrom260To261() {
            Decimal amount = this.I260_1 + this.I261_1;
            Decimal count = this.I260_2 + this.I261_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I269_1 = amount;
            this.I269_2 = count;
            this.I269_3 = average;
        }

        //I279
        public void setTotalResidentialFirstMortgagesFrom270To271() {
            Decimal amount = this.I270_1 + this.I271_1;
            Decimal count = this.I270_2 + this.I271_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I279_1 = amount;
            this.I279_2 = count;
            this.I279_3 = average;
        }

        //I289
        public void setTotalResidentialFirstMortgagesFrom280To281() {
            Decimal amount = this.I280_1 + this.I281_1;
            Decimal count = this.I280_2 + this.I281_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I289_1 = amount;
            this.I289_2 = count;
            this.I289_3 = average;
        }

        //I299
        public void setTotalResidentialFirstMortgagesFrom290To291() {
            Decimal amount = this.I290_1 + this.I291_1;
            Decimal count = this.I290_2 + this.I291_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I299_1 = amount;
            this.I299_2 = count;
            this.I299_3 = average;
        }

        //I309
        public void setTotalResidentialFirstMortgagesFrom300To301() {
            Decimal amount = this.I300_1 + this.I301_1;
            Decimal count = this.I300_2 + this.I301_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I309_1 = amount;
            this.I309_2 = count;
            this.I309_3 = average;
        }

        //I319
        public void setTotalResidentialFirstMortgagesFrom310To314() {
            Decimal amount = this.I310_1 + this.I311_1 + this.I312_1 + this.I313_1 + this.I314_1;
            Decimal count = this.I310_2 + this.I311_2 + this.I312_2 + this.I313_2 + this.I314_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I319_1 = amount;
            this.I319_2 = count;
            this.I319_3 = average;
        }

        //I339
        public void setTotalResidentialFirstMortgagesFrom330To331() {
            Decimal amount = this.I330_1 + this.I331_1;
            Decimal count = this.I330_2 + this.I331_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I339_1 = amount;
            this.I339_2 = count;
            this.I339_3 = average;
        }

        //I349
        public void setTotalResidentialFirstMortgagesFrom340To341() {
            Decimal amount = this.I340_1 + this.I341_1;
            Decimal count = this.I340_2 + this.I341_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I349_1 = amount;
            this.I349_2 = count;
            this.I349_3 = average;
        }
        //I379
        public void setTotalResidentialFirstMortgagesFrom370To375() {
            Decimal amount = this.I370_1 + this.I371_1 + this.I372_1 + this.I373_1 + this.I374_1 + this.I375_1;
            Decimal count = this.I370_2 + this.I371_2 + this.I372_2 + this.I373_2 + this.I374_2 + this.I375_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I379_1 = amount;
            this.I379_2 = count;
            this.I379_3 = average;
        }
        //I409
        public void setTotalResidentialFirstMortgagesFrom400To405() {
            Decimal amount = this.I400_1 + this.I401_1 + this.I402_1 + this.I404_1 + this.I405_1;
            Decimal count = this.I400_2 + this.I401_2 + this.I402_2 + this.I404_2 + this.I405_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I409_1 = amount;
            this.I409_2 = count;
            this.I409_3 = average;
        }
        //I410
        public void setProductionSoldServicingReleased() {
            Decimal amount = this.I400_1 + this.I401_1 + this.I402_1 + this.I404_1 + this.I405_1;
            Decimal count = this.I400_2 + this.I401_2 + this.I402_2 + this.I404_2 + this.I405_2;
            Decimal average = count == 0 ? 0 : amount/count;

            this.I410_1 = amount;
            this.I410_2 = count;
            this.I410_3 = average;
        }
    }
    public class RevenueDataModel {
        @AuraEnabled
        public Decimal AC1100_1;
        public RevenueDataModel() {
            AC1100_1 = 0;
        }
        public void setGrossRevenue(Decimal amount) {
            this.AC1100_1 = amount;
        }
    }
    public class MloDataModel {
        @AuraEnabled
        public String nmlsId;
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String fullname;
        @AuraEnabled
        public Decimal amount;
        @AuraEnabled
        public Decimal count;
        @AuraEnabled
        public Decimal average;

        public MloDataModel(String Id, String name, String nmlsId, Decimal amount, Decimal count) {
            this.fullname = name;
            this.id = Id;
            this.nmlsId = nmlsId;
            this.amount = amount;
            this.count = count;
            this.average = amount / count;
        }
		
        public MloDataModel( String nmlsId, Decimal amount, Decimal count) {         
            this.nmlsId = nmlsId;
            this.amount = amount;
            this.count = count;
            this.average = amount / count;
        }
    }
    public class UserInfoModel {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String username;
        @AuraEnabled
        public IdentityInfo ids;

        public UserInfoModel() {
            this.name = UserInfo.getName();
            this.username = UserInfo.getUserName();
            this.ids = new IdentityInfo();
        }
    }
    public class IdentityInfo {
        @AuraEnabled
        public String cvId;
        @AuraEnabled
        public String sfId;
        @AuraEnabled
        public String lwId;

        public IdentityInfo() {
            this.sfId = UserInfo.getUserId();
        }
    }
    @AuraEnabled
    public static ReportModel generateReport(String quarter, String year, String[] states) {
        ReportModel report = new ReportModel(quarter, year, states);
        return report;
    }
    @AuraEnabled
    public static ReportModel finishGenerateReport(String report) {
        try {
            ReportModel reportModel = (ReportModel)JSON.deserialize(report, ReportModel.class);
            reportModel.generateResidentialFirstMortgagesData();
            return reportModel;
        } catch (Exception e) {
            throw new AuraHandledException('Error in finish generate report: ' + e.getMessage());
        }
    }
    public class StateOptionModel {
        @AuraEnabled
        public String stateCode;
        @AuraEnabled
        public Boolean isComplete;

        public StateOptionModel(String stateCode) {
            this.stateCode = stateCode;
            this.isComplete = false;
        }
    }
    public class StateCheckboxModel {
        @AuraEnabled
        public Boolean value;
        @AuraEnabled
        public String name;
        public StateCheckboxModel(String stateCode) {
            this.name = stateCode;
            this.value = true;
        }

        public Boolean equals(Object obj){
            if(obj instanceOf StateCheckboxModel){
                StateCheckboxModel checkboxModel = (StateCheckboxModel)obj;
                return checkboxModel.name==this.name;
            }
            return false;
        }

        public Integer hashCode(){
            return 38 * this.name.hashCode();
        }
    }

   /* @AuraEnabled
    public static List<StateCheckboxModel> getStateLicenses() {
        
        

        List<StateCheckboxModel> models = new List<StateCheckboxModel>();
        List<String> states = new List<String>{'FL','TN','TX','CO','VA'};
        for(String state: states) {
            models.add(new StateCheckboxModel(state));
        }
        return models;
    }*/
    
    @AuraEnabled
    public static List<StateCheckboxModel> getStateLicenses() {
        
        List<StateCheckboxModel> models = new List<StateCheckboxModel>();
        
        // Querying List-type Custom Setting
        List<NMLS_States__c> stateSettings = [
            SELECT Abbreviation__c 
            FROM NMLS_States__c
            ORDER BY Abbreviation__c
        ];
        
        for (NMLS_States__c cs : stateSettings) {
            if (String.isNotBlank(cs.Abbreviation__c)) {
                models.add(new StateCheckboxModel(cs.Abbreviation__c));
            }
        }
        
        return models;
    }


    @AuraEnabled
    public static Map<String, Object> generateXmlFile(String jsonReport) {
        String file, base64Value;
        try {
            Http http = new Http();
            HttpRequest req = generateHttpRequest(jsonReport);
            HTTPResponse res = http.send(req);
            file = res.getBody();
            base64Value = EncodingUtil.base64Encode(Blob.valueOf(file));
        } catch (Exception e) {
            return new Map<String, Object>{
                    'status' => 'ERROR',
                    'errorMessage' => e.getMessage()
            };
        } finally {

        }
        return new Map<String, Object>{
                'status' => 'SUCCESS',
                'file' => base64Value
        };
    }

    private static HttpRequest generateHttpRequest(String jsonReport){
        HttpRequest req = new httpRequest();
        String endpoint = 'https://callreportgenerator.herokuapp.com/api/v2/corresponder/report';
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        String username = 'admin';
        String password = 'nimbus123';
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        req.setBody(jsonReport);
        return req;
    }

    public class ReportXmlFile{
        @AuraEnabled
        public String name{get;set;}
        @AuraEnabled
        public Date generatedDate{get;set;}
        @AuraEnabled
        public String data {get;set;}

    }
    @AuraEnabled
    public static List<ReportXmlFile> retrievePastReports(){
        List<ReportXmlFile> emptylist = new List<ReportXmlFile>();
        return emptyList;
    }
	@AuraEnabled 
    public static ARIVE_NmlsCallReportTableController.Table viewDatapointDetails(String datapointName, String startDate, String endDate, String state) {
        return ARIVE_NmlsCallReportTableController.translateFieldSetToTable(datapointName, Date.parse(startDate), Date.parse(endDate), state);
    }

}
