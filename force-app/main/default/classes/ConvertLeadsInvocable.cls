/**
* Created by toma on 9/29/2022.
*/

public class ConvertLeadsInvocable {
    @InvocableMethod(Description='When a TRID Date is hit, we auto convert the lead and create the Transaction' Label='convert leads Invoc')
    public static List<Id> convertLeads(List<Id> recordIds) {
        
        List<Id> accountIds = new List<Id>();
        
        for (Id leadId : recordIds) {
            Database.LeadConvert lc = new Database.LeadConvert();
            Lead leadRecord = [SELECT Id, RecordType.Name FROM Lead WHERE Id = :leadId LIMIT 1];
            
            if (leadRecord.RecordType.Name.contains('Consumer')) {
                lc.setConvertedStatus(Label.Consumer_Lead_Process);
            } else {
                lc.setConvertedStatus(Label.Realtor_Lead_Process);
            }
            
            lc.setLeadId(leadId);
            
            try {  
                Id accountId = checkForDuplicateAccountId(leadId);
                System.debug(accountId);
                if (accountId != null) {
                    lc.setAccountId(accountId);
                }
                Database.LeadConvertResult lcr = Database.convertLead(lc);
                accountIds.add(lcr.getAccountId());
                
            } catch (DmlException e) {
                throw e;
            }
        }
        
        return accountIds;
    }
    
    public static Id checkForDuplicateAccountId(String leadId){
        List<String> inputIds = new List<String>();
        inputIds.add(leadId);
        List<Datacloud.FindDuplicatesResult> dupeLeadReults = Datacloud.FindDuplicatesByIds.findDuplicatesByIds(inputIds);
        
        for (Datacloud.FindDuplicatesResult findDupeResult : dupeLeadReults) {
            for (Datacloud.DuplicateResult dupeResult : findDupeResult.getDuplicateResults()) {
                for (Datacloud.MatchResult matchResult : dupeResult.getMatchResults()) {
                    for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                        Id recordId = matchRecord.getRecord().Id;
                        System.debug(recordId);
                        System.debug(recordId.getSobjectType());
                        if(recordId.getSobjectType() == Account.sObjectType){
                            return recordId;   
                        }
                    }
                }
            }
        }
        return null;
    }
}