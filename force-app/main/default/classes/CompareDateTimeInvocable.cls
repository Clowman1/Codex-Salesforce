public with sharing class CompareDateTimeInvocable {
	@InvocableMethod(label='Compare DateTime to new instance' description='Returns Boolean that indicates that passed dateTime is earlier than new instance of dateTime based on params')
	public static List<Boolean> compareDateTimeToNewInstace(List<Request> reqs) {
		Request req = reqs[0];
		// Date today = Date.today();
		DateTime now = DateTime.now();
		Integer day = req.day == null ? now.day() : req.day;
		Integer month = req.month == null ? now.month() : req.month;
		Integer year = req.year == null ? now.year() : req.year;
		Integer hours = req.hours == null ? now.hour() : req.hours;
		Integer minutes = req.minutes == null ? now.minute() : req.minutes;
		Integer seconds = req.minutes == null ? now.second() : req.seconds;

		DateTime localInstance = DateTime.newInstance(year, month, day, hours, minutes, seconds);
        DateTime localInstance2 = DateTime.newInstanceGmt(req.dateTimeToCompare.date(),req.dateTimeToCompare.time());
		DateTime gmtInstance = DateTime.newInstanceGmt(localInstance.date(), localInstance.time());
		return new List<Boolean>{localInstance2 < gmtInstance};
    }

	public class Request{
		@InvocableVariable(label='DateTime to compare' description='GMT Datetime' required=true)
		public DateTime dateTimeToCompare;
		@InvocableVariable(label='Hours of new instance' description='' required=false)
		public Integer hours;
		@InvocableVariable(label='Minutes of new instance' description='' required=false)
		public Integer minutes;
		@InvocableVariable(label='Seconds of new instance' description='' required=false)
		public Integer seconds;
		@InvocableVariable(label='Day of new instance' description='' required=false)
		public Integer day;
		@InvocableVariable(label='Month of new instance' description='' required=false)
		public Integer month;
		@InvocableVariable(label='Year of new instance' description='' required=false)
		public Integer year;
	}
}