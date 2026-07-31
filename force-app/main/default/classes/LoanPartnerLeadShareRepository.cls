public without sharing class LoanPartnerLeadShareRepository {
    public Map<Id, User> selectUsersByIds(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new Map<Id, User>();
        }
        return new Map<Id, User>([
            SELECT Id, Name, Loan_Partner__c
            FROM User
            WHERE Id IN :userIds
        ]);
    }

    public Map<String, Group> selectPublicGroupsByDeveloperNames(Set<String> developerNames) {
        Map<String, Group> groupsByDeveloperName = new Map<String, Group>();
        if (developerNames == null || developerNames.isEmpty()) {
            return groupsByDeveloperName;
        }

        for (Group grp : [
            SELECT Id, Name, DeveloperName, Type
            FROM Group
            WHERE DeveloperName IN :developerNames
            AND Type = 'Regular'
        ]) {
            groupsByDeveloperName.put(grp.DeveloperName, grp);
        }
        return groupsByDeveloperName;
    }

    public Map<String, Group> selectPublicGroupsByNames(Set<String> names) {
        Map<String, Group> groupsByName = new Map<String, Group>();
        if (names == null || names.isEmpty()) {
            return groupsByName;
        }

        for (Group grp : [
            SELECT Id, Name, DeveloperName, Type
            FROM Group
            WHERE Name IN :names
            AND Type = 'Regular'
        ]) {
            groupsByName.put(grp.Name, grp);
        }
        return groupsByName;
    }

    public Map<String, GroupMember> selectGroupMembersByGroupIdsAndUserIds(Set<Id> groupIds, Set<Id> userIds) {
        Map<String, GroupMember> membersByKey = new Map<String, GroupMember>();
        if (groupIds == null || groupIds.isEmpty() || userIds == null || userIds.isEmpty()) {
            return membersByKey;
        }

        for (GroupMember member : [
            SELECT Id, GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :groupIds
            AND UserOrGroupId IN :userIds
        ]) {
            membersByKey.put(buildGroupMemberKey(member.GroupId, member.UserOrGroupId), member);
        }
        return membersByKey;
    }

    public List<Lead> selectLeadsByOwnerIdsAfterId(Set<Id> ownerIds, Id lastLeadId, Integer limitSize) {
        if (ownerIds == null || ownerIds.isEmpty()) {
            return new List<Lead>();
        }

        Integer safeLimit = (limitSize == null || limitSize <= 0) ? 200 : limitSize;
        if (lastLeadId == null) {
            return [
                SELECT Id, OwnerId
                FROM Lead
                WHERE OwnerId IN :ownerIds
                ORDER BY Id ASC
                LIMIT :safeLimit
            ];
        }

        return [
            SELECT Id, OwnerId
            FROM Lead
            WHERE OwnerId IN :ownerIds
            AND Id > :lastLeadId
            ORDER BY Id ASC
            LIMIT :safeLimit
        ];
    }

    public List<LeadShare> selectManualLeadShares(Set<Id> leadIds, Set<Id> userIds) {
        if (leadIds == null || leadIds.isEmpty() || userIds == null || userIds.isEmpty()) {
            return new List<LeadShare>();
        }
        return [
            SELECT Id, LeadId, UserOrGroupId, RowCause, LeadAccessLevel
            FROM LeadShare
            WHERE LeadId IN :leadIds
            AND UserOrGroupId IN :userIds
            AND RowCause = 'Manual'
        ];
    }

    public static String buildGroupMemberKey(Id groupId, Id userId) {
        return String.valueOf(groupId) + ':' + String.valueOf(userId);
    }

    public static String buildLeadShareKey(Id leadId, Id userId) {
        return String.valueOf(leadId) + ':' + String.valueOf(userId);
    }
}