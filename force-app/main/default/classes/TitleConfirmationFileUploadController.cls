public class TitleConfirmationFileUploadController {

    @AuraEnabled
    public static void uploadFile(String recordId, String filename, String filetype, String base64Data) {
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        cv.Title = filename;
        cv.ContentLocation = 'S';
        cv.PathOnClient = filename;
        cv.FirstPublishLocationId = recordId;
        insert cv;
    }
    
    @AuraEnabled
    public static void sendEmail(String recordId, List<String> fileNames, String targetEmail) {
        Transaction__c loan = [SELECT Id, Name FROM Transaction__c WHERE Id = :recordId];
        OrgWideEmailAddress owea = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'reachus@reachhomeloans.com'];

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] { targetEmail };
                
        mail.setOrgWideEmailAddressId(owea.Id);
        mail.setToAddresses(toAddresses);
        mail.setSubject('Closing Package Uploaded: ' + loan.Name);
        
        String htmlTemplate = 'Closing Package files were uploaded for ' +
            				  '<a href="https://reachhomeloans.lightning.force.com/lightning/r/Transaction__c/' + loan.Id + '/view">' + loan.Name + '</a>: ' +
            				  fileNames.toString();
        
        mail.setHtmlBody(htmlTemplate);
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}