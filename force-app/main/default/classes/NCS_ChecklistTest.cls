@IsTest
public class NCS_ChecklistTest {
    @IsTest(SeeAllData=true)
    public static void RunTest()
    {
        ChecklistConfiguration__mdt config = [SELECT Id FROM ChecklistConfiguration__mdt WHERE DeveloperName = 'Opener_Checklist' LIMIT 1];
        Transaction__c t = [SELECT Id FROM Transaction__c LIMIT 1];
        NCS_Checklist.Checklist checklist = NCS_Checklist.generateChecklist(config.Id, t.Id);
        ChecklistController.getChecklist(t.Id, config.Id, null);
    }

    @IsTest(SeeAllData=true)
    public static void RunTest2()
    {
        ChecklistConfiguration__mdt config = [SELECT Id FROM ChecklistConfiguration__mdt WHERE DeveloperName = 'ARIVE_Account_Setup' LIMIT 1];
        Account a = [SELECT Id,PersonContactId FROM Account WHERE PersonContactId != null  LIMIT 1];
        Candidate_Checklist__c checklistCandidate = new Candidate_Checklist__c(Candidate_Name__c=a.Id);
        insert checklistCandidate;
        a.Candidate_Checklist__c = checklistCandidate.Id;
        update a;
        NCS_Checklist.Checklist checklist = ChecklistController.getChecklist(a.Id, config.Id, 'Candidate_Checklist__c');

    }
 
}