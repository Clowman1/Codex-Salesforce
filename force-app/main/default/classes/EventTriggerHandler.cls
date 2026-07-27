public without sharing class EventTriggerHandler {
    private static final String LEAD_ACCESS_ERROR_MESSAGE =
        'This activity could not be saved because you do not have permission to update the related lead. ' +
        'Please contact Operations or an admin if you should have access.';

    public static void beforeInsertUpdate(List<Event> events){
        System.debug('Trigger started');
        Set<Id> whoIds = new Set<Id>();
        List<Lead> leadsForUpdate = new List<Lead>();
        
        for(Event evnt: events){
            System.debug(evnt);
            if(evnt.WhoId != null){
                whoIds.add(evnt.WhoId);
            }
            if(evnt.Lead__c != null){
                whoIds.add(evnt.Lead__c);
            }
        }
        
        Map<Id, Lead> leadsMap = new Map<Id, Lead>([SELECT Id, Appointment_Date_Time__c, Appointment_Date__c, Appointment_Time__c, (SELECT Id, StartDateTime FROM Events) FROM Lead WHERE Id in :whoIds]);
        System.debug(leadsMap);
        for(Event evnt: events){
            if(evnt.WhoId != null && leadsMap.containsKey(evnt.WhoId)){
                if(evnt.StartDateTime != null && (evnt.StartDateTime >= getMaxStartDateTime(leadsMap.get(evnt.WhoId).Events) || getMaxStartDateTime(leadsMap.get(evnt.WhoId).Events) == null)){
                    leadsMap.get(evnt.WhoId).Appointment_Date_Time__c = evnt.StartDateTime;
                    leadsMap.get(evnt.WhoId).Appointment_Date__c = evnt.StartDateTime.date();
                    leadsMap.get(evnt.WhoId).Appointment_Time__c = convertToEasternTime(evnt.StartDateTime);
                    leadsForUpdate.add(leadsMap.get(evnt.WhoId));
                }
            }
        }

        System.debug(leadsForUpdate);

        if (leadsForUpdate.isEmpty()) {
            return;
        }

        try {
            update leadsForUpdate;
        } catch (DmlException e) {
            if (isLeadAccessFailure(e)) {
                for (Event evnt : events) {
                    if (evnt.WhoId != null || evnt.Lead__c != null) {
                        evnt.addError(LEAD_ACCESS_ERROR_MESSAGE);
                    }
                }
                return;
            }
            throw e;
        }
    }

    private static Datetime getMaxStartDateTime(List<Event> eventList) {
        if (eventList == null || eventList.isEmpty()) {
            return null;
        }
        
        Datetime maxStartDateTime = eventList[0].StartDateTime;
        
        for (Event ev : eventList) {
            if (ev.StartDateTime != null && ev.StartDateTime > maxStartDateTime) {
                maxStartDateTime = ev.StartDateTime;
            }
        }
        
        return maxStartDateTime;
    }

public static String convertToEasternTime(DateTime activityDateTime) {
        Integer month = activityDateTime.month();
        Integer day = activityDateTime.day();
        Integer hour = activityDateTime.hour();
        Integer minute = activityDateTime.minute();
        
        if ((month >= 3 && month <= 11) ||
            (month == 12 && day >= 3) ||
            (month <= 2 && day <= 8)) {
            hour -= 4;
        } else {
            hour -= 5;
        }
        
        if (hour < 0) {
            hour += 12;
        }
        
        String period = (hour < 12) ? 'AM' : 'PM';
        hour = (hour == 0 || hour == 12) ? 12 : hour;
        
        String hourStr = String.valueOf(hour);
        if (hour < 10) {
            hourStr = '0' + hourStr;
        }
        
        String minuteStr = String.valueOf(minute);
        if (minute < 10) {
            minuteStr = '0' + minuteStr;
        }
        
        return hourStr + ':' + minuteStr + ' ' + period;
    }

    @TestVisible
    private static Boolean isLeadAccessFailure(DmlException e) {
        if (e == null || String.isBlank(e.getMessage())) {
            return false;
        }

        String message = e.getMessage().toLowerCase();
        return message.contains('insufficient_access_on_cross_reference_entity')
            || message.contains('insufficient_access_on_related_entity')
            || message.contains('insufficient access on related object id')
            || message.contains('insufficient access rights on cross-reference id');
    }
}
