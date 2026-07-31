/***
* @description Controller for the Checklist component, which takes in a list of comma separated date fields
*               within a given design attribute and generates a checklist which a user an take action on.
*/
public class ChecklistController {
    /***
* @description  This method will return a Checklist based on a given record and requested date fields.
* @author Nimbus Cloud Solutions
* @date April 2020
*
* @param recordId The Id of the record which the checklist is related too.
* @param configurationId - the Id of the ChecklistConfiguration__mdt record which represents this specific checklist.
*
* @return Checklist returns the Checklist for the record which was passed in and the requested fields that were given.
* @see Checklist
*/
    @AuraEnabled
    public static NCS_Checklist.Checklist getChecklist(Id recordId, String configurationId, String fieldToTraverseOver) {
        System.debug('what is this -> '+ fieldToTraverseOver);
        if(fieldToTraverseOver == null){
            return NCS_Checklist.generateChecklist(configurationId, recordId);

        }
        return NCS_Checklist.generateChecklist(configurationId, recordId, fieldToTraverseOver);
    }

    @AuraEnabled
    public static BPSVerificationService.VerificationContext getBpsVerificationContext(Id transactionId) {
        return BPSVerificationService.buildVerificationContext(transactionId);
    }

    @AuraEnabled
    public static void saveBpsVerification(Id transactionId, Boolean isVerified) {
        BPSVerificationService.saveVerification(transactionId, isVerified);
    }

}