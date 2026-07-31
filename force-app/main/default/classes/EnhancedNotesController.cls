/**
 * Created by J9 on 8/26/2021.
 */

public with sharing class EnhancedNotesController {

    @AuraEnabled
    public static List<Enhanced_Note__c> getNotesRelatedToLoan(String loanId){
        return EnhancedNotesRepository.getInstance().getEnhancedNotedByLoanId(loanId);
    }

    @AuraEnabled
    public static void deleteTargetNote(String recordId){
        Enhanced_Note__c note = new Enhanced_Note__c(Id=recordId, IsDeleted__c=true);
        update note;
    }
    @AuraEnabled
    public static String getLookupField(Id recordId){
        return EnhancedNotesRepository.getLookupField(recordId);
    }

//@AuraEnabled
//    public static String getApplicationName(String recordId, String noteId){
//    String output;
//    if(noteId != null){
//        List<Enhanced_Note__c> name = [SELECT Application__r.Name FROM Enhanced_Note__c WHERE Id=:noteId];
//        output = name[0].Application__r.Name;
//    }else{
//        List<Enhanced_Note__c> name = [SELECT Application__r.Name FROM Enhanced_Note__c WHERE Application__r.Id=:recordId];
//        output = name[0].Application__r.Name;
//    }
//    return output;
//    } 
}