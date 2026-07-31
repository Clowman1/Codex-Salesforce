/**
 * @author Andrei Karanko
 * @date 8/20/2024
 * description
 */
public without sharing class LeadShareInvocable {
    @InvocableMethod(Label='Share Leads')
    public static void execute(List<LeadShareInput> inputs){
        Map<String,List<LeadShareInput>> dmlTypeToInputsMap = new Map<String,List<LeadShareInput>>();
        for(LeadShareInput input : inputs){
            if(!dmlTypeToInputsMap.containsKey(input.dmlOperationType)){
                dmlTypeToInputsMap.put(input.dmlOperationType, new List<LeadShareInput>());
            }
            dmlTypeToInputsMap.get(input.dmlOperationType).add(input);
        }

        for(String dmlType : dmlTypeToInputsMap.keySet()){
            List<LeadShareInput> inputsToProcess = dmlTypeToInputsMap.get(dmlType);
            List<LeadShare> sharesToInsert = new List<LeadShare>();
            List<LeadShare> sharesToDelete = new List<LeadShare>();
            for(LeadShareInput input : inputsToProcess){
                if (input.dmlOperationType == 'Insert') {
                    sharesToInsert.add(new LeadShare(
                        LeadId = input.recordId,
                        UserOrGroupId = input.sharedToId,
                        RowCause = input.rowCause,
                        LeadAccessLevel = input.accessLevel
                    ));
                } else if (input.dmlOperationType == 'Delete') {
                    sharesToDelete.add(new LeadShare(Id = input.shareRecordId));
                }
            }
            if(!sharesToInsert.isEmpty()){
                Database.insert(sharesToInsert, false, AccessLevel.SYSTEM_MODE);
            }
            if(!sharesToDelete.isEmpty()){
                Database.delete(sharesToDelete, false, AccessLevel.SYSTEM_MODE);
            }
        }

    }

    public class LeadShareInput{
        @InvocableVariable(Label='DML Operation Type' Required=true)
        public String dmlOperationType;
        @InvocableVariable(Label='Lead Id')
        public String recordId;
        @InvocableVariable(Label='User Or Group Id')
        public String sharedToId;
        @InvocableVariable(Label='Share Record Id' Description='Required for delete operation')
        public String shareRecordId;
        @InvocableVariable(Label='Row Cause')
        public String rowCause;
        @InvocableVariable(Label='Access Level')
        public String accessLevel;
    }
}