/**
 * Created by toma on 11/9/2022.
 */

public class ValueLinkController {
    private static final Set<String> VALUE_LINK_OUTSIDE_LO_CONTACT_NAMES = new Set<String>{
        'Edgard Gonzalez',
        'Harold Ellis'
    };

    public static Map<String,String> loanTypeMap = new Map<String,String>{
            'CONV' => 'Conventional',
            'JUMBO' => 'Jumbo',
            'Conventional' => 'Conventional',
            'FHA' => 'FHA',
            'Jumbo' => 'Jumbo',
            'VA' => 'VA',
            'NonQM' => 'Conventional',
            'Other' => 'Other (please specify)', //??
            'FarmersHomeAdministration' => 'USDA / Rural Housing Service' //??
    };
    public static Map<String,String> loanPurposeMap = new Map<String,String>{
        'Purchase' => 'Purchase',
        'Refinance Cash-Out' => 'Re-Finance',
        'Refinance Rate & Term' => 'Re-Finance',
        'HELOC' => 'HELOC',
        'Cash-Out Refinance' => 'Re-Finance',
        'NoCash-Out Refinance' => 'Re-Finance',
        'Refinance' => 'Re-Finance',
        'Refinance No Cash-Out' => 'Re-Finance',
        'Refinance Debt Consolidation'=>'Re-Finance'
    };
    public static Map<String,String> propertyTypeMap = new Map<String,String>{
            'Single Family' => 'Single Family Residential',
            'Single Family Residence' => 'Single Family Residential',
            'SingleFamily' => 'Single Family Residential',
            'Condo' => 'Condominium',
            'Condominium' => 'Condominium',
            'Town House' => 'Townhome',
            '1 Unit' => 'Multi-Unit Property', //? ask adam if this should also count as multi unit property
            '2-4 Units' => 'Multi-Unit Property',
            '2-4 Unit Dwelling' => 'Multi-Unit Property',
            '4-10 Units' => 'Multi-Unit Property',
            '10+ Units' => 'Multi-Unit Property',
            'PUD' => 'Planned Unit Development (PUD)',
            'Planned Unit Development' => 'Planned Unit Development (PUD)',
            'Mobile Home' => 'Mobile Home',
            'Land' => 'Land'
    };
    @AuraEnabled
    public static void createDTORequest(String recordId){
        Loan l = LoanRepository.getInstance().getLoanById(recordId);
        ValueLinkSoapService.OrderRequestDTO requestDTO = buildOrderRequest(l);
        if(l.getProcessorName() != null) {
            requestDTO.processorUsername = getProcessorUsername(l.getProcessorName());
        }
        String apiUsername = getAPIUsername();
        String apiPassword = getAPIPassword();
        ValueLinkSoapService.SubmitSSO(apiUsername, apiPassword, requestDTO);
    }

