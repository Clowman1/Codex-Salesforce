@isTest 
private class RingCentralTests {

	public class GetUserCallLogsMock implements HttpCalloutMock{
		public HttpResponse response;
		public String responseBody200;

		public GetUserCallLogsMock(){
			responseBody200 = '{"uri":"https://platform.devtest.ringcentral.com/restapi/v1.0/account/365691004/extension/365691004/call-log?view=Simple&showBlocked=true&withRecording=false&dateFrom=2023-02-20T19:32:00.000Z&page=1&perPage=1000","records":[],"paging":{"page":1,"perPage":1000},"navigation":{"firstPage":{"uri":"https://platform.devtest.ringcentral.com/restapi/v1.0/account/365691004/extension/365691004/call-log?view=Simple&showBlocked=true&withRecording=false&dateFrom=2023-02-20T19:32:00.000Z&page=1&perPage=1000"}}}';
		}
		public HttpResponse respond(HttpRequest req){
			response.setBody(responseBody200);
			response.setStatusCode(200);
			return response;
		}
	}

		public class GetMessageStoreMock implements HttpCalloutMock{
		public HttpResponse response;
		public String responseBody200;

		public GetMessageStoreMock(){
			responseBody200 = '{"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008","id" : 2585111926008,"extensionId" : "63103870008","to" : [ {  "phoneNumber" : "+19543234375",  "name" : "Byron Richie",  "location" : "Coral Springs, FL"} ],"from" : {  "phoneNumber" : "+19544655321"},"type" : "SMS","creationTime" : "2024-05-16T20:17:15.000Z","readStatus" : "Unread","priority" : "Normal","attachments" : [ {  "id" : 2585111926008,  "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008/content/2585111926008",  "type" : "Text",  "contentType" : "text/plain"} ],"direction" : "Inbound","availability" : "Alive","subject" : "Is an arm worth it now?","messageStatus" : "Received","conversationId" : 332207683907457152,"conversation" : {  "id" : "332207683907457152",  "uri" : "https://platform.ringcentral.com/restapi/v1.0/conversation/332207683907457152"},"lastModifiedTime" : "2024-05-16T20:17:15.021Z"} ],"paging" : {  "page" : 1,  "totalPages" : 3,  "perPage" : 1,  "totalElements" : 3,  "pageStart" : 0,  "pageEnd" : 0},"navigation" : {  "nextPage" : {    "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store?availability=Alive&dateFrom=2024-05-16T14:00:00.000Z&page=2&perPage=1"  },  "firstPage" : {    "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store?availability=Alive&dateFrom=2024-05-16T14:00:00.000Z&page=1&perPage=1"  },  "lastPage" : {    "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store?availability=Alive&dateFrom=2024-05-16T14:00:00.000Z&page=3&perPage=1"  }}}';
		}
		public HttpResponse respond(HttpRequest req){
			response.setBody(responseBody200);
			response.setStatusCode(200);
			return response;
		}
	}

	public class GetAccessTokenMock implements HttpCalloutMock{
		public HttpResponse response;
		public String responseBody200;

