trigger InitialItemsNeededSmsFromEmailMessage on EmailMessage (after insert) {
    InitialItemsNeededSmsService.enqueueFromEmailMessages(Trigger.new);
}