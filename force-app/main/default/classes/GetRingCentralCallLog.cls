public class GetRingCentralCallLog {

    private static List<RingCentralErrorInfo> errors = new List<RingCentralErrorInfo>();
    private static String bearerToken;

    @InvocableMethod
    public static void GetRingCentralCallLog() {
        try{
            Map<String, User> usersMap = getUsersMap();
            if (usersMap.isEmpty()) return;
            List<Ring_Central_Auth_Extension__mdt> mtd = [SELECT Token__c, ExtensionIds__c, DateFrom__c FROM Ring_Central_Auth_Extension__mdt LIMIT 1];
            if (mtd.isEmpty()) return;

            String token = mtd[0].Token__c;
            String dateFrom = mtd[0].DateFrom__c;

            List<Task> tasksToCreate = new List<Task>();
            tasksToCreate.addAll(createTasksForUser(usersMap, null, dateFrom, token));

            if (!tasksToCreate.isEmpty()) {
                System.debug(tasksToCreate);
                Database.insert(tasksToCreate, false);
            }

            if (!errors.isEmpty()) {
                //sendErrorsEmail();
                System.debug(errors);
            }
        } catch (Exception e) {
            handleException(e);
        }
    }

    public static void UpdateRingCentralCallLog() {
        try{
            Map<String, User> usersMap = getUsersMap();
            if (usersMap.isEmpty()) return;
            List<Ring_Central_Auth_Extension__mdt> mtd = [SELECT Token__c, ExtensionIds__c, DateFrom__c FROM Ring_Central_Auth_Extension__mdt LIMIT 1];
            if (mtd.isEmpty()) return;

            String token = mtd[0].Token__c;
            String dateFrom = mtd[0].DateFrom__c;

            List<Task> tasksToCreate = new List<Task>();
            tasksToCreate.addAll(createTasksForUser(usersMap, null, dateFrom, token));

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
                        System.debug(tasksToUpdate);
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



    private static Map<String, User> getUsersMap() {
        List<User> users = [SELECT Id, Name, Phone, Rc_Extension_Id__c FROM User WHERE IsActive = true AND Rc_Extension_Id__c != null];
        Map<String, User> usersMap = new Map<String, User>();

        for (User u : users) {
            usersMap.put(u.Rc_Extension_Id__c, u);
        }

        return usersMap;
    }

    @TestVisible
    private static List<Task> createTasksForUser(Map<String, User> usersMap, String nextUrl, String dateFrom, String token) {
        List<Task> tasksToCreate = new List<Task>();

        try {
            RingCentralApi.GetUserCallRecords request = new RingCentralApi.GetUserCallRecords(getAccessToken(token), nextUrl, dateFrom);
            RingCentralApi_Models.GetUserCallRecordsResponse response = request.consume();

            if (response != null && response.records != null && !response.records.isEmpty()) {
                Set<String> connectedNumbers = extractConnectedNumbers(response.records);
                Map<String, Id> whatIdsFromPhoneMap = RingCentralLeadPriorityMatcher.getTransactionIdsByPhoneNumbers(connectedNumbers);
                Map<String, Id> leadIdsFromPhoneMap = RingCentralLeadPriorityMatcher.getOpenLeadIdsByPhoneNumbers(connectedNumbers);
                Map<String, Id> contactIdsFromPhoneMap = RingCentralLeadPriorityMatcher.getContactIdsByPhoneNumbers(connectedNumbers);
                List<Task> tasksForCheck = new List<Task>();

                for (RingCentralApi_Models.Records rec : response.records) {
                    Task t = createTaskFromCallRecord(rec, usersMap, leadIdsFromPhoneMap, contactIdsFromPhoneMap, whatIdsFromPhoneMap);
                    if (t != null) tasksToCreate.add(t);
                }
                if (response.navigation.nextPage?.uri != null) {
                    tasksToCreate.addAll(createTasksForUser(usersMap, response.navigation.nextPage.uri, null, token));
                }
            }
        } catch (Exception e) {
            handleException(e);
        }

        return tasksToCreate;
    }

    @TestVisible
    private static Task createTaskFromCallRecord(
        RingCentralApi_Models.Records rec,
        Map<String, User> usersMap,
        Map<String, Id> leadIdsFromPhoneMap,
        Map<String, Id> contactIdsFromPhoneMap,
        Map<String, Id> whatIdsFromPhoneMap
    ) {
        
        Id userId = getUserIdFromCallRecord(rec, usersMap);
        if (userId == null) {
            logMissingUser(rec);
            return null;
        }

        Boolean isOutbound = rec?.direction != null && rec.direction.equalsIgnoreCase('Outbound');
        String connectedPhone = isOutbound ? rec?.to?.phoneNumber : rec?.fromObj?.phoneNumber;
        Map<String, Id> taskRelation = resolveTaskRelationship(connectedPhone, leadIdsFromPhoneMap, contactIdsFromPhoneMap, whatIdsFromPhoneMap);

        Task taskToCreate =  new Task(
            rcsfl__CALL_UNIQUE_ID__c = rec.id,
            rcsfl__to_number__c = rec.to.phoneNumber,
            Description = rec.result,
            rcsfl__callee_name__c = rec.to.name,
            Status = 'Completed',
            rcsfl__from_number__c = rec?.fromObj?.phoneNumber,
            CallType = rec?.direction,
            WhatId = taskRelation.get('whatId'),
            WhoId = taskRelation.get('whoId'),
            OwnerId = userId,
            InteractionType__c = 'Call'
        );

        if(rec.startTime != null){
            DateTime actionDateTime = RingCentralApi_Models.parseRCTime(rec.startTime);
            taskToCreate.ActivityDate = actionDateTime.date();
            taskToCreate.rcsfl__call_start_time__c = actionDateTime;
            taskToCreate.Subject = 'Call on ' + actionDateTime;
            if (rec?.to?.Name != null && rec?.fromObj?.Name != null) {
                String formatted = actionDateTime?.format('MM/dd/yyyy \'at\' hh:mm:ss a');
                taskToCreate.Subject = rec?.fromObj?.Name + ' called ' + rec?.to?.Name + ' on ' + formatted;
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

    private static Id getUserIdFromCallRecord(RingCentralApi_Models.Records rec, Map<String, User> usersMap) {
        System.debug(rec);
        if (rec == null || usersMap == null || usersMap.isEmpty()) {
            return null;
        }

        // RingCentral "direction" can be unreliable/cased; try both sides.
        Boolean isInbound = rec.direction != null && rec.direction.equalsIgnoreCase('Inbound');
        Boolean isOutbound = rec.direction != null && rec.direction.equalsIgnoreCase('Outbound');

        String extPrimary = isInbound ? rec?.to?.extensionId : (isOutbound ? rec?.fromObj?.extensionId : rec?.to?.extensionId);
        String extSecondary = isInbound ? rec?.fromObj?.extensionId : (isOutbound ? rec?.to?.extensionId : rec?.fromObj?.extensionId);

        String phonePrimary = isInbound ? rec?.to?.phoneNumber : (isOutbound ? rec?.fromObj?.phoneNumber : rec?.to?.phoneNumber);
        String phoneSecondary = isInbound ? rec?.fromObj?.phoneNumber : (isOutbound ? rec?.to?.phoneNumber : rec?.fromObj?.phoneNumber);

        if (!String.isBlank(extPrimary) && usersMap.containsKey(extPrimary)) {
            return usersMap.get(extPrimary).Id;
        }
        if (!String.isBlank(extSecondary) && usersMap.containsKey(extSecondary)) {
            return usersMap.get(extSecondary).Id;
        }

        // Fallback: match by normalized phone (last 9 digits) between record side and User.Phone.
        String normalizedPrimary = normalizePhoneNumber(phonePrimary);
        String normalizedSecondary = normalizePhoneNumber(phoneSecondary);

        for (User u : usersMap.values()) {
            String normalizedUserPhone = normalizePhoneNumber(u?.Phone);
            if (String.isBlank(normalizedUserPhone)) {
                continue;
            }

            if (!String.isBlank(normalizedPrimary) && normalizedPrimary == normalizedUserPhone) {
                return u.Id;
            }
            if (!String.isBlank(normalizedSecondary) && normalizedSecondary == normalizedUserPhone) {
                return u.Id;
            }
        }

        return null;


    }

    private static void logMissingUser(RingCentralApi_Models.Records rec) {
        if (rec.direction == 'Inbound') {
            System.debug('No user ' + rec?.to?.extensionId + '   ' + rec?.to?.name +   ' in org');
            errors.add(new RingCentralErrorInfo('No user ' + rec?.to?.extensionId + '   ' + rec?.to?.name +   ' in org'));
        } else {
            System.debug('No user ' + rec?.fromObj?.extensionId + '   ' + rec?.fromObj?.name +   ' in org');
            errors.add(new RingCentralErrorInfo('No user ' + rec?.fromObj?.extensionId + '   ' + rec?.fromObj?.name +   ' in org'));
        }
        
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

    private static Set<String> extractConnectedNumbers(List<RingCentralApi_Models.Records> records) {
        Set<String> connectedNumbers = new Set<String>();

        for (RingCentralApi_Models.Records rec : records) {
            if (rec?.direction != null && rec.direction == 'Inbound' && rec.fromObj != null) {
                connectedNumbers.add(rec.fromObj.phoneNumber);
            } else if (rec?.direction != null && rec.direction == 'Outbound' && rec.to != null) {
                connectedNumbers.add(rec.to.phoneNumber);
            }
        }

        return connectedNumbers;
    }
    
    private static String normalizePhoneNumber(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        String normalized = phone.replaceAll('[^0-9]', ''); // Remove all non-numeric characters
        Integer len = normalized.length();
        return len > 9 ? normalized.substring(len - 9) : normalized; // Return last 9 characters
    }



}