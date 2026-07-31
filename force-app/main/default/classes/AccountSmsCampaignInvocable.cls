public with sharing class AccountSmsCampaignInvocable {

    public class Input {
        @InvocableVariable(required=true)
        public Id scheduledMessageId;
    }

    @InvocableMethod(label='Account SMS Drip Campaign Processor')
    public static void process(List<Input> inputs) {
        Set<Id> scheduledMessageIds = new Set<Id>();
        for (Input input : inputs) {
            if (input != null && input.scheduledMessageId != null) {
                scheduledMessageIds.add(input.scheduledMessageId);
            }
        }
        AccountSmsCampaignService.processByScheduledMessageIds(scheduledMessageIds);
    }
}