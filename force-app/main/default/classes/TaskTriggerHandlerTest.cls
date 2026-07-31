@isTest
public with sharing class TaskTriggerHandlerTest {
    @isTest
	static void newLeadNoContactTest() {
		Lead testLead = new Lead(
			FirstName = 'Lead',
			LastName = 'Test ' + Datetime.now().toString(),
			Status = 'New'
		);
		insert testLead;

		Task testCall = new Task(
			Subject = 'Call - No Contact',
			WhoId = testLead.Id,
			External_Message_to_Buyer_s_Agent__c = 'Test',
			TaskSubType = 'Call'
		);

		Test.startTest();
			insert testCall;
		Test.stopTest();

		Lead actualLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals('Contact Attempt 1', actualLead.Status, 'Status should be "Contact Attempt 1"');
	}

    @isTest
	static void contactAttemptLeadNoContactTest() {
		Lead testLead = new Lead(
			FirstName = 'Lead',
			LastName = 'Test ' + Datetime.now().toString(),
			Status = 'Contact Attempt 2'
		);
		insert testLead;

		Task testCall = new Task(
			Subject = 'Call - No Contact',
			WhoId = testLead.Id,
			External_Message_to_Buyer_s_Agent__c = 'Test',
			TaskSubType = 'Call'
		);

		Test.startTest();
			insert testCall;
		Test.stopTest();

		Lead actualLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals('Contact Attempt 3', actualLead.Status, 'Status should be "Contact Attempt 3"');
	}

    @isTest
	static void newLeadContactedCallTest() {
		Lead testLead = new Lead(
			FirstName = 'Lead',
			LastName = 'Test ' + Datetime.now().toString(),
			Status = 'New'
		);
		insert testLead;

		Task testCall = new Task(
			Subject = 'Contacted/Call Back',
			WhoId = testLead.Id,
			External_Message_to_Buyer_s_Agent__c = 'Test',
			TaskSubType = 'Call'
		);

		Test.startTest();
			insert testCall;
		Test.stopTest();

		Lead actualLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals('Contacted/Call Back', actualLead.Status, 'Status should be "Contacted/Call Back"');
	}

    @isTest
	static void contactedLeadWorkingCallTest() {
		Lead testLead = new Lead(
			FirstName = 'Lead',
			LastName = 'Test ' + Datetime.now().toString(),
			Status = 'Contacted/Call Back'
		);
		insert testLead;

		Task testCall = new Task(
			Subject = 'Call - Working',
			WhoId = testLead.Id,
			External_Message_to_Buyer_s_Agent__c = 'Test',
			TaskSubType = 'Call'
		);

		Test.startTest();
			insert testCall;
		Test.stopTest();

		Lead actualLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals('Working', actualLead.Status, 'Status should be "Working"');
	}

	@isTest
	static void newLeadNoContactUpdateTest() {
		Lead testLead = new Lead(
			FirstName = 'Lead',
			LastName = 'Test ' + Datetime.now().toString(),
			Status = 'New'
		);
		insert testLead;

		Task testCall = new Task(
			Subject = 'Call - No Contact',
			WhoId = testLead.Id,
			External_Message_to_Buyer_s_Agent__c = 'Test',
			TaskSubType = 'Call'
		);

		insert testCall;


		testCall.Subject = 'Call - Working';

		Test.startTest();
			update testCall;
		Test.stopTest();
	
		Lead actualLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals('Working', actualLead.Status, 'Status should be "Working"');
	}

	@isTest
	static void callCountChangeTest() {
		Lead testLead = new Lead(
			FirstName = 'Lead',
			LastName = 'Test ' + Datetime.now().toString(),
			Status = 'New'
		);
		insert testLead;

		Task testCall = new Task(
			Subject = 'Call - No Contact',
			WhoId = testLead.Id,
			External_Message_to_Buyer_s_Agent__c = 'Test',
			TaskSubType = 'Call'
		);

		insert testCall;

		Lead actualLead = [SELECT Id, Number_of_Calls__c FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals(1, actualLead.Number_of_Calls__c, 'Number_of_Calls__c should be increased on Call log');
		
		Test.startTest();
			delete testCall;
		Test.stopTest();

		actualLead = [SELECT Id, Number_of_Calls__c FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals(0, actualLead.Number_of_Calls__c, 'Number_of_Calls__c should be decreased on Call deletion');
	}
}