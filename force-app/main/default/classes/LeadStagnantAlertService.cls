/**
 * Use-case service that:
 * - selects eligible Leads (by current Status)
 * - derives days-in-current-status from Lead_Event__c (Status Changed event with no Exit time)
 * - sends 1 email per Lead Owner on exact 7-day milestones (7, 14, 21, 28, 35, 42, ...)
 * - logs summary skip counts and success metrics to Custom_Log__c
 *
 * Milestone filtering:
 * - Day 7: Send notification
 * - Day 14: Send notification
 * - Day 21: Send notification
 * - Day 28: Send notification
 * - Day 35: Send notification
 * - Continues every 7 days (42, 49, 56, etc.)
 */
public with sharing class LeadStagnantAlertService {

    private static final String LOG_SOURCE = 'Stagnant Lead Alerts';
    private static final String ORG_WIDE_FROM_ADDRESS = 'reachus@reachhomeloans.com';

    @TestVisible
    private static List<String> lastBuiltHtmlBodies = new List<String>();

    private static final Set<String> EXCLUDED_STATUSES = new Set<String>{
        'Pre-Approval',
        'Nurture - Preapproval',
        'Nurturing',
        '30 Day+ Follow Up',
        // Status label variations observed/possible across environments.
        '30 Day + Follow Up',
        '30 Day  Follow Up',
        '30 Day Follow Up'
    };

    public class RunResult {
        public Integer ownersEmailed { get; set; }
        public Integer leadsEmailed { get; set; }
        public List<String> warnings { get; set; }
        public RunResult() {
            ownersEmailed = 0;
            leadsEmailed = 0;
            warnings = new List<String>();
        }
    }

    private class LeadLineItem {
        public Id leadId;
        public String leadName;
        public Integer daysInStatus;
        public String leadUrl;
        public String loanDetails;
    }

    public static RunResult run(Date asOfDate) {
        Date effectiveDate = (asOfDate == null) ? Date.today() : asOfDate;
        RunResult result = new RunResult();
        List<Custom_Log__c> logsToInsert = new List<Custom_Log__c>();

        // Read settings from Custom Setting
        LeadStagnantAlertSettings__c settings = LeadStagnantAlertSettings__c.getOrgDefaults();
        Date cutoffDate = (settings != null && settings.Lead_Cutoff_Date__c != null)
            ? settings.Lead_Cutoff_Date__c
            : Date.newInstance(2025, 1, 1);

        if (Test.isRunningTest()) {
            lastBuiltHtmlBodies.clear();
        }

        // Summary counters (aligned with Batch pattern)
        Integer missingEventSkipped = 0;
        Integer invalidDaysSkipped = 0;

        try {
            List<Lead> eligibleLeads = LeadStagnantAlertRepo.selectEligibleLeads(EXCLUDED_STATUSES, cutoffDate);
            if (eligibleLeads.isEmpty()) {
                addLog(logsToInsert, 'No eligible leads found (all leads are either in excluded statuses, converted, or none exist).', null, null);
                flushLogs(logsToInsert);
                return result;
            }

            Map<Id, Lead> eligibleById = new Map<Id, Lead>(eligibleLeads);

            Map<Id, Lead_Event__c> currentStatusEvents =
                LeadStagnantAlertRepo.selectCurrentStatusEvents(eligibleById.keySet());

            Map<Id, List<LeadLineItem>> itemsByOwnerId = new Map<Id, List<LeadLineItem>>();
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();

            for (Lead l : eligibleById.values()) {
                Lead_Event__c e = currentStatusEvents.get(l.Id);
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

            // Write summary logs for skipped leads
            if (missingEventSkipped > 0) {
                addLog(logsToInsert, missingEventSkipped + ' lead(s) skipped: missing current status event (cannot compute days-in-status).', null, null);
            }
            if (invalidDaysSkipped > 0) {
                addLog(logsToInsert, invalidDaysSkipped + ' lead(s) skipped: computed negative/invalid days-in-status.', null, null);
            }

            if (itemsByOwnerId.isEmpty()) {
                addLog(logsToInsert, 'No leads hit a 7-day milestone today (' + String.valueOf(effectiveDate) + '). Eligible leads evaluated: ' + eligibleById.size() + '.', null, null);
                flushLogs(logsToInsert);
                return result;
            }

            Map<Id, User> ownersById =
                LeadStagnantAlertRepo.selectActiveUsersByIds(itemsByOwnerId.keySet());

            List<String> ccEmails = resolveCcEmails(result, logsToInsert);
            Id orgWideEmailAddressId = LeadStagnantAlertRepo.selectOrgWideEmailAddressId(ORG_WIDE_FROM_ADDRESS);

            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
            Integer totalLeadLines = 0;

            for (Id ownerId : itemsByOwnerId.keySet()) {
                User owner = ownersById.get(ownerId);
                if (owner == null) {
                    addLog(logsToInsert, 'Owner is not an active User; skipping ownerId=' + String.valueOf(ownerId), null, ownerId);
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
                String body = buildHtmlBody(owner, ownerItems);
                msg.setHtmlBody(body);
                if (Test.isRunningTest()) {
                    lastBuiltHtmlBodies.add(body);
                }
                if (orgWideEmailAddressId != null) {
                    msg.setOrgWideEmailAddressId(orgWideEmailAddressId);
                }
                emailsToSend.add(msg);
                totalLeadLines += ownerItems.size();
            }

            if (!emailsToSend.isEmpty()) {
                // Populate result counters based on intended sends (even if email is disabled in an environment).
                result.ownersEmailed = emailsToSend.size();
                result.leadsEmailed = totalLeadLines;
                try {
                    Messaging.sendEmail(emailsToSend);
                    addLog(logsToInsert, 'Successfully sent ' + emailsToSend.size() + ' email(s) to ' + emailsToSend.size() + ' owner(s) covering ' + totalLeadLines + ' lead(s).', null, null);
                } catch (Exception emailEx) {
                    String warn = 'Failed to send email(s): ' + emailEx.getMessage();
                    result.warnings.add(warn);
                    addLog(logsToInsert, warn, null, null);
                }
            }

            flushLogs(logsToInsert);
            return result;
        } catch (Exception e) {
            addLog(
                logsToInsert,
                'Unhandled exception: ' + e.getMessage() + '\n' + e.getStackTraceString(),
                null,
                null
            );
            flushLogs(logsToInsert);
            notifyDevOnError(e);
            throw e;
        }
    }

    /**
     * Checks if the days-in-status represents an exact 7-day milestone.
     * Returns true for: 7, 14, 21, 28, 35, 42, 49, 56, etc. (all multiples of 7 >= 7)
     * Returns false for: < 7, or any non-multiple of 7 (e.g., 8, 15, 22, 29, etc.)
     *
     * This ensures alerts continue at 7-day intervals beyond 21 days.
     */
    private static Boolean isExactSevenDayMilestone(Integer daysInStatus) {
        return daysInStatus != null && daysInStatus >= 7 && Math.mod(daysInStatus, 7) == 0;
    }

    private static List<String> resolveCcEmails(RunResult result, List<Custom_Log__c> logsToInsert) {
        List<String> ccEmails = new List<String>();

        try {
            String labelValue = System.Label.CC_Recipients_for_Stagnant_Lead_Email_Alerts;
            if (String.isBlank(labelValue)) {
                return ccEmails;
            }

            String[] emailParts = labelValue.split(';');
            for (String emailPart : emailParts) {
                String trimmedEmail = emailPart.trim();
                if (String.isNotBlank(trimmedEmail)) {
                    ccEmails.add(trimmedEmail);
                }
            }
        } catch (Exception e) {
            String warn = 'Failed to read CC recipients from Custom Label "CC_Recipients_for_Stagnant_Lead_Email_Alerts": ' + e.getMessage();
            result.warnings.add(warn);
            addLog(logsToInsert, warn, null, null);
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
            // Preserve readability for long text by converting line breaks to <br/> after escaping.
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

    private class LeadLineItemSorter implements Comparator<LeadLineItem> {
        public Integer compare(LeadLineItem a, LeadLineItem b) {
            Integer ad = (a == null || a.daysInStatus == null) ? 0 : a.daysInStatus;
            Integer bd = (b == null || b.daysInStatus == null) ? 0 : b.daysInStatus;
            if (ad != bd) {
                // Descending days
                return bd - ad;
            }
            String an = (a == null || a.leadName == null) ? '' : a.leadName.toLowerCase();
            String bn = (b == null || b.leadName == null) ? '' : b.leadName.toLowerCase();
            return an.compareTo(bn);
        }
    }

    private static void addLog(
        List<Custom_Log__c> logsToInsert,
        String message,
        Id leadId,
        Id relatedId
    ) {
        if (logsToInsert == null) {
            return;
        }
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
        try {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ 'development@nimbuscloudsolutions.com' });
            msg.setSubject('ERROR: ' + LOG_SOURCE);
            msg.setPlainTextBody(
                'Unhandled exception in ' + LOG_SOURCE + '\n\n' +
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