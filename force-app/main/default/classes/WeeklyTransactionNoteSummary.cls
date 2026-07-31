public class WeeklyTransactionNoteSummary implements Schedulable {
    public void execute(SchedulableContext ctx) {
        Date startOfWeek = Date.today().toStartOfWeek();
        Date endOfWeek = startOfWeek.addDays(6);
        
        List<Transaction__c> transactions = [
            SELECT Id, Name, Loan_Officer__c, Loan_Officer__r.Email,
            Status__c,  Opener_Note__c, Opener_Note_Date_Time__c,
            Processor_Note__c, Processor_Note_Date_Time__c,
            Closer_Note__c, Closer_Note_Date_Time__c,
            Management_Note__c, Management_Note_Date_Time__c
            FROM Transaction__c
            WHERE (Opener_Note_Date_Time__c = THIS_WEEK    OR
                   Processor_Note_Date_Time__c = THIS_WEEK  OR
                   Closer_Note_Date_Time__c = THIS_WEEK     OR
                   Management_Note_Date_Time__c = THIS_WEEK)
            AND Loan_Officer__c  != null
            AND Status__c != 'Post-Closed'
        ];
        
        Map<Id, List<Transaction__c>> groupedByOfficer = new Map<Id, List<Transaction__c>>();
        Map<Id, String> officerEmails = new Map<Id, String>();
        
        for (Transaction__c t : transactions) {
            if (!groupedByOfficer.containsKey(t.Loan_Officer__c)) {
                groupedByOfficer.put(t.Loan_Officer__c, new List<Transaction__c>());
                officerEmails.put(t.Loan_Officer__c, t.Loan_Officer__r.Email);
            }
            groupedByOfficer.get(t.Loan_Officer__c).add(t);
        }
        
        Map<Id, User> loanOfficers = new Map<Id, User>([SELECT Id, FirstName, LastName FROM User WHERE Id IN :groupedByOfficer.keySet()]);
        OrgWideEmailAddress address = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'reachus@reachhomeloans.com'];
        
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Id officerId : groupedByOfficer.keySet()) {
            List<Transaction__c> officerTransactions = groupedByOfficer.get(officerId);
            String htmlBody = buildHtmlTable(officerTransactions);
            User loanOfficer = loanOfficers.get(officerId);
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { officerEmails.get(officerId) });
            email.setCcAddresses(new String[] { 'ccash@reachhomeloans.com' });
            email.setSubject('Transaction Notes Summary ' + loanOfficer.FirstName + ' ' + loanOfficer.LastName + ': ' + Date.today().format());
            email.setHtmlBody(htmlBody);
            email.setOrgWideEmailAddressId(address.Id);
            messages.add(email);
        }
        
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(messages);
        }
    }
    
    private String buildHtmlTable(List<Transaction__c> transactions) {
        String html = '<h3>Transaction Notes Summary</h3>';
        html += '<table border="1" cellpadding="5" cellspacing="0" style="border: 1px solid #9e9e9e;">';
        html += '<tr style="border: 1px solid #9e9e9e;"><th style="border: 1px solid #9e9e9e;">Transaction Name</th><th style="border: 1px solid #9e9e9e;">Status</th><th style="border: 1px solid #9e9e9e;">Opener Note</th><th style="border: 1px solid #9e9e9e;">Opener Date</th>' +
            '<th style="border: 1px solid #9e9e9e;">Processor Note</th><th style="border: 1px solid #9e9e9e;">Processor Date</th>' +
            '<th style="border: 1px solid #9e9e9e;">Closer Note</th><th style="border: 1px solid #9e9e9e;">Closer Date</th>' +
            '<th style="border: 1px solid #9e9e9e;">Management Note</th><th style="border: 1px solid #9e9e9e;">Management Date</th></tr>';
        
        for (Transaction__c t : transactions) {
            html += '<tr style="border: 1px solid #9e9e9e;">';
            html += '<td style="border: 1px solid #9e9e9e;">' + t.Name + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + t.Status__c + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + (t.Opener_Note__c == null ? '' : t.Opener_Note__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + formatDateTime(t.Opener_Note_Date_Time__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + (t.Processor_Note__c == null ? '' : t.Processor_Note__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + formatDateTime(t.Processor_Note_Date_Time__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + (t.Closer_Note__c == null ? '' : t.Closer_Note__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + formatDateTime(t.Closer_Note_Date_Time__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + (t.Management_Note__c == null ? '' : t.Management_Note__c) + '</td>';
            html += '<td style="border: 1px solid #9e9e9e;">' + formatDateTime(t.Management_Note_Date_Time__c) + '</td>';
            html += '</tr>';
        }
        
        html += '</table>';
        return html;
    }
    
    private String formatDateTime(Datetime dt) {
        return dt == null ? '' : dt.format('yyyy-MM-dd HH:mm');
    }
}