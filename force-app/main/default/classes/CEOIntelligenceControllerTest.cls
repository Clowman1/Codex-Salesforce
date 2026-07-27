@IsTest(SeeAllData=true)
private class CEOIntelligenceControllerTest {
    @IsTest
    static void hubReturnsNavigationAndSnapshot() {
        Test.startTest();
        CEOIntelligenceController.PageData data = CEOIntelligenceController.getPageData('hub');
        Test.stopTest();

        System.assertEquals('CEO Intelligence Hub', data.title);
        System.assertEquals(8, data.navItems.size(), 'Expected hub plus seven topic pages.');
        System.assert(!data.cards.isEmpty(), 'Expected high-level summary cards.');
        System.assert(!data.sections.isEmpty(), 'Expected hub sections.');
    }

    @IsTest
    static void leadAndTransactionPagesReturnUsableDataShells() {
        assertPages(new List<String>{ 'leads', 'transactions' });
    }

    @IsTest
    static void trendPageReturnsUsableDataShell() {
        assertPages(new List<String>{ 'trends' });
    }

    @IsTest
    static void loanOfficerPageReturnsUsableDataShell() {
        assertPages(new List<String>{ 'loanOfficers' });
    }

    @IsTest
    static void realtorAndFalloutPagesReturnUsableDataShells() {
        assertPages(new List<String>{ 'realtors', 'fallout' });
    }

    @IsTest
    static void operationsPageReturnsUsableDataShell() {
        assertPages(new List<String>{ 'operations' });
    }

    private static void assertPages(List<String> pageKeys) {
        Test.startTest();
        for (String pageKey : pageKeys) {
            CEOIntelligenceController.PageData data = CEOIntelligenceController.getPageData(pageKey);
            System.assert(String.isNotBlank(data.title), 'Expected title for ' + pageKey);
            System.assert(!data.cards.isEmpty(), 'Expected metric cards for ' + pageKey);
            System.assert(!data.sections.isEmpty(), 'Expected sections for ' + pageKey);
        }
        Test.stopTest();
    }
}
