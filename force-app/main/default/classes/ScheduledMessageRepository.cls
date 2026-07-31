/**
 * SOQL-only repository for Scheduled_Message__c.
 * Block/unblock selectors delegate to an inner without-sharing class so that
 * all unsent messages for opted-out/opted-in Leads are found regardless of
 * the running user's sharing (compliance requirement: no messages sent to opted-out Leads).
 */
public with sharing class ScheduledMessageRepository {
    private static final String TYPE_RINGCENTRAL_SMS = 'RingCentral SMS';

    public List<Scheduled_Message__c> selectUnsentSmsNeedingBlockByLeadIds(Set<Id> leadIds) {
        return new ScheduledMessageRepositorySystem().selectUnsentSmsNeedingBlockByLeadIds(leadIds);
    }

    public List<Scheduled_Message__c> selectUnsentSmsNeedingUnblockByLeadIds(Set<Id> leadIds) {
        return new ScheduledMessageRepositorySystem().selectUnsentSmsNeedingUnblockByLeadIds(leadIds);
    }

    /**
     * Runs block/unblock queries in system context so all relevant Scheduled_Message__c
     * records are selected regardless of sharing. Used only for SMS opt-out compliance
     * (block/unblock all unsent messages for the Lead).
     */
    private without sharing class ScheduledMessageRepositorySystem {
        private List<Scheduled_Message__c> selectUnsentSmsNeedingBlockByLeadIds(Set<Id> leadIds) {
            if (leadIds == null || leadIds.isEmpty()) {
                return new List<Scheduled_Message__c>();
            }
            return [
                SELECT Id, Lead__c, Blocked__c, Sent_DateTime__c, Type__c
                FROM Scheduled_Message__c
                WHERE Lead__c IN :leadIds
                    AND Type__c = :TYPE_RINGCENTRAL_SMS
                    AND Sent_DateTime__c = NULL
                    AND Blocked__c = false
            ];
        }

        private List<Scheduled_Message__c> selectUnsentSmsNeedingUnblockByLeadIds(Set<Id> leadIds) {
            if (leadIds == null || leadIds.isEmpty()) {
                return new List<Scheduled_Message__c>();
            }
            return [
                SELECT Id, Lead__c, Blocked__c, Sent_DateTime__c, Type__c
                FROM Scheduled_Message__c
                WHERE Lead__c IN :leadIds
                    AND Type__c = :TYPE_RINGCENTRAL_SMS
                    AND Sent_DateTime__c = NULL
                    AND Blocked__c = true
            ];
        }
    }
}