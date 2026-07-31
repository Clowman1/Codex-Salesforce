public class BusinessDaysInvocable {    
    public class Request{
        @InvocableVariable
        public Datetime startDatetime; 
        @InvocableVariable
        public Datetime endDatetime;
    }
    
    public class Response{
        @InvocableVariable
        public Integer numberOfDays;
        @InvocableVariable
        public Integer numberOfHours;
        
        public Response(Datetime startDate, Datetime endDate){
            String businessHoursId = [SELECT Id FROM BusinessHours WHERE IsDefault=true].Id;
            this.numberOfHours = Integer.valueOf(BusinessHours.diff(businessHoursId, startDate, endDate)/3600000);
            this.numberOfDays = Integer.valueOf(BusinessHours.diff(businessHoursId, startDate, endDate)/86400000);
        }
        
    }
    @InvocableMethod(label='Calculate Business Days')
    public static List<Response> getNumberOfDaysBetweenDates(List<Request> requests){
        List<Response> responses = new List<Response>();
        for(Request r : requests){
            responses.add(new Response(r.startDatetime, r.endDatetime));
        }
        return responses;
    }
}