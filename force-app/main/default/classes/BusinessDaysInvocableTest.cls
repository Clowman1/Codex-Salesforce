@isTest
public class BusinessDaysInvocableTest {    
    @IsTest
    static void testForDateTime() {
        BusinessHours hours = [SELECT Id FROM BusinessHours WHERE isDefault = TRUE];
       	BusinessDaysInvocable.Request req = new BusinessDaysInvocable.Request();
        req.startDatetime = (DateTime.now() - 2/24);
        req.endDatetime = Datetime.now();
        BusinessDaysInvocable.getNumberOfDaysBetweenDates(new List<BusinessDaysInvocable.Request>{req});
    }
}