public with sharing class LeadDocumentCarryForwardService {
    public class CarryForwardException extends Exception {}
    @TestVisible private static Boolean forceExceptionForTest = false;

    private class ConvertedRequestContext {
        Lead leadRecord;
        Lead_Document_Request__c requestRecord;
        Condition__c conditionRecord;
    }

    public static void carryForward(Set<Id> leadIds) {
        if (Test.isRunningTest() && forceExceptionForTest) {
            throw new CarryForwardException('Forced carry-forward failure for test coverage.');
        }
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        Map<Id, Lead> leadsById = LeadDocumentRequestRepository.getInstance().selectLeadsByIds(leadIds);
        List<Lead_Document_Request__c> requestRecords =
            LeadDocumentRequestRepository.getInstance().selectUnconvertedByLeadIds(leadsById.keySet());
        if (requestRecords.isEmpty()) {
            return;
        }

        List<ConvertedRequestContext> contexts = new List<ConvertedRequestContext>();
        List<Condition__c> conditionsToInsert = new List<Condition__c>();
        for (Lead_Document_Request__c requestRecord : requestRecords) {
            Lead leadRecord = leadsById.get(requestRecord.Lead__c);
            if (leadRecord == null || leadRecord.Converted_Transaction_ID__c == null) {
                continue;
            }

            ConvertedRequestContext context = new ConvertedRequestContext();
            context.leadRecord = leadRecord;
            context.requestRecord = requestRecord;
            context.conditionRecord = buildConditionFromRequest(requestRecord, leadRecord.Converted_Transaction_ID__c);
            contexts.add(context);
            conditionsToInsert.add(context.conditionRecord);
        }

        if (contexts.isEmpty()) {
            return;
        }

        Database.SaveResult[] insertResults = Database.insert(conditionsToInsert, false, AccessLevel.SYSTEM_MODE);
        List<Lead_Document_Request__c> requestsToUpdate = new List<Lead_Document_Request__c>();
        Map<Id, ConvertedRequestContext> contextsByRequestId = new Map<Id, ConvertedRequestContext>();
        Set<Id> conditionIds = new Set<Id>();
        for (Integer i = 0; i < insertResults.size(); i++) {
            if (!insertResults[i].isSuccess()) {
                continue;
            }
            ConvertedRequestContext context = contexts[i];
            context.conditionRecord.Id = insertResults[i].getId();
            contextsByRequestId.put(context.requestRecord.Id, context);
            conditionIds.add(context.conditionRecord.Id);
            requestsToUpdate.add(new Lead_Document_Request__c(
                Id = context.requestRecord.Id,
                Converted_Condition__c = context.conditionRecord.Id
            ));
        }

        if (!requestsToUpdate.isEmpty()) {
            Database.update(requestsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }

        carryForwardFiles(contextsByRequestId, conditionIds);
        BorrowerPortalService.populateMissingPortalHashes(getConvertedTransactionIds(leadsById.values()));
    }

    private static Condition__c buildConditionFromRequest(Lead_Document_Request__c requestRecord, Id transactionId) {
        return new Condition__c(
            Transaction__c = transactionId,
            Name = requestRecord.Name,
            Status__c = requestRecord.Status__c,
            Description__c = requestRecord.Description__c,
            Subject__c = requestRecord.Subject__c,
            Category__c = requestRecord.Category__c,
            Type__c = resolveConditionPicklistValue(
                Condition__c.Type__c,
                requestRecord.Type__c,
                'Processor'
            ),
            Requested_Date__c = requestRecord.Requested_Date__c,
            Include_In_Email__c = requestRecord.Include_In_Email__c,
            Can_Borrower_See__c = requestRecord.Can_Borrower_See__c,
            Lead_Document_Request_Reference__c = requestRecord.Lead_Document_Request_Reference__c,
            Condition_Group_Key__c = requestRecord.Lead_Document_Request_Reference__r == null
                ? null
                : requestRecord.Lead_Document_Request_Reference__r.Condition_Group_Key__c
        );
    }

    private static String resolveConditionPicklistValue(
        Schema.SObjectField fieldToken,
        String requestedValue,
        String fallbackValue
    ) {
        String resolvedValue = String.isBlank(requestedValue) ? fallbackValue : requestedValue;
        Schema.DescribeFieldResult describeResult = fieldToken.getDescribe();
        if (!describeResult.isRestrictedPicklist()) {
            return resolvedValue;
        }
        for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == resolvedValue) {
                return resolvedValue;
            }
        }
        return fallbackValue;
    }

    private static void carryForwardFiles(Map<Id, ConvertedRequestContext> contextsByRequestId, Set<Id> conditionIds) {
        if (contextsByRequestId.isEmpty()) {
            return;
        }

        Set<Id> sourceRequestIds = contextsByRequestId.keySet();
        List<ContentDocumentLink> sourceLinks = LeadDocumentRequestRepository.getInstance()
            .selectDocumentLinksByEntityIds(sourceRequestIds);
        if (sourceLinks.isEmpty()) {
            return;
        }

        Set<Id> contentDocumentIds = new Set<Id>();
        Set<Id> targetEntityIds = new Set<Id>(conditionIds);
        for (ContentDocumentLink sourceLink : sourceLinks) {
            ConvertedRequestContext context = contextsByRequestId.get(sourceLink.LinkedEntityId);
            if (context == null || context.conditionRecord?.Id == null || context.leadRecord?.Converted_Transaction_ID__c == null) {
                continue;
            }
            contentDocumentIds.add(sourceLink.ContentDocumentId);
            targetEntityIds.add(context.leadRecord.Converted_Transaction_ID__c);
        }

        Set<String> existingPairs = new Set<String>();
        for (ContentDocumentLink existingLink : LeadDocumentRequestRepository.getInstance()
            .selectDocumentLinksByEntityIds(targetEntityIds)) {
            existingPairs.add(existingLink.LinkedEntityId + ':' + existingLink.ContentDocumentId);
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (ContentDocumentLink sourceLink : sourceLinks) {
            ConvertedRequestContext context = contextsByRequestId.get(sourceLink.LinkedEntityId);
            if (context == null || context.conditionRecord?.Id == null || context.leadRecord?.Converted_Transaction_ID__c == null) {
                continue;
            }
            addLinkIfMissing(linksToInsert, existingPairs, sourceLink.ContentDocumentId, context.conditionRecord.Id);
            addLinkIfMissing(linksToInsert, existingPairs, sourceLink.ContentDocumentId, context.leadRecord.Converted_Transaction_ID__c);
        }

        if (!linksToInsert.isEmpty()) {
            Database.insert(linksToInsert, false, AccessLevel.SYSTEM_MODE);
        }

        stampContentVersions(contextsByRequestId, sourceLinks, contentDocumentIds);
    }

    private static void addLinkIfMissing(
        List<ContentDocumentLink> linksToInsert,
        Set<String> existingPairs,
        Id contentDocumentId,
        Id linkedEntityId
    ) {
        String key = linkedEntityId + ':' + contentDocumentId;
        if (existingPairs.contains(key)) {
            return;
        }
        existingPairs.add(key);
        linksToInsert.add(new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = linkedEntityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
    }

    private static void stampContentVersions(
        Map<Id, ConvertedRequestContext> contextsByRequestId,
        List<ContentDocumentLink> sourceLinks,
        Set<Id> contentDocumentIds
    ) {
        Map<Id, Set<Id>> conditionIdsByContentDocumentId = new Map<Id, Set<Id>>();
        for (ContentDocumentLink sourceLink : sourceLinks) {
            ConvertedRequestContext context = contextsByRequestId.get(sourceLink.LinkedEntityId);
            if (context == null || context.conditionRecord?.Id == null) {
                continue;
            }
            if (!conditionIdsByContentDocumentId.containsKey(sourceLink.ContentDocumentId)) {
                conditionIdsByContentDocumentId.put(sourceLink.ContentDocumentId, new Set<Id>());
            }
            conditionIdsByContentDocumentId.get(sourceLink.ContentDocumentId).add(context.conditionRecord.Id);
        }

        List<ContentVersion> versionsToUpdate = new List<ContentVersion>();
        for (ContentVersion version : LeadDocumentRequestRepository.getInstance()
            .selectLatestContentVersionsByDocumentIds(contentDocumentIds)) {
            Set<Id> conditionIdsForDocument = conditionIdsByContentDocumentId.get(version.ContentDocumentId);
            if (conditionIdsForDocument == null || conditionIdsForDocument.size() != 1) {
                continue;
            }
            Id conditionId = new List<Id>(conditionIdsForDocument)[0];
            versionsToUpdate.add(new ContentVersion(
                Id = version.Id,
                Condition__c = conditionId
            ));
        }

        if (!versionsToUpdate.isEmpty()) {
            Database.update(versionsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static Set<Id> getConvertedTransactionIds(List<Lead> leadRecords) {
        Set<Id> transactionIds = new Set<Id>();
        for (Lead leadRecord : leadRecords) {
            if (leadRecord.Converted_Transaction_ID__c != null) {
                transactionIds.add(leadRecord.Converted_Transaction_ID__c);
            }
        }
        return transactionIds;
    }
}