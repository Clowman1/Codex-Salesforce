public class InvocableBusinessHoursUtility {
	public class Request{
		@InvocableVariable
		public Datetime dateTimeToAddToo;
		@InvocableVariable
		public String businessHoursId;
		@InvocableVariable
		public Integer numberOfBusinessDays;
	}
	@InvocableMethod(label='Add Business Hours to Datetime')
	public static List<Response> calculateDays(List<Request> requests){
		List<Response> responses = new List<Response>();
		for(Request r : requests){
			Response res = new Response();
			res.newDate = addBusinessHoursToDate(r.businessHoursId, r.dateTimeToAddToo, r.numberOfBusinessDays);
			responses.add(res);
		}
		return responses;
	}
    public static Datetime addBusinessHoursToDate(String businessHoursId, Datetime dateToAddToo, Integer numberOfBusinessDays) {
        final Integer ONE_BUSINESS_DAY = 86400000;
        return dateToAddToo == null ? null : BusinessHours.add(businessHoursId, dateToAddToo, ONE_BUSINESS_DAY*numberOfBusinessDays);
    }
	public class Response{
		@InvocableVariable
		public Datetime newDate;
	}
}