/**
 * Created by toma on 5/20/2022.
 */
@IsTest
public class UWM_Insights_Tests {
    @IsTest
    public static void testInsightsWebService(){
         List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Testy',RecordTypeId=personAccountType[0].Id, PersonEmail='test@email.com',PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id,Name='TodaysTest',Status__c='Submitted',Loan_Number__c='1522092168',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1522092168',Transaction__c=o.Id);
        insert l;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new UWMInsightsAPIMock());
        UWM_Insights_PipelineUpdateWebservice.doPing();
        Test.stopTest();
    }
    @IsTest
    public static void testOpenTransactionsAreIncludedInInsightsPipeline(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='OpenPipeline',RecordTypeId=personAccountType[0].Id, PersonEmail='openpipeline@example.com',PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id,Name='OpenPipelineTest',Status__c='Open',Loan_Number__c='1526282825', Submission_Form_Date__c=Date.today(), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526282825',Transaction__c=o.Id);
        insert l;

        List<UWM_Loan_Info__c> pipelineLoans = UWMLoanInfoRepository.getInstance().getActiveLoanPipeline();

        System.assertEquals(1, pipelineLoans.size(), 'Open UWM loan info rows should be included in the scheduled Insights pull.');
        System.assertEquals(l.Id, pipelineLoans[0].Id);
    }
    @IsTest
    public static void testInvocableUWMInsights(){
        List<Id> ids = new List<Id>();
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Testy',RecordTypeId=personAccountType[0].Id, PersonEmail='test@email.com',PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id,Name='TodaysTest',Status__c='Submitted',Loan_Number__c='1522092168',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1522092168',Transaction__c=o.Id);
        insert l;
        ids.add(o.Id);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new UWMInsightsAPIMock());
        UWM_Insights_Invocable.doPingInvocable(ids);
        Test.stopTest();
    }
    @IsTest
    public static void testInvocableUWMInsightsNoLoanResultDoesNotThrow(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='NoResult', RecordTypeId=personAccountType[0].Id, PersonEmail='noresult@example.com', PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id, Name='NoResultTest', Status__c='Submitted', Loan_Number__c='1526268639', Clear_to_Close_Date__c=Date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000, Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526268639', Transaction__c=o.Id);
        insert l;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new UWMInsightsEmptyLoanMock());
        UWM_Insights_Invocable.doPingInvocable(new List<Id>{ o.Id });
        Test.stopTest();
    }
        @IsTest
    public static void testInvocableUWMInsights_Async(){
        List<Id> ids = new List<Id>();
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Testy',RecordTypeId=personAccountType[0].Id, PersonEmail='test@email.com',PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id,Name='TodaysTest',Status__c='Submitted',Loan_Number__c='1522092168',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1522092168',Transaction__c=o.Id);
        insert l;
        ids.add(o.Id);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new UWMInsightsAPIMock());
        UWM_Insights_Invocable_Async.doPingInvocable(ids);
        Test.stopTest();
    }
        @IsTest
    public static void testInvocableUWMEvent(){
        List<Id> ids = new List<Id>();
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Testy',RecordTypeId=personAccountType[0].Id, PersonEmail='test@email.com',PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id,Name='TodaysTest',Status__c='Submitted',Loan_Number__c='1522092168',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1522092168',Transaction__c=o.Id);
        insert l;
        ids.add(o.Id);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new UWMInsightsAPIMock());
        UWM_Event__e evt = new UWM_Event__e(UWM_Loan_Info_ID__c=l.Id, Transaction_ID__c=o.Id);
        EventBus.publish(evt);
        Test.stopTest();
    }

    @IsTest
    public static void testUWMEventCanMoveStatusToClosing(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Closing', RecordTypeId=personAccountType[0].Id, PersonEmail='closing@example.com', PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id, Name='ClosingStatusTest', Status__c='Approved', Loan_Number__c='1526208860', Clear_to_Close_Date__c=Date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000, Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526208860', Transaction__c=o.Id);
        l.put('uwm_LoanStatus__c', 'Closing');
        l.put('uwm_ClearToCloseDate__c', Datetime.now());
        insert l;
        UWM_Insights_Mapping__mdt statusMapping = new UWM_Insights_Mapping__mdt(
            API_Name__c = 'uwm_LoanStatus__c',
            Transaction_Field_API_Name__c = 'Status__c',
            Datatype__c = 'Text'
        );

        Test.startTest();
        UwmEventTriggerHandler.handleAfterInsert(
            new List<UWM_Event__e>{ new UWM_Event__e(UWM_Loan_Info_ID__c=l.Id, Transaction_ID__c=o.Id) },
            new List<UWM_Insights_Mapping__mdt>{ statusMapping }
        );
        Test.stopTest();

        System.assertEquals('Closing', [SELECT Status__c FROM Transaction__c WHERE Id = :o.Id].Status__c);
    }

    @IsTest
    public static void testUWMEventDoesNotDeriveClosingFromDisbursementDate(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Disbursement', RecordTypeId=personAccountType[0].Id, PersonEmail='disbursement@example.com', PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id, Name='DisbursementStatusTest', Status__c='Approved', Loan_Number__c='1526175069', Clear_to_Close_Date__c=Date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000, Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526175069', Transaction__c=o.Id);
        l.put('uwm_LoanStatus__c', 'Approved');
        l.put('uwm_DisbursementDate__c', Date.today().addDays(1));
        insert l;
        UWM_Insights_Mapping__mdt statusMapping = new UWM_Insights_Mapping__mdt(
            API_Name__c = 'uwm_LoanStatus__c',
            Transaction_Field_API_Name__c = 'Status__c',
            Datatype__c = 'Text'
        );

        Test.startTest();
        UwmEventTriggerHandler.handleAfterInsert(
            new List<UWM_Event__e>{ new UWM_Event__e(UWM_Loan_Info_ID__c=l.Id, Transaction_ID__c=o.Id) },
            new List<UWM_Insights_Mapping__mdt>{ statusMapping }
        );
        Test.stopTest();

        System.assertEquals('Approved', [SELECT Status__c FROM Transaction__c WHERE Id = :o.Id].Status__c);
    }

    @IsTest
    public static void testUWMEventDerivesApprovedFromClearToCloseDate(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='ClearToClose', RecordTypeId=personAccountType[0].Id, PersonEmail='ctc@example.com', PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id, Name='ClearToCloseStatusTest', Status__c='Submitted', Loan_Number__c='1526175070', BPS__c=0.10, Loan_Amount_1st__c=250000, Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526175070', Transaction__c=o.Id);
        l.put('uwm_LoanStatus__c', 'Conditionally Approved');
        l.put('uwm_ClearToCloseDate__c', Datetime.now());
        insert l;
        UWM_Insights_Mapping__mdt statusMapping = new UWM_Insights_Mapping__mdt(
            API_Name__c = 'uwm_LoanStatus__c',
            Transaction_Field_API_Name__c = 'Status__c',
            Datatype__c = 'Text'
        );

        Test.startTest();
        UwmEventTriggerHandler.handleAfterInsert(
            new List<UWM_Event__e>{ new UWM_Event__e(UWM_Loan_Info_ID__c=l.Id, Transaction_ID__c=o.Id) },
            new List<UWM_Insights_Mapping__mdt>{ statusMapping }
        );
        Test.stopTest();

        System.assertEquals('Approved', [SELECT Status__c FROM Transaction__c WHERE Id = :o.Id].Status__c);
    }

    @IsTest
    public static void testUWMEventDerivesApprovedWhenTranslatedStatusDoesNotMatch(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='TranslatedFallback', RecordTypeId=personAccountType[0].Id, PersonEmail='translated@example.com', PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id, Name='TranslatedFallbackStatusTest', Status__c='Submitted', Loan_Number__c='1526175071', BPS__c=0.10, Loan_Amount_1st__c=250000, Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526175071', Transaction__c=o.Id);
        l.put('uwm_LoanStatus__c', 'Wholesale - New UWM Wording');
        l.put('uwm_ClearToCloseDate__c', Datetime.now());
        insert l;
        UWM_Insights_Mapping__mdt statusMapping = (UWM_Insights_Mapping__mdt) JSON.deserialize(
            '{"API_Name__c":"uwm_LoanStatus__c","Transaction_Field_API_Name__c":"Status__c","Datatype__c":"Text","UWM_Translated_Values__r":{"totalSize":1,"done":true,"records":[{"attributes":{"type":"UWM_Translated_Value__mdt"},"Input_Value__c":"Wholesale - Clear To Close","Output_Value__c":"Approved"}]}}',
            UWM_Insights_Mapping__mdt.class
        );

        Test.startTest();
        UwmEventTriggerHandler.handleAfterInsert(
            new List<UWM_Event__e>{ new UWM_Event__e(UWM_Loan_Info_ID__c=l.Id, Transaction_ID__c=o.Id) },
            new List<UWM_Insights_Mapping__mdt>{ statusMapping }
        );
        Test.stopTest();

        System.assertEquals('Approved', [SELECT Status__c FROM Transaction__c WHERE Id = :o.Id].Status__c);
    }

    @IsTest
    public static void testUWMEventDoesNotOverwriteSalesforceManagedStatus(){
        List<RecordType> personAccountType = [SELECT Id FROM RecordType WHERE Name='Person Account'];
        Account a = new Account(FirstName='ATest', LastName='Funding', RecordTypeId=personAccountType[0].Id, PersonEmail='funding@example.com', PersonLeadSource='Website - Purchase');
        insert a;
        Transaction__c o = new Transaction__c(Borrower_Name__c=a.Id, Name='FundingStatusTest', Status__c='Funding', Loan_Number__c='1526208861', Clear_to_Close_Date__c=Date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000, Lead_Source__c='Website - Purchase');
        insert o;
        UWM_Loan_Info__c l = new UWM_Loan_Info__c(uwm_LoanNumber__c='1526208861', Transaction__c=o.Id);
        l.put('uwm_LoanStatus__c', 'Approved');
        insert l;
        UWM_Insights_Mapping__mdt statusMapping = new UWM_Insights_Mapping__mdt(
            API_Name__c = 'uwm_LoanStatus__c',
            Transaction_Field_API_Name__c = 'Status__c',
            Datatype__c = 'Text'
        );

        Test.startTest();
        UwmEventTriggerHandler.handleAfterInsert(
            new List<UWM_Event__e>{ new UWM_Event__e(UWM_Loan_Info_ID__c=l.Id, Transaction_ID__c=o.Id) },
            new List<UWM_Insights_Mapping__mdt>{ statusMapping }
        );
        Test.stopTest();

        System.assertEquals('Funding', [SELECT Status__c FROM Transaction__c WHERE Id = :o.Id].Status__c);
    }

    public class UWMInsightsAPIMock implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse response = new HttpResponse();
            response.setBody('{"data":{"Loans":[{ "LoanStatus": {"StatusCode": "DeadImport", "Description": "Dead Import Holding","LoanId": null },"AssetExpirationDate" : "04/30/2022", "TitleExpirationDate" : "07/27/2022", "PayOffExpirationDate" : null, "HOIExpirationDate" : "12/09/2022", "CurrentCDDate" : "03/29/2022", "AppraisalExpirationDate" : null, "NumberOfUnits" : 1, "LockExpired" : "N", "UW2EmailAddress" : "jdiscenna@uwm.com", "UW2Ext" : "63344", "UW2FirstName" : "John", "UW2LastName" : "Discenna", "SrUWEmailAddress" : "mdoyle3@uwm.com", "SrUWExt" : "81091", "SrUWFirstName" : "Michael", "SrUWLastName" : "Doyle", "DaysSinceSubmission" : 41, "EsignCompletedDate" : null, "BrokerID" : "NJ1135", "ProcessorAssistOrderOutStanding" : "0", "CoCIndicator" : "0", "CannotCloseBefore" : null, "Term" : "15", "BorrowerIncome" : "9927.67", "LoanStatusDescription" : "Post Closed", "LoanOfficerFullName" : "Robert Campbell", "HOIEffectivedDate" : "2021-12-09T00:00:00.000-05:00", "CreditExpDate" : "2022-06-04T00:00:00.000-04:00", "MortgageAppliedFor" : "CONVENTIONAL", "Borr2SignedAndSubmitted" : null, "Borr2ConsentToEsign" : null, "Borr2LinkDelivered" : null, "Borr1SignedAndSubmitted" : "2022-02-22T19:49:17.000-05:00", "Borr1ConsentToEsign" : "2022-02-18T16:03:52.000-05:00", "Borr1LinkDelivered" : "2022-02-18T12:38:53.000-05:00", "LOSignedAndSubmitted" : null, "LOConsentToEsign" : "2022-02-18T12:42:10.000-05:00", "LOlinkDelivered" : "2022-02-18T12:38:53.000-05:00", "ApprovalExpiration" : "2022-04-14T00:00:00.000-04:00", "MannerHeld" : "Sole Ownership", "TitleToBeHeldIn" : "Lorraine Voigt", "YearAcquired" : 1996, "FinalCreditAmount" : -2803.06, "FinalCredit" : -1.60, "DTIBackEnd" : 26.148, "DTIFrontEnd" : 24.738, "CashtoClose" : 43540.13, "CashtoCloseAvailable" : 515736.86, "VVOEOrderedDate" : "2022-03-17T00:00:00.000-04:00", "VVOEExpDate" : null, "VVOEReceiveddate" : null, "WiredOrderedDate" : "2022-04-05T00:00:00.000-04:00", "ClosingDisclosureDateTime" : "2022-02-23T00:00:00.000-05:00", "MostRecentLoanEstimateDate" : "2022-02-18T00:00:00.000-05:00", "InitialLoanEstimateDate" : "2022-02-18T00:00:00.000-05:00", "UWDate" : "2022-02-23T00:00:00.000-05:00", "LockExpirationDate" : "2022-04-11T00:00:00.000-04:00", "SignatureDate_1003" : "2022-02-18T00:00:00.000-05:00", "BrokerCompensation" : 0.00, "LoanProgram" : "Conv Elite 15 Fixed", "OccupancyType" : "Primary", "PropertyType" : "Single Family Residence", "AppraisedValue" : 590000, "AppraisalReceivedFlag" : "N", "AppraisalReceivedDate" : null, "DocLessIsProcessed" : false, "AUS" : "Loan Prospector", "BusDaysBwsubCtc" : 19, "ProblemUpload" : "N", "CurrentProblemUpload" : "N", "ProcessorEmail" : "jklein@gardenstateloans.com", "UltimateTotalPoints" : 5, "UltimateUtrackDate" : null, "UltimatePIWDdate" : "2022-02-23T13:36:41.823-05:00", "UltimateAMDdate" : null, "UltimatePADate" : "2022-02-23T11:30:39.440-05:00", "UltimateVOADate" : null, "UltimateVOIDdate" : null, "UltimateCDDate" : "2022-02-23T19:59:57.000-05:00", "UltimateOneClickAUSDate" : "2022-02-18T12:10:30.250-05:00", "UltimateEaseDocsDate" : "2022-02-18T12:37:16.477-05:00", "UltimateBlinkDate" : null, "UltimateAWCDate" : "2022-02-23T16:50:31.500-05:00", "ClosingPackageReceivedDate" : "2022-04-05T00:00:00.000-04:00", "NoteReceivedDate" : "2022-04-05T00:00:00.000-04:00", "FederalReferenceNumber" : null, "PITI" : 2455.910000000000, "BorrowerHomePhoneNumber" : "(908) 963-1127", "BorrowerEmail" : "lorrainev@sirispharma.com", "DiscountPoint" : 0E-12, "EPODate" : "2022-08-04T00:00:00.000-04:00", "MItype" : "", "CompensationType" : "Correspondent", "FinalCDDateTime" : "2022-03-29T14:55:32.000-04:00", "MostRecentCDDateTime" : "2022-03-29T14:55:32.000-04:00", "InitialCDDateTime" : "2022-02-23T19:59:57.000-05:00", "MostRecentRelockDate" : null, "LockSecondExtension" : null, "LockFirstExtension" : null, "DateOfFirstPayment" : "2022-06-01T00:00:00.000-04:00", "AppraisalOrderedFlag" : "N", "LockActionDescription" : "Confirm", "Investor" : null, "BaseLoanAmount" : 175000.000000000000, "RecordModifiedDateTime" : "2022-04-05T15:55:27.987-04:00", "RecordCreatedDateTime" : "2022-02-17T19:35:10.220-05:00", "SecondaryBorrower4FullName" : null, "SecondaryBorrower3FullName" : null, "SecondaryBorrower2FullName" : null, "SecondaryBorrower1FullName" : null, "ESignCompletedFlag" : null, "ApplicationOutDatetime" : "2022-02-18T12:38:53.000-05:00", "CustomLockUsedFlag" : "0", "ExactRateUsedFlag" : "1", "ProcessorAssistUsedFlag" : "1", "DocLessUsedFlag" : "0", "OneClickUsedFlag" : "1", "ServicingSoldDate" : null, "PaidInFullDate" : null, "UWTouches" : 2, "NumberOfPayment" : 180, "LTV" : 29.661000000000, "FICO" : 707, "Product" : "Conventional Elite 15 Year Fixed", "RefinancePurpose" : "ChangeInRateTerm", "Purpose" : "Refinance", "LoanType" : "CONV", "CorrespondentInd" : 1, "AppraisalCompletedDate" : null, "AppraisalOrderedDate" : null, "AppraisalWaiver" : "ACE - Automated Collateral Evaluation", "CDSignedDatetime" : null, "CDSignedFlag" : null, "FundedDate" : null, "ClosingDateTime" : "2022-04-05T00:00:00.000-04:00", "ContingencyDate" : "2022-06-04T00:00:00.000-04:00", "LoanRate" : 3.317000000000, "LockExpiration" : "2022-04-11T00:00:00.000-04:00", "LockDate" : "2022-03-11T18:23:03.543-05:00", "LockStatus" : "1", "ProcessorFullName" : "Joann Klein", "PrimaryBorrowerFirstName" : "Lorraine", "PrimaryBorrowerLastName" : "Voigt", "SubjectProperty" : { "LoanId" : null, "Zip" : "08804", "State" : "NJ", "PropertyType" : "Single Family Residence", "Address2" : null, "Address1" : "9 GARNER RD", "Occupancy" : "Primary Residence", "County" : null, "City" : "BLOOMSBURY" }, "LoanId" : "1522092168" }]}}');
            response.setStatusCode(200);
            return response;
        }
    }
    public class UWMInsightsEmptyLoanMock implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse response = new HttpResponse();
            response.setBody('{"data":{"Loans":[]}}');
            response.setStatusCode(200);
            return response;
        }
    }
    @IsTest
    public static void testUWMInsightsAuth(){
        UWM_Insights_AuthProvider auth = new UWM_Insights_AuthProvider();
        System.assertEquals('UWM_InsightsAuthSettings__mdt', auth.getCustomMetadataType());
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AuthMock());
        Map<String,String> queryParams = new Map<String,String>();
        queryParams.put('code','code');
        queryParams.put('state','999');
        Map<String,String> headers = new Map<String, String>();
        headers.put('Authorization','123abc');
        headers.put('Accept','*/*');
        headers.put('Content-Type', 'application/x-www-form-urlencoded');
        String payload = 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion='+EncodingUtil.urlEncode('123abc','UTF-8');
        Auth.AuthProviderCallbackState cbState = new Auth.AuthProviderCallbackState(headers,payload,queryParams);
        Auth.AuthProviderTokenResponse actualAuthProvResponse = auth.handleCallback(new Map<String,String>{
                'ClientSecret__c'=> 'ABC',
                'AuthProviderName__c'=> 'SECRET'
        }, cbState);
        auth.refresh(new Map<String,String>{
                'ClientSecret__c'=> 'ABC',
                'AuthProviderName__c'=> 'SECRET'
        }, '123abc');
        Test.stopTest();
    }
    public class AuthMock implements HttpCalloutMock{
        private String AUTH_RESPONSE_PAYLOAD = '{' +
                '  "token_type": "Bearer",' +
                '  "access_token" : "abc123"' +
                '}';
        public HttpResponse respond(HttpRequest req){
            HttpResponse response = new HttpResponse();
            response.setBody(AUTH_RESPONSE_PAYLOAD);
            response.setStatusCode(200);
            return response;
        }
    }

    @IsTest
    public static void testBatchErrorEmailHelper(){
        Test.startTest();
        UWM_Insights_PipelineUpdateWebservice.sendBatchErrorEmail('test error');
        Test.stopTest();
    }
}
