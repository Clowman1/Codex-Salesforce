@isTest
public class InvocableBusinessHoursTest {    
    @IsTest
    static void testForDateStamp() {
        BusinessHours hours = [SELECT Id FROM BusinessHours WHERE isDefault = TRUE];
       	InvocableBusinessHoursUtility.Request req = new InvocableBusinessHoursUtility.Request();
        req.businessHoursId = hours.Id;
        req.dateTimeToAddToo = Datetime.now();
        req.numberOfBusinessDays = 1;
        InvocableBusinessHoursUtility.calculateDays(new List<InvocableBusinessHoursUtility.Request>{req});        
    }
}