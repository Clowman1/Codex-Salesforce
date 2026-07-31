@IsTest
private class TwilioMessageRelateRecordsInvocableTest {
    @IsTest
    static void relate_invocable_bulk_safe() {
        TwilioMessageRelateRecordsInvocable.Request a = new TwilioMessageRelateRecordsInvocable.Request();
        a.twilioMessageId = null;
        TwilioMessageRelateRecordsInvocable.Request b = new TwilioMessageRelateRecordsInvocable.Request();
        b.twilioMessageId = UserInfo.getUserId();

        List<TwilioMessageRelateRecordsInvocable.Response> out = TwilioMessageRelateRecordsInvocable.relate(
            new List<TwilioMessageRelateRecordsInvocable.Request>{ a, b }
        );
        System.assertEquals(2, out.size());
        System.assertEquals(false, out[0].success);
        System.assertEquals(true, out[1].success);
    }
}