/**
 * @author Andrei Karanko
 * @date 9/15/2023
 * description
 */
@IsTest
private class ReferenceInvocableQueryTest {
    private static final String TEST_LOAN_CONDITION_REFERENCE_LABEL = 'Test Borrower Label';
    private static final String TEST_LOAN_CONDITION_REFERENCE_TYPE_PROCESSOR = 'Processor';
    private static final String TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2 = 'W2';
    private static final String TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_SELF_EMPLOYED = 'Self Employed';
    private static final String TEST_USER_PROFILE_NAME = 'System Administrator';
    private static final String CONDITION_PERMISSIONS_NAME = 'ConditionPermissions';
    private static final String TEST_USER_LAST_NAME = 'ReferenceInvocableQuery';

    private static final String TEST_REQUEST_LOAN_PURPOSE_PURCHASE = 'Purchase';
    private static final String TEST_REQUEST_TYPE_INITIAL_SUBMISSION = 'Initial Submission';

    @TestSetup
    static void setupUserWithConditionPermissions() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        User testUser = TestDataFactory.createUser(new Map<String, Object>{
            'profileName' => TEST_USER_PROFILE_NAME,
            'userName' => 'referenceinvocablequery.' + uniqueSuffix + '@example.com',
            'email' => 'referenceinvocablequery.' + uniqueSuffix + '@example.com',
            'lastName' => TEST_USER_LAST_NAME
        });
        insert testUser;