		public GetAccessTokenMock(){
			responseBody200 = '{"access_token":"U0pDMTFQMDFQQVMwMHxBQUNTS2ZmcnUtN2M2SmdqckNjV3N0bWdzWjlMWnFNMnlKeUdsYWpYalFlckFHOFBsVzlIdnR6dnU4T1ljUEM4OVNMY1ZSeTRZZ2txS1E1STdsNnpvOWxjaHJ0ZUpMUHhoN0VFTk1JOS1ENWJFeEZJZ1RkSTZacVV1YUpwX0pFd0xnTVRhNGpWeHBzY0oxWWtzWnRQbVd5bjdPR2YxUzhpTjBUUXpkNjBRaGNjTVl5TVpKRTJzdXFyMzBUM0FtS3BDYWdrYV9rdXRiRXx4aXZHV0F8TG5LZzZaMVB4QnVjdUo2OG1vaU8yZ3xBUXxBQXxBQUFBQURzVHc5OA","token_type":"bearer","expires_in":3600,"refresh_token":"U0pDMTFQMDFQQVMwMHxBQUJyZE95azU1RW1HLTlscUxuRW51cjh6TXM5R3JPcVloczhaVVByWFdNbDlCLWYzTjBhNFBVbFhaMi1iQ1VpUDdCX0NOd1BpZmVNanJOYnpzaWE5VHk0TWNxRjk5bkdfZC1FODZkWC01Z2JhdDhPODZTbldXVkk2bWt3S1JfMnZ5WmRmU2xoQ0lOdXFBRW1JUU1JUVNVT3QwQU14SnlKQTh2MldBMFo4blBJMVhPVTZEbk1RMFl4ZDI3Rm1HS2t2WGdoQlJ4UGtsNHx4aXZHV0F8T3UtVml4T2Q3YVluUl9EeDJyWmtGQXxBUXxBQXxBQUFBQUJCUm9RNA","refresh_token_expires_in":604800,"scope":"ReadCallLog","owner_id":"365691004","endpoint_id":"n_kbS2pkTvWKL9GaWtumGg"}';
		}
		public HttpResponse respond(HttpRequest req){
			response.setBody(responseBody200);
			response.setStatusCode(200);
			return response;
		}
	}

	public class SingleRequestMock implements HttpCalloutMock {
        protected Integer code;
        protected String status;
        protected String bodyAsString;
        protected Blob bodyAsBlob;
        protected Map<String, String> responseHeaders;

        public SingleRequestMock(Integer code, String status, String body,
                Map<String, String> responseHeaders) {
            this.code = code;
            this.status = status;
            this.bodyAsString = body;
            this.bodyAsBlob = null;
            this.responseHeaders = responseHeaders;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse resp = new HttpResponse();
            resp.setStatusCode(code);
            resp.setStatus(status);
            if (bodyAsBlob != null) {
                resp.setBodyAsBlob(bodyAsBlob);
            } else {
                resp.setBody(bodyAsString);
            }

            if (responseHeaders != null) {
                for (String key : responseHeaders.keySet()) {
                    resp.setHeader(key, responseHeaders.get(key));
                }
            }
            return resp;
        }
    }

		public class MultiRequestMock implements HttpCalloutMock {

