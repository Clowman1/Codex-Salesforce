@isTest
public with sharing class CompareDateTimeInvocableTest {
    @isTest
	static void compareDateTimeToNewInstace() {
		CompareDateTimeInvocable.Request req = new CompareDateTimeInvocable.Request();
		req.dateTimeToCompare = DateTime.newInstanceGMT(2024, 5, 23, 15, 30, 0);
		req.hours = 15;
		req.minutes = 45;
		req.seconds = 35;
		req.day = 23;
		req.month = 5;
		req.year = 2024;

		List<CompareDateTimeInvocable.Request> reqs = new List<CompareDateTimeInvocable.Request>{req};

		Test.startTest();
			List<Boolean> res = CompareDateTimeInvocable.compareDateTimeToNewInstace(reqs);
		Test.stopTest();

		System.assertEquals(true, res[0], 'Wrong boolean returned');
	}
}