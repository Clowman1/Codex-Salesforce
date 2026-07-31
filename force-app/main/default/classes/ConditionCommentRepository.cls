public with sharing class ConditionCommentRepository {
    private static ConditionCommentRepository self;

    public static ConditionCommentRepository getInstance() {
        if (self == null) {
            self = new ConditionCommentRepository();
        }
        return self;
    }

    public List<Condition_Comment__c> selectByConditionId(Id conditionId, Boolean includePrivateComments) {
        if (conditionId == null) {
            return new List<Condition_Comment__c>();
        }

        if (includePrivateComments) {
            return [
                SELECT
                    Id,
                    Condition__c,
                    Condition__r.Name,
                    Condition__r.Description__c,
                    Condition__r.Assigned_To__c,
                    Condition__r.Transaction__c,
                    Condition__r.Transaction__r.Name,
                    Condition__r.Transaction__r.Borrower_Email__c,
                    Condition__r.Transaction__r.Portal_Hash_Parameter__c,
                    Condition__r.Transaction__r.Processor__r.Name,
                    Condition__r.Transaction__r.Processor__r.FirstName,
                    Condition__r.Transaction__r.Processor__r.LastName,
                    Condition__r.Transaction__r.Processor__r.Title,
                    Condition__r.Transaction__r.Processor__r.Phone,
                    Condition__r.Transaction__r.Processor__r.MobilePhone,
                    Condition__r.Transaction__r.Processor__r.Email,
                    Condition__r.Transaction__r.Processor__r.Fax,
                    Condition__r.Transaction__r.Processor__r.NMLS__c,
                    Condition__r.Transaction__r.Processor__r.Headshot_URL__c,
                    Comment_Text__c,
                    Portal_Comment__c,
                    Public__c,
                    Read__c,
                    Created_By_Name__c,
                    CreatedDate
                FROM Condition_Comment__c
                WHERE Condition__c = :conditionId
                ORDER BY CreatedDate ASC
            ];
        }

        return [
            SELECT
                Id,
                Condition__c,
                Condition__r.Name,
                Condition__r.Description__c,
                Condition__r.Assigned_To__c,
                Condition__r.Transaction__c,
                Condition__r.Transaction__r.Name,
                Condition__r.Transaction__r.Borrower_Email__c,
                Condition__r.Transaction__r.Portal_Hash_Parameter__c,
                Condition__r.Transaction__r.Processor__r.Name,
                Condition__r.Transaction__r.Processor__r.FirstName,
                Condition__r.Transaction__r.Processor__r.LastName,
                Condition__r.Transaction__r.Processor__r.Title,
                Condition__r.Transaction__r.Processor__r.Phone,
                Condition__r.Transaction__r.Processor__r.MobilePhone,
                Condition__r.Transaction__r.Processor__r.Email,
                Condition__r.Transaction__r.Processor__r.Fax,
                Condition__r.Transaction__r.Processor__r.NMLS__c,
                Condition__r.Transaction__r.Processor__r.Headshot_URL__c,
                Comment_Text__c,
                Portal_Comment__c,
                Public__c,
                Read__c,
                Created_By_Name__c,
                CreatedDate
            FROM Condition_Comment__c
            WHERE Condition__c = :conditionId
            AND Public__c = true
            ORDER BY CreatedDate ASC
        ];
    }

    public Condition_Comment__c selectById(Id commentId) {
        if (commentId == null) {
            return null;
        }

        List<Condition_Comment__c> comments = [
            SELECT
                Id,
                Condition__c,
                Condition__r.Name,
                Condition__r.Description__c,
                Condition__r.Assigned_To__c,
                Condition__r.Transaction__c,
                Condition__r.Transaction__r.Name,
                Condition__r.Transaction__r.Borrower_Email__c,
                Condition__r.Transaction__r.Portal_Hash_Parameter__c,
                Condition__r.Transaction__r.Processor__r.Name,
                Condition__r.Transaction__r.Processor__r.FirstName,
                Condition__r.Transaction__r.Processor__r.LastName,
                Condition__r.Transaction__r.Processor__r.Title,
                Condition__r.Transaction__r.Processor__r.Phone,
                Condition__r.Transaction__r.Processor__r.MobilePhone,
                Condition__r.Transaction__r.Processor__r.Email,
                Condition__r.Transaction__r.Processor__r.Fax,
                Condition__r.Transaction__r.Processor__r.NMLS__c,
                Condition__r.Transaction__r.Processor__r.Headshot_URL__c,
                Comment_Text__c,
                Portal_Comment__c,
                Public__c,
                Read__c,
                Created_By_Name__c,
                CreatedDate
            FROM Condition_Comment__c
            WHERE Id = :commentId
            LIMIT 1
        ];
        return comments.isEmpty() ? null : comments[0];
    }
}