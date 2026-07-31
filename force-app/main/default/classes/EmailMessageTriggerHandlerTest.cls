@IsTest
private class EmailMessageTriggerHandlerTest {
    @testSetup static void setup() {
        Account acc = (Account)TDF.createSObject('Account', new Map<String,Object>{
                'FirstName' => 'Test',
                'LastName' => 'Somebody',
                'PersonEmail' => 'test@email.com',
                'RecordTypeId' => [SELECT Id, Name FROM RecordType WHERE Name = 'Person Account'].Id
        });

        Transaction__c o = new Transaction__c(Borrower_Name__c=acc.Id,Name='TodaysTest',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;

    }

    @IsTest
    static void testForDateStamp() {
        Transaction__c transact = [SELECT Id FROM Transaction__c LIMIT 1];
        transact.Closing_Package_One_Drive_Link__c = 'abc';
        update transact;
        
        EmailTemplate temp = [Select id from EmailTemplate where DeveloperName = 'Closing_Instructions_Funding_Authorization_1656379782794'];

        EmailMessage emailMessage = new EmailMessage();
        emailMessage.status = '3'; // email was sent
        emailMessage.relatedToId = transact.Id;
        emailMessage.fromAddress = 'test@test.com'; // from address
        emailMessage.fromName = 'Test Department'; // from name
        emailMessage.toAddress = 'test@example.com';
        emailMessage.Subject = 'Hello';
        emailMessage.EmailTemplateId = temp.Id;
        emailMessage.HtmlBody = 'Hello World';

        insert emailMessage;
        Transaction__c o = [SELECT Id, Closing_Package_Sent__c FROM  Transaction__c WHERE Name = 'TodaysTest'];
    }
    

    @IsTest
    static void testForNoLink() {
        Transaction__c transact = [SELECT Id, Closing_Package_Sent__c FROM  Transaction__c WHERE Name = 'TodaysTest'];        
        EmailTemplate temp = [Select id from EmailTemplate where DeveloperName = 'Closing_Instructions_Funding_Authorization_1656379782794'];

        EmailMessage emailMessage = new EmailMessage();
        emailMessage.status = '3'; // email was sent
        emailMessage.relatedToId = transact.Id;
        emailMessage.fromAddress = 'test@test.com'; // from address
        emailMessage.fromName = 'Test Department'; // from name
        emailMessage.toAddress = 'test@example.com';
        emailMessage.Subject = 'Hello';
        emailMessage.EmailTemplateId = temp.Id;
        emailMessage.HtmlBody = 'Hello World';
		
        Boolean isExceptionCaught = false;
        try{            
            insert emailMessage;
        }catch(DmlException e){
            isExceptionCaught = true;
        }
        System.assertEquals(true,isExceptionCaught);
    }
}