@IsTest
private class TwilioOutboundMessageOwnerInvocableTest {
    @IsTest
    static void reassign_invocable_returns_row_per_request() {
        TwilioOutboundMessageOwnerInvocable.Request a = new TwilioOutboundMessageOwnerInvocable.Request();
        a.twilioMessageId = null;

        List<TwilioOutboundMessageOwnerInvocable.Response> out = TwilioOutboundMessageOwnerInvocable.reassign(
            new List<TwilioOutboundMessageOwnerInvocable.Request>{ a }
        );
        System.assertEquals(1, out.size());
        System.assertEquals(false, out[0].success);
    }
}