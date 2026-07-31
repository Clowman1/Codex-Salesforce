/**
 * Loan Partner Lead sharing automation service.
 * Runs in system context because it manages org-level sharing artifacts (Group/GroupMember/LeadShare).
 */
public without sharing class LoanPartnerLeadShareService {
    private static final String GROUP_NAME_PREFIX = 'LP-';
    private static final String GROUP_DEVELOPER_PREFIX = 'LP_';
    private static final String LEAD_SHARE_ROW_CAUSE = 'Manual';
    private static final String LEAD_SHARE_ACCESS_EDIT = 'Edit';
    private static final Integer LEAD_CHUNK_SIZE = 500;
    private static final String LOG_SOURCE = 'LoanPartnerLeadShareService';
    @TestVisible private static Boolean bypassQueueableEnqueueInTests = false;

    public class RelationshipChange {
        public Id parentUserId;
        public Id oldLoanPartnerId;
        public Id newLoanPartnerId;

        public RelationshipChange(Id parentUserId, Id oldLoanPartnerId, Id newLoanPartnerId) {
            this.parentUserId = parentUserId;
            this.oldLoanPartnerId = oldLoanPartnerId;
            this.newLoanPartnerId = newLoanPartnerId;
        }
    }

    public class QueueableResult {
        public Boolean hasMore;
        public Id lastProcessedLeadId;

        public QueueableResult(Boolean hasMore, Id lastProcessedLeadId) {
            this.hasMore = hasMore;
            this.lastProcessedLeadId = lastProcessedLeadId;
        }
    }

    private class GroupDescriptor {
        public Id loanPartnerId;
        public String groupName;
        public String developerName;

        public GroupDescriptor(Id loanPartnerId, String groupName, String developerName) {
            this.loanPartnerId = loanPartnerId;
            this.groupName = groupName;
            this.developerName = developerName;
        }
    }

    public static void enqueueForUserChanges(List<User> users, Map<Id, User> oldUsersById) {
        List<RelationshipChange> changes = collectRelationshipChanges(users, oldUsersById);
        if (changes.isEmpty()) {
            return;
        }
        if (Test.isRunningTest() && bypassQueueableEnqueueInTests) {
            return;
        }
        System.enqueueJob(new LoanPartnerLeadShareQueueable(changes, null, true));
    }

    public static QueueableResult processRelationshipChangesChunk(
        List<RelationshipChange> changes,
        Id lastProcessedLeadId,
        Boolean shouldSyncGroupsAndMembers
    ) {
        QueueableResult result = new QueueableResult(false, lastProcessedLeadId);
        if (changes == null || changes.isEmpty()) {
            return result;
        }

        Map<Id, Id> oldLoanPartnerByOwner = new Map<Id, Id>();
        Map<Id, Id> newLoanPartnerByOwner = new Map<Id, Id>();
        for (RelationshipChange changeItem : changes) {
            if (changeItem == null || changeItem.parentUserId == null) {
                continue;
            }
            oldLoanPartnerByOwner.put(changeItem.parentUserId, changeItem.oldLoanPartnerId);
            newLoanPartnerByOwner.put(changeItem.parentUserId, changeItem.newLoanPartnerId);
        }
        if (newLoanPartnerByOwner.isEmpty()) {
            return result;
        }

        LoanPartnerLeadShareRepository repo = new LoanPartnerLeadShareRepository();

        if (shouldSyncGroupsAndMembers == true) {
            syncPublicGroupsAndMembership(changes, repo);
            result.lastProcessedLeadId = lastProcessedLeadId;
            result.hasMore = true;
            return result;
        }

        List<Lead> leads = repo.selectLeadsByOwnerIdsAfterId(
            newLoanPartnerByOwner.keySet(),
            lastProcessedLeadId,
            LEAD_CHUNK_SIZE
        );
        if (leads.isEmpty()) {
            result.lastProcessedLeadId = lastProcessedLeadId;
            result.hasMore = false;
            return result;
        }

        Map<Id, Id> createShareByLeadId = new Map<Id, Id>();
        Map<Id, Id> deleteShareByLeadId = new Map<Id, Id>();
        Id nextCursor = lastProcessedLeadId;
        for (Lead leadRecord : leads) {
            nextCursor = leadRecord.Id;
            Id oldLoanPartnerId = oldLoanPartnerByOwner.get(leadRecord.OwnerId);
            Id newLoanPartnerId = newLoanPartnerByOwner.get(leadRecord.OwnerId);

            if (oldLoanPartnerId != null && oldLoanPartnerId != newLoanPartnerId) {
                deleteShareByLeadId.put(leadRecord.Id, oldLoanPartnerId);
            }
            if (newLoanPartnerId != null) {
                createShareByLeadId.put(leadRecord.Id, newLoanPartnerId);
            }
        }

        syncLeadShares(createShareByLeadId, deleteShareByLeadId);

        result.lastProcessedLeadId = nextCursor;
        result.hasMore = (leads.size() == LEAD_CHUNK_SIZE);
        return result;
    }

    public static void syncLeadShares(Map<Id, Id> createLeadToPartnerMap, Map<Id, Id> deleteLeadToPartnerMap) {
        Map<Id, Id> createMap = (createLeadToPartnerMap == null) ? new Map<Id, Id>() : createLeadToPartnerMap;
        Map<Id, Id> deleteMap = (deleteLeadToPartnerMap == null) ? new Map<Id, Id>() : deleteLeadToPartnerMap;
        if (createMap.isEmpty() && deleteMap.isEmpty()) {
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        for (Id leadId : createMap.keySet()) {
            leadIds.add(leadId);
            if (createMap.get(leadId) != null) {
                userIds.add(createMap.get(leadId));
            }
        }
        for (Id leadId : deleteMap.keySet()) {
            leadIds.add(leadId);
            if (deleteMap.get(leadId) != null) {
                userIds.add(deleteMap.get(leadId));
            }
        }
        if (leadIds.isEmpty() || userIds.isEmpty()) {
            return;
        }

        LoanPartnerLeadShareRepository repo = new LoanPartnerLeadShareRepository();
        List<LeadShare> existingShares = repo.selectManualLeadShares(leadIds, userIds);
        Map<String, LeadShare> shareByKey = new Map<String, LeadShare>();
        for (LeadShare existingShare : existingShares) {
            String shareKey = LoanPartnerLeadShareRepository.buildLeadShareKey(existingShare.LeadId, existingShare.UserOrGroupId);
            if (!shareByKey.containsKey(shareKey)) {
                shareByKey.put(shareKey, existingShare);
            }
        }

        List<LeadShare> sharesToInsert = new List<LeadShare>();
        List<LeadShare> sharesToUpdate = new List<LeadShare>();
        List<LeadShare> sharesToDelete = new List<LeadShare>();

        for (Id leadId : createMap.keySet()) {
            Id loanPartnerId = createMap.get(leadId);
            if (leadId == null || loanPartnerId == null) {
                continue;
            }

            String shareKey = LoanPartnerLeadShareRepository.buildLeadShareKey(leadId, loanPartnerId);
            LeadShare existingShare = shareByKey.get(shareKey);
            if (existingShare == null) {
                sharesToInsert.add(new LeadShare(
                    LeadId = leadId,
                    UserOrGroupId = loanPartnerId,
                    RowCause = LEAD_SHARE_ROW_CAUSE,
                    LeadAccessLevel = LEAD_SHARE_ACCESS_EDIT
                ));
                continue;
            }

            if (existingShare.LeadAccessLevel != LEAD_SHARE_ACCESS_EDIT) {
                existingShare.LeadAccessLevel = LEAD_SHARE_ACCESS_EDIT;
                sharesToUpdate.add(existingShare);
            }
        }

        for (Id leadId : deleteMap.keySet()) {
            Id oldLoanPartnerId = deleteMap.get(leadId);
            if (leadId == null || oldLoanPartnerId == null) {
                continue;
            }

            String shareKey = LoanPartnerLeadShareRepository.buildLeadShareKey(leadId, oldLoanPartnerId);
            LeadShare existingShare = shareByKey.get(shareKey);

            // Safety-first cleanup: only remove Edit-level shares so unrelated manual Read shares are preserved.
            if (existingShare != null && existingShare.LeadAccessLevel == LEAD_SHARE_ACCESS_EDIT) {
                sharesToDelete.add(new LeadShare(Id = existingShare.Id));
            }
        }

        if (!sharesToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(sharesToInsert, false, System.AccessLevel.SYSTEM_MODE);
            logSaveResults('LeadShare insert', insertResults);
        }
        if (!sharesToUpdate.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(sharesToUpdate, false, System.AccessLevel.SYSTEM_MODE);
            logSaveResults('LeadShare update', updateResults);
        }
        if (!sharesToDelete.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(sharesToDelete, false, System.AccessLevel.SYSTEM_MODE);
            logDeleteResults('LeadShare delete', deleteResults);
        }
    }

    @TestVisible
    private static List<RelationshipChange> collectRelationshipChanges(List<User> users, Map<Id, User> oldUsersById) {
        List<RelationshipChange> changes = new List<RelationshipChange>();
        if (users == null || users.isEmpty()) {
            return changes;
        }

        for (User userRecord : users) {
            if (userRecord == null || userRecord.Id == null) {
                continue;
            }

            Id oldLoanPartnerId = null;
            if (oldUsersById != null && oldUsersById.containsKey(userRecord.Id)) {
                oldLoanPartnerId = oldUsersById.get(userRecord.Id).Loan_Partner__c;
            }
            Id newLoanPartnerId = userRecord.Loan_Partner__c;

            if (oldLoanPartnerId != newLoanPartnerId) {
                changes.add(new RelationshipChange(userRecord.Id, oldLoanPartnerId, newLoanPartnerId));
            }
        }

        return changes;
    }

    private static void syncPublicGroupsAndMembership(List<RelationshipChange> changes, LoanPartnerLeadShareRepository repo) {
        Set<Id> loanPartnerIds = new Set<Id>();
        Set<Id> parentUserIds = new Set<Id>();
        for (RelationshipChange changeItem : changes) {
            if (changeItem == null || changeItem.parentUserId == null) {
                continue;
            }
            parentUserIds.add(changeItem.parentUserId);
            if (changeItem.newLoanPartnerId != null) {
                loanPartnerIds.add(changeItem.newLoanPartnerId);
            }
            if (changeItem.oldLoanPartnerId != null) {
                loanPartnerIds.add(changeItem.oldLoanPartnerId);
            }
        }
        if (loanPartnerIds.isEmpty() || parentUserIds.isEmpty()) {
            return;
        }

        Map<Id, User> loanPartnerById = repo.selectUsersByIds(loanPartnerIds);
        Map<Id, GroupDescriptor> groupDescriptorByPartnerId = new Map<Id, GroupDescriptor>();
        Set<String> devNames = new Set<String>();
        Set<String> groupNames = new Set<String>();
        for (Id loanPartnerId : loanPartnerById.keySet()) {
            GroupDescriptor descriptor = new GroupDescriptor(
                loanPartnerId,
                buildGroupName(loanPartnerById.get(loanPartnerId).Name),
                buildGroupDeveloperName(loanPartnerId)
            );
            groupDescriptorByPartnerId.put(loanPartnerId, descriptor);
            devNames.add(descriptor.developerName);
            groupNames.add(descriptor.groupName);
        }
        if (groupDescriptorByPartnerId.isEmpty()) {
            return;
        }

        Map<String, Group> groupsByDevName = repo.selectPublicGroupsByDeveloperNames(devNames);
        Map<String, Group> groupsByName = repo.selectPublicGroupsByNames(groupNames);
        Map<Id, Id> groupIdByPartnerId = new Map<Id, Id>();
        List<Group> groupsToInsert = new List<Group>();
        List<Group> groupsToUpdate = new List<Group>();
        Map<Integer, Id> insertIndexToPartnerId = new Map<Integer, Id>();

        for (Id loanPartnerId : groupDescriptorByPartnerId.keySet()) {
            GroupDescriptor descriptor = groupDescriptorByPartnerId.get(loanPartnerId);
            Group existingGroup = groupsByDevName.get(descriptor.developerName);
            if (existingGroup == null) {
                existingGroup = groupsByName.get(descriptor.groupName);
            }

            if (existingGroup == null) {
                insertIndexToPartnerId.put(groupsToInsert.size(), loanPartnerId);
                groupsToInsert.add(new Group(
                    Name = descriptor.groupName,
                    DeveloperName = descriptor.developerName,
                    Type = 'Regular'
                ));
                continue;
            }

            groupIdByPartnerId.put(loanPartnerId, existingGroup.Id);
            if (existingGroup.DeveloperName == descriptor.developerName && existingGroup.Name != descriptor.groupName) {
                existingGroup.Name = descriptor.groupName;
                groupsToUpdate.add(existingGroup);
            }
        }

        if (!groupsToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(groupsToInsert, false);
            for (Integer i = 0; i < insertResults.size(); i++) {
                Database.SaveResult sr = insertResults[i];
                if (sr != null && sr.isSuccess()) {
                    groupIdByPartnerId.put(insertIndexToPartnerId.get(i), sr.getId());
                } else {
                    logSaveErrors('Public Group insert', sr);
                }
            }
        }
        if (!groupsToUpdate.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(groupsToUpdate, false);
            logSaveResults('Public Group rename', updateResults);
        }

        Set<Id> groupIds = new Set<Id>();
        groupIds.addAll(groupIdByPartnerId.values());
        if (groupIds.isEmpty()) {
            return;
        }

        Map<String, GroupMember> existingMembersByKey =
            repo.selectGroupMembersByGroupIdsAndUserIds(groupIds, parentUserIds);

        List<GroupMember> membersToInsert = new List<GroupMember>();
        List<GroupMember> membersToDelete = new List<GroupMember>();
        Set<String> removeKeys = new Set<String>();

        for (RelationshipChange changeItem : changes) {
            if (changeItem == null || changeItem.parentUserId == null) {
                continue;
            }
            if (changeItem.newLoanPartnerId != null) {
                Id newGroupId = groupIdByPartnerId.get(changeItem.newLoanPartnerId);
                if (newGroupId != null) {
                    String addKey = LoanPartnerLeadShareRepository.buildGroupMemberKey(newGroupId, changeItem.parentUserId);
                    if (!existingMembersByKey.containsKey(addKey)) {
                        membersToInsert.add(new GroupMember(GroupId = newGroupId, UserOrGroupId = changeItem.parentUserId));
                    }
                }
            }

            if (changeItem.oldLoanPartnerId != null && changeItem.oldLoanPartnerId != changeItem.newLoanPartnerId) {
                Id oldGroupId = groupIdByPartnerId.get(changeItem.oldLoanPartnerId);
                if (oldGroupId != null) {
                    removeKeys.add(LoanPartnerLeadShareRepository.buildGroupMemberKey(oldGroupId, changeItem.parentUserId));
                }
            }
        }

        for (String removeKey : removeKeys) {
            if (existingMembersByKey.containsKey(removeKey)) {
                membersToDelete.add(new GroupMember(Id = existingMembersByKey.get(removeKey).Id));
            }
        }

        if (!membersToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(membersToInsert, false);
            logSaveResults('GroupMember insert', insertResults);
        }
        if (!membersToDelete.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(membersToDelete, false);
            logDeleteResults('GroupMember delete', deleteResults);
        }
    }

    private static String buildGroupName(String loanPartnerName) {
        String safeName = String.isBlank(loanPartnerName) ? 'Unknown' : loanPartnerName.trim();
        String fullName = GROUP_NAME_PREFIX + safeName;
        if (fullName.length() > 80) {
            return fullName.substring(0, 80);
        }
        return fullName;
    }

    private static String buildGroupDeveloperName(Id loanPartnerId) {
        return GROUP_DEVELOPER_PREFIX + String.valueOf(loanPartnerId);
    }

    private static void logSaveResults(String operation, Database.SaveResult[] results) {
        if (results == null) {
            return;
        }
        for (Database.SaveResult sr : results) {
            if (sr == null || sr.isSuccess()) {
                continue;
            }
            logSaveErrors(operation, sr);
        }
    }

    private static void logDeleteResults(String operation, Database.DeleteResult[] results) {
        if (results == null) {
            return;
        }
        for (Database.DeleteResult dr : results) {
            if (dr == null || dr.isSuccess()) {
                continue;
            }
            List<String> errors = new List<String>();
            for (Database.Error err : dr.getErrors()) {
                errors.add(err.getStatusCode() + ': ' + err.getMessage());
            }
            logError(operation + ' failed. errors=' + String.join(errors, ' | '));
        }
    }

    private static void logSaveErrors(String operation, Database.SaveResult sr) {
        List<String> errors = new List<String>();
        if (sr != null) {
            for (Database.Error err : sr.getErrors()) {
                errors.add(err.getStatusCode() + ': ' + err.getMessage());
            }
        }
        logError(operation + ' failed. errors=' + String.join(errors, ' | '));
    }

    private static void logError(String message) {
        try {
            insert new Custom_Log__c(
                Source__c = LOG_SOURCE,
                Data__c = message
            );
        } catch (Exception ignore) {
            System.debug('Unable to log Loan Partner Lead share error: ' + ignore.getMessage());
        }
    }
}