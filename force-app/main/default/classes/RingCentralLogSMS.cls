public with sharing class RingCentralLogSMS {

    public class Input {
        @InvocableVariable
        public List<String> extensionIds = new List<String>();
    }


    private static List<RingCentralErrorInfo> errors = new List<RingCentralErrorInfo>();
    private static String bearerToken;

    @InvocableMethod
    public static void  RingCentralCallSMS(List<Input> inputs) {
        try{

            Map<String, User> usersMap = getUsersMap(inputs[0].extensionIds);

            if (usersMap.isEmpty()) return;
            List<Ring_Central_Auth_Extension__mdt> mtd = [SELECT Token__c, ExtensionIds__c, DateFrom__c FROM Ring_Central_Auth_Extension__mdt LIMIT 1];
            if (mtd.isEmpty()) return;

            String token = mtd[0].Token__c;
            String dateFrom = mtd[0].DateFrom__c;

            List<Task> tasksToCreate = new List<Task>();

            if (inputs != null && inputs.size() != 0) {
                for (String extId:inputs[0].extensionIds ) {
                    tasksToCreate.addAll(createTasksForUserWithSms(usersMap, null, extId.trim(), dateFrom, token));
                }
            }

            if (!tasksToCreate.isEmpty()) {
                Database.SaveResult[] srList = Database.insert(tasksToCreate, false);
                for (Database.SaveResult sr : srList) {
                    if (sr.isSuccess()) {
                        System.debug('Successfully inserted account. Task ID: ' + sr.getId());
                    }
                    else {
                        for(Database.Error err : sr.getErrors()) {
                            System.debug('The following error has occurred.');                    
                            System.debug(err.getStatusCode() + ': ' + err.getMessage());
                            System.debug('Task fields that affected this error: ' + err.getFields());
                        }
                    }
                }
            }

            if (!errors.isEmpty()) {
                //sendErrorsEmail();
                System.debug(errors);
            }

        } catch (Exception e) {
            handleException(e);
        }
    }

    public static void  UpdateRingCentralCallSMS(List<Input> inputs) {
        try{

            Map<String, User> usersMap = getUsersMap(inputs[0].extensionIds);

            if (usersMap.isEmpty()) return;
            List<Ring_Central_Auth_Extension__mdt> mtd = [SELECT Token__c, ExtensionIds__c, DateFrom__c FROM Ring_Central_Auth_Extension__mdt LIMIT 1];
            if (mtd.isEmpty()) return;

            String token = mtd[0].Token__c;
            String dateFrom = mtd[0].DateFrom__c;

            List<Task> tasksToCreate = new List<Task>();

            if (inputs != null && inputs.size() != 0) {
                for (String extId:inputs[0].extensionIds ) {
                    tasksToCreate.addAll(createTasksForUserWithSms(usersMap, null, extId.trim(), dateFrom, token));
                }
            }

            if (!tasksToCreate.isEmpty()) {

                Map<String, Task> newTasksMap = new Map<String, Task>();
                for(Task t : tasksToCreate){
                    newTasksMap.put(t.rcsfl__CALL_UNIQUE_ID__c, t);
                }

                List<Task> existingTasks = [SELECT Id, rcsfl__CALL_UNIQUE_ID__c FROM Task WHERE rcsfl__CALL_UNIQUE_ID__c IN :newTasksMap.keySet()];
                for(Task t : existingTasks){
                    if(newTasksMap.containsKey(t.rcsfl__CALL_UNIQUE_ID__c)){
                        newTasksMap.get(t.rcsfl__CALL_UNIQUE_ID__c).Id = t.Id;
                    }
                }

                List<Task> tasksToUpdate = new List<Task>();
                for(task t : newTasksMap.values()){
                    if(t.id != null){
                        tasksToUpdate.add(t);
                    }
                }

                Database.update(tasksToUpdate, false);
            }

            if (!errors.isEmpty()) {
                //sendErrorsEmail();
                System.debug(errors);
            }

        } catch (Exception e) {
            handleException(e);
        }
    }

    private static Map<String, User> getUsersMap(List<String> extensionIds) {
        List<User> users = [SELECT Id, Name, Phone, Rc_Extension_Id__c FROM User WHERE IsActive = true AND Rc_Extension_Id__c IN :extensionIds];
        Map<String, User> usersMap = new Map<String, User>();

        for (User u : users) {
            usersMap.put(u.Rc_Extension_Id__c, u);
        }

        return usersMap;
    }

    private static List<Task> createTasksForUserWithSms(Map<String, User> usersMap, String nextUrl, String extensionId, String dateFrom, String token) {
        List<Task> tasksToCreate = new List<Task>();

        try {
            RingCentralApi.GetUserMessageRecords request = new RingCentralApi.GetUserMessageRecords(getAccessToken(token), nextUrl, extensionId, dateFrom);
            RingCentralApi_Models.MessageStoreResponse response = request.consume();

            if (response != null && response.records != null && !response.records.isEmpty()) {

                Set<String> connectedNumbers = extractConnectedNumbers(response.records);
                Map<String, Id> whatIdsFromPhoneMap = RingCentralLeadPriorityMatcher.getTransactionIdsByPhoneNumbers(connectedNumbers);
                Map<String, Id> leadIdsFromPhoneMap = RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(connectedNumbers);
                Map<String, Id> contactIdsFromPhoneMap = RingCentralLeadPriorityMatcher.getContactIdsByPhoneNumbers(connectedNumbers);

                for (RingCentralApi_Models.MessageRecord rec : response.records) {
                    if (!rec.type.equals('SMS')) continue;

                    Task t = createTaskFromMessageRecord(rec, usersMap, leadIdsFromPhoneMap, contactIdsFromPhoneMap, whatIdsFromPhoneMap);
                    if (t != null) tasksToCreate.add(t);

                }

                if (response.navigation.nextPage?.uri != null) {
                    tasksToCreate.addAll(createTasksForUserWithSms(usersMap, response.navigation.nextPage.uri, extensionId, null, token));
                }
            }
        } catch (Exception e) {
            handleException(e);
        }

        return tasksToCreate;
    }

    private static Set<String> extractConnectedNumbers(List<RingCentralApi_Models.MessageRecord> records) {
        Set<String> connectedNumbers = new Set<String>();

        for (RingCentralApi_Models.MessageRecord rec : records) {
            if (rec.direction == 'Inbound') {
                connectedNumbers.add(rec.fromObj.phoneNumber);
            } else if (rec.direction == 'Outbound' && rec.to != null && !rec.to.isEmpty() && rec.to[0] != null) {
                connectedNumbers.add(rec.to[0].phoneNumber);
            }
        }

        return connectedNumbers;
    }

    private static Task createTaskFromMessageRecord(
        RingCentralApi_Models.MessageRecord rec,
        Map<String, User> usersMap,
        Map<String, Id> leadIdsFromPhoneMap,
        Map<String, Id> contactIdsFromPhoneMap,
        Map<String, Id> whatIdsFromPhoneMap
    ) {
        Id userId = getUserIdFromMessageRecord(rec, usersMap);
        if (userId == null) {
            logMissingUser(rec);
            return null;
        }

        String toNumber = rec.to != null && rec.to.size() > 0 ? rec.to[0].phoneNumber : '';
        String calleeName = rec.to != null && rec.to.size() > 0 ? rec.to[0].name : '';

        String connectedPhone = rec.direction == 'Outbound' && rec.to != null && rec.to.size() > 0
            ? rec.to[0].phoneNumber
            : rec.fromObj.phoneNumber;
        Map<String, Id> taskRelation = resolveTaskRelationship(connectedPhone, leadIdsFromPhoneMap, contactIdsFromPhoneMap, whatIdsFromPhoneMap);

        Task taskToCreate = new Task(
            rcsfl__CALL_UNIQUE_ID__c = '' + rec.id,
            Subject = 'SMS',
            rcsfl__to_number__c = toNumber,
            rcsfl__callee_name__c = calleeName,
            Description = rec.subject,
            Status = 'Completed',
            rcsfl__from_number__c = rec.fromObj.phoneNumber,
            InteractionType__c = 'Sms',
            CallType = rec.direction,
            WhatId = taskRelation.get('whatId'),
            WhoId = taskRelation.get('whoId'),
            OwnerId = userId
        );

        if(rec.creationTime != null){
            DateTime actionDateTime = RingCentralApi_Models.parseRCTime(rec.creationTime);
            taskToCreate.ActivityDate = actionDateTime.date();
            taskToCreate.rcsfl__call_start_time__c = actionDateTime;
            String formatted = actionDateTime?.format('MM/dd/yyyy \'at\' hh:mm:ss a');
            taskToCreate.Subject = 'SMS on ' + formatted;
            if (rec?.to != null && rec?.to.size() > 0 && rec?.to[0].Name != null && rec?.fromObj?.Name != null) {
                taskToCreate.Subject = rec?.fromObj?.Name + ' texted ' + rec?.to[0]?.Name + ' on ' + formatted;
            }
        }

        return taskToCreate;
    }

    @TestVisible
    private static Map<String, Id> resolveTaskRelationship(
        String phoneNumber,
        Map<String, Id> leadIdsFromPhoneMap,
        Map<String, Id> contactIdsFromPhoneMap,
        Map<String, Id> whatIdsFromPhoneMap
    ) {
        Map<String, Id> resolution = new Map<String, Id>();
        String normalizedPhone = normalizePhoneNumber(phoneNumber);
        if (String.isBlank(normalizedPhone)) {
            return resolution;
        }

        Id leadId = leadIdsFromPhoneMap != null ? leadIdsFromPhoneMap.get(normalizedPhone) : null;
        if (leadId != null) {
            resolution.put('whoId', leadId);
            return resolution;
        }

        resolution.put('whoId', contactIdsFromPhoneMap != null ? contactIdsFromPhoneMap.get(normalizedPhone) : null);
        resolution.put('whatId', whatIdsFromPhoneMap != null ? whatIdsFromPhoneMap.get(normalizedPhone) : null);
        return resolution;
    }

    private static void handleException(Exception e) {
        System.debug(e);
        errors.add(new RingCentralErrorInfo(e));
        return;
    }

    /*private static void sendErrorsEmail() {
        String subject = 'Reach Home Loans Error Report for RingCentralUpdateCallLogsBatch - ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss');
        String body = getEmailBody();
        List<String> toAddresses = System.Label.Ring_Central_Error_Addresses.split(',');

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }*/

    /*private static String getEmailBody() {
        String body = '';
        for (RingCentralErrorInfo errorInfo : errors) {
            body += 'Exception: ' + errorInfo.exceptionMessage + '\n\n';
            if(errorInfo.exceptionStack != null){
                body += errorInfo.exceptionStack + '\n\n';
            }
        }
        return body;
    }*/

    private static String getAccessToken(String token) {
        System.debug(bearerToken);
        if (bearerToken == null) {
            RingCentralApiAdminToken__c userRCCredentials = RingCentralApiAdminToken__c.getOrgDefaults();
            RingCentralApi_Models.GetAccessTokenRequest getTokenReq = new RingCentralApi_Models.GetAccessTokenRequest();
            getTokenReq.jvtToken = token;
            getTokenReq.grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer';

            RingCentralApi.AuthenticateGetAccessToken consumer = new RingCentralApi.AuthenticateGetAccessToken(getTokenReq);
            bearerToken = consumer.consume();
        }
        return bearerToken;
    }

    private static String findNumber(Set<String> numbers, String phoneNumber) {
        for (String rowNumber : numbers) {
            if (phoneNumber.contains(rowNumber)) {
                return rowNumber;
            }
        }
        return null;
    }

    private class RingCentralErrorInfo {
        private String exceptionMessage;
        private String exceptionStack;

        private RingCentralErrorInfo(Exception e) {
            exceptionMessage = e.getMessage();
            exceptionStack = e.getStackTraceString();
        }

        private RingCentralErrorInfo(String message) {
            exceptionMessage = message;
        }
    }

    private static Id getUserIdFromMessageRecord(RingCentralApi_Models.MessageRecord rec, Map<String, User> usersMap) {
        String extensionId = rec.extensionId;

        if (String.isBlank(extensionId) || usersMap == null || usersMap.isEmpty()) {
            return null;
        }

        Boolean extensionIdExists = usersMap.keySet().contains(extensionId);
        return extensionIdExists ? usersMap.get(extensionId).Id : null;
    }

    private static void logMissingUser(RingCentralApi_Models.MessageRecord rec) {
            System.debug('No user with ' + rec.extensionId + ' in org');
            errors.add(new RingCentralErrorInfo('No user with ' + rec.extensionId  + ' in org'));
        
    }

    private static String normalizePhoneNumber(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        String normalized = phone.replaceAll('[^0-9]', ''); // Remove all non-numeric characters
        Integer len = normalized.length();
        return len > 9 ? normalized.substring(len - 9) : normalized; // Return last 9 characters
    }

    private static DateTime parseISODateTime(String isoDateTime) {
        DateTime result = (DateTime) DateTime.valueOfGmt(isoDateTime.replace('T', ' ').replace('Z', ''));
        return result;
    }

}

/*List<GetExtensionIdsInvocable.Result> extensionResults = GetExtensionIdsInvocable.getExtentionIds();
List<RingCentralLogSMS.Input> inputs = new List<RingCentralLogSMS.Input>();
RingCentralLogSMS.Input rcInput = new RingCentralLogSMS.Input();
rcInput.extensionIds = extensionResults[0].extensionIds;
inputs.add(rcInput);
RingCentralLogSMS.RingCentralCallSMS(inputs);*/