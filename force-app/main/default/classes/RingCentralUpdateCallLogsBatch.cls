global class RingCentralUpdateCallLogsBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable,Database.Stateful{
	private List<RingCentralErrorInfo> errors = new List<RingCentralErrorInfo>();
	private static String bearerToken;
	global RingCentralUpdateCallLogsBatch() {
		
	}
	
	/**
	 * @description gets invoked when the batch job starts
	 * @param context contains the job ID
	 * @returns the record set as a QueryLocator object that will be batched for execution
	 */ 
	global Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator('SELECT Id, Name, Phone FROM User WHERE IsActive = true ' + Label.RingCentralUpdateCallLogsBatchDebug);
	}

	/**
	 * @description gets invoked when the batch job executes and operates on one batch of records. Contains or calls the main execution logic for the batch job.
	 * @param context contains the job ID
	 * @param scope contains the batch of records to process.
	 */ 
   	global void execute(Database.BatchableContext context, List<User> scope) {

		List<Task> tasksToCreate = new List<Task>();
		Map<String, User> usersMap = new Map<String, User>();
		for(User u : scope){
			System.debug('User  = ' + u.Name + u.Phone);
			if(u.Phone != null){
				usersMap.put(u.Phone.replaceAll('[^0-9]', ''), u);
			}
		}
		List<Ring_Central_Auth_Extension__mdt> mtd = new List<Ring_Central_Auth_Extension__mdt>();
		if(Test.isRunningTest() == false){
			mtd.addAll([SELECT Token__c, ExtensionIds__c,  DateFrom__c FROM Ring_Central_Auth_Extension__mdt]);
		} else {
			Ring_Central_Auth_Extension__mdt rcmtd = new Ring_Central_Auth_Extension__mdt(ExtensionIds__c = '12321', Token__c = 'asdasd');
			mtd.add(rcmtd);
		}
		

		List<Task> userTasks = createTasksForUser(usersMap, null, mtd[0].DateFrom__c, mtd[0].Token__c);
		List<Task> smsTask = new List<Task>();

		for(String extId: mtd[0].ExtensionIds__c.split(',')){
			smsTask.addAll(createTasksForUserWithSms(usersMap, null, extId.trim(), mtd[0].DateFrom__c, mtd[0].Token__c));
		}
		if(userTasks != null && userTasks.size() > 0){
			tasksToCreate.addAll(userTasks);
		}
		if(smsTask != null && smsTask.size() > 0){
			tasksToCreate.addAll(smsTask);
		}
		if(tasksToCreate.size() > 0){
			Database.insert(tasksToCreate,false);
		}
	}
	
	global void execute(SchedulableContext sc){
		RingCentralUpdateCallLogsBatch obj = new RingCentralUpdateCallLogsBatch();
		Database.executeBatch(obj,1);
	}
	
	/**
	 * @description gets invoked when the batch job finishes. Place any clean up code in this method.
	 * @param context contains the job ID
	 */ 
	global void finish(Database.BatchableContext context) {
		if (this.errors.size() > 0) {
			sendErrorsEmail();
		}
	}

	public List<Task> createTasksForUser(Map<String, User> usersMap, String nextUrl, String dateFrom, String token){
	
		List<Task> tasksToCreate = new List<Task>();
		List<Task> tasksForCheck = new List<Task>();
		RingCentralApi.GetUserCallRecords getUserCallRecordsrequest;
		RingCentralApi_Models.GetUserCallRecordsResponse response;
		Set<String> rcExternalIds = new Set<String>();
		try {
			getUserCallRecordsrequest = new RingCentralApi.GetUserCallRecords(getAccessToken(token), nextUrl, dateFrom);
			response = getUserCallRecordsrequest.consume();
		} catch (Exception e) {
			//this.errors.add(new RingCentralErrorInfo(u, e));
			if (e.getMessage().contains('invalid_grant')) {

			return null;
			}
		}
		System.debug('Response --- '+JSON.serializePretty(response));
		if(response != null && response.records != null && response.records.size() > 0){
			for(RingCentralApi_Models.Records rec : response?.records){
				rcExternalIds.add(rec.id);
				Task t = new Task(rcsfl__CALL_UNIQUE_ID__c=rec.id,
				rcsfl__to_number__c=rec.to.phoneNumber,
				Description=rec.result,
				rcsfl__callee_name__c=rec.to.name,
				Status='Completed',
				rcsfl__from_number__c=rec?.fromObj?.phoneNumber,
				CallType=rec?.direction);
				
				Id userId = null;

				if(rec.direction == 'Inbound'){
					if(this.findNumber(usersMap.keySet(), (rec.to.phoneNumber)) != null) {
						userId = usersMap.get(this.findNumber(usersMap.keySet(), (rec.to.phoneNumber))).Id;
					}
				} else {
					if(this.findNumber(usersMap.keySet(), (rec.fromObj.phoneNumber)) != null) {
						userId = usersMap.get(this.findNumber(usersMap.keySet(), (rec.fromObj.phoneNumber))).Id;
					}

				}
				if(userId != null){
					t.OwnerId = userId;
					tasksForCheck.add(t);
				} else {
					if(rec.direction == 'Inbound'){
							System.debug('There is`n user with number ' + rec.to + ' in org');
					} else {
						System.debug('There is`n user with number ' + rec.fromObj + ' in org');
					}
				}
			}
		}

		Set<String> ringCentralCallIds = getSetOfRingCentralCallIds(rcExternalIds);
		for(Task t: tasksForCheck){
			if(!ringCentralCallIds.contains(t.rcsfl__CALL_UNIQUE_ID__c)){
				tasksToCreate.add(t);
			}
		}
		System.debug('NextPage = ' + response?.navigation?.nextPage?.uri);
		if(response?.navigation?.nextPage?.uri != null){ 
			tasksToCreate.addAll(createTasksForUser(usersMap ,response?.navigation?.nextPage?.uri, null, token));
		}
		return tasksToCreate;
	}
	


	public List<Task> createTasksForUserWithSms(Map<String, User> usersMap, String nextUrl, String extensionId, String dateFrom, String token){

		RingCentralApi.GetUserMessageRecords getMessagesRequest;
		RingCentralApi_Models.MessageStoreResponse response;
			try {
			getMessagesRequest = new RingCentralApi.GetUserMessageRecords(getAccessToken(token),nextUrl, extensionId, dateFrom);
			response = getMessagesRequest.consume();
		} catch (Exception e) {
			//this.errors.add(new RingCentralErrorInfo(u, e));
			if (e.getMessage().contains('invalid_grant')) {
			return null;
		}
		}

		List<Task> tasksToCreate = new List<Task>();
		List<Task> tasksForCheck = new List<Task>();
		Set<String> connectedNumbers = new Set<String>();
		Set<String> rcExternalIds = new Set<String>();

		if(response.records != null && response.records.size() > 0){
			for(RingCentralApi_Models.MessageRecord rec : response?.records){
				if(rec.direction == 'Inbound'){
					connectedNumbers.add(rec.fromObj.phoneNumber);
				}
				else if (rec.direction == 'Outbound'){
					if(rec.to[0] != null){
						connectedNumbers.add(rec.to[0].phoneNumber);
					}
				}
			}

			Map<String, Id> whoIdsFromPhoneMap = getWhoIdsByPhoneNumbers(connectedNumbers);

			for(RingCentralApi_Models.MessageRecord rec : response?.records){
				if (rec.type != 'SMS') {
					continue;
				}
                System.debug('message -----> \n'  + JSON.serializePretty(rec));
				String toNumber = rec?.to?.size() > 0 ? rec.to[0].phoneNumber : '';
                String calleeName = rec?.to?.size() > 0 ? rec.to[0].name : '';
				rcExternalIds.add(''+rec.id);
				Task t = new Task(rcsfl__CALL_UNIQUE_ID__c=''+rec.id,
				rcsfl__to_number__c=toNumber,
				rcsfl__callee_name__c=calleeName,
				Status='Completed',
				rcsfl__from_number__c=rec?.fromObj?.phoneNumber,
				InteractionType__c = 'Sms',
				CallType=rec?.direction,
				WhoId = whoIdsFromPhoneMap.get(rec.direction == 'Outbound'?rec.to[0].phoneNumber:rec.fromObj.phoneNumber));
				Id userId = null;

				if(rec.direction == 'Inbound'){
					if(this.findNumber(usersMap.keySet(), (rec.to[0].phoneNumber)) != null) {
						userId = usersMap.get(this.findNumber(usersMap.keySet(), (rec.to[0].phoneNumber))).Id;
					}
				} else {
					if(this.findNumber(usersMap.keySet(), (rec.fromObj.phoneNumber)) != null) {
						userId = usersMap.get(this.findNumber(usersMap.keySet(), (rec.fromObj.phoneNumber))).Id;
					}

				}
				if(userId != null){
					t.OwnerId = userId;
					tasksForCheck.add(t);
				} else {
					if(rec.direction == 'Inbound'){
							System.debug('There is`n user with number ' + rec.to + ' in org');
					} else {
						System.debug('There is`n user with number ' + rec.fromObj + ' in org');
					}
				}
			}
		}

		Set<String> ringCentralCallIds = getSetOfRingCentralCallIds(rcExternalIds);
		for(Task t: tasksForCheck){
			if(!ringCentralCallIds.contains(t.rcsfl__CALL_UNIQUE_ID__c)){
				tasksToCreate.add(t);
			}
		}

		System.debug('NextPage = ' + response?.navigation?.nextPage?.uri);
		System.debug(tasksToCreate);
		if(response?.navigation?.nextPage?.uri != null){
			tasksToCreate.addAll(createTasksForUserWithSms(usersMap,response?.navigation?.nextPage?.uri, extensionId, null, token));
		}
		return tasksToCreate;
	}

	private static Map<String, Id> getWhoIdsByPhoneNumbers(Set<String> numbers){
		Map<String, Id> phoneMap = new Map<String, Id>();
		for(Contact cont : [SELECT Id, Phone FROM Contact WHERE Phone in :numbers]){
			phoneMap.put(cont.Phone, cont.Id);
		}
		for(Lead l : [SELECT Id, Phone FROM Lead WHERE Phone in :numbers]){
			phoneMap.put(l.Phone, l.Id);
		}
		return phoneMap;
	}

	public static Set<String> getSetOfRingCentralCallIds(Set<String> ids){
		List<Task> existingTasksForUser = [SELECT Id,rcsfl__CALL_UNIQUE_ID__c FROM Task WHERE rcsfl__CALL_UNIQUE_ID__c IN :ids];
		Set<String> ringCentralCallIds = new Set<String>();
		for(Task t : existingTasksForUser){
			ringCentralCallIds.add(t.rcsfl__CALL_UNIQUE_ID__c);
		}
		if(ringCentralCallIds.size() > 0){
			return ringCentralCallIds;
		}else{
			return ringCentralCallIds;
		}
	}

	public static String getAccessToken(String token){
		if(bearerToken == null){
			RingCentralApiAdminToken__c userRCCredentials = RingCentralApiAdminToken__c.getOrgDefaults();
			RingCentralApi_Models.GetAccessTokenRequest getTokenReq = new RingCentralApi_Models.GetAccessTokenRequest();
			getTokenReq.jvtToken = token;
			getTokenReq.grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
			System.debug('Get Token Request ---- '+JSON.serializePretty(getTokenReq));
			RingCentralApi.AuthenticateGetAccessToken consumer = new RingCentralApi.AuthenticateGetAccessToken(getTokenReq);
			bearerToken = consumer.consume();
			// return accessToken;
		}
		return bearerToken;
	}

	public void sendErrorsEmail() {
		String subject = 'Reach Home Loans Error Report for RingCentralUpdateCallLogsBatch - ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss');
        String body = getEmailBody();
		List<String> toAddresses = System.Label.Ring_Central_Error_Addresses.split(',');
        // String[] toAddresses = new String[] {System.Label.Ring_Central_Recipients};
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
		mail.setTemplateId(null);
        if (!Test.isRunningTest()) {
			Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
		}
	}
    
    // Method to generate email body
    private String getEmailBody() {
        String body = '';
        body += 'Please find below the details of recent errors:\n\n';
        
        for(RingCentralErrorInfo errorInfo : this.errors) {
            body += 'User ID: ' + errorInfo.userId + '\n';
            //body += 'User Name: ' + errorInfo.userName + '\n';
            body += 'Exception Message: ' + errorInfo.exceptionMessage + '\n';
            body += 'Exception Stack Trace: ' + errorInfo.exceptionStack + '\n\n';
        }
        
        return body;
    }

	private class RingCentralErrorInfo {
		private Id userId;
		private String userName;
		private String exceptionMessage;
		private String exceptionStack;

		private RingCentralErrorInfo(User u, Exception e) {
			userId = u.Id;
			userName = u.Name;
			exceptionMessage = e.getMessage();
			exceptionStack = e.getStackTraceString();
		}
	}

	public static String getYesterdayFormattedDate() {

        Datetime yesterday = Datetime.now().addDays(-1);
        
        Datetime yesterdayAt5PM = Datetime.newInstance(
            yesterday.year(),
            yesterday.month(),
            yesterday.day(),
            17, // 5 pm
            0, // Minutes
            0 // Seconds
        );
        
        return yesterdayAt5PM.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }

	private String findNumber(Set<String> numbers, String phoneNumber){
		for(String rowNumber: numbers){
			if(phoneNumber.contains(rowNumber)) {
				return rowNumber;
			}
		}

		return null;
	}
}