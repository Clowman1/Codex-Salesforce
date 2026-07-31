/**
 * @author Andrei Karanko
 * @date 8/20/2024
 * description
 */
@IsTest
private class LeadShareInvocableTest {
    private static final String TEST_LEAD_FIRST_NAME = 'Lead';
    private static final String TEST_INSERT_LEAD_LAST_NAME = 'ShareInsertTest';
    private static final String TEST_DELETE_LEAD_LAST_NAME = 'ShareDeleteTest';
    private static final String TEST_INSERT_LEAD_EMAIL = 'leadinsert08202024@sharetest.com';
    private static final String TEST_DELETE_LEAD_EMAIL = 'leaddelete08202024@sharetest.com';

    private static final String LOAN_OFFICER_PROFILE_NAME = 'Loan Officer Profile';

    @TestSetup
    static void leadShareInvocableTestSetup() {
        List<Lead> leads = new List<Lead>();

        Lead l1 = new Lead();
        l1.FirstName = TEST_LEAD_FIRST_NAME;
        l1.LastName =  TEST_INSERT_LEAD_LAST_NAME;
        l1.Email = TEST_INSERT_LEAD_EMAIL;
        leads.add(l1);

        Lead l2 = new Lead();
        l2.FirstName = TEST_LEAD_FIRST_NAME;
        l2.LastName =  TEST_DELETE_LEAD_LAST_NAME;
        l2.Email = TEST_DELETE_LEAD_EMAIL;
        leads.add(l2);

        insert leads;
    }

    @IsTest
    public static void insertDeleteTest(){
        User loanOfficer = [
            SELECT Id
            FROM User
            WHERE Profile.Name = :LOAN_OFFICER_PROFILE_NAME AND IsActive = TRUE
            LIMIT 1
        ];

        List<Lead> leads = [
            SELECT Id, LastName
            FROM Lead
        ];
        Lead insertShareLead;
        Lead deleteShareLead;
        for (Lead l : leads) {
            if (l.LastName == TEST_INSERT_LEAD_LAST_NAME) {
                insertShareLead = l;
            } else if (l.LastName == TEST_DELETE_LEAD_LAST_NAME) {
                deleteShareLead = l;
            }
        }

        LeadShare ls = new LeadShare(
            LeadId = deleteShareLead.Id,
            UserOrGroupId = loanOfficer.Id,
            RowCause = 'Manual',
            LeadAccessLevel = 'Read'
        );
        insert ls;
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM LeadShare WHERE LeadId = :deleteShareLead.Id AND RowCause = 'Manual'],
            'LeadShare not inserted'
        );

        List<LeadShareInvocable.LeadShareInput> inputs = new List<LeadShareInvocable.LeadShareInput>();
        LeadShareInvocable.LeadShareInput lsInput1 = new LeadShareInvocable.LeadShareInput();
        lsInput1.recordId = insertShareLead.Id;
        lsInput1.sharedToId = loanOfficer.Id;
        lsInput1.rowCause = 'Manual';
        lsInput1.dmlOperationType = 'Insert';
        lsInput1.accessLevel = 'Read';
        inputs.add(lsInput1);
        LeadShareInvocable.LeadShareInput lsInput2 = new LeadShareInvocable.LeadShareInput();
        lsInput2.shareRecordId = ls.Id;
        lsInput2.dmlOperationType = 'Delete';
        inputs.add(lsInput2);

        Test.startTest();
        LeadShareInvocable.execute(inputs);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM LeadShare WHERE LeadId = :insertShareLead.Id AND RowCause = 'Manual'],
            'LeadShare not inserted'
        );
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM LeadShare WHERE LeadId = :deleteShareLead.Id AND RowCause = 'Manual'],
            'LeadShare not deleted'
        );
    }
}