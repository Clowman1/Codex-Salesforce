@isTest
public class AlertControllerTest {
	@isTest
    public static void runTest(){               
        Account acc = (Account)TDF.createSObject('Account', new Map<String,Object>{
                'FirstName' => 'Test',
                'LastName' => 'Somebody',
                'PersonEmail' => 'test@email.com',
                'RecordTypeId' => [SELECT Id, Name FROM RecordType WHERE Name = 'Person Account'].Id
        });
        Transaction__c o = new Transaction__c(Borrower_Name__c=acc.Id,Name='TodaysTest',Clear_to_Close_Date__c=date.today().addMonths(1), BPS__c=0.10, Loan_Amount_1st__c=250000,Lead_Source__c='Website - Purchase');
        insert o;
        Alert__mdt alert = [SELECT Id, Title__c, Complete_Message__c, Incomplete_Message__c, (SELECT Id, Alert__c, API_Name__c, Title__c FROM Alert_Fields__r) FROM Alert__mdt LIMIT 1];
        AlertController.getEmptyFieldsFromLoan(o.Id,alert.Id);
        AlertController.runTest();
    }
}