		SingleRequestMock getToken = new SingleRequestMock(200,
				'Complete',
				'{"access_token":"U0pDMDFQMTlQQVMwMHxBQUJ5","token_type":"bearer"}',
				null);
		SingleRequestMock sendSMSResponseMock = new SingleRequestMock(200,
				'Complete',
				'{ "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/call-log?view=Simple&showBlocked=true&withRecording=false&dateFrom=2024-06-13T10:59:00.000Z&page=1&perPage=2", "records" : [ { "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/call-log/AITcE5-Or_xgoc1A?view=Simple", "id" : "AITcE5-Or_xgoc1A", "sessionId" : "1606174908008", "startTime" : "2024-06-14T00:28:51.595Z", "duration" : 974, "durationMs" : 973833, "type" : "Voice", "internalType" : "LongDistance", "direction" : "Outbound", "action" : "VoIP Call", "result" : "Call connected", "to" : { "phoneNumber" : "+13366843326", "location" : "Burlington, NC" }, "from" : { "name" : "Lawrence Lanos", "phoneNumber" : "+17549465009", "extensionId" : "63349468008" }, "recording" : { "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/recording/2623464471008", "id" : "2623464471008", "type" : "Automatic", "contentUri" : "https://media.ringcentral.com/restapi/v1.0/account/62886676008/recording/2623464471008/content" }, "extension" : { "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63349468008", "id" : 63349468008 }, "telephonySessionId" : "s-a0d172a10c66ez1901425abc9z3bdfd760000", "partyId" : "p-a0d172a10c66ez1901425abc9z3bdfd760000-2" }, { "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/call-log/AITbRNEvRjE6781A?view=Simple", "id" : "AITbRNEvRjE6781A", "sessionId" : "1606136759008", "startTime" : "2024-06-13T23:40:46.797Z", "duration" : 50, "durationMs" : 49929, "type" : "Voice", "internalType" : "LocalNumber", "direction" : "Inbound", "action" : "Phone Call", "result" : "Accepted", "to" : { "phoneNumber" : "+17549465235" }, "from" : { "name" : "Delilah Harper", "phoneNumber" : "+13527057947", "location" : "Leesburg, FL" }, "recording" : { "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/recording/2623423838008", "id" : "2623423838008", "type" : "Automatic", "contentUri" : "https://media.ringcentral.com/restapi/v1.0/account/62886676008/recording/2623423838008/content" }, "reason" : "Accepted", "reasonDescription" : "The call connected to and was accepted by this number.", "telephonySessionId" : "s-a0d7adc095f8fz19013f9a73fz3b903090000", "partyId" : "p-a0d7adc095f8fz19013f9a73fz3b903090000-1" } ], "paging" : { "page" : 1, "perPage" : 2, "pageStart" : 0, "pageEnd" : 1 }, "navigation" : { "firstPage" : { "uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/call-log?view=Simple&showBlocked=true&withRecording=false&dateFrom=2024-06-13T10:59:00.000Z&page=1&perPage=2" } } }',
				null);
		SingleRequestMock getSMSResponseMock = new SingleRequestMock(200,
				'Complete',
				'{"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store?availability=Alive&dateFrom=2024-05-16T14:00:00.000Z&page=1&perPage=1","records" : [ {"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008","id" : 2585111926008,"extensionId" : "63103870008","to" : [ {"phoneNumber" : "+19543234375","name" : "Byron Richie","location" : "Coral Springs, FL"} ],"from" : {"phoneNumber" : "+19544655321"},"type" : "SMS","creationTime" : "2024-05-16T20:17:15.000Z", "readStatus" : "Unread", "priority" : "Normal","attachments" : [ {"id" : 2585111926008,"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008/content/2585111926008", "type" : "Text", "contentType" : "text/plain"} ], "direction" : "Inbound","availability" : "Alive","subject" : "Is an arm worth it now?","messageStatus" : "Received","conversationId" : 332207683907457152,"conversation" : {"id" : "332207683907457152","uri" : "https://platform.ringcentral.com/restapi/v1.0/conversation/332207683907457152"},"lastModifiedTime" : "2024-05-16T20:17:15.021Z"}, {"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008","id" : 2585111926008,"extensionId" : "63103870008","to" : [ {"phoneNumber" : "+9898989898989","name" : "Byron Richie","location" : "Coral Springs, FL"} ],"from" : {"phoneNumber" : "+19544655321"},"type" : "SMS","creationTime" : "2024-05-16T20:17:15.000Z", "readStatus" : "Unread", "priority" : "Normal","attachments" : [ {"id" : 2585111926008,"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008/content/2585111926008", "type" : "Text", "contentType" : "text/plain"} ], "direction" : "Inbound","availability" : "Alive","subject" : "Is an arm worth it now?","messageStatus" : "Received","conversationId" : 332207683907457152,"conversation" : {"id" : "332207683907457152","uri" : "https://platform.ringcentral.com/restapi/v1.0/conversation/332207683907457152"},"lastModifiedTime" : "2024-05-16T20:17:15.021Z"} , {"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008","id" : 2585111926009,"extensionId" : "63103870008323","to" : [ {"phoneNumber" : "+123543234375","name" : "Byron Richie","location" : "Coral Springs, FL"} ],"from" : {"phoneNumber" : "+19544655322"},"type" : "SMS","creationTime" : "2024-05-16T20:17:15.000Z", "readStatus" : "Unread", "priority" : "Normal","attachments" : [ {"id" : 2585111926008,"uri" : "https://platform.ringcentral.com/restapi/v1.0/account/62886676008/extension/63103870008/message-store/2585111926008/content/2585111926008", "type" : "Text", "contentType" : "text/plain"} ], "direction" : "Inbound","availability" : "Alive","subject" : "Is an arm worth it now?","messageStatus" : "Received","conversationId" : 332207683907457152,"conversation" : {"id" : "332207683907457152","uri" : "https://platform.ringcentral.com/restapi/v1.0/conversation/332207683907457152"},"lastModifiedTime" : "2024-05-16T20:17:15.021Z"}  ],"paging" : {"page" : 1,"totalPages" : 3,"perPage" : 1,"totalElements" : 3,"pageStart" : 0,"pageEnd" : 0},"navigation":{"firstPage":{"uri":"https://platform.devtest.ringcentral.com/restapi/v1.0/account/365691004/extension/365691004/call-log?view=Simple&phoneNumber=12053320032&extensionNumber=101&showBlocked=true&withRecording=false&dateFrom=2023-02-21T19:10:00.000Z&showDeleted=false&page=1&perPage=100"}}}',
				null);

