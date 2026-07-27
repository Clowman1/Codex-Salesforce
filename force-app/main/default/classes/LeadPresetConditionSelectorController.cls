public with sharing class LeadPresetConditionSelectorController {
    private static final Set<String> INITIAL_TYPES = new Set<String>{
        'Initial Submission',
        'Initial Submission Optional'
    };
    private static final String REAL_ESTATE_OWNED_KEY = 'OTHER_REAL_ESTATE_OWNED';

    public class PresetConditionItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String category;
        @AuraEnabled public String section;
        @AuraEnabled public Boolean defaultSelected;
        @AuraEnabled public Decimal sortOrder;
    }

    public class SaveResponse {
        @AuraEnabled public Integer createdCount;
    }

    @AuraEnabled(cacheable=true)
    public static List<PresetConditionItem> getPresetConditions(
        String loanPurpose,
        String employmentType,
        String selfEmploymentType
    ) {
        List<PresetConditionItem> items = new List<PresetConditionItem>();
        for (Lead_Document_Request_Reference__c referenceRecord : [
            SELECT Id, Name, Active__c, Borrower_Label__c, Borrower_Description__c,
                   Category__c, Package__c, Type__c, Condition_Group_Key__c,
                   Loan_Purpose__c, Loan_Type__c, Employment_Type__c, Self_Employment_Type__c,
                   Reference_Id__c, Sort_Order__c, Include_In_Email__c, Can_Borrower_See__c
            FROM Lead_Document_Request_Reference__c
            WHERE Active__c = TRUE
            AND Type__c IN :INITIAL_TYPES
            WITH SYSTEM_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST, Borrower_Label__c ASC
        ]) {
            if (!shouldInclude(referenceRecord, loanPurpose, employmentType, selfEmploymentType)) {
                continue;
            }
            PresetConditionItem item = new PresetConditionItem();
            item.id = referenceRecord.Id;
            item.key = String.valueOf(referenceRecord.Id);
            item.label = displayLabel(referenceRecord);
            item.description = displayDescription(referenceRecord, item.label);
            item.category = referenceRecord.Category__c;
            item.section = displaySection(referenceRecord);
            item.defaultSelected = shouldDefaultSelect(referenceRecord, item.label);
            item.sortOrder = referenceRecord.Sort_Order__c == null ? 999999 : referenceRecord.Sort_Order__c;
            items.add(item);
        }
        items.add(buildRealEstateOwnedItem());
        return items;
    }

    @AuraEnabled
    public static SaveResponse createSelectedConditions(Id leadId, List<Id> referenceIds) {
        List<LeadDocumentRequestService.RequestItem> created =
            LeadDocumentRequestService.createRequestsFromReferences(leadId, referenceIds, 'Loan Officer');
        SaveResponse response = new SaveResponse();
        response.createdCount = created == null ? 0 : created.size();
        return response;
    }

    @AuraEnabled
    public static SaveResponse createSelectedConditionKeys(Id leadId, List<String> selectedKeys) {
        Set<Id> referenceIds = new Set<Id>();
        Boolean includeRealEstateOwned = false;
        for (String selectedKey : selectedKeys == null ? new List<String>() : selectedKeys) {
            if (String.isBlank(selectedKey)) {
                continue;
            }
            if (selectedKey == REAL_ESTATE_OWNED_KEY) {
                includeRealEstateOwned = true;
                continue;
            }
            try {
                referenceIds.add((Id) selectedKey);
            } catch (Exception ex) {
                // Ignore unknown non-reference keys so one bad option cannot block valid selections.
            }
        }

        List<LeadDocumentRequestService.RequestItem> created = new List<LeadDocumentRequestService.RequestItem>();
        if (!referenceIds.isEmpty()) {
            created.addAll(LeadDocumentRequestService.createRequestsFromReferences(
                leadId,
                new List<Id>(referenceIds),
                'Loan Officer'
            ));
        }
        if (includeRealEstateOwned) {
            created.addAll(LeadDocumentRequestService.saveRequests(
                leadId,
                buildRealEstateOwnedRequests()
            ));
        }
        if (referenceIds.isEmpty() && !includeRealEstateOwned) {
            throw new LeadDocumentRequestService.LeadDocumentRequestException(
                'Select at least one condition before saving.'
            );
        }

        SaveResponse response = new SaveResponse();
        response.createdCount = created == null ? 0 : created.size();
        return response;
    }

    private static Boolean shouldInclude(
        Lead_Document_Request_Reference__c referenceRecord,
        String loanPurpose,
        String employmentType,
        String selfEmploymentType
    ) {
        if (referenceRecord == null || !INITIAL_TYPES.contains(referenceRecord.Type__c)) {
            return false;
        }

        String category = referenceRecord.Category__c;
        String section = referenceRecord.Package__c;
        if (category == 'Assets' || category == 'Gift Letter') {
            return !isLargeDepositReference(referenceRecord)
                && matchesMultiPicklist(referenceRecord.Loan_Purpose__c, loanPurpose);
        }
        if (section == 'Special Income Types') {
            return true;
        }
        if (category == 'Income' || isIncomeSection(section)) {
            return true;
        }
        if (category == 'ID' || String.isBlank(category)) {
            return true;
        }
        if (!matchesMultiPicklist(referenceRecord.Loan_Purpose__c, loanPurpose)) {
            return false;
        }
        if (!matchesMultiPicklist(referenceRecord.Employment_Type__c, employmentType)) {
            return false;
        }
        if (employmentType == 'Self Employed') {
            return matchesMultiPicklist(referenceRecord.Self_Employment_Type__c, selfEmploymentType);
        }
        return true;
    }

    private static Boolean matchesMultiPicklist(String configuredValues, String selectedValue) {
        if (String.isBlank(configuredValues) || String.isBlank(selectedValue)) {
            return true;
        }
        return configuredValues.split(';').contains(selectedValue);
    }

    private static String displayLabel(Lead_Document_Request_Reference__c referenceRecord) {
        String label = referenceRecord.Borrower_Label__c;
        if (isGenericLabel(label) && String.isNotBlank(referenceRecord.Borrower_Description__c)) {
            return referenceRecord.Borrower_Description__c;
        }
        return String.isBlank(label) ? referenceRecord.Name : label;
    }

    private static String displayDescription(Lead_Document_Request_Reference__c referenceRecord, String resolvedLabel) {
        if (String.isBlank(referenceRecord.Borrower_Description__c)) {
            return null;
        }
        return referenceRecord.Borrower_Description__c == resolvedLabel
            ? null
            : referenceRecord.Borrower_Description__c;
    }

    private static Boolean isGenericLabel(String label) {
        return new Set<String>{ 'ID', 'Income', 'Assets', 'Gift Letter', 'WVOE' }.contains(label);
    }

    private static String displaySection(Lead_Document_Request_Reference__c referenceRecord) {
        if (isGiftDocumentationReference(referenceRecord)) {
            return 'Additional Asset Documentation';
        }
        if (String.isBlank(referenceRecord.Package__c)) {
            return 'Identification';
        }
        return referenceRecord.Package__c
            .replace('Identification - Others', 'Identification - Others')
            .replace('Self-Employed Borrowers - Additional Items', 'Self-Employed Borrowers - Additional Self-Employment Items');
    }

    private static Boolean shouldDefaultSelect(
        Lead_Document_Request_Reference__c referenceRecord,
        String resolvedLabel
    ) {
        if (referenceRecord.Type__c != 'Initial Submission') {
            return false;
        }
        if (referenceRecord.Category__c == 'Gift Letter') {
            return false;
        }
        if (referenceRecord.Category__c == 'Assets') {
            return isDefaultAssetReference(referenceRecord, resolvedLabel);
        }
        return referenceRecord.Category__c == 'ID' || isCommonIdentificationReference(referenceRecord, resolvedLabel);
    }

    private static Boolean isIncomeSection(String section) {
        if (String.isBlank(section)) {
            return false;
        }
        String normalizedSection = section.toLowerCase();
        return normalizedSection.contains('w-2')
            || normalizedSection.contains('w2')
            || normalizedSection.contains('self-employed')
            || normalizedSection.contains('retired')
            || normalizedSection.contains('special income');
    }

    private static Boolean isDefaultAssetReference(
        Lead_Document_Request_Reference__c referenceRecord,
        String resolvedLabel
    ) {
        String normalizedText = normalizeText(
            resolvedLabel + ' ' + referenceRecord.Borrower_Description__c + ' ' + referenceRecord.Name
        );
        return normalizedText.contains('2 months bank statements')
            || normalizedText.contains('two months bank statements')
            || (
                normalizedText.contains('investment')
                && normalizedText.contains('retirement')
            );
    }

    private static Boolean isLargeDepositReference(Lead_Document_Request_Reference__c referenceRecord) {
        String normalizedText = normalizeText(
            referenceRecord.Borrower_Label__c + ' ' +
            referenceRecord.Borrower_Description__c + ' ' +
            referenceRecord.Name
        );
        return normalizedText.contains('large deposit');
    }

    private static Boolean isGiftDocumentationReference(Lead_Document_Request_Reference__c referenceRecord) {
        String normalizedText = normalizeText(
            referenceRecord.Borrower_Label__c + ' ' +
            referenceRecord.Borrower_Description__c + ' ' +
            referenceRecord.Name
        );
        return referenceRecord.Category__c == 'Gift Letter' || normalizedText.contains('gift');
    }

    private static Boolean isCommonIdentificationReference(
        Lead_Document_Request_Reference__c referenceRecord,
        String resolvedLabel
    ) {
        String normalizedText = normalizeText(
            resolvedLabel + ' ' +
            referenceRecord.Borrower_Label__c + ' ' +
            referenceRecord.Borrower_Description__c + ' ' +
            referenceRecord.Name
        );
        return normalizedText.contains('government-issued photo id')
            || normalizedText.contains('government issued photo id')
            || (
                normalizedText.contains('driver')
                && normalizedText.contains('license')
            )
            || normalizedText.contains('state id');
    }

    private static String normalizeText(String value) {
        return String.isBlank(value) ? '' : value.toLowerCase();
    }

    private static PresetConditionItem buildRealEstateOwnedItem() {
        PresetConditionItem item = new PresetConditionItem();
        item.key = REAL_ESTATE_OWNED_KEY;
        item.label = 'Real Estate Owned';
        item.description = 'Mortgage Statement (if applicable) and Insurance (if applicable) for each real estate property currently owned.';
        item.category = 'Other Items';
        item.section = 'Other Items';
        item.defaultSelected = false;
        item.sortOrder = 900000;
        return item;
    }

    private static List<LeadDocumentRequestService.RequestInput> buildRealEstateOwnedRequests() {
        return new List<LeadDocumentRequestService.RequestInput>{
            buildManualRequest(
                'Other Items',
                'Real Estate Owned - Please upload the current mortgage statement and insurance declaration page for any real estate property currently owned, if applicable.'
            )
        };
    }

    private static LeadDocumentRequestService.RequestInput buildManualRequest(String name, String description) {
        LeadDocumentRequestService.RequestInput input = new LeadDocumentRequestService.RequestInput();
        input.name = name;
        input.subject = name;
        input.description = description;
        input.category = 'REO';
        input.type = 'Loan Officer';
        input.includeInEmail = true;
        input.canBorrowerSee = true;
        return input;
    }
}