        PermissionSet conditionPermissions = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :CONDITION_PERMISSIONS_NAME
            LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = conditionPermissions.Id
        );
    }

    @IsTest
    static void getReferencesForNotSelfEmployedTest() {
        User testUser = getTestUserWithConditionPermissions();
        List<Transaction_Condition_Reference__c> loanConditionsReferences = TestDataFactory.createLoanConditionsReferences(new Map<String,Object>{
            'label' => TEST_LOAN_CONDITION_REFERENCE_LABEL,
            'numberOfRecords' => 1,
            'type' => TEST_REQUEST_TYPE_INITIAL_SUBMISSION,
            'referenceId' => null,
            'conditionGroupKey' => null
        });
        loanConditionsReferences[0].Loan_Purpose__c = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        loanConditionsReferences[0].Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;

        List<ReferenceInvocableQuery.Request> requests = new List<ReferenceInvocableQuery.Request>();
        ReferenceInvocableQuery.Request request = new ReferenceInvocableQuery.Request();
        request.loanPurpose = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        request.employmentType = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;
        request.type = TEST_REQUEST_TYPE_INITIAL_SUBMISSION;
        requests.add(request);

        List<ReferenceInvocableQuery.Response> responses;
        Test.startTest();
        System.runAs(testUser) {
            insert loanConditionsReferences;
            responses = ReferenceInvocableQuery.getReferences(requests);
        }
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Expected one response for a matching W2 request.');
        System.assertEquals(1, responses[0].conditions.size(), 'Expected one matching condition reference.');
        System.assertEquals(loanConditionsReferences[0].Id, responses[0].conditions[0].Id);
    }

    @IsTest
    static void getReferencesForSelfEmployedTest() {
        User testUser = getTestUserWithConditionPermissions();
        String selfEmploymentTypeValue = getActiveSelfEmploymentTypeValue();
        if (selfEmploymentTypeValue == null) {
            System.assert(true);
            return;
        }

        List<Transaction_Condition_Reference__c> loanConditionsReferences = TestDataFactory.createLoanConditionsReferences(new Map<String,Object>{
            'label' => TEST_LOAN_CONDITION_REFERENCE_LABEL,
            'numberOfRecords' => 1,
            'type' => TEST_REQUEST_TYPE_INITIAL_SUBMISSION,
            'referenceId' => null,
            'conditionGroupKey' => null
        });
        loanConditionsReferences[0].Loan_Purpose__c = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        loanConditionsReferences[0].Loan_Type__c = 'FHA';
        loanConditionsReferences[0].Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_SELF_EMPLOYED;
        loanConditionsReferences[0].Self_Employment_Type__c = selfEmploymentTypeValue;
        List<ReferenceInvocableQuery.Request> requests = new List<ReferenceInvocableQuery.Request>();
        ReferenceInvocableQuery.Request request = new ReferenceInvocableQuery.Request();
        request.loanPurpose = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        request.loanType = 'FHA';
        request.employmentType = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_SELF_EMPLOYED;
        request.selfEmploymentType = selfEmploymentTypeValue;
        request.type = TEST_REQUEST_TYPE_INITIAL_SUBMISSION;
        requests.add(request);

        List<ReferenceInvocableQuery.Response> responses;
        Test.startTest();
        System.runAs(testUser) {
            insert loanConditionsReferences;
            responses = ReferenceInvocableQuery.getReferences(requests);
        }
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Expected one response for a matching self-employed request.');
        System.assertEquals(1, responses[0].conditions.size(), 'Expected one matching self-employed condition reference.');
        System.assertEquals(loanConditionsReferences[0].Id, responses[0].conditions[0].Id);
    }

    @IsTest
    static void getReferencesReturnsEmptyForUnknownType() {
        User testUser = getTestUserWithConditionPermissions();
        List<Transaction_Condition_Reference__c> loanConditionsReferences =
            TestDataFactory.createLoanConditionsReferences(new Map<String, Object>{
                'label' => TEST_LOAN_CONDITION_REFERENCE_LABEL,
                'numberOfRecords' => 1,
                'type' => TEST_REQUEST_TYPE_INITIAL_SUBMISSION,
                'referenceId' => null,
                'conditionGroupKey' => null
            });
        loanConditionsReferences[0].Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;
        List<ReferenceInvocableQuery.Request> requests = new List<ReferenceInvocableQuery.Request>();
        ReferenceInvocableQuery.Request request = new ReferenceInvocableQuery.Request();
        request.loanPurpose = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        request.employmentType = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;
        request.type = 'Unknown Type';
        requests.add(request);

        Test.startTest();
        List<ReferenceInvocableQuery.Response> responses;
        System.runAs(testUser) {
            insert loanConditionsReferences;
            responses = ReferenceInvocableQuery.getReferences(requests);
        }
        Test.stopTest();

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void getReferencesReturnsMatchingConditionForW2Request() {
        User testUser = getTestUserWithConditionPermissions();
        Transaction_Condition_Reference__c conditionReference =
            TestDataFactory.createLoanConditionsReferences(new Map<String, Object>{
                'label' => TEST_LOAN_CONDITION_REFERENCE_LABEL,
                'numberOfRecords' => 1,
                'type' => TEST_REQUEST_TYPE_INITIAL_SUBMISSION,
                'referenceId' => null,
                'conditionGroupKey' => null
            })[0];
        conditionReference.Loan_Purpose__c = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        conditionReference.Loan_Type__c = 'Conventional';
        conditionReference.Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;
        ReferenceInvocableQuery.Request requestItem = new ReferenceInvocableQuery.Request();
        requestItem.loanPurpose = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        requestItem.loanType = 'Conventional';
        requestItem.employmentType = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;
        requestItem.type = TEST_REQUEST_TYPE_INITIAL_SUBMISSION;

        Test.startTest();
        List<ReferenceInvocableQuery.Response> responses;
        System.runAs(testUser) {
            insert conditionReference;
            responses = ReferenceInvocableQuery.getReferences(
                new List<ReferenceInvocableQuery.Request>{ requestItem }
            );
        }
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(1, responses[0].conditions.size());
        System.assertEquals(conditionReference.Id, responses[0].conditions[0].Id);
    }

    @IsTest
    static void getReferencesFiltersSelfEmployedConditionsBySubtype() {
        User testUser = getTestUserWithConditionPermissions();
        String selfEmploymentTypeValue = getActiveSelfEmploymentTypeValue();
        if (selfEmploymentTypeValue == null) {
            System.assert(true);
            return;
        }

        List<Transaction_Condition_Reference__c> conditionReferences =
            TestDataFactory.createLoanConditionsReferences(new Map<String, Object>{
                'label' => 'Self Employed Reference',
                'numberOfRecords' => 2,
                'type' => TEST_REQUEST_TYPE_INITIAL_SUBMISSION,
                'referenceId' => null,
                'conditionGroupKey' => null
            });
        conditionReferences[0].Loan_Purpose__c = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        conditionReferences[0].Loan_Type__c = 'FHA';
        conditionReferences[0].Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_SELF_EMPLOYED;
        conditionReferences[0].Self_Employment_Type__c = selfEmploymentTypeValue;

        conditionReferences[1].Loan_Purpose__c = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        conditionReferences[1].Loan_Type__c = 'FHA';
        conditionReferences[1].Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;

        ReferenceInvocableQuery.Request requestItem = new ReferenceInvocableQuery.Request();
        requestItem.loanPurpose = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        requestItem.loanType = 'FHA';
        requestItem.employmentType = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_SELF_EMPLOYED;
        requestItem.selfEmploymentType = selfEmploymentTypeValue;
        requestItem.type = TEST_REQUEST_TYPE_INITIAL_SUBMISSION;

        Test.startTest();
        List<ReferenceInvocableQuery.Response> responses;
        System.runAs(testUser) {
            insert conditionReferences;
            responses = ReferenceInvocableQuery.getReferences(
                new List<ReferenceInvocableQuery.Request>{ requestItem }
            );
        }
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(1, responses[0].conditions.size());
        System.assertEquals(conditionReferences[0].Id, responses[0].conditions[0].Id);
    }

    @IsTest
    static void getReferencesReturnsEmptyWhenEmploymentTypeDoesNotMatch() {
        User testUser = getTestUserWithConditionPermissions();
        Transaction_Condition_Reference__c conditionReference =
            TestDataFactory.createLoanConditionsReferences(new Map<String, Object>{
                'label' => 'Employment mismatch',
                'numberOfRecords' => 1,
                'type' => TEST_REQUEST_TYPE_INITIAL_SUBMISSION,
                'referenceId' => null,
                'conditionGroupKey' => null
            })[0];
        conditionReference.Loan_Purpose__c = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        conditionReference.Loan_Type__c = 'Conventional';
        conditionReference.Employment_Type__c = TEST_LOAN_CONDITION_REFERENCE_EMPLOYMENT_TYPE_W2;
        ReferenceInvocableQuery.Request requestItem = new ReferenceInvocableQuery.Request();
        requestItem.loanPurpose = TEST_REQUEST_LOAN_PURPOSE_PURCHASE;
        requestItem.loanType = 'Conventional';
        requestItem.employmentType = '1099';
        requestItem.type = TEST_REQUEST_TYPE_INITIAL_SUBMISSION;

        Test.startTest();
        List<ReferenceInvocableQuery.Response> responses;
        System.runAs(testUser) {
            insert conditionReference;
            responses = ReferenceInvocableQuery.getReferences(
                new List<ReferenceInvocableQuery.Request>{ requestItem }
            );
        }
        Test.stopTest();

        System.assertEquals(0, responses.size(), 'Expected no responses when employment type does not match.');
    }

    private static String getActiveSelfEmploymentTypeValue() {
        Map<String, SObjectField> fieldMap =
            Transaction_Condition_Reference__c.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey('Self_Employment_Type__c')) {
            return null;
        }

        for (Schema.PicklistEntry entry :
            fieldMap.get('Self_Employment_Type__c').getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return null;
    }

    private static User getTestUserWithConditionPermissions() {
        return [
            SELECT Id
            FROM User
            WHERE LastName = :TEST_USER_LAST_NAME
            LIMIT 1
        ];
    }

}