		public HTTPResponse respond(HTTPRequest req) {
			HttpCalloutMock mock;
			HTTPResponse output;
			if (req.getEndpoint().contains('/call-log')) {
				output= sendSMSResponseMock.respond(req);
			} else if (req.getEndpoint().contains('/token')) {
				output= getToken.respond(req);
			} else if (req.getEndpoint().contains('/message-store')){
				output = getSMSResponseMock.respond(req);
			}
			return output;
		}
    }

	/*@isTest
	private static void testUpdateCallLogsBatch() {
		User u = new User(
			ProfileId = [SELECT Id FROM Profile LIMIT 1].Id,
			LastName = 'last',
			Email = 'puser000@amamama.com',
			Username = 'puser000@amamama.com' + System.currentTimeMillis(),
			CompanyName = 'TEST',
			Title = 'title',
			Alias = 'alias',
			TimeZoneSidKey = 'America/Los_Angeles',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			Phone = '+19543234375'
		);

		Contact cont = new Contact(
			FirstName = 'Test',
			LastName = 'Test',
			Phone = '+19544655321');
		
		Lead l = new Lead(
			FirstName = 'TestLead',
			LastName = 'TestLead',
			Phone = '+19544655322');

		insert cont;
		insert l;
		insert u;

		Task t = new Task(OwnerId=u.Id, rcsfl__CALL_UNIQUE_ID__c='8vsAH84JRCeg-DLA');
		insert t;
		insert new RingCentralUserAuth__c(Password__c = 'Value',Username__c='123abc');
		Test.setMock(HttpCalloutMock.class, new MultiRequestMock());
		Test.startTest();
		RingCentralUpdateCallLogsBatch obj = new RingCentralUpdateCallLogsBatch();

		Database.executeBatch(obj);
		//obj.createTasksForUser(u, null);
		//obj.sendErrorsEmail();

		Test.stopTest();
		System.debug(JSON.serializePretty('Tasks'+[SELECT Id,rcsfl__CALL_UNIQUE_ID__c,OwnerId,Description FROM Task]));
		System.assertEquals(4,[SELECT Id FROM Task].size(),'Another Task was created');
	}

	@isTest
	private static void RingCentralUpdateCallsAndSMSQueueable() {
		User u = new User(
			ProfileId = [SELECT Id FROM Profile LIMIT 1].Id,
			LastName = 'last',
			Email = 'puser000@amamama.com',
			Username = 'puser000@amamama.com' + System.currentTimeMillis(),
			CompanyName = 'TEST',
			Title = 'title',
			Alias = 'alias',
			TimeZoneSidKey = 'America/Los_Angeles',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			Phone = '+19543234375'
		);

		Contact cont = new Contact(
			FirstName = 'Test',
			LastName = 'Test',
			Phone = '+19544655321');
		
		Lead l = new Lead(
			FirstName = 'TestLead',
			LastName = 'TestLead',
			Phone = '+19544655322');

		insert cont;
		insert l;
		insert u;

		Task t = new Task(OwnerId=u.Id, rcsfl__CALL_UNIQUE_ID__c='8vsAH84JRCeg-DLA');
		insert t;


		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new MultiRequestMock());
		RingCentralUpdateCallsAndSMSQueueable queueableJob = new RingCentralUpdateCallsAndSMSQueueable();
        System.enqueueJob(queueableJob);

		Test.stopTest();
		System.debug(JSON.serializePretty('Tasks'+[SELECT Id,rcsfl__CALL_UNIQUE_ID__c,OwnerId,Description FROM Task]));
		System.assertEquals(4,[SELECT Id FROM Task].size(),'Another Task was created');
	}*/

