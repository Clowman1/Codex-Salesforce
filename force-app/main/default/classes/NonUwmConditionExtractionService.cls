public with sharing class NonUwmConditionExtractionService {
    private class FileTooLargeException extends Exception {
    }

    private static final String OPEN_AI_SETTING_NAME = 'Non_UWM_Condition_Import';
    private static final String DEFAULT_TYPE = 'Processor';
    private static final String DEFAULT_STATUS = 'New';
    private static final String DEFAULT_CATEGORY = 'Generic';
    @TestVisible 
    private static Integer maxDirectPdfBytes = 4 * 1024 * 1024;
    @TestVisible
    private static List<NonUwmConditionImportDtos.ConditionDraft> testExtractedConditionsOverride;

    public static NonUwmConditionImportDtos.ExtractionResponse extract(Id opportunityId, List<Id> contentDocumentIds) {
        NonUwmConditionImportDtos.ExtractionResponse response = new NonUwmConditionImportDtos.ExtractionResponse();
        response.success = true;
        response.userMessage = 'Extraction completed.';

        if (opportunityId == null) {
            response.success = false;
            response.errorCode = 'MISSING_OPPORTUNITY';
            response.userMessage = 'Loan context is required to extract conditions.';
            response.errors.add(response.userMessage);
            return response;
        }

        Set<Id> documentIdSet = new Set<Id>(contentDocumentIds == null ? new List<Id>() : contentDocumentIds);
        if (documentIdSet.isEmpty()) {
            response.globalMessage = 'No files selected. Please upload at least one PDF.';
            return response;
        }

        NonUwmLoanConditionRepository repo = new NonUwmLoanConditionRepository();
        List<ContentVersion> versions = repo.selectLatestContentVersionsByDocumentIds(documentIdSet);

        Set<String> existingKeys = new Set<String>();
        for (TransactionCondition__c existing : repo.selectExistingConditionsByOpportunity(opportunityId)) {
            existingKeys.add(buildConditionKey(existing.Description__c, existing.Type__c));
        }
        Set<String> sessionKeys = new Set<String>();

        OpenAI_Integration_Setting__mdt setting = repo.selectOpenAiSettingByDeveloperName(OPEN_AI_SETTING_NAME);

        for (ContentVersion version : versions) {
            NonUwmConditionImportDtos.ExtractionFileResult fileResult = new NonUwmConditionImportDtos.ExtractionFileResult();
            fileResult.contentDocumentId = version.ContentDocumentId;
            fileResult.fileName = version.Title;

            try {
                enforcePdfSizeLimit(version.VersionData, version.Title);

                List<NonUwmConditionImportDtos.ConditionDraft> extractedConditions = getExtractedConditions(
                    setting,
                    version.VersionData,
                    version.Title
                );
                if (extractedConditions.isEmpty()) {
                    extractedConditions = parseFallbackConditions(version.Title);
                }

                for (NonUwmConditionImportDtos.ConditionDraft draft : extractedConditions) {
                    hydrateDraftDefaults(draft, version);
                    String key = buildConditionKey(draft.description, draft.type);
                    if (existingKeys.contains(key)) {
                        draft.isDuplicate = true;
                        draft.duplicateReason = 'Already exists on this loan (Description + Type).';
                    } else if (sessionKeys.contains(key)) {
                        draft.isDuplicate = true;
                        draft.duplicateReason = 'Duplicate in this upload session (Description + Type).';
                    } else {
                        sessionKeys.add(key);
                        draft.isDuplicate = false;
                    }
                    response.conditions.add(draft);
                }

                fileResult.success = true;
                fileResult.message = extractedConditions.isEmpty()
                    ? 'No conditions detected. Manual entry is available.'
                    : 'Extracted ' + extractedConditions.size() + ' condition(s).';
            } catch (Exception ex) {
                fileResult.success = false;
                fileResult.message = ex instanceof FileTooLargeException
                    ? ex.getMessage()
                    : 'Extraction failed. Manual entry is available for this file.';
                response.errors.add('File ' + version.Title + ': ' + ex.getMessage());
            }

            response.files.add(fileResult);
        }

        if (response.conditions.isEmpty()) {
            response.globalMessage = 'No conditions extracted. You can manually add conditions before import.';
        }

        return response;
    }

    private static List<NonUwmConditionImportDtos.ConditionDraft> getExtractedConditions(
        OpenAI_Integration_Setting__mdt setting,
        Blob pdfData,
        String fileName
    ) {
        if (Test.isRunningTest() && testExtractedConditionsOverride != null) {
            return cloneDrafts(testExtractedConditionsOverride);
        }

        return fromAi(setting, pdfData, fileName);
    }

    private static List<NonUwmConditionImportDtos.ConditionDraft> cloneDrafts(
        List<NonUwmConditionImportDtos.ConditionDraft> sourceDrafts
    ) {
        List<NonUwmConditionImportDtos.ConditionDraft> clonedDrafts = new List<NonUwmConditionImportDtos.ConditionDraft>();
        for (NonUwmConditionImportDtos.ConditionDraft sourceDraft : sourceDrafts) {
            NonUwmConditionImportDtos.ConditionDraft clone = new NonUwmConditionImportDtos.ConditionDraft();
            clone.clientKey = sourceDraft.clientKey;
            clone.sourceContentDocumentId = sourceDraft.sourceContentDocumentId;
            clone.sourceFileName = sourceDraft.sourceFileName;
            clone.name = sourceDraft.name;
            clone.description = sourceDraft.description;
            clone.type = sourceDraft.type;
            clone.status = sourceDraft.status;
            clone.category = sourceDraft.category;
            clone.assignedToId = sourceDraft.assignedToId;
            clone.canBorrowerSee = sourceDraft.canBorrowerSee;
            clone.includeInEmail = sourceDraft.includeInEmail;
            clone.confidence = sourceDraft.confidence;
            clone.isDuplicate = sourceDraft.isDuplicate;
            clone.duplicateReason = sourceDraft.duplicateReason;
            clone.selected = sourceDraft.selected;
            clonedDrafts.add(clone);
        }

        return clonedDrafts;
    }

    private static List<NonUwmConditionImportDtos.ConditionDraft> fromAi(
        OpenAI_Integration_Setting__mdt setting,
        Blob pdfData,
        String fileName
    ) {
        List<NonUwmConditionImportDtos.ConditionDraft> drafts = new List<NonUwmConditionImportDtos.ConditionDraft>();
        if (setting == null || pdfData == null) {
            return drafts;
        }

        List<Map<String, Object>> aiItems = NonUwmOpenAIGateway.parseConditionsFromPdf(
            pdfData,
            fileName,
            setting.Model__c,
            setting.Instructions__c,
            setting.Request__c
        );

        for (Map<String, Object> row : aiItems) {
            NonUwmConditionImportDtos.ConditionDraft draft = new NonUwmConditionImportDtos.ConditionDraft();
            draft.name = asString(row, 'name');
            draft.description = asString(row, 'description');
            draft.type = asString(row, 'type');
            draft.status = asString(row, 'status');
            draft.category = asString(row, 'category');
            draft.confidence = asDecimal(row, 'confidence');
            drafts.add(draft);
        }
        return drafts;
    } 

    private static void enforcePdfSizeLimit(Blob pdfData, String fileName) {
        Integer fileSize = pdfData == null ? 0 : pdfData.size();
        if (fileSize > maxDirectPdfBytes) {
            String displayName = String.isBlank(fileName) ? 'PDF' : fileName;
            throw new FileTooLargeException(
                displayName +
                ' exceeds the AI extraction file-size limit. Split or compress this PDF and retry.'
            );
        }
    }

    @TestVisible
    private static List<NonUwmConditionImportDtos.ConditionDraft> parseFallbackConditions(String extractedText) {
        List<NonUwmConditionImportDtos.ConditionDraft> drafts = new List<NonUwmConditionImportDtos.ConditionDraft>();
        if (String.isBlank(extractedText)) {
            return drafts;
        }

        List<String> lines = extractedText.split('[\\n\\r]+');
        Integer added = 0;
        for (String line : lines) {
            String normalized = normalizeSpaces(line);
            if (String.isBlank(normalized) || normalized.length() < 8) {
                continue;
            }
            if (normalized.length() > 1000) {
                normalized = normalized.substring(0, 1000);
            }

            NonUwmConditionImportDtos.ConditionDraft draft = new NonUwmConditionImportDtos.ConditionDraft();
            draft.description = normalized;
            draft.name = normalized.length() > 80 ? normalized.substring(0, 80) : normalized;
            draft.category = inferCategory(normalized);
            draft.confidence = 60;
            drafts.add(draft);
            added++;

            if (added >= 20) {
                break;
            }
        }

        return drafts;
    }

    private static void hydrateDraftDefaults(NonUwmConditionImportDtos.ConditionDraft draft, ContentVersion version) {
        if (draft == null) {
            return;
        }

        draft.clientKey = Crypto.getRandomLong() + '-' + String.valueOf(Datetime.now().getTime());
        draft.sourceContentDocumentId = version.ContentDocumentId;
        draft.sourceFileName = version.Title;
        draft.selected = true;
        draft.canBorrowerSee = draft.canBorrowerSee == null ? true : draft.canBorrowerSee;
        draft.includeInEmail = draft.includeInEmail == null ? true : draft.includeInEmail;
        draft.type = String.isBlank(draft.type) ? DEFAULT_TYPE : draft.type;
        draft.status = String.isBlank(draft.status) ? DEFAULT_STATUS : draft.status;
        draft.category = String.isBlank(draft.category) ? DEFAULT_CATEGORY : draft.category;
        draft.description = normalizeSpaces(draft.description);
        if (String.isBlank(draft.name)) {
            draft.name = draft.description;
        }
        if (String.isBlank(draft.name)) {
            draft.name = 'Imported Condition';
        }
        if (draft.name.length() > 80) {
            draft.name = draft.name.substring(0, 80);
        }
        if (draft.confidence == null) {
            draft.confidence = 75;
        }
    }

    public static String buildConditionKey(String description, String type) {
        return normalizeKeyPart(description) + '||' + normalizeKeyPart(type);
    }

    private static String normalizeKeyPart(String value) {
        return String.isBlank(value) ? '' : normalizeSpaces(value).toLowerCase();
    }

    private static String normalizeSpaces(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.replaceAll('\\s+', ' ').trim();
    }

    private static String inferCategory(String description) {
        String lower = description == null ? '' : description.toLowerCase();
        if (
            lower.contains('income') ||
            lower.contains('pay stub') ||
            lower.contains('employment') ||
            lower.contains('w2')
        ) {
            return 'Income';
        }
        if (
            lower.contains('asset') ||
            lower.contains('bank') ||
            lower.contains('statement') ||
            lower.contains('fund')
        ) {
            return 'Assets';
        }
        if (lower.contains('title') || lower.contains('lien')) {
            return 'Title';
        }
        if (lower.contains('insurance')) {
            return 'HOI';
        }
        if (lower.contains('appraisal')) {
            return 'Appraisal';
        }
        return DEFAULT_CATEGORY;
    }

    private static String asString(Map<String, Object> row, String key) {
        if (row == null || !row.containsKey(key) || row.get(key) == null) {
            return null;
        }
        return String.valueOf(row.get(key));
    }

    private static Decimal asDecimal(Map<String, Object> row, String key) {
        String raw = asString(row, key);
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Decimal.valueOf(raw);
        } catch (Exception ex) {
            return null;
        }
    }
}