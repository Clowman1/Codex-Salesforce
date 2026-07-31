@isTest
public with sharing class LeadNotesFormControllerTest {
	@TestSetup
	static void makeData(){
		Lead testLead = new Lead(
			FirstName = 'Test',
			LastName = Datetime.now().toString()
		);

		insert testLead;
	}
    @isTest
	static void getNotesTest() {
		Lead testLead = [SELECT Id FROM Lead ORDER BY CreatedDate DESC LIMIT 1];
		String testLeadNotes = 'Test Lead Notes on: ' + Datetime.now().toString();
		testLead.Lead_Notes_JSON__c = testLeadNotes;
	
		update testLead;

		Test.startTest();
		String actualNotes = LeadNotesFormController.getNotes(testLead.Id);
		Test.stopTest();

		System.assertEquals(testLeadNotes, actualNotes, 'Wrong notes returned');
    } 

	@isTest
	static void saveNotesTest() {
		Lead testLead = [SELECT Id FROM Lead ORDER BY CreatedDate DESC LIMIT 1];
		String testLeadNotes = 'Test Lead Notes on: ' + Datetime.now().toString();
		
		Test.startTest();
		LeadNotesFormController.saveNotes(testLead.Id, testLeadNotes);
		Test.stopTest();

		Lead actualLead = [SELECT Id, Lead_Notes_JSON__c FROM Lead WHERE Id = :testLead.Id];

		System.assertEquals(testLeadNotes, actualLead.Lead_Notes_JSON__c, 'Notes were not set');
	}

	@isTest
	static void createNoteTest() {
		Lead testLead = [SELECT Id, Name FROM Lead ORDER BY CreatedDate DESC LIMIT 1];
		Map<String, String> notesMap = new Map<String, String>{
			'Borrower Name' => testLead.Name
		};
		String notesJSON = JSON.serialize(notesMap);

		Test.startTest();
		LeadNotesFormController.createNote(testLead.Id, notesJSON, notesJSON);
		Test.stopTest();

		Enhanced_Note__c note = [SELECT Id, Body__c FROM Enhanced_Note__c WHERE Lead__c = :testLead.Id ORDER BY CreatedDate DESC LIMIT 1];
	
		System.assertNotEquals(null, note, 'Note should be created');
		System.assertEquals(true, note.Body__c.contains(testLead.name), 'Enhanced Note is not populated correctly');
	}
}