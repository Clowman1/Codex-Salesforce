trigger EventDurationGuardTrigger on Event (before insert, before update) {
    EventDurationGuard.normalizeLeadEvents(Trigger.new);
}