	/*
	@IsTest
    public static void testUpdateCallLogsSchedule(){
		User u = new User(
			ProfileId = [SELECT Id FROM Profile LIMIT 1].Id,
			LastName = 'last',
			Email = 'puser000@amamama.com',
			Username = 'puser000@amamama.com' + System.currentTimeMillis(),
			CompanyName = 'TEST',
			Title = 'title',
			Alias = 'alias',
			TimeZoneSidKey = 'America/Los_Angeles',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US'
		);
		insert u;
		Task t = new Task(OwnerId=u.Id, rcsfl__CALL_UNIQUE_ID__c='8vsAH84JRCeg-DLA');
		insert t;
		insert new RingCentralUserAuth__c(Password__c = 'Value',Username__c='123abc');
		Test.startTest();
		String jobId = System.schedule('testBasicScheduledApex',
			'0 0 0 3 9 ? 2042',new RingCentralUpdateCallLogsBatch());
		Test.stopTest();
	}
	*/

		@isTest
	private static void TestGetCallLog() {
		User u = new User(
			ProfileId = [SELECT Id FROM Profile LIMIT 1].Id,
			Rc_Extension_Id__c = '631038700081',
			LastName = 'last',
			Email = 'puser000@amamama.com',
			Username = 'puser000@amamama.com' + System.currentTimeMillis(),
			CompanyName = 'TEST',
			Title = 'title',
			Alias = 'alias',
			TimeZoneSidKey = 'America/Los_Angeles',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			Phone = '+19543234375'
		);

		Contact cont = new Contact(
			FirstName = 'Test',
			LastName = 'Test',
			Phone = '+19544655321');
		
		Lead l = new Lead(
			FirstName = 'TestLead',
			LastName = 'TestLead',
			Phone = '+19544655322');

		insert cont;
		insert l;
		insert u;

		Task t = new Task(OwnerId=u.Id, rcsfl__CALL_UNIQUE_ID__c='8vsAH84JRCeg-DLA');
		insert t;
		insert new RingCentralUserAuth__c(Password__c = 'Value',Username__c='123abc');
		Test.setMock(HttpCalloutMock.class, new MultiRequestMock());
		Test.startTest();

		GetRingCentralCallLog.GetRingCentralCallLog();
		GetRingCentralCallLog.UpdateRingCentralCallLog();

		Test.stopTest();
		System.debug(JSON.serializePretty('Tasks'+[SELECT Id,rcsfl__CALL_UNIQUE_ID__c,OwnerId,Description FROM Task]));
		//System.assertEquals(2,[SELECT Id FROM Task].size(),'Another Task was created');
	}

