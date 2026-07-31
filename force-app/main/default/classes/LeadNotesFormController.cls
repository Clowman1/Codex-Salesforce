public class LeadNotesFormController {
	@AuraEnabled
	public static String getNotes(Id recordId){
		try {
			return [SELECT Id, Lead_Notes_JSON__c FROM Lead WHERE Id = :recordId].Lead_Notes_JSON__c;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static void saveNotes(Id recordId, String notes){
		try {
			Lead l = new Lead(Id = recordId, Lead_Notes_JSON__c = notes);
			update l;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static void createNote(Id recordId, String borrowerNotes, String coBorrowerNotes){
		try {
			User currentUser = getCurrentUser();
			Enhanced_Note__c newNote = new Enhanced_Note__c();
			newNote.Lead__c = recordId;
			newNote.Subject__c = 'Lead Details';
			newNote.Body__c = getNoteBody(borrowerNotes, coBorrowerNotes);
	
			insert newNote;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static User getCurrentUser() {
		return [
			SELECT Id, Enhanced_Note_Role__c
			FROM User
			WHERE Id = :UserInfo.getUserId()
		];
	}

	private static String getNoteBody(String borrowerNotes, String coBorrowerNotes) {
		String body = '<p><b>Borrower</b></p><ul>';
		Map<String, Object> notesMap = (Map<String, Object>) JSON.deserializeUntyped(borrowerNotes);

		for (String key :notesMap.keySet()) {
			body += '<li>' + key + ': ' + (String) notesMap.get(key) + '</li>';
		}

        body = body + '</ul>';
        
        Map<String, Object> coBorrNotesMap = (Map<String, Object>) JSON.deserializeUntyped(coBorrowerNotes);
        
        if (coBorrNotesMap != null && coBorrNotesMap.size() > 0) {
            body = body + '<hr/><p><b>Co-Borrower</b></p><ul>';
            for (String key : coBorrNotesMap.keySet()) {
                body += '<li>' + key + ': ' + (String) coBorrNotesMap.get(key) + '</li>';
            }
            
            body = body + '</ul>';
        }
        
		return body;
	}
}