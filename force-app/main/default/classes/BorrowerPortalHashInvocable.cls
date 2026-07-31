public with sharing class BorrowerPortalHashInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id recordId;
    }

    @InvocableMethod(label='Encrypt Transaction Id')
    public static List<String> encryptTransactionIds(List<Request> requests) {
        List<String> hashes = new List<String>();
        for (Request requestItem : requests) {
            hashes.add(BorrowerPortalService.encryptTransactionId(requestItem.recordId));
        }
        return hashes;
    }
}