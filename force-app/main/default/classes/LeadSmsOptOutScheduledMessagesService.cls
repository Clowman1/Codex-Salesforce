/**
 * Use-case service:
 * When Lead.Opt_Out_from_SMS_Automation__c toggles:
 * - Opt-out (false->true): block all unsent scheduled SMS messages (RingCentral SMS) related to the Lead.
 * - Opt-in  (true->false): unblock all blocked unsent scheduled SMS messages (RingCentral SMS) related to the Lead.
 *
 * Notes:
 * - We define "unsent" as Sent_DateTime__c = NULL, which aligns with Status__c formula producing 'Sent' when Sent_DateTime__c is populated.
 * - Per business decision, opt-in unblocks ALL blocked unsent scheduled SMS messages (even if blocked for other reasons).
 */
public with sharing class LeadSmsOptOutScheduledMessagesService {
    private static final String LOG_SOURCE = 'Lead SMS Opt Out Blocking';
    private static final String ORG_WIDE_FROM_ADDRESS = 'reachus@reachhomeloans.com';

    /** Test-only: when true, applySmsOptOutChanges throws at start of try to exercise catch/notify paths. */
    @TestVisible
    private static Boolean throwInTryForTest = false;
    /** Test-only: when true, exercise Blocked__c not updateable branch (no DML). */
    @TestVisible
    private static Boolean blockFieldNotUpdateableForTest = false;
    /** Test-only: when true, setBlocked simulates one DML error to cover error-handling paths. */
    @TestVisible
    private static Boolean simulateDmlErrorForTest = false;
    /** Test-only: when true, notifyDevOnError(String) throws so the catch (ignore) path is covered. */
    @TestVisible
    private static Boolean notifyThrowForTest = false;

    public static void applySmsOptOutChanges(Set<Id> leadIdsOptedOut, Set<Id> leadIdsOptedIn) {
        Set<Id> optedOutIds = (leadIdsOptedOut == null) ? new Set<Id>() : new Set<Id>(leadIdsOptedOut);
        Set<Id> optedInIds = (leadIdsOptedIn == null) ? new Set<Id>() : new Set<Id>(leadIdsOptedIn);

        if (optedOutIds.isEmpty() && optedInIds.isEmpty()) {
            return;
        }

        List<Custom_Log__c> logsToInsert = new List<Custom_Log__c>();
        try {
            if (Test.isRunningTest() && throwInTryForTest) {
                throw new CalloutException('Test exception to cover catch and notify paths.');
            }
            if ((Test.isRunningTest() && blockFieldNotUpdateableForTest) || !Schema.SObjectType.Scheduled_Message__c.fields.Blocked__c.isUpdateable()) {
                addLog(logsToInsert, 'Blocked__c not updateable; cannot enforce SMS opt-out blocking.', null);
                flushLogs(logsToInsert);
                notifyDevOnError('Blocked__c not updateable; cannot enforce SMS opt-out blocking.');
                return;
            }

            ScheduledMessageRepository repo = new ScheduledMessageRepository();

            // Process opted-out Leads in batches to avoid SOQL query row limit (50,000 rows)
            // This handles scenarios where Leads have hundreds of scheduled messages each
            if (!optedOutIds.isEmpty()) {
                processLeadBatch(optedOutIds, true, repo, logsToInsert);
            }

            // Process opted-in Leads in batches to avoid SOQL query row limit (50,000 rows)
            if (!optedInIds.isEmpty()) {
                processLeadBatch(optedInIds, false, repo, logsToInsert);
            }

            flushLogs(logsToInsert);
        } catch (Exception e) {
            addLog(logsToInsert, 'Unhandled exception: ' + e.getMessage() + '\n' + e.getStackTraceString(), null);
            flushLogs(logsToInsert);
            notifyDevOnError(e);
            throw e;
        }
    }

    /**
     * Processes Leads in batches to avoid SOQL query row limits.
     * Assumes average of ~500 messages per Lead, so processing 100 Leads at a time
     * keeps us safely under the 50,000 query row limit.
     */
    private static void processLeadBatch(
        Set<Id> leadIds,
        Boolean block,
        ScheduledMessageRepository repo,
        List<Custom_Log__c> logsToInsert
    ) {
        List<Id> leadIdList = new List<Id>(leadIds);
        // Process 100 Leads at a time to stay under 50,000 query row limit
        // (assuming max ~500 messages per Lead)
        Integer batchSize = 100;
        
        for (Integer i = 0; i < leadIdList.size(); i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, leadIdList.size());
            Set<Id> batch = new Set<Id>();
            for (Integer j = i; j < endIndex; j++) {
                batch.add(leadIdList[j]);
            }
            
            List<Scheduled_Message__c> messages = block 
                ? repo.selectUnsentSmsNeedingBlockByLeadIds(batch)
                : repo.selectUnsentSmsNeedingUnblockByLeadIds(batch);

            setBlocked(messages, block, logsToInsert);
        }
    }

    private static void setBlocked(
        List<Scheduled_Message__c> records,
        Boolean blockedValue,
        List<Custom_Log__c> logsToInsert
    ) {
        if (records == null || records.isEmpty()) {
            return;
        }

        // Set blocked value on all records
        for (Scheduled_Message__c m : records) {
            m.Blocked__c = blockedValue;
        }

        // Chunk DML updates to avoid governor limits (10,000 rows per DML operation)
        // This handles scenarios where a Lead has hundreds of scheduled messages
        // or multiple Leads are processed simultaneously
        Integer chunkSize = 10000;
        List<String> errors = new List<String>();
        
        for (Integer i = 0; i < records.size(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, records.size());
            List<Scheduled_Message__c> chunk = new List<Scheduled_Message__c>();
            for (Integer j = i; j < endIndex; j++) {
                chunk.add(records[j]);
            }
            
            List<Database.SaveResult> results = Database.update(chunk, false, System.AccessLevel.SYSTEM_MODE);
            if (Test.isRunningTest() && simulateDmlErrorForTest && !chunk.isEmpty()) {
                String msg = 'Simulated DML error for test coverage';
                errors.add(msg);
                addLog(logsToInsert, msg, chunk[0].Lead__c);
            }
            for (Integer k = 0; k < results.size(); k++) {
                Database.SaveResult sr = results[k];
                if (sr == null || sr.isSuccess()) {
                    continue;
                }
                for (Database.Error err : sr.getErrors()) {
                    String msg =
                        'Failed to update Scheduled_Message__c id=' + String.valueOf(chunk[k].Id) +
                        ', Lead__c=' + String.valueOf(chunk[k].Lead__c) +
                        ', Blocked__c=' + String.valueOf(blockedValue) +
                        ', status=' + String.valueOf(err.getStatusCode()) +
                        ', message=' + err.getMessage();
                    errors.add(msg);
                    addLog(logsToInsert, msg, chunk[k].Lead__c);
                }
            }
        }

        if (!errors.isEmpty()) {
            notifyDevOnError('One or more Scheduled_Message__c updates failed. Count=' + String.valueOf(errors.size()) + '\n' + String.join(errors, '\n'));
        }
    }

    @TestVisible
    private static void addLog(List<Custom_Log__c> logsToInsert, String message, Id leadId) {
        if (logsToInsert == null) {
            return;
        }
        Custom_Log__c l = new Custom_Log__c();
        l.Source__c = LOG_SOURCE;
        l.Data__c = message;
        if (leadId != null) {
            l.Lead__c = leadId;
        }
        logsToInsert.add(l);
    }

    private static void flushLogs(List<Custom_Log__c> logsToInsert) {
        if (logsToInsert == null || logsToInsert.isEmpty()) {
            return;
        }
        try {
            insert logsToInsert;
        } catch (Exception e) {
            System.debug('Failed to insert Custom_Log__c: ' + e.getMessage());
        }
    }

    private static void notifyDevOnError(Exception e) {
        notifyDevOnError('Unhandled exception in ' + LOG_SOURCE + '\n\nMessage: ' + e.getMessage() + '\n\nStack:\n' + e.getStackTraceString());
    }

    private static void notifyDevOnError(String body) {
        try {
            if (Test.isRunningTest() && notifyThrowForTest) {
                throw new CalloutException('Test notify failure');
            }
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ 'development@nimbuscloudsolutions.com' });
            msg.setSubject('ERROR: ' + LOG_SOURCE);
            msg.setPlainTextBody(body);

            // Mirror existing org-wide usage pattern (best-effort; ok if not present in a sandbox).
            Id orgWideEmailAddressId = LeadStagnantAlertRepo.selectOrgWideEmailAddressId(ORG_WIDE_FROM_ADDRESS);
            if (orgWideEmailAddressId != null) {
                msg.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
        } catch (Exception ignore) {
            System.debug('Failed to notify development@nimbuscloudsolutions.com: ' + ignore.getMessage());
        }
    }
}