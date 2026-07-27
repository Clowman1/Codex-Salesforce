@IsTest
private class LeadPresetCondSelectorTest {
    @TestSetup
    static void setupSettings() {
        insert new AesKey__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            AesKey__c = '12345678901234567890123456789012'
        );
    }

    @IsTest
    static void getPresetConditionsFiltersAndDefaultsSelections() {
        Lead_Document_Request_Reference__c idReference = createReference(
            'Initial Submission',
            'Government-issued photo ID (Driver\'s License or State ID)',
            null,
            null,
            null,
            null,
            null,
            null,
            10
        );
        createReference(
            'Initial Submission Optional',
            'Permanent Resident Card',
            'Permanent Resident Card',
            'ID',
            'Identification - Others',
            null,
            null,
            null,
            20
        );
        createReference(
            'Initial Submission',
            'Income',
            'Most Recent 30 Days Paystubs',
            'Income',
            'W-2 Borrowers - Commonly Requested',
            'Purchase',
            'W2',
            null,
            30
        );
        createReference(
            'Initial Submission Optional',
            'Income',
            'Lease Agreements',
            'Income',
            'Special Income Types',
            null,
            null,
            null,
            40
        );
        createReference(
            'Initial Submission',
            'Assets',
            'Most Recent 2 Months Bank Statements',
            'Assets',
            'Required Assets',
            'Purchase',
            null,
            null,
            50
        );
        createReference(
            'Initial Submission',
            'Assets',
            'Most Recent Investment/Retirement Account Statements',
            'Assets',
            'Required Assets',
            'Purchase',
            null,
            null,
            51
        );
        createReference(
            'Initial Submission',
            'Assets',
            'Documentation for Any Large Deposits',
            'Assets',
            'Required Assets',
            'Purchase',
            null,
            null,
            52
        );
        createReference(
            'Initial Submission',
            'Gift Letter',
            'Gift Fund Documentation (if applicable)',
            'Gift Letter',
            'Required Assets',
            'Purchase',
            null,
            null,
            53
        );
        createReference(
            'Initial Submission',
            'Income',
            'Most Recent 2 Years Personal Federal Tax Returns',
            'Income',
            'Self-Employed Borrowers - Commonly Requested',
            'Purchase',
            'Self Employed',
            null,
            60
        );
        createReference(
            'Initial Submission',
            'Income',
            'Social Security Award Letter',
            'Income',
            'Retired Borrowers - Commonly Requested',
            'Refinance',
            'Retired',
            null,
            70
        );

        Test.startTest();
        List<LeadPresetConditionSelectorController.PresetConditionItem> purchaseW2Items =
            LeadPresetConditionSelectorController.getPresetConditions('Purchase', null, null);
        List<LeadPresetConditionSelectorController.PresetConditionItem> refinanceW2Items =
            LeadPresetConditionSelectorController.getPresetConditions('Refinance', null, null);
        Test.stopTest();

        Set<String> purchaseLabels = new Set<String>();
        Map<String, LeadPresetConditionSelectorController.PresetConditionItem> purchaseItemsByLabel =
            new Map<String, LeadPresetConditionSelectorController.PresetConditionItem>();
        for (LeadPresetConditionSelectorController.PresetConditionItem item : purchaseW2Items) {
            purchaseLabels.add(item.label);
            purchaseItemsByLabel.put(item.label, item);
        }

        System.assert(purchaseLabels.contains('Government-issued photo ID (Driver\'s License or State ID)'));
        System.assert(purchaseLabels.contains('Permanent Resident Card'));
        System.assert(purchaseLabels.contains('Most Recent 30 Days Paystubs'));
        System.assert(purchaseLabels.contains('Lease Agreements'));
        System.assert(purchaseLabels.contains('Most Recent 2 Months Bank Statements'));
        System.assert(purchaseLabels.contains('Most Recent Investment/Retirement Account Statements'));
        System.assert(!purchaseLabels.contains('Documentation for Any Large Deposits'));
        System.assert(purchaseLabels.contains('Gift Fund Documentation (if applicable)'));
        System.assert(purchaseLabels.contains('Real Estate Owned'));
        System.assert(purchaseLabels.contains('Most Recent 2 Years Personal Federal Tax Returns'));
        System.assert(purchaseLabels.contains('Social Security Award Letter'));
        System.assertEquals(
            true,
            purchaseItemsByLabel.get('Government-issued photo ID (Driver\'s License or State ID)').defaultSelected
        );
        System.assertEquals(false, purchaseItemsByLabel.get('Permanent Resident Card').defaultSelected);
        System.assertEquals(false, purchaseItemsByLabel.get('Most Recent 30 Days Paystubs').defaultSelected);
        System.assertEquals(false, purchaseItemsByLabel.get('Most Recent 2 Years Personal Federal Tax Returns').defaultSelected);
        System.assertEquals(false, purchaseItemsByLabel.get('Social Security Award Letter').defaultSelected);
        System.assertEquals(false, purchaseItemsByLabel.get('Lease Agreements').defaultSelected);
        System.assertEquals(true, purchaseItemsByLabel.get('Most Recent 2 Months Bank Statements').defaultSelected);
        System.assertEquals(true, purchaseItemsByLabel.get('Most Recent Investment/Retirement Account Statements').defaultSelected);
        System.assertEquals(false, purchaseItemsByLabel.get('Gift Fund Documentation (if applicable)').defaultSelected);
        System.assertEquals(
            'Identification',
            purchaseItemsByLabel.get('Government-issued photo ID (Driver\'s License or State ID)').section
        );
        System.assertEquals('Special Income Types', purchaseItemsByLabel.get('Lease Agreements').section);
        System.assertEquals(
            'Additional Asset Documentation',
            purchaseItemsByLabel.get('Gift Fund Documentation (if applicable)').section
        );
        System.assertEquals('Other Items', purchaseItemsByLabel.get('Real Estate Owned').section);

        Set<String> refinanceLabels = new Set<String>();
        for (LeadPresetConditionSelectorController.PresetConditionItem item : refinanceW2Items) {
            refinanceLabels.add(item.label);
        }
        System.assert(!refinanceLabels.contains('Most Recent 2 Months Bank Statements'));
        System.assert(refinanceLabels.contains('Most Recent 30 Days Paystubs'));
        System.assert(refinanceLabels.contains('Most Recent 2 Years Personal Federal Tax Returns'));
        System.assert(refinanceLabels.contains('Social Security Award Letter'));
        System.assert(refinanceLabels.contains('Real Estate Owned'));
        System.assertEquals(
            idReference.Id,
            purchaseItemsByLabel.get('Government-issued photo ID (Driver\'s License or State ID)').id
        );
    }

    @IsTest
    static void createSelectedConditionKeysCreatesLoanOfficerRequests() {
        Lead leadRecord = new Lead(
            FirstName = 'Preset',
            LastName = 'Borrower',
            Company = 'Preset Borrower',
            Status = 'New',
            Email = 'preset@example.com'
        );
        insert leadRecord;
        Lead_Document_Request_Reference__c referenceRecord = createReference(
            'Initial Submission',
            'Income',
            'Most Recent 30 Days Paystubs',
            'Income',
            'W-2 Borrowers - Commonly Requested',
            'Purchase',
            'W2',
            null,
            10
        );

        Test.startTest();
        LeadPresetConditionSelectorController.SaveResponse response =
            LeadPresetConditionSelectorController.createSelectedConditionKeys(
                leadRecord.Id,
                new List<String>{ String.valueOf(referenceRecord.Id), 'OTHER_REAL_ESTATE_OWNED' }
            );
        Test.stopTest();

        List<Lead_Document_Request__c> createdRequests = [
            SELECT Name, Type__c, Category__c, Description__c, Lead_Document_Request_Reference__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
        ];
        Map<String, Lead_Document_Request__c> requestsByDescription = new Map<String, Lead_Document_Request__c>();
        for (Lead_Document_Request__c requestRecord : createdRequests) {
            requestsByDescription.put(requestRecord.Description__c, requestRecord);
        }

        System.assert(response.createdCount >= 2);
        System.assertEquals('Income', requestsByDescription.get('Most Recent 30 Days Paystubs').Name);
        System.assertEquals('Loan Officer', requestsByDescription.get('Most Recent 30 Days Paystubs').Type__c);
        System.assertEquals(
            referenceRecord.Id,
            requestsByDescription.get('Most Recent 30 Days Paystubs').Lead_Document_Request_Reference__c
        );
        System.assertEquals('Other Items', requestsByDescription.get(
            'Real Estate Owned - Please upload the current mortgage statement and insurance declaration page for any real estate property currently owned, if applicable.'
        ).Name);
        System.assertEquals('Loan Officer', requestsByDescription.get(
            'Real Estate Owned - Please upload the current mortgage statement and insurance declaration page for any real estate property currently owned, if applicable.'
        ).Type__c);
        System.assertEquals('REO', requestsByDescription.get(
            'Real Estate Owned - Please upload the current mortgage statement and insurance declaration page for any real estate property currently owned, if applicable.'
        ).Category__c);
        System.assert(
            requestsByDescription.get(
                'Real Estate Owned - Please upload the current mortgage statement and insurance declaration page for any real estate property currently owned, if applicable.'
            ).Description__c.contains('mortgage statement and insurance declaration page')
        );
        System.assert(!requestsByDescription.containsKey('Mortgage Statement'));
        System.assert(!requestsByDescription.containsKey('Insurance'));
    }

    private static Lead_Document_Request_Reference__c createReference(
        String type,
        String borrowerLabel,
        String borrowerDescription,
        String category,
        String packageName,
        String loanPurpose,
        String employmentType,
        String selfEmploymentType,
        Decimal sortOrder
    ) {
        String keySource = String.isBlank(borrowerDescription) ? borrowerLabel : borrowerDescription;
        Lead_Document_Request_Reference__c referenceRecord = new Lead_Document_Request_Reference__c(
            Active__c = true,
            Borrower_Label__c = borrowerLabel,
            Borrower_Description__c = borrowerDescription,
            Category__c = category,
            Package__c = packageName,
            Type__c = type,
            Loan_Purpose__c = loanPurpose,
            Employment_Type__c = employmentType,
            Self_Employment_Type__c = selfEmploymentType,
            Condition_Group_Key__c = keySource.replace(' ', '_'),
            Reference_Id__c = type.replace(' ', '_') + '_' + keySource.replace(' ', '_'),
            Sort_Order__c = sortOrder,
            Include_In_Email__c = true,
            Can_Borrower_See__c = true
        );
        insert referenceRecord;
        return referenceRecord;
    }
}