		@isTest
	private static void TestGetSMS() {
		User u = new User(
			ProfileId = [SELECT Id FROM Profile LIMIT 1].Id,
			LastName = 'last',
			Email = 'puser000@amamama.com',
			Username = 'puser000@amamama.com' + System.currentTimeMillis(),
			CompanyName = 'TEST',
			Title = 'title',
			Alias = 'alias',
			TimeZoneSidKey = 'America/Los_Angeles',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			Phone = '+19543234375'
		);

		Contact cont = new Contact(
			FirstName = 'Test',
			LastName = 'Test',
			Phone = '+19544655321');
		
		Lead l = new Lead(
			FirstName = 'TestLead',
			LastName = 'TestLead',
			Phone = '+19544655322');

		insert cont;
		insert l;
		insert u;

		Task t = new Task(OwnerId=u.Id, rcsfl__CALL_UNIQUE_ID__c='8vsAH84JRCeg-DLA');
		insert t;
		insert new RingCentralUserAuth__c(Password__c = 'Value',Username__c='123abc');
		Test.setMock(HttpCalloutMock.class, new MultiRequestMock());
		Test.startTest();
		RingCentralUpdateCallLogsBatch obj = new RingCentralUpdateCallLogsBatch();

		List<GetExtensionIdsInvocable.Result> extensionResults = GetExtensionIdsInvocable.getExtentionIds();
		List<RingCentralLogSMS.Input> inputs = new List<RingCentralLogSMS.Input>();
		RingCentralLogSMS.Input rcInput = new RingCentralLogSMS.Input();
		rcInput.extensionIds = new List<String>{'63103870008', '1231234214'};
		inputs.add(rcInput);
		RingCentralLogSMS.RingCentralCallSMS(inputs);
		RingCentralLogSMS.UpdateRingCentralCallSMS(inputs);

		Test.stopTest();
		System.debug(JSON.serializePretty('Tasks'+[SELECT Id,rcsfl__CALL_UNIQUE_ID__c,OwnerId,Description FROM Task]));
		//System.assertEquals(2,[SELECT Id FROM Task].size(),'Another Task was created');
	}

	    @isTest
    static void testGetAccessTokenRequest() {

        RingCentralApi_Models.GetAccessTokenRequest request = new RingCentralApi_Models.GetAccessTokenRequest();
        request.grant_type = 'password';
        request.jvtToken = 'test_token';
        
        System.assertEquals('password', request.grant_type, 'Grant type should be password');
        System.assertEquals('test_token', request.jvtToken, 'Username should be test_token');
    }

    @isTest
    static void testTokenResponse() {

        RingCentralApi_Models.TokenResponse response = new RingCentralApi_Models.TokenResponse();
        response.access_token = 'test_access_token';
        response.token_type = 'Bearer';
        
        System.assertEquals('test_access_token', response.getAccessToken(), 'Access token should be test_access_token');
        System.assertEquals('Bearer', response.getTokenType(), 'Token type should be Bearer');
    }

	@isTest
    static void testSendErrorsEmail() {

        Profile p = [SELECT Id FROM Profile LIMIT 1];
        User u = new User(
            ProfileId = p.Id,
            LastName = 'TestLastNameTest',
            Email = 'testuser@example.com',
            // Usernames are globally unique across every Salesforce org, so this needs the same
            // unique suffix the other User inserts in this class already use.
            Username = 'testuserTest2@example.com' + System.currentTimeMillis(),
            CompanyName = 'TestCompany',
            Title = 'TestTitle',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
			Phone = '+19543234375'
        );
        insert u;


        RingCentralUpdateCallLogsBatch batchInstance = new RingCentralUpdateCallLogsBatch();

        Test.startTest();
        batchInstance.sendErrorsEmail();
        Test.stopTest();
    }

	    @isTest
    static void testGetYesterdayFormattedDate() {
        Test.startTest();
        String formattedDate = RingCentralUpdateCallLogsBatch.getYesterdayFormattedDate();
        Test.stopTest();
    }

	@isTest
	static void testGetExtentionIds(){
		Test.startTest();
		GetExtensionIdsInvocable.getExtentionIds();
		Test.stopTest();
	}
}