    @AuraEnabled(cacheable=true)
    public static OrderActionModel getOrderActionModel(String recordId) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Missing Transaction Id.');
        }
        Transaction__c transactionRecord = [
            SELECT Id, Name, Processor__c, Additional_Processor__c, Loan_Type_1st_TD__c, FHA_Case_Number__c, ValueLink_Appraisal_Type__c
            FROM Transaction__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        OrderActionModel model = new OrderActionModel();
        model.transactionId = transactionRecord.Id;
        model.transactionName = transactionRecord.Name;
        model.processorUserId1 = transactionRecord.Processor__c;
        model.processorUserId2 = transactionRecord.Additional_Processor__c;
        model.processorOptions = getValueLinkProcessorOptions();
        model.loanType = transactionRecord.Loan_Type_1st_TD__c;
        model.fhaCaseNumber = transactionRecord.FHA_Case_Number__c;
        model.appraisalType = transactionRecord.ValueLink_Appraisal_Type__c;
        model.appraisalTypeOptions = getValueLinkAppraisalTypeOptions();
        return model;
    }

    @AuraEnabled
    public static OrderActionResult createOrderWithContacts(OrderActionRequest input) {
        return createOrderWithContactsInternal(input);
    }

    @AuraEnabled
    public static OrderActionResult createOrderWithContactValues(
        String loanId,
        String transactionName,
        String processorUserId1,
        String processorUserId2,
        String processorUserId3,
        String fhaCaseNumber,
        String appraisalType,
        String generalComment,
        List<String> contractContentDocumentIds
    ) {
        OrderActionRequest input = new OrderActionRequest();
        input.loanId = loanId;
        input.transactionName = transactionName;
        input.processorUserId1 = processorUserId1;
        input.processorUserId2 = processorUserId2;
        input.processorUserId3 = processorUserId3;
        input.fhaCaseNumber = fhaCaseNumber;
        input.appraisalType = appraisalType;
        input.generalComment = generalComment;
        input.contractContentDocumentIds = contractContentDocumentIds;
        return createOrderWithContactsInternal(input);
    }

    private static OrderActionResult createOrderWithContactsInternal(OrderActionRequest input) {
        Id resolvedLoanId = resolveOrderLoanId(input);
        if (resolvedLoanId == null) {
            throw new AuraHandledException('Missing Transaction Id.');
        }
        input.loanId = String.valueOf(resolvedLoanId);
        Loan l = LoanRepository.getInstance().getLoanById(input.loanId);
        ValueLinkSoapService.OrderRequestDTO requestDTO = buildOrderRequest(l);
        requestDTO.processorUsername = getProcessorUsernameByUserId(input.processorUserId1);
        requestDTO.processorUsername2 = getProcessorUsernameByUserId(input.processorUserId2);
        requestDTO.processorUsername3 = getProcessorUsernameByUserId(input.processorUserId3);
        if (String.isNotBlank(input.appraisalType)) {
            requestDTO.appraisalType = input.appraisalType;
        }
        if (String.isNotBlank(input.fhaCaseNumber)) {
            requestDTO.FHACaseNumber = input.fhaCaseNumber;
        }
        requestDTO.lenderComments = input.generalComment;

        if (String.isBlank(requestDTO.processorUsername)) {
            throw new AuraHandledException('Processor Contact 1 must be a user with ValueLink credentials configured.');
        }
        if (String.isBlank(requestDTO.appraisalType)) {
            throw new AuraHandledException('Appraisal Product is required.');
        }
        Boolean hasContractDocuments = input.contractContentDocumentIds != null && !input.contractContentDocumentIds.isEmpty();
        if (hasContractDocuments) {
            validateContractDocuments(input.contractContentDocumentIds);
        }

        String apiUsername = getAPIUsername();
        String apiPassword = getAPIPassword();
        ValueLinkSoapService.ResponseModel responseModel = ValueLinkSoapService.SubmitSSO(apiUsername, apiPassword, requestDTO);
        saveSelectedAppraisalType(input.loanId, requestDTO.appraisalType);
        if (hasContractDocuments) {
            queueContractDocuments(input.loanId, responseModel, input.contractContentDocumentIds, apiUsername, apiPassword);
        }

        OrderActionResult result = new OrderActionResult();
        result.orderId = responseModel == null ? null : responseModel.orderId;
        result.orderNumber = responseModel == null ? null : responseModel.orderNumber;
        result.message = hasContractDocuments
            ? 'Appraisal order created and contract PDF upload queued for ValueLink.'
            : 'Appraisal order created.';
        return result;
    }

    private static void saveSelectedAppraisalType(String loanId, String appraisalType) {
        if (String.isBlank(loanId) || String.isBlank(appraisalType)) {
            return;
        }
        try {
            update new Transaction__c(
                Id = Id.valueOf(loanId),
                ValueLink_Appraisal_Type__c = appraisalType
            );
        } catch (DmlException e) {
            System.debug(LoggingLevel.WARN, 'Unable to save ValueLink appraisal type to Transaction: ' + e.getMessage());
        }
    }

    private static Id resolveOrderLoanId(OrderActionRequest input) {
        if (input == null) {
            return null;
        }
        if (String.isNotBlank(input.loanId)) {
            return Id.valueOf(input.loanId);
        }
        if (String.isBlank(input.transactionName)) {
            return null;
        }
        List<Transaction__c> transactions = [
            SELECT Id
            FROM Transaction__c
            WHERE Name = :input.transactionName
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return transactions.isEmpty() ? null : transactions[0].Id;
    }

    private static ValueLinkSoapService.OrderRequestDTO buildOrderRequest(Loan l) {
        String loanType = l.getLoanType();
        String transactionType = l.getLoanPurpose();
        String propStreet = l.getPropertyStreet();
        String propState = l.getPropertyState();
        String propCity = l.getPropertyCity();
        String propZip = l.getPropertyZipcode();
        String propCounty = l.getPropertyCounty();
        String loanNumber = l.getLoanNumber();
        String propertyType = l.getPropertyType();
        String appraisalType = l.getAppraisalType();
        String borrowerEmail = l.getPrimaryBorrowerEmail();
        String borrowerFirstName = l.getPrimaryBorrowerFirstName();
        String borrowerLastName = l.getPrimaryBorrowerLastName();
        String borrowerPhone = l.getPrimaryBorrowerPhone();
        //Date dateAppraisalNeeded = l.getDateAppraisalNeeded();
        ValueLinkSoapService.OrderRequestDTO requestDTO = new ValueLinkSoapService.OrderRequestDTO();
        requestDTO.loanType = loanTypeMap.get(loanType);
        requestDTO.loanNumber = loanNumber;
        requestDTO.transactionType = loanPurposeMap.get(transactionType);
        requestDTO.propertyType = propertyTypeMap.get(propertyType);
        requestDTO.subPropState = propState;
        requestDTO.subPropCity = propCity;
        requestDTO.subPropZip = propZip;
        requestDTO.subPropStreet = propStreet;
        requestDTO.subPropCounty = propCounty;
        requestDTO.appraisalType = appraisalType;
        requestDTO.borrowerEmail = borrowerEmail;
        requestDTO.borrowerName = l.getBorrowerName();
        requestDTO.borrowerPhone = borrowerPhone;
        requestDTO.loanID = l.getId();
//        if(dateAppraisalNeeded != null)
//            requestDTO.dateAppraisalNeeded = String.valueOf(dateAppraisalNeeded);
        if(l.getFHACaseNumber() != null)
            requestDTO.FHACaseNumber = l.getFHACaseNumber();
        return requestDTO;
    }
    private static String getProcessorUsername(String processorName){
        String processorUserName = ValueLink_Prod_Creds__c.getInstance(processorName)?.Username__c;
        if(processorUserName != null){
            return processorUserName;
        }else{
            return null;
        }
    }
    @TestVisible
    private static String getProcessorUsernameByUserId(String userId) {
        if (String.isBlank(userId)) {
            return null;
        }
        User selectedUser = [
            SELECT Id, Name, Email
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        List<ValueLink_Prod_Creds__c> exactUserCreds = [
            SELECT Username__c
            FROM ValueLink_Prod_Creds__c
            WHERE SetupOwnerId = :selectedUser.Id
            LIMIT 1
        ];
        if (!exactUserCreds.isEmpty() && String.isNotBlank(exactUserCreds[0].Username__c)) {
            return exactUserCreds[0].Username__c;
        }
        return selectedUser.Email;
    }

    private static List<ProcessorOption> getValueLinkProcessorOptions() {
        List<ProcessorOption> options = new List<ProcessorOption>();
        for (User userRecord : [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            AND (UserType = 'Standard' OR Name IN :VALUE_LINK_OUTSIDE_LO_CONTACT_NAMES)
            ORDER BY Name
            LIMIT 250
        ]) {
            ProcessorOption option = new ProcessorOption();
            option.value = userRecord.Id;
            option.label = userRecord.Name;
            options.add(option);
        }
        return options;
    }

    private static List<ProcessorOption> getValueLinkAppraisalTypeOptions() {
        List<ProcessorOption> options = new List<ProcessorOption>();
        for (Schema.PicklistEntry entry : Transaction__c.ValueLink_Appraisal_Type__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                ProcessorOption option = new ProcessorOption();
                option.value = entry.getValue();
                option.label = entry.getLabel();
                options.add(option);
            }
        }
        return options;
    }

    private static void validateContractDocuments(List<String> contentDocumentIds) {
        Set<Id> documentIds = new Set<Id>();
        for (String contentDocumentId : contentDocumentIds) {
            if (String.isNotBlank(contentDocumentId)) {
                documentIds.add((Id) contentDocumentId);
            }
        }
        List<ContentVersion> contractVersions = [
            SELECT Id, FileExtension
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :documentIds
        ];
        if (contractVersions.isEmpty()) {
            throw new AuraHandledException('The uploaded contract PDF could not be found.');
        }
        for (ContentVersion contractVersion : contractVersions) {
            if (String.valueOf(contractVersion.FileExtension).toLowerCase() != 'pdf') {
                throw new AuraHandledException('Only PDF contract files can be sent with the appraisal order.');
            }
        }
    }

    private static void queueContractDocuments(
        Id loanId,
        ValueLinkSoapService.ResponseModel responseModel,
        List<String> contentDocumentIds,
        String apiUsername,
        String apiPassword
    ) {
        if (responseModel == null || String.isBlank(responseModel.orderId)) {
            throw new AuraHandledException('ValueLink order was created without an Order ID, so the contract PDF could not be posted.');
        }
        System.enqueueJob(new ValueLinkContractPostQueueable(
            loanId,
            responseModel.orderId,
            contentDocumentIds,
            apiUsername,
            apiPassword
        ));
    }

    public static String getAPIUsername(){
        ValueLink_Prod_Creds__c orgDefaultCreds = ValueLink_Prod_Creds__c.getOrgDefaults();
        ValueLink_Prod_Creds__c userDefaultCreds = ValueLink_Prod_Creds__c.getInstance(UserInfo.getUserId());
        if(userDefaultCreds != null){
            return userDefaultCreds.Username__c;
        }else{
            return orgDefaultCreds.Username__c;
        }
    }
    public static String getAPIPassword(){
        ValueLink_Prod_Creds__c orgDefaultCreds = ValueLink_Prod_Creds__c.getOrgDefaults();
        ValueLink_Prod_Creds__c userDefaultCreds = ValueLink_Prod_Creds__c.getInstance(UserInfo.getUserId());
        if(userDefaultCreds != null){
            return userDefaultCreds.Password__c;
        }else{
            return orgDefaultCreds.Password__c;
        }
    }

    public class OrderActionModel {
        @AuraEnabled public String transactionId;
        @AuraEnabled public String transactionName;
        @AuraEnabled public String processorUserId1;
        @AuraEnabled public String processorUserId2;
        @AuraEnabled public String processorUserId3;
        @AuraEnabled public String loanType;
        @AuraEnabled public String fhaCaseNumber;
        @AuraEnabled public String appraisalType;
        @AuraEnabled public List<ProcessorOption> processorOptions;
        @AuraEnabled public List<ProcessorOption> appraisalTypeOptions;
    }

    public class ProcessorOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class OrderActionRequest {
        @AuraEnabled public String loanId;
        @AuraEnabled public String transactionName;
        @AuraEnabled public String processorUserId1;
        @AuraEnabled public String processorUserId2;
        @AuraEnabled public String processorUserId3;
        @AuraEnabled public String fhaCaseNumber;
        @AuraEnabled public String appraisalType;
        @AuraEnabled public String generalComment;
        @AuraEnabled public List<String> contractContentDocumentIds;
    }

    public class OrderActionResult {
        @AuraEnabled public String orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String message;
    }
}
