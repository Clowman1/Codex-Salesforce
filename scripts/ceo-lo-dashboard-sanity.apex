CEOIntelligenceController.PageData data = CEOIntelligenceController.getPageData('loanOfficers');
System.debug('TITLE|' + data.title);
for (CEOIntelligenceController.NavItem item : data.navItems) {
    if (item.key == 'loanofficers') {
        System.debug('NAV|' + item.label + '|' + item.tabApiName);
    }
}
for (CEOIntelligenceController.Section section : data.sections) {
    if (section.title == 'This Month' || section.title == 'Lead Sources' || section.title == '2025 Baseline' || section.title == 'Recent Lead Months' || section.title == 'Activity' || section.title == 'Data Fixes') {
        System.debug('SECTION|' + section.title);
        System.debug('COLUMNS|' + String.join(section.columns, '|'));
        for (CEOIntelligenceController.DataRow row : section.rows) {
            System.debug('ROW|' + String.join(row.values, '|'));
            System.debug('URLS|' + String.join(row.cellUrlPaths, '|'));
        }
    }
}
