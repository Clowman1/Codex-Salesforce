public with sharing class NonUwmConditionCreationService {
    private static final String DEFAULT_TYPE = 'Processor';
    private static final String DEFAULT_STATUS = 'New';
    private static final String DEFAULT_CATEGORY = 'Generic';

    public static NonUwmConditionImportDtos.UploadFilesResponse uploadPdfFiles(
        Id opportunityId,
        List<NonUwmConditionImportDtos.FileUploadRequest> files
    ) {
        NonUwmConditionImportDtos.UploadFilesResponse response = new NonUwmConditionImportDtos.UploadFilesResponse();

        if (opportunityId == null) {
            response.errors.add('Loan context is missing.');
            return response;
        }
        if (files == null || files.isEmpty()) {
            response.errors.add('No files were provided.');
            return response;
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<String> inputNames = new List<String>();
        for (NonUwmConditionImportDtos.FileUploadRequest file : files) {
            NonUwmConditionImportDtos.UploadedFileResult fileResult = new NonUwmConditionImportDtos.UploadedFileResult();
            fileResult.fileName = file == null ? null : file.fileName;
            if (file == null || String.isBlank(file.fileName) || String.isBlank(file.base64Data)) {
                fileResult.success = false;
                fileResult.message = 'Invalid file payload.';
                response.files.add(fileResult);
                continue;
            }

            String loweredName = file.fileName.toLowerCase();
            if (!loweredName.endsWith('.pdf')) {
                fileResult.success = false;
                fileResult.message = 'Only PDF files are supported.';
                response.files.add(fileResult);
                continue;
            }

            try {
                String cleanBase64 = file.base64Data.contains(',')
                    ? file.base64Data.substringAfter(',')
                    : file.base64Data;

                ContentVersion version = new ContentVersion();
                version.Title = file.fileName.endsWith('.pdf') ? file.fileName.substring(0, file.fileName.length() - 4) : file.fileName;
                version.PathOnClient = file.fileName;
                version.VersionData = EncodingUtil.base64Decode(cleanBase64);
                version.FirstPublishLocationId = opportunityId;
                versionsToInsert.add(version);
                inputNames.add(file.fileName);
            } catch (Exception ex) {
                fileResult.success = false;
                fileResult.message = 'Could not decode uploaded file.';
                response.files.add(fileResult);
            }
        }

        if (versionsToInsert.isEmpty()) {
            return response;
        }

        insert versionsToInsert;

        NonUwmLoanConditionRepository repo = new NonUwmLoanConditionRepository();
        Map<Id, ContentVersion> insertedVersionsById = new Map<Id, ContentVersion>(
            repo.selectContentVersionsByIds(new Set<Id>(new Map<Id, ContentVersion>(versionsToInsert).keySet()))
        );

        for (Integer i = 0; i < versionsToInsert.size(); i++) {
            ContentVersion insertedVersion = insertedVersionsById.get(versionsToInsert[i].Id);
            NonUwmConditionImportDtos.UploadedFileResult fileResult = new NonUwmConditionImportDtos.UploadedFileResult();
            fileResult.fileName = inputNames[i];
            fileResult.success = true;
            fileResult.contentDocumentId = insertedVersion == null ? null : insertedVersion.ContentDocumentId;
            fileResult.message = 'Uploaded';
            response.files.add(fileResult);
        }

        return response;
    }

    public static NonUwmConditionImportDtos.CreateResponse createConditions(
        Id opportunityId,
        List<NonUwmConditionImportDtos.ConditionDraft> drafts
    ) {
        NonUwmConditionImportDtos.CreateResponse response = new NonUwmConditionImportDtos.CreateResponse();
        response.success = true;

        if (opportunityId == null) {
            response.success = false;
            response.errorCode = 'MISSING_OPPORTUNITY';
            response.userMessage = 'Loan context is required to create conditions.';
            response.errors.add(response.userMessage);
            return response;
        }

        if (drafts == null || drafts.isEmpty()) {
            response.selectedCount = 0;
            response.createdCount = 0;
            response.skippedDuplicateCount = 0;
            response.userMessage = 'No conditions selected for import.';
            return response;
        }

        NonUwmLoanConditionRepository repo = new NonUwmLoanConditionRepository();
        Set<String> existingKeys = new Set<String>();
        for (TransactionCondition__c existing : repo.selectExistingConditionsByOpportunity(opportunityId)) {
            existingKeys.add(NonUwmConditionExtractionService.buildConditionKey(existing.Description__c, existing.Type__c));
        }

        Set<String> batchKeys = new Set<String>();
        List<TransactionCondition__c> toInsert = new List<TransactionCondition__c>();

        for (NonUwmConditionImportDtos.ConditionDraft draft : drafts) {
            if (draft == null || draft.selected == false) {
                continue;
            }
            response.selectedCount = response.selectedCount == null ? 1 : response.selectedCount + 1;

            String description = normalizeSpaces(draft.description);
            String typeValue = String.isBlank(draft.type) ? DEFAULT_TYPE : draft.type;
            String key = NonUwmConditionExtractionService.buildConditionKey(description, typeValue);

            if (existingKeys.contains(key) || batchKeys.contains(key)) {
                NonUwmConditionImportDtos.ConditionDraft skipped = cloneDraftForResponse(draft);
                skipped.isDuplicate = true;
                skipped.duplicateReason = 'Duplicate by Description + Type.';
                response.skippedDuplicates.add(skipped);
                continue;
            }

            batchKeys.add(key);

            TransactionCondition__c conditionToCreate = new TransactionCondition__c();
            //conditionToCreate.Name = String.isBlank(draft.name) ? defaultNameFromDescription(description) : draft.name;
            conditionToCreate.Description__c = description;
            conditionToCreate.Transaction__c = opportunityId;
            conditionToCreate.Type__c = typeValue;
            conditionToCreate.Status__c = String.isBlank(draft.status) ? DEFAULT_STATUS : draft.status;
            conditionToCreate.Category__c = String.isBlank(draft.category) ? DEFAULT_CATEGORY : draft.category;
            //conditionToCreate.imbus__Can_Borrower_See__c = draft.canBorrowerSee == null ? true : draft.canBorrowerSee;
            conditionToCreate.IncludeInEmail__c = draft.includeInEmail == null ? true : draft.includeInEmail;
            conditionToCreate.Assigned_To__c = draft.assignedToId == null ? UserInfo.getUserId() : draft.assignedToId;
            toInsert.add(conditionToCreate);
        }

        response.skippedDuplicateCount = response.skippedDuplicates.size();
        if (toInsert.isEmpty()) {
            response.createdCount = 0;
            response.userMessage = 'No new conditions to create. Duplicates were skipped.';
            return response;
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
        List<SObject> sanitizedRecords = decision.getRecords();
        List<TransactionCondition__c> sanitizedToInsert = new List<TransactionCondition__c>();
        for (SObject recordObj : sanitizedRecords) {
            sanitizedToInsert.add((TransactionCondition__c) recordObj);
        }

        insert sanitizedToInsert;

        for (TransactionCondition__c insertedCondition : sanitizedToInsert) {
            response.recordIdsAffected.add(insertedCondition.Id);
        }
        response.createdCount = sanitizedToInsert.size();
        response.userMessage = 'Created ' + response.createdCount + ' condition(s).';
        return response;
    }

    private static String normalizeSpaces(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.replaceAll('\\s+', ' ').trim();
    }

    private static String defaultNameFromDescription(String description) {
        String normalized = String.isBlank(description) ? 'Imported Condition' : description;
        return normalized.length() > 80 ? normalized.substring(0, 80) : normalized;
    }

    private static NonUwmConditionImportDtos.ConditionDraft cloneDraftForResponse(NonUwmConditionImportDtos.ConditionDraft draft) {
        NonUwmConditionImportDtos.ConditionDraft clone = new NonUwmConditionImportDtos.ConditionDraft();
        clone.clientKey = draft.clientKey;
        clone.sourceContentDocumentId = draft.sourceContentDocumentId;
        clone.sourceFileName = draft.sourceFileName;
        clone.name = draft.name;
        clone.description = draft.description;
        clone.type = draft.type;
        clone.status = draft.status;
        clone.category = draft.category;
        clone.assignedToId = draft.assignedToId;
        clone.canBorrowerSee = draft.canBorrowerSee;
        clone.includeInEmail = draft.includeInEmail;
        clone.confidence = draft.confidence;
        clone.selected = draft.selected;
        return clone;
    }
}