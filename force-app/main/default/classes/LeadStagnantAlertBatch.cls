/**
 * Batchable replacement for LeadStagnantAlertService.run().
 *
 * Processes eligible leads in chunks to avoid heap-size limits.
 * - start:   returns a QueryLocator (cursor) for all eligible leads
 * - execute: evaluates each chunk against the 7-day milestone rule,
 *            accumulates hits into itemsByOwnerId (Database.Stateful)
 * - finish:  sends one email per owner and logs results
 *
 * Called by LeadStagnantAlertScheduler. LeadStagnantAlertService.run()
 * is retained for manual / anonymous-Apex invocations.
 */
public without sharing class LeadStagnantAlertBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String LOG_SOURCE = 'Stagnant Lead Alerts';
    private static final String ORG_WIDE_FROM_ADDRESS = 'reachus@reachhomeloans.com';

    private static final Set<String> EXCLUDED_STATUSES = new Set<String>{
        'Pre-Approval',
        'Nurture - Preapproval',
        'Nurturing',
        '30 Day+ Follow Up',
        '30 Day + Follow Up',
        '30 Day  Follow Up',
        '30 Day Follow Up'
    };

    // ── Stateful fields (preserved across execute() calls) ──────────────────
    private final Date effectiveDate;
    private final Date cutoffDate;
    private final String baseUrl;
    private Map<Id, List<LeadLineItem>> itemsByOwnerId;
    private List<Custom_Log__c> logsToInsert;
    private Integer eligibleLeadsProcessed;
    private Integer missingEventSkipped;
    private Integer invalidDaysSkipped;

    // ── Inner types ─────────────────────────────────────────────────────────
    private class LeadLineItem {
        public Id leadId;
        public String leadName;
        public Integer daysInStatus;
        public String leadUrl;
        public String loanDetails;
    }

    private class LeadLineItemSorter implements Comparator<LeadLineItem> {
        public Integer compare(LeadLineItem a, LeadLineItem b) {
            Integer ad = (a == null || a.daysInStatus == null) ? 0 : a.daysInStatus;
            Integer bd = (b == null || b.daysInStatus == null) ? 0 : b.daysInStatus;
            if (ad != bd) {
                return bd - ad; // descending
            }
            String an = (a == null || a.leadName == null) ? '' : a.leadName.toLowerCase();
            String bn = (b == null || b.leadName == null) ? '' : b.leadName.toLowerCase();
            return an.compareTo(bn);
        }
    }

    // ── Constructors ─────────────────────────────────────────────────────────
    public LeadStagnantAlertBatch() {
        this(null);
    }

    public LeadStagnantAlertBatch(Date asOfDate) {
        effectiveDate = (asOfDate == null) ? Date.today() : asOfDate;
        LeadStagnantAlertSettings__c settings = LeadStagnantAlertSettings__c.getOrgDefaults();
        cutoffDate = (settings != null && settings.Lead_Cutoff_Date__c != null)
            ? settings.Lead_Cutoff_Date__c
            : Date.newInstance(2025, 1, 1);
        baseUrl = URL.getOrgDomainUrl().toExternalForm();
        itemsByOwnerId = new Map<Id, List<LeadLineItem>>();
        logsToInsert = new List<Custom_Log__c>();
        eligibleLeadsProcessed = 0;
        missingEventSkipped = 0;
        invalidDaysSkipped = 0;
    }

    // ── Batchable interface ──────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return LeadStagnantAlertRepo.getEligibleLeadsLocator(EXCLUDED_STATUSES, cutoffDate);
    }

    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        // Silently drop any queue-owned leads that slip past the SOQL filter.
        List<Lead> userOwnedLeads = new List<Lead>();
        for (Lead l : scope) {
            if (l.OwnerId.getSObjectType() == User.sObjectType) {
                userOwnedLeads.add(l);
            }
        }
        if (userOwnedLeads.isEmpty()) {
            return;
        }

        eligibleLeadsProcessed += userOwnedLeads.size();

        Set<Id> chunkIds = new Map<Id, Lead>(userOwnedLeads).keySet();
        Map<Id, Lead_Event__c> events = LeadStagnantAlertRepo.selectCurrentStatusEvents(chunkIds);

        for (Lead l : userOwnedLeads) {
            Lead_Event__c e = events.get(l.Id);
            if (e == null || e.Status_Entered_Date_Time__c == null) {
                missingEventSkipped++;
                continue;
            }

            Date enteredDate = e.Status_Entered_Date_Time__c.date();
            Integer daysInStatus = enteredDate.daysBetween(effectiveDate);
            if (daysInStatus == null || daysInStatus < 0) {
                invalidDaysSkipped++;
                continue;
            }

            if (!isExactSevenDayMilestone(daysInStatus)) {
                continue;
            }

            LeadLineItem item = new LeadLineItem();
            item.leadId = l.Id;
            item.leadName = l.Name;
            item.daysInStatus = daysInStatus;
            item.leadUrl = baseUrl + '/lightning/r/Lead/' + String.valueOf(l.Id) + '/view';
            item.loanDetails = l.Loan_Details__c;

            if (!itemsByOwnerId.containsKey(l.OwnerId)) {
                itemsByOwnerId.put(l.OwnerId, new List<LeadLineItem>());
            }
            itemsByOwnerId.get(l.OwnerId).add(item);
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            if (missingEventSkipped > 0) {
                addLog(missingEventSkipped + ' lead(s) skipped: missing current status event (cannot compute days-in-status).', null, null);
            }
            if (invalidDaysSkipped > 0) {
                addLog(invalidDaysSkipped + ' lead(s) skipped: computed negative/invalid days-in-status.', null, null);
            }

            if (itemsByOwnerId.isEmpty()) {
                String reason = (eligibleLeadsProcessed == 0)
                    ? 'No eligible leads found (all leads are either in excluded statuses, converted, or none exist).'
                    : 'No leads hit a 7-day milestone today (' + String.valueOf(effectiveDate) + '). Eligible leads evaluated: ' + eligibleLeadsProcessed + '.';
                addLog(reason, null, null);
                flushLogs();
                return;
            }

            Map<Id, User> ownersById = LeadStagnantAlertRepo.selectActiveUsersByIds(itemsByOwnerId.keySet());
            List<String> ccEmails = resolveCcEmails();
            Id orgWideEmailAddressId = LeadStagnantAlertRepo.selectOrgWideEmailAddressId(ORG_WIDE_FROM_ADDRESS);

            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
            Integer totalLeadLines = 0;
            for (Id ownerId : itemsByOwnerId.keySet()) {
                User owner = ownersById.get(ownerId);
                if (owner == null) {
                    addLog('Owner is not an active User; skipping ownerId=' + String.valueOf(ownerId), null, ownerId);
                    continue;
                }

                List<LeadLineItem> ownerItems = itemsByOwnerId.get(ownerId);
                if (ownerItems == null || ownerItems.isEmpty()) {
                    continue;
                }

                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setToAddresses(new List<String>{ owner.Email });
                if (!ccEmails.isEmpty()) {
                    msg.setCcAddresses(ccEmails);
                }
                msg.setSubject('Stagnant Lead Follow-up Reminder - ' + effectiveDate.format());
                msg.setHtmlBody(buildHtmlBody(owner, ownerItems));
                if (orgWideEmailAddressId != null) {
                    msg.setOrgWideEmailAddressId(orgWideEmailAddressId);
                }
                emailsToSend.add(msg);
                totalLeadLines += ownerItems.size();
            }

            if (!emailsToSend.isEmpty()) {
                try {
                    Messaging.sendEmail(emailsToSend);
                    addLog('Successfully sent ' + emailsToSend.size() + ' email(s) to ' + emailsToSend.size() + ' owner(s) covering ' + totalLeadLines + ' lead(s).', null, null);
                } catch (Exception emailEx) {
                    String warn = 'Failed to send email(s): ' + emailEx.getMessage();
                    addLog(warn, null, null);
                    notifyDevOnError(emailEx);
                }
            }

            flushLogs();
        } catch (Exception e) {
            addLog('Unhandled exception in finish: ' + e.getMessage() + '\n' + e.getStackTraceString(), null, null);
            flushLogs();
            notifyDevOnError(e);
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────
    private static Boolean isExactSevenDayMilestone(Integer daysInStatus) {
        return daysInStatus != null && daysInStatus >= 7 && Math.mod(daysInStatus, 7) == 0;
    }

    private List<String> resolveCcEmails() {
        List<String> ccEmails = new List<String>();
        try {
            String labelValue = System.Label.CC_Recipients_for_Stagnant_Lead_Email_Alerts;
            if (String.isBlank(labelValue)) {
                return ccEmails;
            }
            for (String part : labelValue.split(';')) {
                String trimmed = part.trim();
                if (String.isNotBlank(trimmed)) {
                    ccEmails.add(trimmed);
                }
            }
        } catch (Exception e) {
            addLog('Failed to read CC recipients from Custom Label "CC_Recipients_for_Stagnant_Lead_Email_Alerts": ' + e.getMessage(), null, null);
        }
        return ccEmails;
    }

    private static String buildHtmlBody(User owner, List<LeadLineItem> items) {
        String safeOwnerName = escapeHtml(owner == null ? '' : owner.Name);

        String html = '';
        html += '<p>Hi ' + safeOwnerName + ',</p>';
        html += '<p>Please follow up with the Loan Officer on the following lead(s) that have not progressed and remain in their current status:</p>';
        html += '<ul>';

        items.sort(new LeadLineItemSorter());
        for (LeadLineItem item : items) {
            String safeLeadName = escapeHtml(item.leadName);
            String loanDetailsDisplay = String.isBlank(item.loanDetails) ? 'N/A' : item.loanDetails;
            String safeLoanDetails = escapeHtml(loanDetailsDisplay);
            safeLoanDetails = safeLoanDetails.replace('\r\n', '\n');
            safeLoanDetails = safeLoanDetails.replace('\r', '\n');
            safeLoanDetails = safeLoanDetails.replace('\n', '<br/>');
            String safeUrl = escapeHtml(item.leadUrl);
            html += '<li>' + safeLeadName + ' (' + item.daysInStatus + ' days) - ' + safeLoanDetails + ' - <a href="' + safeUrl + '">link</a></li>';
        }
        html += '</ul>';
        html += '<p>Thank you.</p>';
        return html;
    }

    private static String escapeHtml(String raw) {
        if (raw == null) {
            return '';
        }
        String s = raw;
        s = s.replace('&', '&amp;');
        s = s.replace('<', '&lt;');
        s = s.replace('>', '&gt;');
        s = s.replace('"', '&quot;');
        s = s.replace('\'', '&#39;');
        return s;
    }

    private void addLog(String message, Id leadId, Id relatedId) {
        Custom_Log__c l = new Custom_Log__c();
        l.Source__c = LOG_SOURCE;
        l.Data__c = message;
        if (leadId != null) {
            l.Lead__c = leadId;
        } else if (relatedId != null) {
            l.Data__c = message + ' (relatedId=' + String.valueOf(relatedId) + ')';
        }
        logsToInsert.add(l);
    }

    private void flushLogs() {
        if (logsToInsert.isEmpty()) {
            return;
        }
        try {
            insert logsToInsert;
            logsToInsert.clear();
        } catch (Exception e) {
            System.debug('Failed to insert Custom_Log__c: ' + e.getMessage());
        }
    }

    private void notifyDevOnError(Exception e) {
        try {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ 'development@nimbuscloudsolutions.com' });
            msg.setSubject('ERROR: ' + LOG_SOURCE);
            msg.setPlainTextBody(
                'Unhandled exception in ' + LOG_SOURCE + ' (Batch)\n\n' +
                'Message: ' + e.getMessage() + '\n\n' +
                'Stack:\n' + e.getStackTraceString()
            );
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