public with sharing class NonUwmConditionImportDtos {
    public class FileUploadRequest {
        @AuraEnabled
        public String fileName { get; set; }
        @AuraEnabled
        public String base64Data { get; set; }
    }

    public class UploadedFileResult {
        @AuraEnabled
        public Id contentDocumentId;
        @AuraEnabled
        public String fileName;
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String message;
    }

    public class UploadFilesResponse {
        @AuraEnabled
        public List<UploadedFileResult> files = new List<UploadedFileResult>();
        @AuraEnabled
        public List<String> errors = new List<String>();
    }

    public class ExtractionFileResult {
        @AuraEnabled
        public Id contentDocumentId;
        @AuraEnabled
        public String fileName;
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String message;
    }

    public class ConditionDraft {
        @AuraEnabled
        public String clientKey { get; set; }
        @AuraEnabled
        public Id sourceContentDocumentId { get; set; }
        @AuraEnabled
        public String sourceFileName { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String category { get; set; }
        @AuraEnabled
        public Id assignedToId { get; set; }
        @AuraEnabled
        public Boolean canBorrowerSee { get; set; }
        @AuraEnabled
        public Boolean includeInEmail { get; set; }
        @AuraEnabled
        public Decimal confidence { get; set; }
        @AuraEnabled
        public Boolean isDuplicate { get; set; }
        @AuraEnabled
        public String duplicateReason { get; set; }
        @AuraEnabled
        public Boolean selected { get; set; }
    }

    public class ExtractionResponse {
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String userMessage;
        @AuraEnabled
        public String errorCode;
        @AuraEnabled
        public String adminMessage;
        @AuraEnabled
        public List<String> errors = new List<String>();
        @AuraEnabled
        public List<Id> recordIdsAffected = new List<Id>();
        @AuraEnabled
        public List<ExtractionFileResult> files = new List<ExtractionFileResult>();
        @AuraEnabled
        public List<ConditionDraft> conditions = new List<ConditionDraft>();
        @AuraEnabled
        public String globalMessage;
    }

    public class CreateResponse {
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String userMessage;
        @AuraEnabled
        public String errorCode;
        @AuraEnabled
        public String adminMessage;
        @AuraEnabled
        public List<String> errors = new List<String>();
        @AuraEnabled
        public List<Id> recordIdsAffected = new List<Id>();
        @AuraEnabled
        public Integer selectedCount;
        @AuraEnabled
        public Integer createdCount;
        @AuraEnabled
        public Integer skippedDuplicateCount;
        @AuraEnabled
        public List<ConditionDraft> skippedDuplicates = new List<ConditionDraft>();
    }
}