public inherited sharing class LeadDocumentRequestRepository {
    private static LeadDocumentRequestRepository self;

    public static LeadDocumentRequestRepository getInstance() {
        if (self == null) {
            self = new LeadDocumentRequestRepository();
        }
        return self;
    }

    public Map<Id, Lead> selectLeadsByIds(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new Map<Id, Lead>();
        }

        String query = buildLeadPortalQuery('Id IN :leadIds', 'WITH USER_MODE');
        return new Map<Id, Lead>((List<Lead>) Database.query(query));
    }

    public Map<Id, Lead> selectLeadsForPortalHash(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new Map<Id, Lead>();
        }

        String fields = hasLeadField('Portal_Hash_Parameter__c') ? 'Id, Portal_Hash_Parameter__c' : 'Id';
        return new Map<Id, Lead>((List<Lead>) Database.query(
            'SELECT ' + fields + ' FROM Lead WHERE Id IN :leadIds WITH USER_MODE'
        ));
    }

    public Lead selectLeadByPortalHash(String portalHash) {
        if (String.isBlank(portalHash) || !hasLeadField('Portal_Hash_Parameter__c')) {
            return null;
        }

        String query = buildLeadPortalQuery('Portal_Hash_Parameter__c = :portalHash', 'WITH SYSTEM_MODE LIMIT 1');
        List<Lead> leads = (List<Lead>) Database.query(query);
        return leads.isEmpty() ? null : leads[0];
    }

    public List<Lead_Document_Request__c> selectByLeadIds(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new List<Lead_Document_Request__c>();
        }

        return [
            SELECT Id, Name, Lead__c, Owner.Name, Status__c, Description__c, Internal_Notes__c,
                   Comments__c, Subject__c, Category__c,
                   Type__c, Requested_Date__c, Include_In_Email__c, Can_Borrower_See__c,
                   Converted_Condition__c, Lead_Document_Request_Reference__c,
                   Lead_Document_Request_Reference__r.Condition_Group_Key__c, CreatedDate
            FROM Lead_Document_Request__c
            WHERE Lead__c IN :leadIds
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    public List<Lead_Document_Request__c> selectVisibleByLeadId(Id leadId) {
        if (leadId == null) {
            return new List<Lead_Document_Request__c>();
        }

        return [
            SELECT Id, Name, Lead__c, Owner.Name, Status__c, Description__c, Internal_Notes__c,
                   Comments__c, Subject__c, Category__c,
                   Type__c, Requested_Date__c, Include_In_Email__c, Can_Borrower_See__c,
                   Converted_Condition__c, Lead_Document_Request_Reference__c,
                   Lead_Document_Request_Reference__r.Condition_Group_Key__c, CreatedDate
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadId
            AND Can_Borrower_See__c = TRUE
            AND Status__c != 'Approved'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    public Lead_Document_Request__c selectRequestForPortalUpload(Id requestId) {
        if (requestId == null) {
            return null;
        }

        List<Lead_Document_Request__c> requests = [
            SELECT Id, Name, Lead__c, Owner.Name, Status__c, Description__c, Internal_Notes__c,
                   Comments__c, Subject__c, Category__c,
                   Type__c, Requested_Date__c, Include_In_Email__c, Can_Borrower_See__c,
                   Converted_Condition__c, Lead_Document_Request_Reference__c,
                   Lead_Document_Request_Reference__r.Condition_Group_Key__c, CreatedDate
            FROM Lead_Document_Request__c
            WHERE Id = :requestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0];
    }

    public Lead_Document_Request__c selectGenericUploadRequest(Id leadId, String requestName) {
        if (leadId == null || String.isBlank(requestName)) {
            return null;
        }

        List<Lead_Document_Request__c> requests = [
            SELECT Id, Name, Lead__c, Status__c, Subject__c, Description__c, Internal_Notes__c,
                   Comments__c, Category__c,
                   Type__c, Can_Borrower_See__c, Include_In_Email__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadId
            AND Name = :requestName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0];
    }

    public Lead selectFirstLeadWithPortalHash() {
        if (!hasLeadField('Portal_Hash_Parameter__c')) {
            return null;
        }

        String query = buildLeadPortalQuery('Portal_Hash_Parameter__c != NULL', 'WITH SYSTEM_MODE LIMIT 1');
        List<Lead> leads = (List<Lead>) Database.query(query);
        return leads.isEmpty() ? null : leads[0];
    }

    public List<Lead_Document_Request__c> selectIncludedForEmail(Id leadId) {
        if (leadId == null) {
            return new List<Lead_Document_Request__c>();
        }

        return [
            SELECT Id, Name, Lead__c, Status__c, Description__c, Internal_Notes__c,
                   Comments__c, Subject__c, Category__c,
                   Type__c, Requested_Date__c, Include_In_Email__c, Can_Borrower_See__c,
                   Converted_Condition__c, Lead_Document_Request_Reference__c,
                   Lead_Document_Request_Reference__r.Condition_Group_Key__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadId
            AND Include_In_Email__c = TRUE
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    public List<Lead_Document_Request__c> selectUnconvertedByLeadIds(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new List<Lead_Document_Request__c>();
        }

        return [
            SELECT Id, Name, Lead__c, Status__c, Description__c, Internal_Notes__c,
                   Comments__c, Subject__c, Category__c,
                   Type__c, Requested_Date__c, Include_In_Email__c, Can_Borrower_See__c,
                   Converted_Condition__c, Lead_Document_Request_Reference__c,
                   Lead_Document_Request_Reference__r.Condition_Group_Key__c
            FROM Lead_Document_Request__c
            WHERE Lead__c IN :leadIds
            AND Converted_Condition__c = NULL
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    public Map<Id, Decimal> selectLinkedDocumentCountsByRequestIds(Set<Id> requestIds) {
        Map<Id, Decimal> countsByRequestId = new Map<Id, Decimal>();
        if (requestIds == null || requestIds.isEmpty()) {
            return countsByRequestId;
        }

        for (AggregateResult result : [
            SELECT LinkedEntityId requestId, COUNT(Id) fileCount
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :requestIds
            GROUP BY LinkedEntityId
        ]) {
            countsByRequestId.put((Id) result.get('requestId'), (Decimal) result.get('fileCount'));
        }
        return countsByRequestId;
    }

    public List<ContentVersion> selectContentVersionsByLatestIds(Set<Id> contentVersionIds) {
        if (contentVersionIds == null || contentVersionIds.isEmpty()) {
            return new List<ContentVersion>();
        }

        return [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
            WITH SYSTEM_MODE
        ];
    }

    public List<ContentVersion> selectLatestContentVersionsByDocumentIds(Set<Id> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return new List<ContentVersion>();
        }

        return [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND IsLatest = TRUE
            WITH SYSTEM_MODE
        ];
    }

    public List<ContentDocumentLink> selectDocumentLinksByEntityIds(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<ContentDocumentLink>();
        }

        return [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
            WITH SYSTEM_MODE
        ];
    }

    public List<ContentDocument> selectDocumentsByLinkedEntityId(Id entityId) {
        if (entityId == null) {
            return new List<ContentDocument>();
        }

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : selectDocumentLinksByEntityIds(new Set<Id>{ entityId })) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        if (contentDocumentIds.isEmpty()) {
            return new List<ContentDocument>();
        }

        String versionFields = 'LatestPublishedVersion.ContentSize, LatestPublishedVersion.Folder__c';
        if (Schema.SObjectType.ContentVersion.fields.getMap().containsKey('Condition_Document_Review_Status__c')) {
            versionFields += ', LatestPublishedVersion.Condition_Document_Review_Status__c';
        }

        String query =
            'SELECT Id, Title, FileExtension, CreatedDate, CreatedBy.Name, LatestPublishedVersionId, ' +
            versionFields +
            ' FROM ContentDocument WHERE Id IN :contentDocumentIds WITH SYSTEM_MODE ORDER BY CreatedDate DESC';
        return (List<ContentDocument>) Database.query(query);
    }

    public EmailTemplate selectEmailTemplateByDeveloperName(String developerName) {
        if (String.isBlank(developerName)) {
            return null;
        }

        List<EmailTemplate> templates = [
            SELECT Id, DeveloperName, Subject, HtmlValue, Body
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
            WITH USER_MODE
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0];
    }

    public Id selectOrgWideEmailAddressId(String address) {
        if (String.isBlank(address)) {
            return null;
        }

        List<OrgWideEmailAddress> addresses = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :address
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return addresses.isEmpty() ? null : addresses[0].Id;
    }

    public Map<Id, User> selectUsersByIds(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new Map<Id, User>();
        }

        return new Map<Id, User>([
            SELECT Id, FirstName, LastName, Name, Email, Phone, MobilePhone, Title,
                   Fax, Headshot_URL__c, NMLS__c
            FROM User
            WHERE Id IN :userIds
            WITH SYSTEM_MODE
        ]);
    }

    public Boolean hasLeadPortalHashField() {
        return hasLeadField('Portal_Hash_Parameter__c');
    }

    public Boolean hasLeadPortalLinkField() {
        return hasLeadField('Lead_Portal_Link_As_URL__c');
    }

    private static String buildLeadPortalQuery(String whereClause, String accessAndLimitClause) {
        List<String> fields = new List<String>{
            'Id', 'Name', 'FirstName', 'LastName', 'Email', 'OwnerId', 'IsConverted', 'Converted_Transaction_ID__c'
        };
        if (hasLeadField('Portal_Hash_Parameter__c')) {
            fields.add('Portal_Hash_Parameter__c');
        }
        if (hasLeadField('Lead_Portal_Link_As_URL__c')) {
            fields.add('Lead_Portal_Link_As_URL__c');
        }
        if (hasLeadField('Loan_Partner__c')) {
            fields.add('Loan_Partner__c');
        }

        return 'SELECT ' + String.join(fields, ',') +
            ' FROM Lead WHERE ' + whereClause + ' ' + accessAndLimitClause;
    }

    private static Boolean hasLeadField(String fieldApiName) {
        if (Test.isRunningTest()) {
            return false;
        }
        return Schema.SObjectType.Lead.fields.getMap().containsKey(fieldApiName);
    }
}