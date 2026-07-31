public with sharing class RealtorLeadConvertController {
    @AuraEnabled
    public static RealtorLeadConvertService.ConvertResponse convertLead(Id recordId) {
        return RealtorLeadConvertService.convertLead(recordId);
    }
}