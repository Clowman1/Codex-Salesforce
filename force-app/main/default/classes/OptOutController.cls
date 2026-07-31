public with sharing class OptOutController {
    @TestVisible
    private static Boolean forceUnexpectedExceptionForTest = false;

    private class ForcedUnexpectedException extends Exception {}

    @AuraEnabled
    public static void handleOptOut(String email) {
        try {
            if (Test.isRunningTest() && forceUnexpectedExceptionForTest) {
                throw new ForcedUnexpectedException('Forced opt out failure');
            }
            BorrowerPortalOptOutService.optOutByEmail(email);
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}