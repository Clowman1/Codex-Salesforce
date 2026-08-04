public with sharing class PipelineCommandCenterController {
    private static final List<String> SUPPORTED_OBJECTS = new List<String>{ 'Transaction__c', 'Lead', 'Account', 'Case', 'TransactionCondition__c' };
    private static final Date MIN_LEAD_CREATED_DATE = Date.newInstance(2024, 1, 1);
    private static final DateTime MIN_TRANSACTION_CREATED_DATETIME = DateTime.newInstanceGmt(2024, 1, 1, 0, 0, 0);
    private static final List<String> ATTENTION_LEAD_STATUSES = new List<String>{
        'New',
        'Contacted/Call Back',
        'Contact Attempt 1',
        'Contact Attempt 2',
        'Contact Attempt 3',
        'Contact Attempt 4',
        'Contact Attempt 5',
        'Contact Attempt 6',
        'Contact_Attempt_6',
        'Working',
        'Application Link Out',
        'Application',
        'Documents Requested',
        'Documents Received for Review'
    };
    private static final List<String> ACTIVE_LEAD_STATUSES = new List<String>{
        'New',
        'Contacted/Call Back',
        'Contact Attempt 1',
        'Contact Attempt 2',
        'Contact Attempt 3',
        'Contact Attempt 4',
        'Contact Attempt 5',
        'Contact Attempt 6',
        'Contact_Attempt_6',
        'Working',
        'Application',
        'Application Link Out',
        'Documents Requested',
        'Documents Received for Review',
        'Under Contract'
    };
    private static final Set<String> CONSUMER_LEAD_RECORD_TYPES = new Set<String>{
        'Consumer_Lead_record_type',
        'Consumer_Under_Contract_Lead_Record_Type'
    };
    private static final Set<String> ALL_LO_MONITOR_EXCLUDED_USER_NAMES = new Set<String>{
        'benjamin bondarevsky',
        'nimbus development',
        'nimbus development - outside'
    };
    private static final List<String> EXCLUDED_ACTIVE_PIPELINE_STATUSES = new List<String>{
        'Cancelled',
        'PC Review',
        'QC Review',
        'Post-Closed',
        'Lost'
    };
    private static final List<String> LO_CLOSED_THIS_MONTH_STATUSES = new List<String>{
        'Funding',
        'PC Review',
        'QC Review',
        'Post-Closed'
    };
    private static final String DPA_SECOND_LOAN_TYPE = 'DPA 2nd';
    private static final List<String> CLOSING_TRANSACTION_STATUSES = new List<String>{
        'Closing',
        'Funding'
    };
    private static final List<String> OPENER_VIEW_USERNAMES = new List<String>{
        'laura@reachhomeloans.com',
        'lhoyos@reachhomeloans.com'
    };
    private static final List<String> CLOSER_VIEW_USERNAMES = new List<String>{
        'monicaquintero@reachhomeloans.com'
    };
    private static final List<String> FUNDING_LOCKDESK_VIEW_USERNAMES = new List<String>{
        'jmartinez@reachhomeloans.com'
    };
    private static final List<String> PIPELINE_TAB_EDITOR_USERNAMES = new List<String>{
        'clowman@reachhomeloans.com',
        'monicaquintero@reachhomeloans.com',
        'jmartinez@reachhomeloans.com'
    };
    private static final List<String> EXECUTIVE_VIEW_USERNAMES = new List<String>{
        'brandonbrotsky@reachhomeloans.com'
    };
    private static final List<String> CEO_VIEW_USERNAMES = new List<String>{
        'astephens@reachhomeloans.com'
    };
    private static final List<String> LO_ASSISTANT_VIEW_USERNAMES = new List<String>{
        'joey@reachhomeloans.com'
    };
    private static final List<String> MEGAN_PARTNER_VIEW_USERNAMES = new List<String>{
        'mstraight@reachhomeloans.com'
    };
    private static final String BRANDON_BROTSKY_USERNAME = 'bbrotsky@reachhomeloans.com';
    private static final String ZACHARY_FRITZ_USERNAME = 'zfritz@reachhomeloans.com';
    private static final List<String> PAST_CLIENT_VIEW_USERNAMES = new List<String>{
        'benjamin@reachhomeloans.com'
    };
    private static final List<String> JOEY_ASSISTED_LO_USERNAMES = new List<String>{
        'zfritz@reachhomeloans.com',
        'jolmsted@reachhomeloans.com',
        'rdelaney@reachhomeloans.com'
    };
    // Standalone gate for the "My Nickley Realtors" Home tab. Intentionally NOT shared with
    // JOEY_ASSISTED_LO_USERNAMES above (a separate, unrelated assistant-view feature) even though
    // the three usernames happen to overlap.
    private static final Map<String, String> NICKLEY_REALTOR_TAB_USERNAME_TO_LABEL = new Map<String, String>{
        'zfritz@reachhomeloans.com' => 'Zach Fritz',
        'jolmsted@reachhomeloans.com' => 'Joe Olmsted',
        'rdelaney@reachhomeloans.com' => 'Rhett Delaney'
    };
    private static final List<String> PROCESSING_TEAM_LEAD_USERNAMES = new List<String>{
        'anoble@reachhomeloans.com'
    };
    private static final List<String> MANAGEMENT_ALERT_USERNAMES = new List<String>{
        'clowman@reachhomeloans.com',
        'anoble@reachhomeloans.com'
    };
    private static final Set<String> NEW_LEAD_OWNER_ASSIGNMENT_OVERRIDE_NAMES = new Set<String>{
        'bianca rodrigues'
    };
    private static final Set<String> NEW_LEAD_OWNER_PICKLIST_NAMES = new Set<String>{
        'zach fritz',
        'zachary fritz',
        'megan straight',
        'martin rebagliati',
        'manuel anagnostou',
        'alaina pugh',
        'joe olmsted',
        'rhett delaney',
        'brandon brotsky'
    };
    private static final Set<Id> CLA_NOT_CONTACTED_MANUAL_EXCLUDED_TRANSACTION_IDS = new Set<Id>{
        'a01Qi00001Cjtc3IAB', // Ashby - 1526203266
        'a01Qi000019Wa7VIAS'  // Castro Jordan - 1526175069
    };
    private static Id defaultBusinessHoursId;
    private static final List<String> OPENER_TRANSACTION_STATUSES = new List<String>{
        'TRID Application',
        'Open',
        'Disclosures Out',
        'Pre-Processing'
    };
    private static final List<String> CLOSER_TRANSACTION_STATUSES = new List<String>{
        'Conditionally Approved',
        'Closing',
        'Funding',
        'PC Review'
    };
    private static final List<String> CLOSING_CHECKLIST_FIELDS = new List<String>{
        'Closing_Date__c',
        'CD_Sent_Date__c',
        'Funding_Date__c',
        'Closing_Instructions_Sent__c',
        'Vesting_Confirmed__c',
        'CD_Is_Balanced__c',
        'Closing_Package_Sent__c',
        'Closing_Package_Status__c',
        'Closing_Package_Rejection_Notes__c'
    };
    private static final List<String> FUNDING_CHECKLIST_FIELDS = new List<String>{
        'MERS_Registration_Complete__c',
        'MERS_Min__c',
        'Warehouse_Bank_Picklist__c',
        'FedexTrackingNumber__c',
        'FedEx_Label_Sent__c',
        'Funding_Wire_Requested__c',
        'Federal_Reference_Number__c',
        'Funding_Authorization__c',
        'MERSUploadedActivated__c',
        'FedEx_Labels_Received__c',
        'Note_Ship_Requested_at_Warehouse__c',
        'Note_Received_Date__c',
        'PC_Conditions_Satisfied__c',
        'Purchase_Advice_Date__c',
        'PA_uploaded_to_Warehouse_Bank__c',
        'MERS_Transfer_to_Investor__c'
    };
    private static final List<String> FUNDING_ELECTRONIC_CHECKLIST_FIELDS = new List<String>{
        'MERS_Registration_Complete__c',
        'MERS_Min__c',
        'Warehouse_Bank_Picklist__c',
        'Funding_Wire_Requested__c',
        'Federal_Reference_Number__c',
        'Funding_Authorization__c',
        'MERSUploadedActivated__c',
        'Note_Ship_Requested_at_Warehouse__c',
        'Note_Received_Date__c',
        'PC_Conditions_Satisfied__c',
        'Purchase_Advice_Date__c',
        'PA_uploaded_to_Warehouse_Bank__c',
        'MERS_Transfer_to_Investor__c'
    };
    private static final Set<String> ELECTRONIC_FUNDING_CLOSING_TYPES = new Set<String>{
        'Hybrid ENote',
        'Virtual'
    };
    private static final List<String> CLOSER_ACTIVE_EXCLUDED_STATUSES = new List<String>{
        'Cancelled',
        'Post-Closed',
        'Lost'
    };
    private static final List<String> CLOSER_LENDER_NAMES = new List<String>{
        'UWM',
        'Gold Star Mortgage Financial Group Corp'
    };
    private static final List<String> ATTENTION_BIZ_DEV_VALUES = new List<String>{
        'Biz Dev - Reach',
        'Biz Dev - Cabrera',
        'Biz Dev - Perrault',
        'Biz Dev - Hornaday',
        'Biz Dev - SERHANT ORL',
        'Biz Dev - Wemert',
        'Biz Dev - Hsieh'
    };
    private static final String MANAGEMENT_LEAD_BIZ_DEV_VALUE = 'Biz Dev - Reach';
    private static final List<String> HOUSE_BIZ_DEV_VALUES = new List<String>{
        'Biz Dev - Reach',
        'Biz Dev - Bondarevsky',
        'Biz Dev - Cabrera',
        'Biz Dev - Hornaday',
        'Biz Dev - Hsieh',
        'Biz Dev - Hseih',
        'Biz Dev - Perrault'
    };
    private static final List<String> PAST_CLIENT_PRIMARY_OCCUPANCIES = new List<String>{
        'Primary',
        'Primary Residence'
    };
    private static final Set<String> PAST_CLIENT_EXCLUDED_LO_NAMES = new Set<String>{
        'Harold Ellis',
        'Joseph Carey',
        'Edgard Gonzalez'
    };
    private static final Set<String> PAST_CLIENT_EXCLUDED_BIZ_DEV_VALUES = new Set<String>{
        'Biz Dev - Pugh',
        'Biz Dev - Olmsted',
        'Biz Dev - Waters',
        'Biz Dev - Fritz'
    };
    private static final String PAST_CLIENT_PURCHASE_PURPOSE = 'Purchase';
    private static final Date PAST_CLIENT_MIN_CLOSED_DATE = Date.newInstance(2019, 1, 1);
    private static final Integer PAST_CLIENT_VISIBLE_BATCH_SIZE = 75;
    private static final Integer PAST_CLIENT_CANDIDATE_SCAN_SIZE = 1500;
    private static final List<String> NURTURE_OR_PREAPPROVAL_STATUSES = new List<String>{
        'Nurtured',
        'Nurturing',
        'Nurture - Preapproval',
        'Nurture-Preapproval',
        'Nurture-Pre-Approval',
        'Pre-Approval'
    };
    private static final Set<String> EXCLUDED_CONVERSION_USER_NAMES = new Set<String>{
        'benjamin bondarevsky',
        'byron richie',
        'edgard gonzalez',
        'joseph carey',
        'nimbus development',
        'nimbus development - outside'
    };
    private static final String REPORT_NEW_TO_PREAPPROVAL = '00OQi000002mZlVMAU';
    private static final String REPORT_PREAPPROVAL_TO_TRANSACTION = '00O5x0000086tsWEAQ';
    private static final String REPORT_NEW_TO_POST_CLOSED = '00OQi000002mZtZMAU';
    private static final String REPORT_ACTIVE_DAYS = '00O5x000008B3dmEAC';
    private static final String REPORT_CONVERSION_RATE = '00Of20000075Cn6EAE';
    private static final String REPORT_MARKETING_LEADS_BY_SOURCE = '00Of20000079nzjEAA';
    private static final String REPORT_REALTOR_REFERRAL_LEADS = '00OAJ000000Kimy2AC';
    private static final String REPORT_LEAD_APPOINTMENT = '00OQi000000PvPiMAK';
    private static final String REPORT_CONSUMER_WEBINAR_LEADS = '00OQi000008ZrsrMAC';
    private static final String REPORT_NICKLEY_LEADS = '00O5x000008Aww7EAC';
    private static final List<String> EXCLUDED_ATTENTION_PURPOSES = new List<String>{
        'Refinance',
        'Refinance Cash-Out',
        'Refinance Rate & Term',
        'HELOC'
    };

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        Boolean openerPipeline = currentUserUsesOpenerPipeline();
        Boolean closerPipeline = !openerPipeline && currentUserUsesCloserPipeline();
        Boolean fundingLockDeskPipeline = !openerPipeline && !closerPipeline && currentUserUsesFundingLockDeskPipeline();
        Boolean ceoPipeline = !openerPipeline && !closerPipeline && !fundingLockDeskPipeline && currentUserUsesCeoPipeline();
        Boolean executivePipeline = !openerPipeline && !closerPipeline && !fundingLockDeskPipeline && !ceoPipeline && currentUserUsesExecutivePipeline();
        Boolean loanOfficerAssistantPipeline = !openerPipeline && !closerPipeline && !fundingLockDeskPipeline && !ceoPipeline && !executivePipeline && currentUserUsesLoanOfficerAssistantPipeline();
        Boolean pastClientPipeline = !openerPipeline && !closerPipeline && !fundingLockDeskPipeline && !ceoPipeline && !executivePipeline && !loanOfficerAssistantPipeline && currentUserUsesPastClientPipeline();
        Boolean adminPipeline = !openerPipeline && !closerPipeline && !fundingLockDeskPipeline && !ceoPipeline && !executivePipeline && !loanOfficerAssistantPipeline && !pastClientPipeline && currentUserUsesAdminPipeline();
        Boolean leadPipeline = !openerPipeline && !closerPipeline && !fundingLockDeskPipeline && !ceoPipeline && !executivePipeline && !loanOfficerAssistantPipeline && !pastClientPipeline && !adminPipeline && currentUserUsesLeadPipeline();
        Boolean leadScopedPipeline = loanOfficerAssistantPipeline || leadPipeline;
        Boolean managementCommandCenter = currentUserUsesManagementCommandCenterHeader();
        Boolean rhettDelaney = currentUserIsRhettDelaney();
        DashboardData data = new DashboardData();
        data.currentUserId = UserInfo.getUserId();
        data.columnPreferencesJson = getUserColumnPreferencesJson();
        data.headerTitle = ceoPipeline
            ? 'CEO Command Center'
            : (pastClientPipeline
            ? 'Ben\'s Command Center'
            : ((executivePipeline || managementCommandCenter)
            ? 'Management Command Center'
            : 'Pipeline Command Center'));
        data.headerSubtitle = loanOfficerAssistantPipeline
            ? 'A focused assistant view for Zach Fritz, Joe Olmsted, and Rhett Delaney lead pipelines.'
            : (pastClientPipeline
            ? 'A focused view for past clients, realtor leads, pre-approvals, and webinar follow-up.'
            : (ceoPipeline
            ? 'High-level company view of lead flow, conversion, production, and operational health.'
            : (data.headerTitle == 'Management Command Center'
            ? 'A focused view for company management, conversion percentages, and operations.'
            : 'A focused view for production queues, upcoming closings, and daily review work.')));
        List<PipelineTab> pastClientTabs = pastClientPipeline ? buildPastClientPipelineTabs() : new List<PipelineTab>();
        data.statusCards = openerPipeline ? buildOpenerStatusCards() : (closerPipeline ? buildCloserStatusCards() : (fundingLockDeskPipeline ? buildFundingLockDeskStatusCards() : (ceoPipeline ? buildCeoStatusCards() : (pastClientPipeline ? buildPastClientStatusCards(pastClientTabs) : (executivePipeline ? buildExecutiveStatusCards() : (leadScopedPipeline ? buildLeadStatusCards() : buildTransactionStatusCards(adminPipeline)))))));
        data.pipelineRows = ceoPipeline ? new List<PipelineRow>() : (openerPipeline ? buildOpenerTransactionsByStatus('Open') : (closerPipeline ? buildCloserActiveTransactions() : (fundingLockDeskPipeline ? buildFundingLockDeskActivePipeline() : (pastClientPipeline ? new List<PipelineRow>() : (leadScopedPipeline ? (currentUserUsesMeganPartnerView() ? buildLeadRowsByOwnerScope(new Set<Id>{ UserInfo.getUserId() }, null, null, false, 'active', 50) : buildAssignedLeads()) : ((adminPipeline || executivePipeline) ? buildAdminTransactions() : buildAssignedTransactions()))))));
        data.pipelineTitle = ceoPipeline ? 'Executive Overview' : (openerPipeline ? 'Ready for Disclosures' : (closerPipeline ? 'Active Pipeline' : (fundingLockDeskPipeline ? 'Active Pipeline' : (pastClientPipeline ? 'Ben\'s Past Client List' : (leadScopedPipeline ? 'Active Leads' : 'Active Pipeline')))));
        if (openerPipeline) {
            data.pipelineSubtitle = 'Files with completed submission forms ready for disclosure work and the Opener Checklist.';
        } else if (closerPipeline) {
            data.pipelineSubtitle = 'All active files created since 2024 for Closer workflow review.';
        } else if (fundingLockDeskPipeline) {
            data.pipelineSubtitle = 'Funding, lock desk, and COC work needing review.';
        } else if (ceoPipeline) {
            data.pipelineSubtitle = 'Company-level production, lead source, conversion, referral partner, and operational health views.';
        } else if (pastClientPipeline) {
            data.pipelineSubtitle = 'Primary-occupancy buyers with closed transactions after 1/1/2019, excluding protected LO and Biz Dev pipelines.';
        } else if (executivePipeline) {
            data.pipelineSubtitle = 'Executive transaction oversight with assigned Loan Officer lead follow-up.';
        } else if (leadScopedPipeline) {
            data.pipelineSubtitle = loanOfficerAssistantPipeline
                ? 'Active Zach Fritz, Joe Olmsted, and Rhett Delaney leads in contact, application, document, and contract statuses.'
                : 'Assigned active leads in contact, application, document, and contract statuses.';
        } else {
            data.pipelineSubtitle = adminPipeline
                ? 'All active and closing files created since 2024.'
                : 'Assigned active files ordered by closing date.';
        }
        data.pipelineObjectApiName = ceoPipeline ? 'Metric' : (pastClientPipeline ? 'Account' : (leadScopedPipeline ? 'Lead' : 'Transaction__c'));
        data.pipelineTabs = currentUserUsesMeganPartnerView()
            ? buildMeganPartnerPipelineTabs(data.pipelineRows)
            : (loanOfficerAssistantPipeline
            ? buildLoanOfficerAssistantPipelineTabs()
            : (openerPipeline
            ? buildOpenerPipelineTabs(data.pipelineRows)
            : (closerPipeline
                ? buildCloserPipelineTabs(data.pipelineRows)
                : (fundingLockDeskPipeline
                    ? buildFundingLockDeskPipelineTabs(data.pipelineRows)
                    : (ceoPipeline
                    ? buildCeoPipelineTabs()
                    : (pastClientPipeline
                    ? pastClientTabs
                    : (executivePipeline
                    ? buildExecutivePipelineTabs(data.pipelineRows)
                    : buildPipelineTabs(data.pipelineRows, data.pipelineTitle, data.pipelineSubtitle, data.pipelineObjectApiName, adminPipeline, managementCommandCenter))))))));
        data.quickButtons = (ceoPipeline || pastClientPipeline)
            ? new List<QuickButton>()
            : (rhettDelaney ? rhettDelaneyQuickButtons() : getUserQuickButtons());
        if ((leadPipeline || rhettDelaney) && data.quickButtons != null) {
            data.quickButtons.add(approvedInvestorsQuickButton());
        }
        data.queueShortcuts = openerPipeline ? openerQueueShortcuts() : (closerPipeline ? closerQueueShortcuts() : (fundingLockDeskPipeline ? fundingLockDeskQueueShortcuts() : defaultQueueShortcuts()));
        data.canEditPipelineTabRows = currentUserCanEditPipelineTabRows();
        data.canEditQuickButtons = !rhettDelaney;
        data.canCreateLead = !ceoPipeline && (leadPipeline || openerPipeline || adminPipeline || executivePipeline || managementCommandCenter || currentUserCanAssignNewLeadOwner());
        data.canAssignNewLeadOwner = currentUserCanAssignNewLeadOwner();
        data.canCreateTitleAgent = !ceoPipeline && !pastClientPipeline && !leadScopedPipeline;
        data.isCeoDashboard = ceoPipeline;
        data.isPastClientDashboard = pastClientPipeline;
        data.isRhettDelaney = rhettDelaney;
        String nickleyRealtorLOLabel = currentUserNickleyRealtorLOLabel();
        if (nickleyRealtorLOLabel != null) {
            data.pipelineTabs.add(buildNickleyRealtorStubTab(nickleyRealtorLOLabel));
        }
        return data;
    }

    @AuraEnabled(cacheable=true)
    public static List<PipelineRow> getPastClientRowsByYear(Integer closingYear) {
        if (closingYear == null || closingYear < PAST_CLIENT_MIN_CLOSED_DATE.year() || closingYear > Date.today().year()) {
            return new List<PipelineRow>();
        }
        return buildPastClientRows(closingYear);
    }

    // Stamps a Pass on a Pre-Approval Follow Ups lead. The cadence treats this the same as a
    // logged call, so the lead leaves the queue and returns after the applicable gap.
    @AuraEnabled
    public static void passPreApprovalFollowUp(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('A Lead is required to pass on a follow-up.');
        }
        List<Lead> leads = [
            SELECT Id, Status
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leads.isEmpty()) {
            throw new AuraHandledException('Unable to locate that Lead.');
        }
        if (leads[0].Status != 'Pre-Approval') {
            throw new AuraHandledException('Only leads in Pre-Approval status can be passed on.');
        }
        update new Lead(
            Id = leadId,
            Pre_Approval_Pass_At__c = System.now()
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<PipelineRow> getNickleyRealtorRows() {
        String nickleyRealtorLOLabel = currentUserNickleyRealtorLOLabel();
        if (nickleyRealtorLOLabel == null) {
            return new List<PipelineRow>();
        }
        return buildNickleyRealtorRows(nickleyRealtorLOLabel);
    }

    private static String currentUserNickleyRealtorLOLabel() {
        User currentUser = [
            SELECT Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        return NICKLEY_REALTOR_TAB_USERNAME_TO_LABEL.get(username);
    }

    private static PipelineTab buildNickleyRealtorStubTab(String loLabel) {
        Integer realtorCount = [
            SELECT COUNT()
            FROM Account
            WHERE Nickley_Realtor_LO__c = :loLabel
        ];
        PipelineTab tab = new PipelineTab(
            'myNickleyRealtors',
            'My Nickley Realtors',
            'Your allocated Nickley Group realtor partners.',
            'Account',
            new List<PipelineRow>(),
            buildNickleyRealtorColumns()
        );
        tab.count = realtorCount;
        return tab;
    }

    private static List<TableColumn> buildNickleyRealtorColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('phone', 'Phone'),
            new TableColumn('email', 'Email'),
            new TableColumn('lastLeadSentDate', 'Last Lead Sent')
        };
    }

    private static List<PipelineRow> buildNickleyRealtorRows(String loLabel) {
        List<Account> realtorAccounts = [
            SELECT Id, Name, Phone, PersonMobilePhone, PersonEmail
            FROM Account
            WHERE Nickley_Realtor_LO__c = :loLabel
            ORDER BY Name
        ];
        Set<Id> accountIds = new Set<Id>();
        for (Account realtorAccount : realtorAccounts) {
            accountIds.add(realtorAccount.Id);
        }
        Map<Id, Datetime> lastLeadDateByAccountId = nickleyRealtorLastLeadSentDates(accountIds);
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Account realtorAccount : realtorAccounts) {
            rows.add(buildNickleyRealtorRow(realtorAccount, lastLeadDateByAccountId.get(realtorAccount.Id)));
        }
        return rows;
    }

    // "Last lead sent" must reflect ALL leads ever sent by the realtor, not just the ones the
    // viewing LO happens to own/share (Lead sharing here is per-owner, unlike Account). Delegates
    // to a separate without-sharing class scoped to a date-only aggregate keyed by an already-vetted
    // set of Account Ids - no Lead content is exposed.
    private static Map<Id, Datetime> nickleyRealtorLastLeadSentDates(Set<Id> accountIds) {
        return NickleyRealtorLeadDateService.lastLeadSentDates(accountIds);
    }

    private static PipelineRow buildNickleyRealtorRow(Account realtorAccount, Datetime lastLeadSentDate) {
        PipelineRow row = new PipelineRow();
        row.id = realtorAccount.Id;
        row.name = realtorAccount.Name;
        String phone = firstNonBlank(new List<String>{ realtorAccount.Phone, realtorAccount.PersonMobilePhone });
        String email = realtorAccount.PersonEmail;
        String lastLeadDisplay = lastLeadSentDate == null ? '' : formatDateForCell(lastLeadSentDate.date());
        String lastLeadSort = formatDatetimeSortValue(lastLeadSentDate);
        row.customCells = new List<TableCell>{
            new TableCell('name', blankToLabel(realtorAccount.Name, ''), blankToLabel(realtorAccount.Name, ''), true),
            new TableCell('phone', blankToLabel(phone, ''), blankToLabel(phone, ''), false),
            new TableCell('email', blankToLabel(email, ''), blankToLabel(email, ''), false),
            new TableCell('lastLeadSentDate', lastLeadDisplay, lastLeadSort, false)
        };
        return row;
    }

    @AuraEnabled(cacheable=true)
    public static List<ListViewOption> getListViewOptions() {
        List<ListViewOption> options = new List<ListViewOption>();
        for (ListView viewRecord : [
            SELECT DeveloperName, Name, SobjectType
            FROM ListView
            WHERE SobjectType IN :SUPPORTED_OBJECTS
            ORDER BY SobjectType, Name
        ]) {
            options.add(new ListViewOption(viewRecord));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getRealtorPartnerFormOptions() {
        Map<String, List<PicklistOption>> optionsByField = new Map<String, List<PicklistOption>>();
        optionsByField.put('bizDevDesignation', picklistOptions(Account.Biz_Dev_Designation__c));
        optionsByField.put('realtorGroup', picklistOptions(Account.Realtor_Group__c));
        return optionsByField;
    }

    @AuraEnabled(cacheable=true)
    public static NewLeadFormOptions getNewLeadFormOptions() {
        if (!currentUserCanAssignNewLeadOwner()) {
            throw new AuraHandledException('You do not have access to assign a Lead owner from this form.');
        }

        NewLeadFormOptions options = new NewLeadFormOptions();
        options.leadSourceOptions = picklistOptions(Lead.LeadSource);
        options.loanPurposeOptions = picklistOptions(Lead.Loan_Purpose__c);
        options.bizDevOptions = picklistOptions(Lead.Biz_Dev__c);
        options.ownerOptions = new List<PicklistOption>();

        for (User userRecord : [
            SELECT Id, Name, Title, Profile.Name, UserRole.Name
            FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            ORDER BY Name
        ]) {
            String normalizedName = String.isBlank(userRecord.Name) ? '' : userRecord.Name.toLowerCase();
            if (NEW_LEAD_OWNER_PICKLIST_NAMES.contains(normalizedName)) {
                options.ownerOptions.add(new PicklistOption(userRecord.Name, String.valueOf(userRecord.Id)));
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<QuickButton> getUserQuickButtons() {
        List<Pipeline_Command_Center_Preference__c> preferences = [
            SELECT Button_1_Label__c, Button_1_Object__c, Button_1_Filter__c,
                   Button_2_Label__c, Button_2_Object__c, Button_2_Filter__c,
                   Button_3_Label__c, Button_3_Object__c, Button_3_Filter__c
            FROM Pipeline_Command_Center_Preference__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (preferences.isEmpty()) {
            return currentUserUsesOpenerPipeline()
                ? openerQuickButtons()
                : (currentUserUsesCloserPipeline()
                    ? closerQuickButtons()
                    : (currentUserUsesFundingLockDeskPipeline()
                        ? fundingLockDeskQuickButtons()
                        : (currentUserUsesLoanOfficerAssistantPipeline() ? loanOfficerAssistantQuickButtons() : defaultQuickButtons())));
        }

        Pipeline_Command_Center_Preference__c preference = preferences[0];
        List<QuickButton> fallbackButtons = currentUserUsesOpenerPipeline()
            ? openerQuickButtons()
            : (currentUserUsesCloserPipeline()
                ? closerQuickButtons()
                : (currentUserUsesFundingLockDeskPipeline()
                    ? fundingLockDeskQuickButtons()
                    : (currentUserUsesLoanOfficerAssistantPipeline() ? loanOfficerAssistantQuickButtons() : defaultQuickButtons())));
        List<QuickButton> buttons = new List<QuickButton>{
            new QuickButton(preference.Button_1_Label__c, preference.Button_1_Object__c, preference.Button_1_Filter__c),
            new QuickButton(preference.Button_2_Label__c, preference.Button_2_Object__c, preference.Button_2_Filter__c),
            new QuickButton(preference.Button_3_Label__c, preference.Button_3_Object__c, preference.Button_3_Filter__c)
        };
        for (Integer i = 0; i < buttons.size(); i++) {
            if (String.isBlank(buttons[i].objectApiName) || String.isBlank(buttons[i].filterName)) {
                buttons[i] = fallbackButtons[i];
            }
        }
        return buttons;
    }

    private static String getUserColumnPreferencesJson() {
        List<Pipeline_Command_Center_Preference__c> preferences = [
            SELECT Column_Preferences__c
            FROM Pipeline_Command_Center_Preference__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        return preferences.isEmpty() ? null : preferences[0].Column_Preferences__c;
    }

    @AuraEnabled
    public static List<QuickButton> saveUserQuickButtons(List<QuickButton> buttons) {
        if (buttons == null || buttons.size() != 3) {
            throw new AuraHandledException('Choose exactly three list view buttons.');
        }
        validateButtons(buttons);

        List<Pipeline_Command_Center_Preference__c> preferences = [
            SELECT Id
            FROM Pipeline_Command_Center_Preference__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        Pipeline_Command_Center_Preference__c preference = preferences.isEmpty()
            ? new Pipeline_Command_Center_Preference__c(User__c = UserInfo.getUserId(), Name = 'Pipeline Command Center - ' + UserInfo.getUserId())
            : preferences[0];

        preference.Button_1_Label__c = buttons[0].label;
        preference.Button_1_Object__c = buttons[0].objectApiName;
        preference.Button_1_Filter__c = buttons[0].filterName;
        preference.Button_2_Label__c = buttons[1].label;
        preference.Button_2_Object__c = buttons[1].objectApiName;
        preference.Button_2_Filter__c = buttons[1].filterName;
        preference.Button_3_Label__c = buttons[2].label;
        preference.Button_3_Object__c = buttons[2].objectApiName;
        preference.Button_3_Filter__c = buttons[2].filterName;
        upsert preference;

        return getUserQuickButtons();
    }

    @AuraEnabled
    public static String saveUserColumnPreferences(String columnPreferencesJson) {
        String cleanedPreferences = String.isBlank(columnPreferencesJson) ? null : columnPreferencesJson.trim();
        if (cleanedPreferences != null && cleanedPreferences.length() > 32000) {
            throw new AuraHandledException('Column preferences are too large to save.');
        }

        List<Pipeline_Command_Center_Preference__c> preferences = [
            SELECT Id
            FROM Pipeline_Command_Center_Preference__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        Pipeline_Command_Center_Preference__c preference = preferences.isEmpty()
            ? new Pipeline_Command_Center_Preference__c(User__c = UserInfo.getUserId(), Name = 'Pipeline Command Center - ' + UserInfo.getUserId())
            : preferences[0];

        preference.Column_Preferences__c = cleanedPreferences;
        upsert preference;
        return preference.Column_Preferences__c;
    }

    @AuraEnabled
    public static void saveProcessorNote(Id transactionId, String noteText) {
        if (transactionId == null) {
            throw new AuraHandledException('A Transaction is required.');
        }
        if (String.isBlank(noteText)) {
            throw new AuraHandledException('Enter a processor note before saving.');
        }
        String cleanedNote = noteText.trim();
        Transaction__c transactionRecord = new Transaction__c(
            Id = transactionId,
            Processor_Note__c = cleanedNote,
            Processor_Note_For_Display__c = notePreview(cleanedNote, 255),
            Processor_Note_Date_Time__c = System.now()
        );
        update transactionRecord;

        insert new Enhanced_Note__c(
            Subject__c = 'FILE NOTE ' + DateTime.now().format('M.d'),
            Body__c = '<p>' + cleanedNote.escapeHtml4() + '</p>',
            Transaction__c = transactionId,
            Type__c = 'Note'
        );

        ContentNote transactionNote = new ContentNote(
            Title = 'Processor Note - ' + DateTime.now().format('M/d/yyyy h:mm a'),
            Content = Blob.valueOf(cleanedNote)
        );
        insert transactionNote;

        insert new ContentDocumentLink(
            ContentDocumentId = transactionNote.Id,
            LinkedEntityId = transactionId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static String notePreview(String noteText, Integer maxLength) {
        if (String.isBlank(noteText) || maxLength == null || maxLength <= 0) {
            return noteText;
        }
        String preview = noteText.replaceAll('\\s+', ' ').trim();
        return preview.length() <= maxLength ? preview : preview.substring(0, maxLength);
    }

    @AuraEnabled
    public static void saveManagerNote(Id transactionId, String noteText) {
        if (transactionId == null) {
            throw new AuraHandledException('A Transaction is required.');
        }
        if (String.isBlank(noteText)) {
            throw new AuraHandledException('Enter a manager note before saving.');
        }
        String cleanedNote = noteText.trim();
        update new Transaction__c(
            Id = transactionId,
            Manager_Notes__c = cleanedNote
        );

        insert new Enhanced_Note__c(
            Subject__c = 'MANAGER NOTE ' + DateTime.now().format('M.d'),
            Body__c = '<p>' + cleanedNote.escapeHtml4() + '</p>',
            Transaction__c = transactionId,
            Type__c = 'Note'
        );

        ContentNote transactionNote = new ContentNote(
            Title = 'Manager Note - ' + DateTime.now().format('M/d/yyyy h:mm a'),
            Content = Blob.valueOf(cleanedNote)
        );
        insert transactionNote;

        insert new ContentDocumentLink(
            ContentDocumentId = transactionNote.Id,
            LinkedEntityId = transactionId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @AuraEnabled
    public static void saveAccountNote(Id accountId, String noteText) {
        if (accountId == null) {
            throw new AuraHandledException('An Account is required.');
        }
        if (String.isBlank(noteText)) {
            throw new AuraHandledException('Enter a note before saving.');
        }
        String cleanedNote = noteText.trim();

        ContentNote accountNote = new ContentNote(
            Title = 'Past Client Note - ' + DateTime.now().format('M/d/yyyy h:mm a'),
            Content = Blob.valueOf(cleanedNote)
        );
        insert accountNote;

        insert new ContentDocumentLink(
            ContentDocumentId = accountNote.Id,
            LinkedEntityId = accountId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @AuraEnabled
    public static void saveLeadNote(Id leadId, String noteText) {
        if (leadId == null) {
            throw new AuraHandledException('A Lead is required.');
        }
        if (String.isBlank(noteText)) {
            throw new AuraHandledException('Enter a note before saving.');
        }
        String cleanedNote = noteText.trim();

        ContentNote leadNote = new ContentNote(
            Title = 'Lead Note - ' + DateTime.now().format('M/d/yyyy h:mm a'),
            Content = Blob.valueOf(cleanedNote)
        );
        insert leadNote;

        insert new ContentDocumentLink(
            ContentDocumentId = leadNote.Id,
            LinkedEntityId = leadId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @AuraEnabled
    public static void clearAccountPhoneNumber(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('An Account is required.');
        }
        Account borrowerAccount = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        update new Account(
            Id = borrowerAccount.Id,
            Phone = null,
            PersonMobilePhone = null
        );
    }

    @AuraEnabled
    public static void markAccountPropertySold(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('An Account is required.');
        }
        Account borrowerAccount = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        update new Account(
            Id = borrowerAccount.Id,
            Property_Sold__c = true
        );
    }

    @AuraEnabled
    public static Id createRealtorPartner(
        String firstName,
        String lastName,
        String mobilePhone,
        String email,
        String bizDevDesignation,
        String brokerage,
        String realtorGroup,
        Id transactionCoordinatorId,
        String realtorIndividualLicenseNumber,
        String companyLicenseNumber
    ) {
        if (String.isBlank(firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (String.isBlank(mobilePhone)) {
            throw new AuraHandledException('Mobile Phone is required.');
        }
        if (String.isBlank(email)) {
            throw new AuraHandledException('Email is required.');
        }
        if (String.isBlank(bizDevDesignation)) {
            throw new AuraHandledException('Biz Dev Designation is required.');
        }

        Id personAccountRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account realtorPartner = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = firstName.trim(),
            LastName = lastName.trim(),
            PersonMobilePhone = mobilePhone.trim(),
            Phone = mobilePhone.trim(),
            PersonEmail = email.trim(),
            Biz_Dev_Designation__c = bizDevDesignation,
            Type__c = 'Realtor Account',
            Group__pc = 'Realtor',
            Is_Realtor__c = true
        );

        if (!String.isBlank(brokerage)) {
            realtorPartner.PersonTitle = brokerage.trim();
        }
        if (!String.isBlank(realtorGroup)) {
            realtorPartner.Realtor_Group__c = realtorGroup;
        }
        if (transactionCoordinatorId != null) {
            realtorPartner.Transaction_Coordinator__c = transactionCoordinatorId;
        }
        if (!String.isBlank(realtorIndividualLicenseNumber)) {
            realtorPartner.Realtor_Individual_License_Number__c = realtorIndividualLicenseNumber.trim();
        }
        if (!String.isBlank(companyLicenseNumber)) {
            realtorPartner.Company_License_Number__c = companyLicenseNumber.trim();
        }

        try {
            insert realtorPartner;
        } catch (DmlException e) {
            if (e.getNumDml() > 0 && e.getDmlStatusCode(0) == 'DUPLICATES_DETECTED') {
                throw new AuraHandledException('This appears to be a duplicate Realtor Partner account. Please search Accounts for this Realtor before creating a new one.');
            }
            throw e;
        }
        return realtorPartner.Id;
    }

    private static List<PicklistOption> picklistOptions(Schema.SObjectField fieldToken) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    @AuraEnabled
    public static Id createRealtorLead(String firstName, String lastName, String phone, String email, String leadSource, String notes) {
        if (String.isBlank(firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (String.isBlank(phone)) {
            throw new AuraHandledException('Phone is required.');
        }
        if (String.isBlank(email)) {
            throw new AuraHandledException('Email is required.');
        }

        Id realtorLeadRecordTypeId = Schema.SObjectType.Lead
            .getRecordTypeInfosByDeveloperName()
            .get('Realtor_Lead_record_type')
            .getRecordTypeId();

        Lead realtorLead = new Lead(
            RecordTypeId = realtorLeadRecordTypeId,
            FirstName = firstName.trim(),
            LastName = lastName.trim(),
            Company = firstName.trim() + ' ' + lastName.trim(),
            Phone = phone.trim(),
            Email = email.trim(),
            Status = 'Working',
            OwnerId = UserInfo.getUserId()
        );
        if (!String.isBlank(leadSource)) {
            realtorLead.LeadSource = leadSource.trim();
        }
        if (!String.isBlank(notes)) {
            realtorLead.Comments__c = notes.trim();
        }

        insert realtorLead;
        return realtorLead.Id;
    }

    @AuraEnabled
    public static Id createConsumerLead(
        String firstName,
        String lastName,
        String phone,
        String email,
        String leadSource,
        String loanPurpose,
        String bizDev,
        Id realtorBuyingAgentId,
        Id ownerId
    ) {
        if (!currentUserCanAssignNewLeadOwner()) {
            throw new AuraHandledException('You do not have access to assign a Lead owner from this form.');
        }
        if (String.isBlank(firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (String.isBlank(phone)) {
            throw new AuraHandledException('Phone is required.');
        }
        if (String.isBlank(email)) {
            throw new AuraHandledException('Email is required.');
        }
        if (String.isBlank(leadSource)) {
            throw new AuraHandledException('Lead Source is required.');
        }
        if (String.isBlank(loanPurpose)) {
            throw new AuraHandledException('Loan Purpose is required.');
        }
        if (String.isBlank(bizDev)) {
            throw new AuraHandledException('Biz Dev is required.');
        }

        Id assignedOwnerId = UserInfo.getUserId();
        if (ownerId != null) {
            List<User> owners = [
                SELECT Id
                FROM User
                WHERE Id = :ownerId
                AND IsActive = true
                LIMIT 1
            ];
            if (owners.isEmpty()) {
                throw new AuraHandledException('Choose an active owner for the new Lead.');
            }
            assignedOwnerId = owners[0].Id;
        }

        Lead consumerLead = new Lead(
            RecordTypeId = getConsumerLeadRecordTypeId(),
            FirstName = firstName.trim(),
            LastName = lastName.trim(),
            Company = firstName.trim() + ' ' + lastName.trim(),
            Phone = phone.trim(),
            Email = email.trim(),
            LeadSource = leadSource.trim(),
            Loan_Purpose__c = loanPurpose.trim(),
            Biz_Dev__c = bizDev.trim(),
            OwnerId = assignedOwnerId
        );
        if (realtorBuyingAgentId != null) {
            consumerLead.Realtor_Buying_Agent__c = realtorBuyingAgentId;
        }

        insert consumerLead;
        return consumerLead.Id;
    }

    @AuraEnabled
    public static Id createTitleAgentAccount(String accountName, String phoneNumber, String email) {
        if (String.isBlank(accountName)) {
            throw new AuraHandledException('Title Agent Name is required.');
        }
        if (String.isBlank(phoneNumber)) {
            throw new AuraHandledException('Phone Number is required.');
        }
        if (String.isBlank(email)) {
            throw new AuraHandledException('Email is required.');
        }

        Id personAccountRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account titleAgent = new Account(
            RecordTypeId = personAccountRecordTypeId,
            LastName = accountName.trim(),
            Phone = phoneNumber.trim(),
            PersonMobilePhone = phoneNumber.trim(),
            PersonEmail = email.trim(),
            Type__c = 'Title Agent Account',
            Group__pc = 'Title Agent'
        );

        insert titleAgent;
        return titleAgent.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchRealtorAccounts(String searchTerm) {
        String normalizedTerm = String.isBlank(searchTerm) ? '' : searchTerm.trim();
        if (normalizedTerm.length() < 2) {
            return new List<LookupOption>();
        }

        String searchPattern = '%' + String.escapeSingleQuotes(normalizedTerm) + '%';
        List<LookupOption> options = new List<LookupOption>();
        for (Account realtorAccount : [
            SELECT Id, Name, PersonEmail, PersonMobilePhone, Phone, Realtor_Group__c
            FROM Account
            WHERE Name LIKE :searchPattern
            AND (
                Type__c = 'Realtor Account'
                OR Group__pc INCLUDES ('Realtor')
                OR Is_Realtor__c = true
            )
            ORDER BY Name
            LIMIT 10
        ]) {
            String subtitle = firstNonBlank(new List<String>{
                realtorAccount.Realtor_Group__c,
                realtorAccount.PersonMobilePhone,
                realtorAccount.Phone,
                realtorAccount.PersonEmail
            });
            options.add(new LookupOption(realtorAccount.Id, realtorAccount.Name, subtitle));
        }
        return options;
    }

    @AuraEnabled
    public static Id createTransactionEvent(Id transactionId, String subject, Datetime startDateTime) {
        if (transactionId == null) {
            throw new AuraHandledException('A Transaction is required.');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Enter an event name before saving.');
        }
        if (startDateTime == null) {
            throw new AuraHandledException('Choose an event date and time before saving.');
        }

        Event eventRecord = new Event(
            Subject = subject.trim(),
            WhatId = transactionId,
            OwnerId = UserInfo.getUserId(),
            StartDateTime = startDateTime,
            EndDateTime = startDateTime.addMinutes(15),
            DurationInMinutes = 15,
            Event_Type__c = 'Scheduled Appointment',
            IsReminderSet = true,
            ReminderDateTime = startDateTime.addMinutes(-15)
        );
        insert eventRecord;
        return eventRecord.Id;
    }

    @AuraEnabled
    public static Id createAccountEvent(Id accountId, String subject, Datetime startDateTime) {
        if (accountId == null) {
            throw new AuraHandledException('An Account is required.');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Enter an event name before saving.');
        }
        if (startDateTime == null) {
            throw new AuraHandledException('Choose an event date and time before saving.');
        }

        Event eventRecord = new Event(
            Subject = subject.trim(),
            WhatId = accountId,
            OwnerId = UserInfo.getUserId(),
            StartDateTime = startDateTime,
            EndDateTime = startDateTime.addMinutes(15),
            DurationInMinutes = 15,
            Event_Type__c = 'Scheduled Appointment',
            IsReminderSet = true,
            ReminderDateTime = startDateTime.addMinutes(-15)
        );
        insert eventRecord;
        return eventRecord.Id;
    }

    @AuraEnabled
    public static Id createLeadEvent(Id leadId, String subject, Datetime startDateTime) {
        if (leadId == null) {
            throw new AuraHandledException('A Lead is required.');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Enter an event name before saving.');
        }
        if (startDateTime == null) {
            throw new AuraHandledException('Choose an event date and time before saving.');
        }

        Event eventRecord = new Event(
            Subject = subject.trim(),
            WhoId = leadId,
            OwnerId = UserInfo.getUserId(),
            StartDateTime = startDateTime,
            EndDateTime = startDateTime.addMinutes(15),
            DurationInMinutes = 15,
            Event_Type__c = 'Scheduled Appointment',
            IsReminderSet = true,
            ReminderDateTime = startDateTime.addMinutes(-15)
        );
        insert eventRecord;
        return eventRecord.Id;
    }

    @AuraEnabled
    public static void markBrokerCheckReceived(Id transactionId) {
        if (transactionId == null) {
            throw new AuraHandledException('A Transaction is required.');
        }

        update new Transaction__c(
            Id = transactionId,
            Broker_Check_Recieved__c = true
        );
    }

    private static void validateButtons(List<QuickButton> buttons) {
        Set<String> requestedPairs = new Set<String>();
        for (QuickButton button : buttons) {
            if (button == null || String.isBlank(button.objectApiName) || String.isBlank(button.filterName)) {
                throw new AuraHandledException('Each button must include an object and list view.');
            }
            if (!SUPPORTED_OBJECTS.contains(button.objectApiName)) {
                throw new AuraHandledException('Unsupported object selected: ' + button.objectApiName);
            }
            requestedPairs.add(button.objectApiName + ':' + button.filterName);
        }

        Set<String> validPairs = new Set<String>();
        for (ListView viewRecord : [
            SELECT DeveloperName, SobjectType
            FROM ListView
            WHERE SobjectType IN :SUPPORTED_OBJECTS
        ]) {
            validPairs.add(viewRecord.SobjectType + ':' + viewRecord.DeveloperName);
        }
        for (String requestedPair : requestedPairs) {
            if (!validPairs.contains(requestedPair)) {
                throw new AuraHandledException('One selected list view is no longer available.');
            }
        }
    }

    private static List<QuickButton> defaultQuickButtons() {
        return new List<QuickButton>{
            new QuickButton('Processor Review', 'Transaction__c', 'Copy_of_Open_Pipeline_Processor'),
            new QuickButton('Open Pipeline', 'Transaction__c', 'Open_Pipeline'),
            new QuickButton('Working Leads', 'Lead', 'Biz_Dev_Team_Working_Leads')
        };
    }

    private static List<QuickButton> openerQuickButtons() {
        return new List<QuickButton>{
            new QuickButton('Open / Disclosures Out', 'Transaction__c', 'X1_Application'),
            new QuickButton('Initial Disclosures Required', 'Transaction__c', 'Initial_Disclosures_Required'),
            new QuickButton('Broker Checks Outstanding', 'Transaction__c', 'Broker_Check_Outstanding')
        };
    }

    private static List<QuickButton> closerQuickButtons() {
        return new List<QuickButton>{
            new QuickButton('Correspondent Closer View', 'Transaction__c', 'Correspondent_Closer_View'),
            new QuickButton('Brokered Closer View', 'Transaction__c', 'Brokered_Closer_View'),
            new QuickButton('Correspondent Funder View', 'Transaction__c', 'Correspondent_Funder_View')
        };
    }

    private static List<QuickButton> fundingLockDeskQuickButtons() {
        return new List<QuickButton>{
            new QuickButton('Correspondent Funder View', 'Transaction__c', 'Correspondent_Funder_View'),
            new QuickButton('Funder Action Required', 'Transaction__c', 'Action_Required'),
            new QuickButton('Open COC Requests', 'Case', 'All_Open_COC_Requests')
        };
    }

    private static List<QuickButton> loanOfficerAssistantQuickButtons() {
        return new List<QuickButton>{
            new QuickButton('Working Leads', 'Lead', 'Biz_Dev_Team_Working_Leads'),
            new QuickButton('Pre-Approvals', 'Lead', 'Active_Pre_Approvals_in_2026'),
            new QuickButton('Intake Form Queue', 'Lead', 'Intake_Form_Queue_Lead')
        };
    }

    private static List<QuickButton> defaultQueueShortcuts() {
        return new List<QuickButton>{
            new QuickButton('Locks Expiring within a Week', 'Transaction__c', 'Locks_Expiring_Next_7_Days'),
            new QuickButton('Initial Disclosures Required', 'Transaction__c', 'Initial_Disclosures_Required'),
            new QuickButton('Closer Action Required', 'Transaction__c', 'Closer_Action_Required'),
            new QuickButton('Intake Form Queue', 'Lead', 'Intake_Form_Queue_Lead')
        };
    }

    private static List<QuickButton> openerQueueShortcuts() {
        return new List<QuickButton>{
            new QuickButton('Initial Disclosures Required', 'Transaction__c', 'Initial_Disclosures_Required')
        };
    }

    private static List<QuickButton> closerQueueShortcuts() {
        return new List<QuickButton>{
            new QuickButton('Closer Action Required', 'Transaction__c', 'Closer_Action_Required')
        };
    }

    private static List<QuickButton> fundingLockDeskQueueShortcuts() {
        return new List<QuickButton>{
            new QuickButton('Locks Expiring within a Week', 'Transaction__c', 'Locks_Expiring_Next_7_Days'),
            new QuickButton('Funder Action Required', 'Transaction__c', 'Action_Required'),
            new QuickButton('Open COC Requests', 'Case', 'All_Open_COC_Requests')
        };
    }

    private static List<QuickButton> rhettDelaneyQuickButtons() {
        return new List<QuickButton>{
            new QuickButton('My Realtors', 'Account', 'My_Realtors'),
            new QuickButton('My Client List', 'Account', 'My_Client_List')
        };
    }

    private static QuickButton approvedInvestorsQuickButton() {
        return new QuickButton('Approved Investors', 'Account', 'Investor_Accounts');
    }

    private static Boolean currentUserUsesOpenerPipeline() {
        User currentUser = [
            SELECT Name, Username, Email, Title
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String email = String.isBlank(currentUser.Email) ? '' : currentUser.Email.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();
        String title = String.isBlank(currentUser.Title) ? '' : currentUser.Title.toLowerCase();

        return OPENER_VIEW_USERNAMES.contains(username)
            || OPENER_VIEW_USERNAMES.contains(email)
            || name == 'laura hoyos'
            || title.contains('opening processor')
            || title.contains('opener');
    }

    private static Boolean currentUserUsesCloserPipeline() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return CLOSER_VIEW_USERNAMES.contains(username)
            || name == 'monica quintero';
    }

    private static Boolean currentUserUsesFundingLockDeskPipeline() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return FUNDING_LOCKDESK_VIEW_USERNAMES.contains(username)
            || name == 'jamie martinez';
    }

    private static Boolean currentUserCanEditPipelineTabRows() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return PIPELINE_TAB_EDITOR_USERNAMES.contains(username)
            || name == 'christopher lowman'
            || name == 'monica quintero'
            || name == 'jamie martinez';
    }

    private static Boolean currentUserUsesExecutivePipeline() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return EXECUTIVE_VIEW_USERNAMES.contains(username)
            || name == 'brandon brotsky';
    }

    private static Boolean currentUserUsesCeoPipeline() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return CEO_VIEW_USERNAMES.contains(username)
            || name == 'adam stephens';
    }

    private static Boolean currentUserUsesManagementCommandCenterHeader() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return name == 'christopher lowman'
            || username == 'clowman@reachhomeloans.com';
    }

    private static Boolean currentUserUsesManagementAlertTabs() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return MANAGEMENT_ALERT_USERNAMES.contains(username)
            || name == 'christopher lowman'
            || name == 'angelina noble';
    }

    private static Boolean currentUserUsesLoanOfficerAssistantPipeline() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return LO_ASSISTANT_VIEW_USERNAMES.contains(username)
            || name == 'joey d\'alessandro';
    }

    private static Boolean currentUserUsesPastClientPipeline() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return PAST_CLIENT_VIEW_USERNAMES.contains(username)
            || name == 'benjamin bondarevsky';
    }

    private static Set<Id> getScopedLeadUserIds() {
        Set<Id> userIds = new Set<Id>{ UserInfo.getUserId() };
        if (!currentUserUsesLoanOfficerAssistantPipeline()) {
            return userIds;
        }

        for (User assistedUser : [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Username IN :JOEY_ASSISTED_LO_USERNAMES
        ]) {
            userIds.add(assistedUser.Id);
        }
        return userIds;
    }

    private static Set<Id> getAllActiveLoanOfficerUserIds() {
        Set<Id> userIds = new Set<Id>();
        for (User userRecord : [
            SELECT Id, Name, Title, Profile.Name, UserRole.Name
            FROM User
            WHERE IsActive = true
        ]) {
            String normalizedName = String.isBlank(userRecord.Name) ? '' : userRecord.Name.toLowerCase();
            if (!ALL_LO_MONITOR_EXCLUDED_USER_NAMES.contains(normalizedName)
                && userLooksLikeLoanOfficer(userRecord)) {
                userIds.add(userRecord.Id);
            }
        }
        return userIds;
    }

    private static Map<String, User> getAssistedLoanOfficersByUsername() {
        Map<String, User> usersByUsername = new Map<String, User>();
        for (User assistedUser : [
            SELECT Id, Name, Username
            FROM User
            WHERE IsActive = true
            AND Username IN :JOEY_ASSISTED_LO_USERNAMES
        ]) {
            usersByUsername.put(assistedUser.Username.toLowerCase(), assistedUser);
        }
        return usersByUsername;
    }

    private static Boolean currentUserUsesLeadPipeline() {
        User currentUser = [
            SELECT Title, Profile.Name, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        List<String> descriptorParts = new List<String>();
        if (String.isNotBlank(currentUser.Title)) {
            descriptorParts.add(currentUser.Title);
        }
        if (currentUser.Profile != null && String.isNotBlank(currentUser.Profile.Name)) {
            descriptorParts.add(currentUser.Profile.Name);
        }
        if (currentUser.UserRole != null && String.isNotBlank(currentUser.UserRole.Name)) {
            descriptorParts.add(currentUser.UserRole.Name);
        }
        String descriptor = String.join(descriptorParts, ' ').toLowerCase();

        if (descriptor.contains('processor')) {
            return false;
        }
        return descriptor.contains('loan officer')
            || descriptor.contains('loan originator')
            || descriptor.contains('outside lo')
            || descriptor.contains('inside lo');
    }

    private static Boolean currentUserIsRhettDelaney() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return username == 'rdelaney@reachhomeloans.com'
            || name == 'rhett delaney';
    }

    private static Boolean currentUserUsesAdminPipeline() {
        User currentUser = [
            SELECT Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return currentUser.Profile != null
            && String.isNotBlank(currentUser.Profile.Name)
            && currentUser.Profile.Name.toLowerCase().contains('system administrator');
    }

    private static Boolean currentUserCanAssignNewLeadOwner() {
        User currentUser = [
            SELECT Name, Username, Email, Profile.Name, Title
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String normalizedName = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();

        return currentUserUsesAdminPipeline()
            || currentUserUsesOpenerPipeline()
            || NEW_LEAD_OWNER_ASSIGNMENT_OVERRIDE_NAMES.contains(normalizedName);
    }

    private static Id getConsumerLeadRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> recordTypesByDeveloperName =
            Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        for (String developerName : CONSUMER_LEAD_RECORD_TYPES) {
            Schema.RecordTypeInfo info = recordTypesByDeveloperName.get(developerName);
            if (info != null) {
                return info.getRecordTypeId();
            }
        }
        throw new AuraHandledException('A Consumer Lead record type could not be found.');
    }

    private static List<StatusCard> buildTransactionStatusCards(Boolean adminPipeline) {
        Map<String, Integer> countsByStatus = new Map<String, Integer>();
        if (adminPipeline) {
            for (AggregateResult result : [
                SELECT Status__c statusValue, COUNT(Id) recordCount
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
                GROUP BY Status__c
            ]) {
                countsByStatus.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
            }
        } else {
            Id currentUserId = UserInfo.getUserId();
            for (AggregateResult result : [
                SELECT Status__c statusValue, COUNT(Id) recordCount
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND (OwnerId = :currentUserId
                    OR Transaction_Owner__c = :currentUserId
                    OR Processor__c = :currentUserId
                    OR Additional_Processor__c = :currentUserId
                    OR Loan_Officer__c = :currentUserId
                    OR Loan_Partner__c = :currentUserId)
                GROUP BY Status__c
            ]) {
                countsByStatus.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
            }
        }

        return new List<StatusCard>{
            new StatusCard('Processing', countsByStatus.get('Processing'), 'Files in active processing and intake work.'),
            new StatusCard('Conditionally Approved', countsByStatus.get('Conditionally Approved'), 'Files needing conditions and client follow-up.'),
            new StatusCard('Closing', countsByStatus.get('Closing'), 'Files moving through closing preparation.'),
            new StatusCard('Funding', countsByStatus.get('Funding'), 'Files in final funding review.')
        };
    }

    private static List<StatusCard> buildExecutiveStatusCards() {
        Date currentMonthStart = Date.today().toStartOfMonth();
        Date nextMonthStart = currentMonthStart.addMonths(1);
        Date followingMonthStart = currentMonthStart.addMonths(2);
        Date preApprovalStartDate = Date.newInstance(2026, 1, 1);

        Integer productionThisMonth = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Status__c != 'Cancelled'
            AND Closing_Date__c >= :currentMonthStart
            AND Closing_Date__c < :nextMonthStart
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        Integer productionNextMonth = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Status__c != 'Cancelled'
            AND Closing_Date__c >= :nextMonthStart
            AND Closing_Date__c < :followingMonthStart
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        Integer activeHouseLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND Biz_Dev__c IN :HOUSE_BIZ_DEV_VALUES
            AND Status IN :ACTIVE_LEAD_STATUSES
        ];
        Integer currentHousePreApprovedLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND Biz_Dev__c IN :HOUSE_BIZ_DEV_VALUES
            AND Status = 'Pre-Approval'
            AND Pre_Approval_Date__c >= :preApprovalStartDate
        ];

        return new List<StatusCard>{
            new StatusCard('Production Board This Month', productionThisMonth, 'Files closing this month.', 'Transaction__c', 'Brandon_Production_This_Month'),
            new StatusCard('Production Board Next Month', productionNextMonth, 'Files closing next month.', 'Transaction__c', 'Brandon_Production_Next_Month'),
            new StatusCard('Active House Leads', activeHouseLeads, 'House Biz Dev leads in active statuses.', 'Lead', 'Active_House_Leads'),
            new StatusCard('Active Pre-Approvals in 2026', currentHousePreApprovedLeads, 'House Biz Dev leads in Pre-Approval.', 'Lead', 'Active_Pre_Approvals_in_2026')
        };
    }

    private static List<StatusCard> buildCeoStatusCards() {
        Date todayDate = Date.today();
        Date currentMonthStart = todayDate.toStartOfMonth();
        Date nextMonthStart = currentMonthStart.addMonths(1);
        Date quarterStart = currentQuarterStart(todayDate);
        Date yearStart = Date.newInstance(todayDate.year(), 1, 1);

        Integer fundedThisMonth = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Funding_Date__c >= :currentMonthStart
            AND Funding_Date__c < :nextMonthStart
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        Date nextQuarterStart = nextQuarterStart(todayDate);
        Integer fundedThisQuarter = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Funding_Date__c >= :quarterStart
            AND Funding_Date__c < :nextQuarterStart
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        Integer fundedThisYear = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Funding_Date__c >= :yearStart
            AND Funding_Date__c <= :todayDate
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        Integer nextMonthClosingUnits = closingUnits(nextMonthStart, nextMonthStart.addMonths(1));
        Integer activePipelineUnits = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
        ];

        return new List<StatusCard>{
            new StatusCard('Funded MTD', fundedThisMonth, String.valueOf(fundedThisMonth) + ' units', formatCurrency(fundedVolume(currentMonthStart, nextMonthStart)) + ' total loan amount'),
            new StatusCard('Funded QTD', fundedThisQuarter, String.valueOf(fundedThisQuarter) + ' units', formatCurrency(fundedVolume(quarterStart, nextQuarterStart)) + ' total loan amount'),
            new StatusCard('Funded YTD', fundedThisYear, String.valueOf(fundedThisYear) + ' units', formatCurrency(fundedVolume(yearStart, todayDate.addDays(1))) + ' total loan amount'),
            new StatusCard('Next Month Pipeline', nextMonthClosingUnits, String.valueOf(nextMonthClosingUnits) + ' units', formatCurrency(closingVolume(nextMonthStart, nextMonthStart.addMonths(1))) + ' scheduled closing volume. Active files: ' + String.valueOf(activePipelineUnits))
        };
    }

    private static List<StatusCard> buildOpenerStatusCards() {
        Map<String, Integer> countsByStatus = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT Status__c statusValue, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE Status__c IN :OPENER_TRANSACTION_STATUSES
            GROUP BY Status__c
        ]) {
            countsByStatus.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
        }

        return new List<StatusCard>{
            new StatusCard('TRID Application', countsByStatus.get('TRID Application'), 'Files moving into the opening workflow.'),
            new StatusCard('Submission Form Complete', countsByStatus.get('Open'), 'Files ready for disclosure preparation.'),
            new StatusCard('Disclosures Out', countsByStatus.get('Disclosures Out'), 'Files waiting on borrower signatures.'),
            new StatusCard('Pre-Processing', countsByStatus.get('Pre-Processing'), 'Files ready to open into processing.')
        };
    }

    private static List<StatusCard> buildCloserStatusCards() {
        Map<String, Integer> countsByStatus = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT Status__c statusValue, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE Status__c IN :CLOSER_TRANSACTION_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            AND Lender_lookup__r.Name IN :CLOSER_LENDER_NAMES
            GROUP BY Status__c
        ]) {
            countsByStatus.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
        }

        return new List<StatusCard>{
            new StatusCard('Conditionally Approved', countsByStatus.get('Conditionally Approved'), 'Files approaching closing workflow.'),
            new StatusCard('Closing', countsByStatus.get('Closing'), 'Files in active closing checklist work.'),
            new StatusCard('Funding', countsByStatus.get('Funding'), 'Files in final funding checklist work.'),
            new StatusCard('PC Review', countsByStatus.get('PC Review'), 'Files in post-closing review.')
        };
    }

    private static List<StatusCard> buildFundingLockDeskStatusCards() {
        Date todayDate = Date.today();
        Date lockWindowEnd = todayDate.addDays(7);
        Integer fundingCount = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Status__c = 'Funding'
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
        ];
        Integer funderActionCount = buildFunderActionRequiredTransactions().size();
        Integer locksExpiringCount = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Rate_Lock_Exp_Date__c >= :todayDate
            AND Rate_Lock_Exp_Date__c <= :lockWindowEnd
            AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
        ];
        Integer openCocCount = [
            SELECT COUNT()
            FROM Case
            WHERE IsClosed = FALSE
            AND Subject LIKE 'Change of Circumstances%'
        ];

        return new List<StatusCard>{
            new StatusCard('Funding', fundingCount, 'Files currently in Funding status.', 'Transaction__c', 'Correspondent_Funder_View'),
            new StatusCard('Funder Action Required', funderActionCount, 'Funding files missing checklist items.', 'Transaction__c', 'Action_Required'),
            new StatusCard('Locks Expiring within a Week', locksExpiringCount, 'Active files with rate locks expiring within the next 7 calendar days.', 'Transaction__c', 'Locks_Expiring_Next_7_Days'),
            new StatusCard('Open COC Requests', openCocCount, 'Open Change of Circumstance requests.', 'Case', 'All_Open_COC_Requests')
        };
    }

    private static List<StatusCard> buildLeadStatusCards() {
        Map<String, Integer> countsByStatus = new Map<String, Integer>();
        Set<Id> leadScopeUserIds = getScopedLeadUserIds();
        for (AggregateResult result : [
            SELECT Status statusValue, COUNT(Id) recordCount
            FROM Lead
            WHERE IsConverted = false
            AND Status IN ('New', 'Working', 'Pre-Approval', 'Under Contract')
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            GROUP BY Status
        ]) {
            countsByStatus.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
        }

        return new List<StatusCard>{
            new StatusCard('New', countsByStatus.get('New'), 'Assigned new leads awaiting first action.'),
            new StatusCard('Working', countsByStatus.get('Working'), 'Assigned leads currently in active follow-up.'),
            new StatusCard('Pre-Approval', countsByStatus.get('Pre-Approval'), 'Assigned leads in pre-approval workflow.'),
            new StatusCard('Under Contract', countsByStatus.get('Under Contract'), 'Assigned leads moving toward transaction setup.')
        };
    }

    private static List<PipelineRow> buildAssignedTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Last_Processor_RC_SMS__c, Last_Processor_RC_Call__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c,
                Property_Address__c, Property_City__c, Property_State__c,
                Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail,
                Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND Status__c NOT IN :CLOSING_TRANSACTION_STATUSES
            AND (OwnerId = :currentUserId
                OR Transaction_Owner__c = :currentUserId
                OR Processor__c = :currentUserId
                OR Additional_Processor__c = :currentUserId
                OR Loan_Officer__c = :currentUserId
                OR Loan_Partner__c = :currentUserId)
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 50
        ]) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildAdminTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Last_Processor_RC_SMS__c, Last_Processor_RC_Call__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c,
                Property_Address__c, Property_City__c, Property_State__c,
                Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail,
                Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND Status__c NOT IN :CLOSING_TRANSACTION_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ]) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildLoanOfficerActiveTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Funding_Date__c, Loan_Amount_1st__c, Loan_Purpose__c,
                Processor_Note__c, Processor_Note_For_Display__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c,
                Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail,
                Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            AND (OwnerId = :currentUserId
                OR Transaction_Owner__c = :currentUserId
                OR Loan_Officer__c = :currentUserId
                OR Loan_Partner__c = :currentUserId)
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildLoanOfficerClosedThisMonth() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        Date currentMonthStart = Date.today().toStartOfMonth();
        Date nextMonthStart = currentMonthStart.addMonths(1);
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Funding_Date__c, Loan_Amount_1st__c, Loan_Purpose__c,
                Processor_Note__c, Processor_Note_For_Display__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c,
                Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail,
                Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c IN :LO_CLOSED_THIS_MONTH_STATUSES
            AND Funding_Date__c >= :currentMonthStart
            AND Funding_Date__c < :nextMonthStart
            AND (OwnerId = :currentUserId
                OR Transaction_Owner__c = :currentUserId
                OR Loan_Officer__c = :currentUserId
                OR Loan_Partner__c = :currentUserId)
            ORDER BY Funding_Date__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(new PipelineRow(transactionRecord, transactionRecord.Funding_Date__c, null, transactionRecord.Processor_Note__c));
        }
        return rows;
    }

    private static List<PipelineRow> buildLoanOfficerDisclosuresNeedingSigned() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Funding_Date__c, Disclosures_Out_Date__c, Disclosures_Received_Date__c,
                Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Ease_Link__c, Biz_Dev__c, Borrower_Name__c, Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail, Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone,
                Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c = 'Disclosures Out'
            AND Disclosures_Received_Date__c = NULL
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            AND (OwnerId = :currentUserId
                OR Transaction_Owner__c = :currentUserId
                OR Loan_Officer__c = :currentUserId
                OR Loan_Partner__c = :currentUserId)
            ORDER BY Disclosures_Out_Date__c ASC NULLS FIRST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            Date disclosuresOutDate = transactionRecord.Disclosures_Out_Date__c == null
                ? null
                : Date.newInstance(
                    transactionRecord.Disclosures_Out_Date__c.year(),
                    transactionRecord.Disclosures_Out_Date__c.month(),
                    transactionRecord.Disclosures_Out_Date__c.day()
                );
            rows.add(new PipelineRow(
                transactionRecord,
                disclosuresOutDate,
                transactionRecord.Disclosures_Out_Date__c,
                transactionRecord.Processor_Note__c
            ));
        }
        return rows;
    }

    private static List<PipelineRow> buildTransactionRowsByLoanOfficerScope(
        Set<Id> userIds,
        Id loanOfficerId,
        Id partnerId,
        Boolean requireLoanPartner,
        String rowType,
        Integer rowLimit
    ) {
        List<PipelineRow> rows = new List<PipelineRow>();
        Integer effectiveLimit = rowLimit == null ? 100 : rowLimit;
        if ((requireLoanPartner && (loanOfficerId == null || partnerId == null))
            || (!requireLoanPartner && (userIds == null || userIds.isEmpty()))) {
            return rows;
        }

        String scopeClause = requireLoanPartner
            ? 'Loan_Officer__c = :loanOfficerId AND Loan_Partner__c = :partnerId'
            : '(OwnerId IN :userIds OR Transaction_Owner__c IN :userIds OR Loan_Officer__c IN :userIds)';
        String baseSelect = 'SELECT Id, Name, Status__c, Closing_Date__c, Funding_Date__c, Disclosures_Out_Date__c, Disclosures_Received_Date__c, '
            + 'Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c, '
            + 'Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail, '
            + 'Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name '
            + 'FROM Transaction__c WHERE ' + scopeClause + ' ';
        String queryString;

        if (rowType == 'disclosures') {
            queryString = baseSelect
                + 'AND Status__c = \'Disclosures Out\' '
                + 'AND Disclosures_Received_Date__c = NULL '
                + 'AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME '
                + 'ORDER BY Disclosures_Out_Date__c ASC NULLS FIRST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC '
                + 'LIMIT :effectiveLimit';
            for (Transaction__c transactionRecord : Database.query(queryString)) {
                Date disclosuresOutDate = transactionRecord.Disclosures_Out_Date__c == null
                    ? null
                    : Date.newInstance(
                        transactionRecord.Disclosures_Out_Date__c.year(),
                        transactionRecord.Disclosures_Out_Date__c.month(),
                        transactionRecord.Disclosures_Out_Date__c.day()
                    );
                rows.add(new PipelineRow(
                    transactionRecord,
                    disclosuresOutDate,
                    transactionRecord.Disclosures_Out_Date__c,
                    transactionRecord.Processor_Note__c
                ));
            }
            return rows;
        }

        if (rowType == 'closedThisMonth') {
            Date currentMonthStart = Date.today().toStartOfMonth();
            Date nextMonthStart = currentMonthStart.addMonths(1);
            queryString = baseSelect
                + 'AND Status__c IN :LO_CLOSED_THIS_MONTH_STATUSES '
                + 'AND Funding_Date__c >= :currentMonthStart '
                + 'AND Funding_Date__c < :nextMonthStart '
                + 'ORDER BY Funding_Date__c DESC NULLS LAST, LastModifiedDate DESC '
                + 'LIMIT :effectiveLimit';
            for (Transaction__c transactionRecord : Database.query(queryString)) {
                rows.add(new PipelineRow(transactionRecord, transactionRecord.Funding_Date__c, null, transactionRecord.Processor_Note__c));
            }
            return rows;
        }

        queryString = baseSelect
            + 'AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES '
            + 'AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME '
            + 'ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC '
            + 'LIMIT :effectiveLimit';
        for (Transaction__c transactionRecord : Database.query(queryString)) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildFilesInClosing() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Ease_Link__c, Biz_Dev__c, Borrower_Name__c, Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail, Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c IN :CLOSING_TRANSACTION_STATUSES
            AND (OwnerId = :currentUserId
                OR Transaction_Owner__c = :currentUserId
                OR Processor__c = :currentUserId
                OR Additional_Processor__c = :currentUserId
                OR Loan_Officer__c = :currentUserId
                OR Loan_Partner__c = :currentUserId)
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 50
        ]) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildAllFilesInClosing() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Ease_Link__c, Biz_Dev__c, Borrower_Name__c, Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail, Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Officer__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c IN :CLOSING_TRANSACTION_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ]) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildGoldStarTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Amount_1st__c, Loan_Purpose__c,
                Rate_Lock_Status__c, Rate_Lock_Exp_Date__c, Processor_Note__c, Processor_Note_For_Display__c,
                Ease_Link__c, Biz_Dev__c, Borrower_Name__c, Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail, Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone,
                Lender_lookup__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND Lender_lookup__r.Name LIKE 'Gold Star%'
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ]) {
            rows.add(buildGoldStarTransactionRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildCloserActiveTransactions() {
        return buildCloserTransactions(null, false);
    }

    private static List<PipelineRow> buildCloserFilesInClosing() {
        return buildCloserTransactions(new List<String>{ 'Approved', 'Closing' }, false);
    }

    private static List<PipelineRow> buildCloserFilesInFunding() {
        return buildCloserTransactions(new List<String>{ 'Funding' }, true);
    }

    private static List<PipelineRow> buildCloserFilesClosingToday() {
        return buildCloserTransactionsClosingToday();
    }

    private static List<PipelineRow> buildFundingQueueTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : selectFundingLockDeskTransactions(
            'Status__c = \'Funding\' ORDER BY Funding_Date__c ASC NULLS LAST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC'
        )) {
            PipelineRow row = new PipelineRow(transactionRecord, transactionRecord.Funding_Date__c, null, null);
            row.detail = buildFundingChecklistDetail(transactionRecord);
            rows.add(row);
        }
        return rows;
    }

    private static List<PipelineRow> buildFundingLockDeskActivePipeline() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : selectFundingLockDeskTransactions(
            'Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC'
        )) {
            rows.add(new PipelineRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildPcReviewPipeline() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : selectFundingLockDeskTransactions(
            'Status__c = \'PC Review\' ORDER BY Funding_Date__c ASC NULLS LAST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC'
        )) {
            PipelineRow row = new PipelineRow(transactionRecord, transactionRecord.Funding_Date__c, null, (String) safeSObjectValue(transactionRecord, 'Processor_Note__c'));
            rows.add(row);
        }
        return rows;
    }

    private static List<PipelineRow> buildNeedingWarehouseAssignmentTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : selectFundingLockDeskTransactions(
            'Closing_Date__c >= TODAY'
            + ' AND Closing_Date__c <= NEXT_N_DAYS:14'
            + ' AND Warehouse_Bank_Picklist__c = NULL'
            + ' AND Channel__c = \'Correspondent\''
            + ' AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES'
            + ' ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC'
        )) {
            PipelineRow row = new PipelineRow(transactionRecord);
            row.detail = 'Warehouse Bank not assigned';
            rows.add(row);
        }
        return rows;
    }

    private static List<PipelineRow> buildFunderActionRequiredTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Action_Required_Reason__c,
                Status__c,
                Closing_Type__c,
                Closing_Date__c,
                Funding_Date__c,
                Rate_Lock_Exp_Date__c,
                Warehouse_Bank_Picklist__c,
                MERS_Activated__c,
                Funding_Authorization__c,
                MERSUploadedActivated__c,
                Manager_Notes__c,
                Ease_Link__c
            FROM Transaction__c
            WHERE Action_Required__c = true
            AND Status__c IN ('Approved', 'Closing', 'Funding')
            ORDER BY Funding_Date__c ASC NULLS LAST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(buildFunderActionRequiredRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildLocksExpiringTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : selectFundingLockDeskTransactions(
            'Rate_Lock_Exp_Date__c >= TODAY'
            + ' AND Rate_Lock_Exp_Date__c <= NEXT_N_DAYS:7'
            + ' AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES'
            + ' ORDER BY Rate_Lock_Exp_Date__c ASC NULLS LAST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC'
        )) {
            rows.add(buildLocksExpiringRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildOpenCocRequestTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Case caseRecord : [
            SELECT Id, CaseNumber, Status, Subject, Transaction__c,
                Transaction__r.Id,
                Transaction__r.Name,
                Transaction__r.Status__c,
                Transaction__r.Closing_Date__c,
                Transaction__r.Funding_Date__c,
                Transaction__r.Loan_Amount_1st__c,
                Transaction__r.Loan_Purpose__c,
                Transaction__r.Processor_Note__c, Transaction__r.Processor_Note_For_Display__c,
                Transaction__r.Ease_Link__c,
                Transaction__r.Lender_lookup__r.Name,
                Transaction__r.Owner.Name
            FROM Case
            WHERE IsClosed = FALSE
            AND Subject LIKE 'Change of Circumstances%'
            AND Transaction__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 100
        ]) {
            PipelineRow row = new PipelineRow(caseRecord.Transaction__r);
            row.detail = 'COC Case ' + caseRecord.CaseNumber + ': ' + caseRecord.Status;
            rows.add(row);
        }
        return rows;
    }

    private static List<Transaction__c> selectFundingLockDeskTransactions(String whereAndOrderClause) {
        Set<String> fieldNames = new Set<String>{
            'Id',
            'Name',
            'Status__c',
            'Closing_Type__c',
            'Closing_Date__c',
            'Funding_Date__c',
            'Loan_Amount_1st__c',
            'Loan_Purpose__c',
            'Lender_lookup__c',
            'Borrower_Name__c',
            'Ease_Link__c',
            'Manager_Notes__c',
            'Processor_Note__c',
            'Processor_Note_For_Display__c',
            'Rate_Lock_Exp_Date__c',
            'Rate_Lock_Status__c'
        };
        fieldNames.addAll(FUNDING_CHECKLIST_FIELDS);

        Map<String, Schema.SObjectField> transactionFields = Schema.SObjectType.Transaction__c.fields.getMap();
        List<String> selectFields = new List<String>{
            'Borrower_Name__r.Corrected_Mobile__pc',
            'Borrower_Name__r.Corrected_Phone__pc',
            'Borrower_Name__r.PersonEmail',
            'Borrower_Name__r.PersonMobilePhone',
            'Borrower_Name__r.Phone',
            'Lender_lookup__r.Name',
            'Warehouse_Bank__r.Name',
            'Owner.Name'
        };
        for (String fieldName : fieldNames) {
            if (transactionFields.containsKey(fieldName)) {
                selectFields.add(fieldName);
            }
        }
        selectFields.sort();

        String query = 'SELECT ' + String.join(selectFields, ', ')
            + ' FROM Transaction__c'
            + ' WHERE CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME'
            + ' AND ' + whereAndOrderClause;
        return Database.query(query);
    }

    private static List<PipelineRow> buildCloserTransactions(List<String> statusValues, Boolean useFundingDateForSort) {
        List<PipelineRow> rows = new List<PipelineRow>();
        Set<String> fieldNames = new Set<String>{
            'Id',
            'Name',
            'Status__c',
            'Closing_Date__c',
            'Funding_Date__c',
            'Loan_Amount_1st__c',
            'Loan_Purpose__c',
            'Lender_lookup__c',
            'Borrower_Name__c',
            'Ease_Link__c',
            'Manager_Notes__c'
        };
        fieldNames.addAll(CLOSING_CHECKLIST_FIELDS);
        fieldNames.addAll(FUNDING_CHECKLIST_FIELDS);

        Map<String, Schema.SObjectField> transactionFields = Schema.SObjectType.Transaction__c.fields.getMap();
        List<String> selectFields = new List<String>{
            'Borrower_Name__r.Corrected_Mobile__pc',
            'Borrower_Name__r.Corrected_Phone__pc',
            'Borrower_Name__r.PersonEmail',
            'Borrower_Name__r.PersonMobilePhone',
            'Borrower_Name__r.Phone',
            'Lender_lookup__r.Name',
            'Owner.Name'
        };
        for (String fieldName : fieldNames) {
            if (transactionFields.containsKey(fieldName)) {
                selectFields.add(fieldName);
            }
        }
        selectFields.sort();

        String query = 'SELECT ' + String.join(selectFields, ', ')
            + ' FROM Transaction__c'
            + ' WHERE CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME'
            + ' AND Lender_lookup__r.Name IN :CLOSER_LENDER_NAMES';
        if (statusValues == null || statusValues.isEmpty()) {
            query += ' AND Status__c NOT IN :CLOSER_ACTIVE_EXCLUDED_STATUSES';
        } else {
            query += ' AND Status__c IN :statusValues';
        }
        query += ' ORDER BY ' + (useFundingDateForSort ? 'Funding_Date__c' : 'Closing_Date__c') + ' ASC NULLS LAST, LastModifiedDate DESC';

        for (Transaction__c transactionRecord : Database.query(query)) {
            Date rowDate = useFundingDateForSort
                ? (Date) safeSObjectValue(transactionRecord, 'Funding_Date__c')
                : (Date) safeSObjectValue(transactionRecord, 'Closing_Date__c');
            PipelineRow row = new PipelineRow(transactionRecord, rowDate, null, null);
            row.detail = buildCloserChecklistDetail(transactionRecord);
            rows.add(row);
        }
        return rows;
    }

    private static List<PipelineRow> buildCloserTransactionsClosingToday() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Set<String> fieldNames = new Set<String>{
            'Id',
            'Name',
            'Status__c',
            'Closing_Date__c',
            'Funding_Date__c',
            'Loan_Amount_1st__c',
            'Loan_Purpose__c',
            'Lender_lookup__c',
            'Borrower_Name__c',
            'Manager_Notes__c'
        };
        fieldNames.addAll(CLOSING_CHECKLIST_FIELDS);
        fieldNames.addAll(FUNDING_CHECKLIST_FIELDS);

        Map<String, Schema.SObjectField> transactionFields = Schema.SObjectType.Transaction__c.fields.getMap();
        List<String> selectFields = new List<String>{
            'Borrower_Name__r.Corrected_Mobile__pc',
            'Borrower_Name__r.Corrected_Phone__pc',
            'Borrower_Name__r.PersonEmail',
            'Borrower_Name__r.PersonMobilePhone',
            'Borrower_Name__r.Phone',
            'Lender_lookup__r.Name',
            'Owner.Name'
        };
        for (String fieldName : fieldNames) {
            if (transactionFields.containsKey(fieldName)) {
                selectFields.add(fieldName);
            }
        }
        selectFields.sort();

        Date todayDate = Date.today();
        String query = 'SELECT ' + String.join(selectFields, ', ')
            + ' FROM Transaction__c'
            + ' WHERE CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME'
            + ' AND Lender_lookup__r.Name IN :CLOSER_LENDER_NAMES'
            + ' AND Closing_Date__c = :todayDate'
            + ' AND Status__c NOT IN :CLOSER_ACTIVE_EXCLUDED_STATUSES'
            + ' ORDER BY LastModifiedDate DESC';

        for (Transaction__c transactionRecord : Database.query(query)) {
            PipelineRow row = new PipelineRow(transactionRecord, transactionRecord.Closing_Date__c, null, null);
            row.detail = buildCloserChecklistDetail(transactionRecord);
            rows.add(row);
        }
        return rows;
    }

    private static String buildCloserChecklistDetail(Transaction__c transactionRecord) {
        String statusValue = (String) safeSObjectValue(transactionRecord, 'Status__c');
        if (statusValue == 'Closing') {
            return buildFieldChecklistDetail(transactionRecord, CLOSING_CHECKLIST_FIELDS, 'Closing checklist complete');
        }
        if (statusValue == 'Funding') {
            return buildFundingChecklistDetail(transactionRecord);
        }
        return 'No active closer checklist';
    }

    private static String buildFundingChecklistDetail(Transaction__c transactionRecord) {
        String closingType = (String) safeSObjectValue(transactionRecord, 'Closing_Type__c');
        List<String> checklistFields = ELECTRONIC_FUNDING_CLOSING_TYPES.contains(closingType)
            ? FUNDING_ELECTRONIC_CHECKLIST_FIELDS
            : FUNDING_CHECKLIST_FIELDS;
        return buildFieldChecklistDetail(transactionRecord, checklistFields, 'Funding checklist complete');
    }

    private static String buildFieldChecklistDetail(Transaction__c transactionRecord, List<String> fieldNames, String completeText) {
        List<String> openLabels = new List<String>();
        Map<String, Schema.SObjectField> transactionFields = Schema.SObjectType.Transaction__c.fields.getMap();
        for (String fieldName : fieldNames) {
            if (!transactionFields.containsKey(fieldName)) {
                continue;
            }
            if (fieldName == 'Closing_Package_Rejection_Notes__c'
                && normalizeChecklistValue(safeSObjectValue(transactionRecord, 'Closing_Package_Status__c')) != 'rejected') {
                continue;
            }
            if (!isChecklistFieldComplete(safeSObjectValue(transactionRecord, fieldName))) {
                openLabels.add(transactionFields.get(fieldName).getDescribe().getLabel());
            }
        }
        if (openLabels.isEmpty()) {
            return completeText;
        }

        Integer visibleCount = Math.min(3, openLabels.size());
        List<String> visibleLabels = new List<String>();
        for (Integer i = 0; i < visibleCount; i++) {
            visibleLabels.add(openLabels[i]);
        }
        String extraText = openLabels.size() > visibleCount ? ' +' + String.valueOf(openLabels.size() - visibleCount) + ' more' : '';
        return String.valueOf(openLabels.size()) + ' open: ' + String.join(visibleLabels, ', ') + extraText;
    }

    private static List<PipelineRow> buildOpenerTransactionsByStatus(String statusValue) {
        List<PipelineRow> rows = new List<PipelineRow>();
        List<OpenerChecklistItem> checklistItems = getOpenerChecklistItems();
        Set<String> fieldNames = new Set<String>{
            'Id',
            'Name',
            'Status__c',
            'Closing_Date__c',
            'TRID_Date__c',
            'Disclosures_Out_Date__c',
            'Disclosures_Received_Date__c',
            'Loan_Amount_1st__c',
            'Loan_Purpose__c',
            'Lender_lookup__c',
            'Borrower_Name__c',
            'Ease_Link__c',
            'Loan_Officer__c'
        };
        for (OpenerChecklistItem checklistItem : checklistItems) {
            fieldNames.add(checklistItem.fieldName);
            if (String.isNotBlank(checklistItem.validationField)) {
                fieldNames.add(checklistItem.validationField);
            }
        }

        Map<String, Schema.SObjectField> transactionFields = Schema.SObjectType.Transaction__c.fields.getMap();
        List<String> selectFields = new List<String>{
            'Borrower_Name__r.Corrected_Mobile__pc',
            'Borrower_Name__r.Corrected_Phone__pc',
            'Borrower_Name__r.PersonEmail',
            'Borrower_Name__r.PersonMobilePhone',
            'Borrower_Name__r.Phone',
            'Lender_lookup__r.Name',
            'Loan_Officer__r.Name',
            'Owner.Name'
        };
        for (String fieldName : fieldNames) {
            if (transactionFields.containsKey(fieldName)) {
                selectFields.add(fieldName);
            }
        }
        selectFields.sort();

        String escapedStatus = String.escapeSingleQuotes(statusValue);
        String query = 'SELECT ' + String.join(selectFields, ', ')
            + ' FROM Transaction__c'
            + ' WHERE Status__c = \'' + escapedStatus + '\''
            + ' ORDER BY LastModifiedDate DESC'
            + ' LIMIT 100';

        for (Transaction__c transactionRecord : Database.query(query)) {
            PipelineRow row = new PipelineRow(transactionRecord, transactionRecord.Closing_Date__c, null, 'Opener Checklist');
            if (statusValue == 'Open') {
                row.status = 'Submission Form Complete';
            }
            row.detail = buildOpenerChecklistDetail(transactionRecord, checklistItems);
            rows.add(row);
        }
        return rows;
    }

    private static List<PipelineRow> buildOpenerAppraisalsOutstandingTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Status__c,
                Appraisal_1_Ordered_Date__c,
                Appraisal_Ordered_Date_ValueLink__c,
                Appraisal_1_Received_Date__c,
                Appraisal_Back__c,
                Appraisal_Order__c,
                Appraisal_Order__r.Appraisal_Status__c,
                Appraisal_Order__r.EstimatedCompletionDate__c,
                Appraisal_Order__r.Is_Complete__c,
                Appraisal_Order__r.Order_Number__c,
                Lender_lookup__r.Name,
                Loan_Officer__r.Name,
                Processor__r.Name,
                Owner.Name
            FROM Transaction__c
            WHERE CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            AND (
                Appraisal_1_Ordered_Date__c != NULL
                OR Appraisal_Ordered_Date_ValueLink__c != NULL
                OR Appraisal_Order__c != NULL
            )
            AND Status__c NOT IN ('Cancelled', 'Post-Closed')
            AND Appraisal_1_Received_Date__c = NULL
            AND (Appraisal_Back__c = FALSE OR Appraisal_Back__c = NULL)
            AND (
                Appraisal_Order__c = NULL
                OR (
                    Appraisal_Order__r.Is_Complete__c = FALSE
                    AND Appraisal_Order__r.Appraisal_Status__c != 'Cancelled'
                )
            )
            ORDER BY Appraisal_1_Ordered_Date__c ASC NULLS LAST,
                Appraisal_Ordered_Date_ValueLink__c ASC NULLS LAST,
                LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(buildOpenerAppraisalOutstandingRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildBrokerChecksOutstandingTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date postClosedThreshold = Date.newInstance(2024, 5, 15);
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Status__c,
                Funding_Date__c,
                Broker_Compensation__c,
                Broker_Check_Recieved__c
            FROM Transaction__c
            WHERE Channel__c = 'Broker'
            AND RecordType.DeveloperName = 'Brokered'
            AND Broker_Check_Recieved__c = FALSE
            AND Status__c IN ('Post-Closed', 'PC Review')
            AND (Post_Closed_Date__c > :postClosedThreshold OR Post_Closed_Date__c = NULL)
            ORDER BY Funding_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(buildBrokerChecksOutstandingRow(transactionRecord));
        }
        return rows;
    }

    private static List<OpenerChecklistItem> getOpenerChecklistItems() {
        List<OpenerChecklistItem> checklistItems = new List<OpenerChecklistItem>();
        Map<String, Schema.SObjectField> transactionFields = Schema.SObjectType.Transaction__c.fields.getMap();
        for (ChecklistItem__mdt itemRecord : [
            SELECT MasterLabel,
                FieldName__c,
                HasValidation__c,
                ValidationField__c,
                ValidationType__c,
                ValidationValue__c,
                Order__c,
                Custom_Label__c
            FROM ChecklistItem__mdt
            WHERE Checklist__r.DeveloperName = 'Opener_Checklist'
            ORDER BY Order__c ASC NULLS LAST
        ]) {
            if (String.isBlank(itemRecord.FieldName__c) || !transactionFields.containsKey(itemRecord.FieldName__c)) {
                continue;
            }
            if (
                itemRecord.HasValidation__c
                && String.isNotBlank(itemRecord.ValidationField__c)
                && !transactionFields.containsKey(itemRecord.ValidationField__c)
            ) {
                continue;
            }
            checklistItems.add(new OpenerChecklistItem(itemRecord));
        }
        return checklistItems;
    }

    private static String buildOpenerChecklistDetail(Transaction__c transactionRecord, List<OpenerChecklistItem> checklistItems) {
        List<String> openItems = new List<String>();
        Integer requiredCount = 0;
        for (OpenerChecklistItem checklistItem : checklistItems) {
            if (!isOpenerChecklistItemRequired(transactionRecord, checklistItem)) {
                continue;
            }
            requiredCount++;
            if (!isChecklistFieldComplete(transactionRecord.get(checklistItem.fieldName))) {
                openItems.add(checklistItem.label);
            }
        }

        if (requiredCount == 0 || openItems.isEmpty()) {
            return 'Checklist complete';
        }

        List<String> previewItems = new List<String>();
        Integer previewLimit = Math.min(3, openItems.size());
        for (Integer i = 0; i < previewLimit; i++) {
            previewItems.add(openItems[i]);
        }
        String detail = openItems.size() + ' open: ' + String.join(previewItems, ', ');
        if (openItems.size() > previewLimit) {
            detail += ' +' + (openItems.size() - previewLimit) + ' more';
        }
        return detail;
    }

    private static Boolean isOpenerChecklistItemRequired(Transaction__c transactionRecord, OpenerChecklistItem checklistItem) {
        if (!checklistItem.hasValidation || String.isBlank(checklistItem.validationField)) {
            return true;
        }
        Object validationValue = transactionRecord.get(checklistItem.validationField);
        String validationType = String.isBlank(checklistItem.validationType) ? '' : checklistItem.validationType;

        if (validationType == 'Is Not Null') {
            return isChecklistFieldComplete(validationValue);
        }
        if (validationType == 'Is Null') {
            return !isChecklistFieldComplete(validationValue);
        }
        if (validationType == 'Is Equal To Value') {
            return matchesChecklistValidationValue(validationValue, checklistItem.validationValue);
        }
        if (validationType == 'Is Equal To') {
            Object comparisonValue = String.isBlank(checklistItem.validationValue)
                ? null
                : transactionRecord.get(checklistItem.validationValue);
            return normalizeChecklistValue(validationValue) == normalizeChecklistValue(comparisonValue);
        }
        return true;
    }

    private static Boolean isChecklistFieldComplete(Object fieldValue) {
        if (fieldValue == null) {
            return false;
        }
        if (fieldValue instanceof Boolean) {
            return (Boolean) fieldValue;
        }
        if (fieldValue instanceof String) {
            return String.isNotBlank((String) fieldValue);
        }
        return true;
    }

    private static Boolean matchesChecklistValidationValue(Object fieldValue, String expectedValue) {
        String normalizedFieldValue = normalizeChecklistValue(fieldValue);
        if (String.isBlank(normalizedFieldValue) || String.isBlank(expectedValue)) {
            return false;
        }
        for (String candidateValue : expectedValue.split(';')) {
            if (normalizedFieldValue == candidateValue.trim().toLowerCase()) {
                return true;
            }
        }
        return false;
    }

    private static String normalizeChecklistValue(Object fieldValue) {
        return fieldValue == null ? '' : String.valueOf(fieldValue).trim().toLowerCase();
    }

    private static Object safeSObjectValue(SObject record, String fieldName) {
        try {
            return record.get(fieldName);
        } catch (SObjectException ex) {
            return null;
        }
    }

    private static SObject safeRelationshipValue(SObject record, String relationshipName) {
        try {
            return record.getSObject(relationshipName);
        } catch (SObjectException ex) {
            return null;
        }
    }

    private static List<PipelineRow> buildApproachingCommitments(Boolean adminPipeline) {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date startDate = Date.today();
        Date endDate = addBusinessDays(startDate, 3);

        if (adminPipeline || currentUserUsesProcessingTeamLeadScope()) {
            for (Transaction__c transactionRecord : [
                SELECT Id, Name, Status__c, Closing_Date__c, Loan_Commitment_Date__c, Loan_Amount_1st__c, Loan_Purpose__c,
                    Processor_Note__c, Processor_Note_For_Display__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c,
                    Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail,
                    Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND Status__c NOT IN :CLOSING_TRANSACTION_STATUSES
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
                AND Loan_Commitment_Date__c >= :startDate
                AND Loan_Commitment_Date__c <= :endDate
                ORDER BY Loan_Commitment_Date__c ASC NULLS LAST, LastModifiedDate DESC
            ]) {
                rows.add(new PipelineRow(
                    transactionRecord,
                    transactionRecord.Loan_Commitment_Date__c,
                    null,
                    transactionRecord.Processor_Note__c
                ));
            }
        } else {
            Id currentUserId = UserInfo.getUserId();
            for (Transaction__c transactionRecord : [
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Commitment_Date__c, Loan_Amount_1st__c, Loan_Purpose__c,
                Processor_Note__c, Processor_Note_For_Display__c, Ease_Link__c, Biz_Dev__c, Borrower_Name__c,
                Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc, Borrower_Name__r.PersonEmail,
                Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone, Lender_lookup__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND Status__c NOT IN :CLOSING_TRANSACTION_STATUSES
                AND Loan_Commitment_Date__c >= :startDate
                AND Loan_Commitment_Date__c <= :endDate
                AND (OwnerId = :currentUserId
                    OR Transaction_Owner__c = :currentUserId
                    OR Processor__c = :currentUserId
                    OR Additional_Processor__c = :currentUserId
                    OR Loan_Officer__c = :currentUserId
                    OR Loan_Partner__c = :currentUserId)
                ORDER BY Loan_Commitment_Date__c ASC NULLS LAST, LastModifiedDate DESC
                LIMIT 50
            ]) {
                rows.add(new PipelineRow(
                    transactionRecord,
                    transactionRecord.Loan_Commitment_Date__c,
                    null,
                    transactionRecord.Processor_Note__c
                ));
            }
        }
        return rows;
    }

    private static Date addBusinessDays(Date startDate, Integer businessDaysToAdd) {
        Date result = startDate;
        Integer daysAdded = 0;
        while (daysAdded < businessDaysToAdd) {
            result = result.addDays(1);
            Integer dayOfWeek = Integer.valueOf(DateTime.newInstance(result, Time.newInstance(0, 0, 0, 0)).format('u'));
            if (dayOfWeek <= 5) {
                daysAdded++;
            }
        }
        return result;
    }

    private static List<PipelineRow> buildAssignedLeads() {
        return buildAssignedLeads(getScopedLeadUserIds());
    }

    private static List<PipelineRow> buildAssignedLeads(Set<Id> leadScopeUserIds) {
        return buildAssignedLeads(leadScopeUserIds, 50);
    }

    private static List<PipelineRow> buildAssignedLeads(Set<Id> leadScopeUserIds, Integer rowLimit) {
        return buildAssignedLeads(leadScopeUserIds, rowLimit, MIN_LEAD_CREATED_DATE);
    }

    private static List<PipelineRow> buildAssignedLeads(Set<Id> leadScopeUserIds, Integer rowLimit, Date minimumCreatedDate) {
        List<PipelineRow> rows = new List<PipelineRow>();

        for (Lead leadRecord : [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND Status IN :ACTIVE_LEAD_STATUSES
            AND CreatedDate >= :minimumCreatedDate
            ORDER BY LastModifiedDate DESC
            LIMIT :rowLimit
        ]) {
            rows.add(new PipelineRow(leadRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildAssignedLeadsForBizDev(Set<Id> leadScopeUserIds, Integer rowLimit, Date minimumCreatedDate, String bizDevValue) {
        List<PipelineRow> rows = new List<PipelineRow>();
        if (String.isBlank(bizDevValue)) {
            return rows;
        }

        for (Lead leadRecord : [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND Status IN :ACTIVE_LEAD_STATUSES
            AND Biz_Dev__c = :bizDevValue
            AND CreatedDate >= :minimumCreatedDate
            ORDER BY LastModifiedDate DESC
            LIMIT :rowLimit
        ]) {
            rows.add(new PipelineRow(leadRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildLeadRowsByOwnerScope(
        Set<Id> ownerIds,
        Id ownerId,
        Id partnerId,
        Boolean requireLoanPartner,
        String rowType,
        Integer rowLimit
    ) {
        List<PipelineRow> rows = new List<PipelineRow>();
        Integer effectiveLimit = rowLimit == null ? 50 : rowLimit;
        String scopeClause = requireLoanPartner
            ? 'OwnerId = :ownerId AND Loan_Partner__c = :partnerId'
            : 'OwnerId IN :ownerIds';
        if ((requireLoanPartner && (ownerId == null || partnerId == null)) || (!requireLoanPartner && (ownerIds == null || ownerIds.isEmpty()))) {
            return rows;
        }

        Date minimumCreatedDate = MIN_LEAD_CREATED_DATE;
        Date staleDate = Date.today().addDays(-7);
        DateTime staleCreatedDateTime = System.now().addDays(-7);
        DateTime sixDaysAgo = System.now().addDays(-6);
        DateTime startOfToday = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

        String baseSelect = 'SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email, '
            + 'Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c, '
            + 'Pre_Approval_Date__c, Biz_Dev__c, '
            + 'Last_Call_Date__c, Last_Call_Attempt_RingCentral__c, Last_SMS_Attempt_RingCentral__c, '
            + 'Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name '
            + 'FROM Lead WHERE IsConverted = false '
            + 'AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES '
            + 'AND ' + scopeClause + ' ';

        String queryString;
        if (rowType == 'new') {
            queryString = baseSelect
                + 'AND Status = \'New\' '
                + 'AND CreatedDate >= :minimumCreatedDate '
                + 'ORDER BY CreatedDate DESC LIMIT 500';
            List<Lead> candidateLeads = Database.query(queryString);
            Set<Id> leadIdsWithFutureEvents = getLeadIdsWithFutureEvents(new Map<Id, Lead>(candidateLeads).keySet());
            for (Lead leadRecord : candidateLeads) {
                if (!leadIdsWithFutureEvents.contains(leadRecord.Id)) {
                    rows.add(new PipelineRow(leadRecord));
                }
                if (rows.size() == effectiveLimit) {
                    break;
                }
            }
            return rows;
        }

        if (rowType == 'stagnant') {
            queryString = baseSelect
                + 'AND Status NOT IN (\'Closed\', \'Closed - Converted\', \'Converted\', \'Dead\', \'Duplicate\', \'Lost\', \'Withdrawn\', '
                + '\'Submitted For Disclosures\', \'Submitted for Disclosures\', \'Nurtured\', \'Nurturing\', \'Pre-Approved\', \'Pre-Approval\', '
                + '\'Nurture-Preapproval\', \'Nurture - Preapproval\', \'Nurture-Pre-Approval\', \'30 Day + Follow Up\', \'Credit Repair\') '
                + 'AND CreatedDate >= :minimumCreatedDate '
                + 'AND CreatedDate <= :staleCreatedDateTime '
                + 'AND (LastActivityDate = null OR LastActivityDate <= :staleDate) '
                + 'ORDER BY LastActivityDate ASC NULLS FIRST, LastModifiedDate ASC LIMIT :effectiveLimit';
            for (Lead leadRecord : Database.query(queryString)) {
                rows.add(new PipelineRow(leadRecord, leadRecord.LastActivityDate, null));
            }
            return rows;
        }

        if (rowType == 'stagnantPreApproval') {
            queryString = baseSelect
                + 'AND Status = \'Pre-Approval\' '
                + 'AND CreatedDate >= :minimumCreatedDate '
                + 'AND (Last_Call_Attempt_RingCentral__c = NULL OR Last_Call_Attempt_RingCentral__c <= :sixDaysAgo) '
                + 'AND (Last_SMS_Attempt_RingCentral__c = NULL OR Last_SMS_Attempt_RingCentral__c <= :sixDaysAgo) '
                + 'ORDER BY LastActivityDate ASC NULLS FIRST, LastModifiedDate ASC LIMIT 100';
            List<Lead> candidateLeads = Database.query(queryString);
            Set<Id> recentlyEmailedLeadIds = leadIdsWithRecentEmail(new Map<Id, Lead>(candidateLeads).keySet(), sixDaysAgo);
            for (Lead leadRecord : candidateLeads) {
                if (!recentlyEmailedLeadIds.contains(leadRecord.Id)) {
                    rows.add(new PipelineRow(leadRecord, leadRecord.LastActivityDate, null, 'No RingCentral call, SMS, or email in 6+ days'));
                }
                if (rows.size() == effectiveLimit) {
                    break;
                }
            }
            return rows;
        }

        if (rowType == 'activePreApproval') {
            queryString = baseSelect
                + 'AND Status = \'Pre-Approval\' '
                + 'ORDER BY Pre_Approval_Date__c DESC NULLS LAST, LastModifiedDate DESC LIMIT :effectiveLimit';
            for (Lead leadRecord : Database.query(queryString)) {
                rows.add(new PipelineRow(leadRecord));
            }
            return rows;
        }

        if (rowType == 'attention') {
            queryString = baseSelect
                + 'AND Status IN :ATTENTION_LEAD_STATUSES '
                + 'AND (Appointment_Date_Time__c = null OR Appointment_Date_Time__c < :startOfToday) '
                + 'AND Biz_Dev__c IN :ATTENTION_BIZ_DEV_VALUES '
                + 'ORDER BY Appointment_Date_Time__c ASC NULLS FIRST, LastModifiedDate ASC LIMIT 100';
            List<Lead> candidateLeads = new List<Lead>();
            for (Lead leadRecord : Database.query(queryString)) {
                if (shouldIncludeAttentionLead(leadRecord)) {
                    candidateLeads.add(leadRecord);
                }
                if (candidateLeads.size() == effectiveLimit) {
                    break;
                }
            }
            Map<Id, Event> latestEventsByLeadId = getLatestEventsByLeadId(new Map<Id, Lead>(candidateLeads).keySet());
            for (Lead leadRecord : candidateLeads) {
                Event latestEvent = latestEventsByLeadId.get(leadRecord.Id);
                rows.add(new PipelineRow(
                    leadRecord,
                    latestEvent == null ? null : latestEvent.ActivityDate,
                    latestEvent == null ? null : latestEvent.ActivityDateTime == null ? latestEvent.StartDateTime : latestEvent.ActivityDateTime,
                    latestEvent == null ? null : latestEvent.Subject
                ));
            }
            return rows;
        }

        if (rowType == 'eventsToday') {
            queryString = baseSelect
                + 'ORDER BY LastModifiedDate DESC LIMIT 1000';
            Map<Id, Lead> leadsById = new Map<Id, Lead>((List<Lead>) Database.query(queryString));
            if (leadsById.isEmpty()) {
                return rows;
            }
            Set<Id> scopedLeadIds = leadsById.keySet();
            for (Event eventRecord : [
                SELECT Id, Subject, WhoId, ActivityDate, ActivityDateTime, StartDateTime
                FROM Event
                WHERE WhoId IN :scopedLeadIds
                AND ActivityDate = TODAY
                ORDER BY ActivityDateTime ASC NULLS LAST, StartDateTime ASC NULLS LAST
                LIMIT 500
            ]) {
                Lead leadRecord = leadsById.get(eventRecord.WhoId);
                if (leadRecord != null) {
                    rows.add(new PipelineRow(
                        leadRecord,
                        eventRecord.ActivityDate,
                        eventRecord.ActivityDateTime == null ? eventRecord.StartDateTime : eventRecord.ActivityDateTime,
                        eventRecord.Subject
                    ));
                }
                if (rows.size() == effectiveLimit) {
                    break;
                }
            }
            return rows;
        }

        if (rowType == 'preApprovalCallsToday') {
            Date preApprovalStartDate = Date.newInstance(2026, 1, 1);
            queryString = baseSelect
                + 'AND Status = \'Pre-Approval\' '
                + 'AND Pre_Approval_Date__c >= :preApprovalStartDate '
                + 'ORDER BY Pre_Approval_Date__c ASC NULLS LAST, LastActivityDate ASC NULLS FIRST LIMIT 500';
            List<Lead> candidateLeads = Database.query(queryString);
            Set<Id> candidateLeadIds = new Map<Id, Lead>(candidateLeads).keySet();
            Set<Id> leadIdsWithEventsToday = getLeadIdsWithEventsToday(candidateLeadIds);
            Set<Id> leadIdsWithFutureEventsAfterToday = getLeadIdsWithFutureEventsAfterToday(candidateLeadIds);
            for (Lead leadRecord : candidateLeads) {
                Boolean hasEventToday = leadIdsWithEventsToday.contains(leadRecord.Id);
                Boolean hasFutureEventAfterToday = leadIdsWithFutureEventsAfterToday.contains(leadRecord.Id);
                if (hasEventToday || !hasFutureEventAfterToday) {
                    rows.add(buildPreApprovalCallsTodayRow(leadRecord));
                }
                if (rows.size() == effectiveLimit) {
                    break;
                }
            }
            return rows;
        }

        queryString = baseSelect
            + 'AND Status IN :ACTIVE_LEAD_STATUSES '
            + 'AND CreatedDate >= :minimumCreatedDate '
            + 'ORDER BY LastModifiedDate DESC LIMIT :effectiveLimit';
        for (Lead leadRecord : Database.query(queryString)) {
            rows.add(new PipelineRow(leadRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildNewLeadAlerts() {
        return buildNewLeadAlerts(getScopedLeadUserIds());
    }

    private static List<PipelineRow> buildNewLeadAlerts(Set<Id> leadScopeUserIds) {
        return buildNewLeadAlerts(leadScopeUserIds, 50);
    }

    private static List<PipelineRow> buildNewLeadAlerts(Set<Id> leadScopeUserIds, Integer rowLimit) {
        Date minimumCreatedDate = currentUserIsAdamStephens()
            ? Date.newInstance(2026, 1, 1)
            : MIN_LEAD_CREATED_DATE;
        return buildNewLeadAlerts(leadScopeUserIds, rowLimit, minimumCreatedDate);
    }

    private static List<PipelineRow> buildNewLeadAlerts(Set<Id> leadScopeUserIds, Integer rowLimit, Date minimumCreatedDate) {
        List<PipelineRow> rows = new List<PipelineRow>();
        List<Lead> candidateLeads = [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND Status = 'New'
            AND CreatedDate >= :minimumCreatedDate
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
        Set<Id> leadIdsWithFutureEvents = getLeadIdsWithFutureEvents(new Map<Id, Lead>(candidateLeads).keySet());

        for (Lead leadRecord : candidateLeads) {
            if (leadIdsWithFutureEvents.contains(leadRecord.Id)) {
                continue;
            }
            rows.add(new PipelineRow(leadRecord));
            if (rows.size() == rowLimit) {
                break;
            }
        }
        return rows;
    }

    private static List<PipelineRow> buildNewLeadAlertsForBizDev(Set<Id> leadScopeUserIds, Integer rowLimit, Date minimumCreatedDate, String bizDevValue) {
        List<PipelineRow> rows = new List<PipelineRow>();
        if (String.isBlank(bizDevValue)) {
            return rows;
        }

        List<Lead> candidateLeads = [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND Status = 'New'
            AND Biz_Dev__c = :bizDevValue
            AND CreatedDate >= :minimumCreatedDate
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
        Set<Id> leadIdsWithFutureEvents = getLeadIdsWithFutureEvents(new Map<Id, Lead>(candidateLeads).keySet());

        for (Lead leadRecord : candidateLeads) {
            if (leadIdsWithFutureEvents.contains(leadRecord.Id)) {
                continue;
            }
            rows.add(new PipelineRow(leadRecord));
            if (rows.size() == rowLimit) {
                break;
            }
        }
        return rows;
    }

    private static Set<Id> getLeadIdsWithFutureEvents(Set<Id> leadIds) {
        Set<Id> leadIdsWithFutureEvents = new Set<Id>();
        if (leadIds == null || leadIds.isEmpty()) {
            return leadIdsWithFutureEvents;
        }
        Date today = Date.today();
        DateTime nowValue = System.now();
        for (Event eventRecord : [
            SELECT WhoId, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhoId IN :leadIds
            AND (
                ActivityDate > :today
                OR ActivityDateTime >= :nowValue
                OR StartDateTime >= :nowValue
            )
            LIMIT 500
        ]) {
            leadIdsWithFutureEvents.add(eventRecord.WhoId);
        }
        return leadIdsWithFutureEvents;
    }

    private static Set<Id> getLeadIdsWithEventsToday(Set<Id> leadIds) {
        Set<Id> leadIdsWithEventsToday = new Set<Id>();
        if (leadIds == null || leadIds.isEmpty()) {
            return leadIdsWithEventsToday;
        }
        for (Event eventRecord : [
            SELECT WhoId
            FROM Event
            WHERE WhoId IN :leadIds
            AND ActivityDate = TODAY
        ]) {
            leadIdsWithEventsToday.add(eventRecord.WhoId);
        }
        return leadIdsWithEventsToday;
    }

    private static Set<Id> getLeadIdsWithFutureEventsAfterToday(Set<Id> leadIds) {
        Set<Id> leadIdsWithFutureEvents = new Set<Id>();
        if (leadIds == null || leadIds.isEmpty()) {
            return leadIdsWithFutureEvents;
        }
        Date today = Date.today();
        DateTime tomorrowStart = DateTime.newInstance(today.addDays(1), Time.newInstance(0, 0, 0, 0));
        for (Event eventRecord : [
            SELECT WhoId
            FROM Event
            WHERE WhoId IN :leadIds
            AND (
                ActivityDate > :today
                OR ActivityDateTime >= :tomorrowStart
                OR StartDateTime >= :tomorrowStart
            )
        ]) {
            leadIdsWithFutureEvents.add(eventRecord.WhoId);
        }
        return leadIdsWithFutureEvents;
    }

    private static Boolean currentUserIsAdamStephens() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();
        return username == 'astephens@reachhomeloans.com'
            || name == 'adam stephens';
    }

    private static Boolean currentUserUsesProcessingTeamLeadScope() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();
        return PROCESSING_TEAM_LEAD_USERNAMES.contains(username)
            || name == 'angelina noble';
    }

    private static Boolean currentUserUsesMeganPartnerView() {
        User currentUser = [
            SELECT Name, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String username = String.isBlank(currentUser.Username) ? '' : currentUser.Username.toLowerCase();
        String name = String.isBlank(currentUser.Name) ? '' : currentUser.Name.toLowerCase();
        return MEGAN_PARTNER_VIEW_USERNAMES.contains(username)
            || name == 'megan straight';
    }

    private static User getActiveUserByUsername(String username) {
        if (String.isBlank(username)) {
            return null;
        }
        List<User> users = [
            SELECT Id, Name, Username
            FROM User
            WHERE IsActive = true
            AND Username = :username
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    private static List<PipelineTab> buildPipelineTabs(
        List<PipelineRow> primaryRows,
        String primaryTitle,
        String primarySubtitle,
        String primaryObjectApiName,
        Boolean adminPipeline,
        Boolean includeConversionMetrics
    ) {
        if (primaryObjectApiName == 'Lead') {
            List<TableColumn> leadColumns = buildLoanOfficerLeadColumns();
            List<TableColumn> preApprovalLeadColumns = buildPreApprovalLeadColumns();
            List<TableColumn> transactionColumns = buildLoanOfficerTransactionColumns();
            return new List<PipelineTab>{
            new PipelineTab('assigned', primaryTitle, primarySubtitle, primaryObjectApiName, applyLoanOfficerLeadCells(primaryRows), leadColumns),
            new PipelineTab(
                'newLeadAlerts',
                'New Leads Alert',
                'Assigned leads currently in New status.',
                'Lead',
                applyLoanOfficerLeadCells(buildNewLeadAlerts()),
                leadColumns
            ),
            new PipelineTab(
                'stagnant',
                'Stagnant Leads',
                'Assigned open leads with no activity in the last 7 days.',
                'Lead',
                applyLoanOfficerLeadCells(buildStagnantLeads()),
                leadColumns
            ),
            new PipelineTab(
                'activePreApprovals',
                'Active Pre-Approvals',
                'Assigned leads currently in Pre-Approval status.',
                'Lead',
                applyPreApprovalLeadCells(buildLeadRowsByOwnerScope(getScopedLeadUserIds(), null, null, false, 'activePreApproval', 100)),
                preApprovalLeadColumns
            ),
            new PipelineTab(
                'stagnantPreApprovals',
                'Stagnant Pre-Approvals',
                'Assigned pre-approved leads without RingCentral call, SMS, or email activity for 6+ days.',
                'Lead',
                applyPreApprovalLeadCells(buildStagnantPreApprovals()),
                preApprovalLeadColumns
            ),
            new PipelineTab(
                'preApprovalCallsToday',
                'Pre-Approval Calls Today',
                'Pre-approved leads with an event today or no future event scheduled.',
                'Lead',
                buildLeadRowsByOwnerScope(getScopedLeadUserIds(), null, null, false, 'preApprovalCallsToday', 100),
                buildPreApprovalCallsTodayColumns()
            ),
            new PipelineTab(
                'attention',
                'Leads Needing Attention',
                'Assigned purchase leads matching the Lead Appointment Report attention criteria.',
                'Lead',
                applyLoanOfficerLeadCells(buildLeadsNeedingAttention()),
                leadColumns
            ),
            new PipelineTab(
                'eventsToday',
                'Leads with Events Today',
                'Assigned leads with calendar events scheduled today.',
                'Lead',
                applyLoanOfficerLeadCells(buildLeadsWithEventsToday()),
                leadColumns
            ),
            new PipelineTab(
                'disclosuresNeedingSigned',
                'Disclosures Needing Signed',
                'Transactions in Disclosures Out status where disclosures have not been received.',
                'Transaction__c',
                applyLoanOfficerTransactionCells(buildLoanOfficerDisclosuresNeedingSigned()),
                transactionColumns
            ),
            new PipelineTab(
                'loanOfficerActiveTransactions',
                'My Active Transactions',
                'Transactions assigned to you that are still in active statuses.',
                'Transaction__c',
                applyLoanOfficerTransactionCells(buildLoanOfficerActiveTransactions()),
                transactionColumns
            ),
            new PipelineTab(
                'loanOfficerClosedThisMonth',
                'Transactions Closed this Month',
                'Funded, review, and post-closed files with a funding date in the current month.',
                'Transaction__c',
                applyLoanOfficerTransactionCells(buildLoanOfficerClosedThisMonth()),
                transactionColumns
            )
            };
        }

        List<PipelineTab> tabs = new List<PipelineTab>();
        if (currentUserUsesProcessingTeamLeadScope() && !adminPipeline) {
            tabs.add(new PipelineTab(
                'assigned',
                'Active Pipeline',
                'All active files created since 2024 for Processing Team Lead review.',
                primaryObjectApiName,
                buildAdminTransactions()
            ));
            tabs.add(new PipelineTab(
                'myActivePipeline',
                'My Active Pipeline',
                'Active files where you are assigned on the transaction.',
                primaryObjectApiName,
                primaryRows
            ));
            tabs.add(new PipelineTab(
                'goldStarTransactions',
                'Gold Star Transactions',
                'All active transactions where Gold Star is the lender.',
                'Transaction__c',
                buildGoldStarTransactions(),
                buildGoldStarTransactionColumns()
            ));
        } else {
            tabs.add(new PipelineTab('assigned', primaryTitle, primarySubtitle, primaryObjectApiName, primaryRows));
        }
        if (includeConversionMetrics) {
            tabs.add(new PipelineTab(
                'executiveConversionMetrics',
                'Conversion Metrics',
                'Year-to-date Loan Officer conversion ratios with report drilldowns.',
                'Metric',
                buildConversionMetricRows(),
                true
            ));
        }
        if (currentUserUsesManagementCommandCenterHeader()) {
            tabs.addAll(buildAllLoanOfficerLeadMonitorTabs());
        }
        if (currentUserUsesManagementAlertTabs()) {
            tabs.add(new PipelineTab(
                'newFilesNotSubmitted24',
                'New Files Not Submitted 24 hrs',
                'Files in Processing for more than 24 hours based on the processing status timestamp.',
                'Transaction__c',
                buildNewFilesNotSubmitted24()
            ));
            tabs.add(new PipelineTab(
                'claFilesNotContacted24',
                'CLA Files Not Contacted 24 hrs',
                'Conditionally Approved files for more than 24 hours without processor RingCentral SMS or phone contact.',
                'Transaction__c',
                buildClaFilesNotContacted24()
            ));
        }
        tabs.add(new PipelineTab(
            'filesInClosing',
            'Files in Closing',
            (adminPipeline || currentUserUsesProcessingTeamLeadScope()) ? 'All files in Closing and Funding status created since 2024.' : 'Assigned files in Closing and Funding status.',
            'Transaction__c',
            (adminPipeline || currentUserUsesProcessingTeamLeadScope()) ? buildAllFilesInClosing() : buildFilesInClosing()
        ));
        tabs.add(new PipelineTab(
            'approachingCommitments',
            'Approaching Commitments',
            adminPipeline ? 'All active files with commitment dates within the next 3 business days.' : 'Assigned active files with commitment dates within the next 3 business days.',
            'Transaction__c',
            buildApproachingCommitments(adminPipeline)
        ));
        if (currentUserUsesManagementCommandCenterHeader()) {
            tabs.add(new PipelineTab(
                'locksExpiring',
                'Locks Expiring within a Week',
                'Active files with rate locks expiring within the next 7 calendar days. Locks expiring today appear first and highlighted.',
                'Transaction__c',
                buildLocksExpiringTransactions(),
                buildLocksExpiringColumns()
            ));
            tabs.add(new PipelineTab(
                'openCocRequests',
                'Open COC Requests',
                'Transactions tied to open Change of Circumstance request cases.',
                'Transaction__c',
                buildOpenCocRequestTransactions()
            ));
        }
        if (!currentUserUsesManagementCommandCenterHeader()) {
            tabs.add(new PipelineTab(
                'transactionEventsToday',
                'Transactions with Events Today',
                'Assigned transactions with calendar events scheduled today.',
                'Transaction__c',
                buildTransactionsWithEventsToday()
            ));
            tabs.add(new PipelineTab(
                'pendingReview',
                'Docs/Comments Pending Review',
                'Assigned condition documents and borrower comments waiting for review.',
                'Transaction__c',
                buildDocsCommentsPendingReview()
            ));
        }
        return tabs;
    }

    private static List<PipelineTab> buildAllLoanOfficerLeadMonitorTabs() {
        Set<Id> allLoanOfficerIds = getAllActiveLoanOfficerUserIds();
        Integer managementLeadRowLimit = 250;
        Date managementLeadCreatedCutoff = Date.newInstance(Date.today().year(), 1, 1);
        return new List<PipelineTab>{
            new PipelineTab(
                'allLoanOfficerActiveLeads',
                'All LO Active Leads',
                'Current-year active leads across all active Loan Officers in contact, application, document, and contract statuses.',
                'Lead',
                buildAssignedLeadsForBizDev(allLoanOfficerIds, managementLeadRowLimit, managementLeadCreatedCutoff, MANAGEMENT_LEAD_BIZ_DEV_VALUE)
            ),
            new PipelineTab(
                'allLoanOfficerNewLeadAlerts',
                'New Leads Needing Contact',
                'Current-year New status leads across all active Loan Officers.',
                'Lead',
                buildNewLeadAlertsForBizDev(allLoanOfficerIds, managementLeadRowLimit, managementLeadCreatedCutoff, MANAGEMENT_LEAD_BIZ_DEV_VALUE)
            ),
            new PipelineTab(
                'allLoanOfficerAttentionLeads',
                'Leads Needing Attention',
                'Purchase leads across all active Loan Officers matching the Lead Appointment Report attention criteria.',
                'Lead',
                buildLeadsNeedingAttentionForBizDev(allLoanOfficerIds, managementLeadRowLimit, MANAGEMENT_LEAD_BIZ_DEV_VALUE)
            ),
            new PipelineTab(
                'allLoanOfficerStagnantLeads',
                'Stagnant Leads',
                'Current-year open leads across all active Loan Officers with no activity in the last 7 days.',
                'Lead',
                buildStagnantLeadsForBizDev(allLoanOfficerIds, managementLeadRowLimit, managementLeadCreatedCutoff, MANAGEMENT_LEAD_BIZ_DEV_VALUE)
            )
        };
    }

    private static List<PipelineRow> buildNewFilesNotSubmitted24() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date cutoffDate = Date.today().addDays(-1);
        List<Transaction__c> candidateTransactions = [
            SELECT Id, Name, Status__c, Closing_Date__c, Submitted_to_Processing_Date__c,
                Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Ease_Link__c, Biz_Dev__c, Borrower_Name__c, Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail, Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone,
                Lender_lookup__r.Name, Loan_Partner__r.Name, Processor__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c = 'Processing'
            AND Submitted_to_Processing_Date__c != null
            AND Submitted_to_Processing_Date__c <= :cutoffDate
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ORDER BY Submitted_to_Processing_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ];
        Map<Id, DateTime> statusTimesByTransactionId = latestStatusChangeTimes(candidateTransactions, 'Processing');
        DateTime cutoffDateTime = System.now().addHours(-24);
        for (Transaction__c transactionRecord : candidateTransactions) {
            Date processingDate = transactionRecord.Submitted_to_Processing_Date__c;
            DateTime processingStart = statusTimesByTransactionId.get(transactionRecord.Id);
            if (processingStart == null && processingDate != null) {
                processingStart = DateTime.newInstance(processingDate, Time.newInstance(0, 0, 0, 0));
            }
            if (processingStart == null || processingStart > cutoffDateTime) {
                continue;
            }
            rows.add(new PipelineRow(
                transactionRecord,
                processingDate,
                processingStart,
                transactionRecord.Processor_Note__c
            ));
        }
        return rows;
    }

    private static List<PipelineRow> buildClaFilesNotContacted24() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date cutoffDate = Date.today().addDays(-1);
        List<Transaction__c> candidateTransactions = [
            SELECT Id, Name, Status__c, Closing_Date__c, Conditionally_Approved_Date__c,
                Last_Processor_RC_SMS__c, Last_Processor_RC_Call__c,
                Loan_Amount_1st__c, Loan_Purpose__c, Processor_Note__c, Processor_Note_For_Display__c,
                Ease_Link__c, Lender_lookup__r.Name, Processor__c, Processor__r.Name, Processor__r.Email,
                Borrower_Name__r.Corrected_Mobile__pc, Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail, Borrower_Name__r.PersonMobilePhone, Borrower_Name__r.Phone,
                Account__c, Borrower_Name__c, Owner.Name
            FROM Transaction__c
            WHERE Status__c = 'Conditionally Approved'
            AND Conditionally_Approved_Date__c != null
            AND Conditionally_Approved_Date__c <= :cutoffDate
            AND (Loan_Officer__c = null OR Loan_Officer__r.Name != 'Harold Ellis')
            AND Id NOT IN :CLA_NOT_CONTACTED_MANUAL_EXCLUDED_TRANSACTION_IDS
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ORDER BY Conditionally_Approved_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ];
        Map<Id, DateTime> statusTimesByTransactionId = earliestStatusChangeTimes(candidateTransactions, 'Conditionally Approved');
        Set<Id> transactionsWithProcessorEmail = transactionsWithProcessorEmailSince(candidateTransactions, statusTimesByTransactionId);
        Set<Id> transactionsWithProcessorTaskContact = transactionsWithProcessorTaskContactSince(candidateTransactions, statusTimesByTransactionId);
        for (Transaction__c transactionRecord : candidateTransactions) {
            Date claDate = transactionRecord.Conditionally_Approved_Date__c;
            DateTime claStart = conditionApprovalStart(transactionRecord, statusTimesByTransactionId);
            DateTime claContactDue = addBusinessHours(claStart, 24);
            if (claContactDue == null || claContactDue > System.now()) {
                continue;
            }
            if (hasProcessorContactSince(transactionRecord, claStart)
                || transactionsWithProcessorEmail.contains(transactionRecord.Id)
                || transactionsWithProcessorTaskContact.contains(transactionRecord.Id)) {
                continue;
            }
            rows.add(new PipelineRow(
                transactionRecord,
                claDate,
                claStart,
                transactionRecord.Processor_Note__c
            ));
        }
        return rows;
    }

    private static DateTime conditionApprovalStart(
        Transaction__c transactionRecord,
        Map<Id, DateTime> statusTimesByTransactionId
    ) {
        if (transactionRecord == null) {
            return null;
        }
        DateTime historyStart = statusTimesByTransactionId == null
            ? null
            : statusTimesByTransactionId.get(transactionRecord.Id);
        Date claDate = transactionRecord.Conditionally_Approved_Date__c;
        DateTime dateStart = claDate == null
            ? null
            : DateTime.newInstance(claDate, Time.newInstance(0, 0, 0, 0));
        if (historyStart == null) {
            return dateStart;
        }
        if (dateStart == null) {
            return historyStart;
        }
        return dateStart < historyStart ? dateStart : historyStart;
    }

    private static Map<Id, DateTime> latestStatusChangeTimes(List<Transaction__c> candidateTransactions, String targetStatus) {
        Map<Id, DateTime> timesByTransactionId = new Map<Id, DateTime>();
        Set<Id> transactionIds = new Set<Id>();
        for (Transaction__c transactionRecord : candidateTransactions) {
            transactionIds.add(transactionRecord.Id);
        }
        if (transactionIds.isEmpty()) {
            return timesByTransactionId;
        }

        for (Transaction__History historyRecord : [
            SELECT ParentId, NewValue, CreatedDate
            FROM Transaction__History
            WHERE ParentId IN :transactionIds
            AND Field = 'Status__c'
            ORDER BY CreatedDate DESC
        ]) {
            if (!timesByTransactionId.containsKey(historyRecord.ParentId)
                && String.valueOf(historyRecord.NewValue) == targetStatus) {
                timesByTransactionId.put(historyRecord.ParentId, historyRecord.CreatedDate);
            }
        }
        return timesByTransactionId;
    }

    private static Map<Id, DateTime> earliestStatusChangeTimes(List<Transaction__c> candidateTransactions, String targetStatus) {
        Map<Id, DateTime> timesByTransactionId = new Map<Id, DateTime>();
        Set<Id> transactionIds = new Set<Id>();
        for (Transaction__c transactionRecord : candidateTransactions) {
            transactionIds.add(transactionRecord.Id);
        }
        if (transactionIds.isEmpty()) {
            return timesByTransactionId;
        }

        for (Transaction__History historyRecord : [
            SELECT ParentId, NewValue, CreatedDate
            FROM Transaction__History
            WHERE ParentId IN :transactionIds
            AND Field = 'Status__c'
            ORDER BY CreatedDate ASC
        ]) {
            if (!timesByTransactionId.containsKey(historyRecord.ParentId)
                && String.valueOf(historyRecord.NewValue) == targetStatus) {
                timesByTransactionId.put(historyRecord.ParentId, historyRecord.CreatedDate);
            }
        }
        return timesByTransactionId;
    }

    private static DateTime addBusinessHours(DateTime startDateTime, Integer businessHoursToAdd) {
        if (startDateTime == null) {
            return null;
        }
        Id businessHoursId = getDefaultBusinessHoursId();
        if (businessHoursId == null) {
            return startDateTime.addHours(businessHoursToAdd);
        }

        Long millisecondsToAdd = Long.valueOf(String.valueOf(businessHoursToAdd)) * 60 * 60 * 1000;
        return BusinessHours.add(businessHoursId, startDateTime, millisecondsToAdd);
    }

    private static Id getDefaultBusinessHoursId() {
        if (defaultBusinessHoursId != null) {
            return defaultBusinessHoursId;
        }

        List<BusinessHours> businessHoursRecords = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];
        if (!businessHoursRecords.isEmpty()) {
            defaultBusinessHoursId = businessHoursRecords[0].Id;
        }
        return defaultBusinessHoursId;
    }

    private static Set<Id> transactionsWithProcessorEmailSince(
        List<Transaction__c> candidateTransactions,
        Map<Id, DateTime> statusTimesByTransactionId
    ) {
        Set<Id> transactionIds = new Set<Id>();
        Set<Id> processorIds = new Set<Id>();
        Set<String> processorEmails = new Set<String>();
        Map<Id, String> processorEmailByTransactionId = new Map<Id, String>();
        DateTime earliestClaStart;

        for (Transaction__c transactionRecord : candidateTransactions) {
            DateTime claStart = conditionApprovalStart(transactionRecord, statusTimesByTransactionId);
            if (claStart == null) {
                continue;
            }

            transactionIds.add(transactionRecord.Id);
            if (earliestClaStart == null || claStart < earliestClaStart) {
                earliestClaStart = claStart;
            }
            if (transactionRecord.Processor__c != null) {
                processorIds.add(transactionRecord.Processor__c);
            }

            SObject processorRecord = safeRelationshipValue(transactionRecord, 'Processor__r');
            String processorEmail = normalizeEmail((String) safeSObjectValue(processorRecord, 'Email'));
            if (!String.isBlank(processorEmail)) {
                processorEmails.add(processorEmail);
                processorEmailByTransactionId.put(transactionRecord.Id, processorEmail);
            }
        }

        Set<Id> transactionIdsWithEmail = new Set<Id>();
        if (transactionIds.isEmpty() || earliestClaStart == null) {
            return transactionIdsWithEmail;
        }

        for (EmailMessage emailRecord : [
            SELECT RelatedToId, FromAddress, CreatedById, MessageDate
            FROM EmailMessage
            WHERE RelatedToId IN :transactionIds
            AND Incoming = false
            AND MessageDate >= :earliestClaStart
            ORDER BY MessageDate DESC
        ]) {
            DateTime claStart = statusTimesByTransactionId.get(emailRecord.RelatedToId);
            if (claStart == null || emailRecord.MessageDate == null || emailRecord.MessageDate < claStart) {
                continue;
            }

            String expectedProcessorEmail = processorEmailByTransactionId.get(emailRecord.RelatedToId);
            String fromAddress = normalizeEmail(emailRecord.FromAddress);
            if (processorIds.contains(emailRecord.CreatedById)
                || (!String.isBlank(expectedProcessorEmail) && fromAddress == expectedProcessorEmail)
                || (!String.isBlank(fromAddress) && processorEmails.contains(fromAddress))) {
                transactionIdsWithEmail.add(emailRecord.RelatedToId);
            }
        }
        return transactionIdsWithEmail;
    }

    private static Set<Id> transactionsWithProcessorTaskContactSince(
        List<Transaction__c> candidateTransactions,
        Map<Id, DateTime> statusTimesByTransactionId
    ) {
        Map<Id, DateTime> statusStartByTransactionId = new Map<Id, DateTime>();
        Map<Id, Set<Id>> transactionIdsByRelatedRecordId = new Map<Id, Set<Id>>();
        Set<Id> processorIds = new Set<Id>();
        DateTime earliestClaStart;

        for (Transaction__c transactionRecord : candidateTransactions) {
            DateTime claStart = conditionApprovalStart(transactionRecord, statusTimesByTransactionId);
            if (claStart == null) {
                continue;
            }
            if (earliestClaStart == null || claStart < earliestClaStart) {
                earliestClaStart = claStart;
            }
            if (transactionRecord.Processor__c != null) {
                processorIds.add(transactionRecord.Processor__c);
            }
            statusStartByTransactionId.put(transactionRecord.Id, claStart);
            addTaskContactRelatedRecord(transactionRecord.Id, transactionRecord.Id, transactionIdsByRelatedRecordId);
            addTaskContactRelatedRecord((Id) safeSObjectValue(transactionRecord, 'Account__c'), transactionRecord.Id, transactionIdsByRelatedRecordId);
            addTaskContactRelatedRecord((Id) safeSObjectValue(transactionRecord, 'Borrower_Name__c'), transactionRecord.Id, transactionIdsByRelatedRecordId);
        }

        Set<Id> contactedTransactionIds = new Set<Id>();
        if (transactionIdsByRelatedRecordId.isEmpty() || processorIds.isEmpty() || earliestClaStart == null) {
            return contactedTransactionIds;
        }

        for (Task taskRecord : [
            SELECT WhatId, OwnerId, CreatedDate, Subject, Description
            FROM Task
            WHERE WhatId IN :transactionIdsByRelatedRecordId.keySet()
            AND OwnerId IN :processorIds
            AND CreatedDate >= :earliestClaStart
            ORDER BY CreatedDate DESC
        ]) {
            if (!isProcessorContactTask(taskRecord)) {
                continue;
            }
            for (Id transactionId : transactionIdsByRelatedRecordId.get(taskRecord.WhatId)) {
                DateTime statusStart = statusStartByTransactionId.get(transactionId);
                if (statusStart != null && taskRecord.CreatedDate >= statusStart) {
                    contactedTransactionIds.add(transactionId);
                }
            }
        }
        return contactedTransactionIds;
    }

    private static void addTaskContactRelatedRecord(
        Id relatedRecordId,
        Id transactionId,
        Map<Id, Set<Id>> transactionIdsByRelatedRecordId
    ) {
        if (relatedRecordId == null || transactionId == null) {
            return;
        }
        if (!transactionIdsByRelatedRecordId.containsKey(relatedRecordId)) {
            transactionIdsByRelatedRecordId.put(relatedRecordId, new Set<Id>());
        }
        transactionIdsByRelatedRecordId.get(relatedRecordId).add(transactionId);
    }

    private static Boolean isProcessorContactTask(Task taskRecord) {
        String subject = normalizeChecklistValue(taskRecord.Subject);
        String description = normalizeChecklistValue(taskRecord.Description);
        return subject.contains('call')
            || subject.contains('called')
            || subject.contains('sms')
            || subject.contains('text')
            || description.contains('ringcentral')
            || description.contains('ace call details link')
            || description.contains('direction:');
    }

    private static String normalizeEmail(String emailAddress) {
        if (String.isBlank(emailAddress)) {
            return null;
        }
        String normalized = emailAddress.trim().toLowerCase();
        Integer leftBracketIndex = normalized.indexOf('<');
        Integer rightBracketIndex = normalized.indexOf('>');
        if (leftBracketIndex >= 0 && rightBracketIndex > leftBracketIndex) {
            normalized = normalized.substring(leftBracketIndex + 1, rightBracketIndex).trim();
        }
        return normalized;
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null) {
            return null;
        }
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String composePropertyAddress(String street, String city, String state) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(street)) {
            parts.add(street.trim());
        }
        String cityState = '';
        if (String.isNotBlank(city)) {
            cityState = city.trim();
        }
        if (String.isNotBlank(state)) {
            cityState = String.isBlank(cityState) ? state.trim() : cityState + ', ' + state.trim();
        }
        if (String.isNotBlank(cityState)) {
            parts.add(cityState);
        }
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    private static String phoneUrl(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        String dialable = phone.replaceAll('[^0-9+]', '');
        return String.isBlank(dialable) ? null : 'tel:' + dialable;
    }

    private static String buildAddress(List<String> parts) {
        List<String> cleanedParts = new List<String>();
        if (parts != null) {
            for (String part : parts) {
                if (String.isNotBlank(part)) {
                    cleanedParts.add(part.trim());
                }
            }
        }
        return String.join(cleanedParts, ', ');
    }

    private static String buildCityStateZip(String city, String state, String postalCode) {
        List<String> statePostalParts = new List<String>();
        if (String.isNotBlank(state)) {
            statePostalParts.add(state.trim());
        }
        if (String.isNotBlank(postalCode)) {
            statePostalParts.add(postalCode.trim());
        }
        String statePostal = String.join(statePostalParts, ' ');
        return buildAddress(new List<String>{ city, statePostal });
    }

    private static Boolean hasProcessorContactSince(Transaction__c transactionRecord, DateTime statusStart) {
        if (statusStart == null) {
            return false;
        }
        return (transactionRecord.Last_Processor_RC_SMS__c != null && transactionRecord.Last_Processor_RC_SMS__c >= statusStart)
            || (transactionRecord.Last_Processor_RC_Call__c != null && transactionRecord.Last_Processor_RC_Call__c >= statusStart);
    }

    private static List<PipelineTab> buildExecutivePipelineTabs(List<PipelineRow> activeTransactionRows) {
        return new List<PipelineTab>{
            new PipelineTab(
                'executiveConversionMetrics',
                'YTD Conversion Metrics',
                'Year-to-date Loan Officer conversion ratios with report drilldowns.',
                'Metric',
                buildConversionMetricRows(),
                true
            ),
            new PipelineTab(
                'executiveAssignedLeads',
                'Active Leads',
                'Assigned active leads in contact, application, document, and contract statuses.',
                'Lead',
                buildAssignedLeads()
            ),
            new PipelineTab(
                'executiveNewLeadAlerts',
                'New Leads Alert',
                'Assigned leads currently in New status.',
                'Lead',
                buildNewLeadAlerts()
            ),
            new PipelineTab(
                'executiveLeadsWithEventsToday',
                'Leads with Events Today',
                'Assigned leads with calendar events scheduled today.',
                'Lead',
                buildLeadsWithEventsToday()
            ),
            new PipelineTab(
                'executiveActivePipeline',
                'Active Transactions',
                'Active transactions not in Closing or Funding status.',
                'Transaction__c',
                activeTransactionRows
            ),
            new PipelineTab(
                'executiveFilesInClosing',
                'Transactions in Closing',
                'Transactions in Closing or Funding status.',
                'Transaction__c',
                buildAllFilesInClosing()
            )
        };
    }

    private static List<PipelineTab> buildLoanOfficerAssistantPipelineTabs() {
        Map<String, User> assistedUsersByUsername = getAssistedLoanOfficersByUsername();
        Id currentUserId = UserInfo.getUserId();
        List<PipelineTab> tabs = new List<PipelineTab>();
        tabs.addAll(buildAssistedLoanOfficerTabs(assistedUsersByUsername.get('jolmsted@reachhomeloans.com'), 'joeOlmsted', 'Joe Olmsted'));
        tabs.addAll(buildAssistedLoanOfficerTabs(assistedUsersByUsername.get('zfritz@reachhomeloans.com'), 'zachFritz', 'Zach Fritz', currentUserId));
        tabs.addAll(buildAssistedLoanOfficerTabs(assistedUsersByUsername.get('rdelaney@reachhomeloans.com'), 'rhettDelaney', 'Rhett Delaney'));
        return tabs;
    }

    private static List<PipelineTab> buildMeganPartnerPipelineTabs(List<PipelineRow> ownActiveLeadRows) {
        Id meganUserId = UserInfo.getUserId();
        Set<Id> meganUserIds = new Set<Id>{ meganUserId };
        User brandon = getActiveUserByUsername(BRANDON_BROTSKY_USERNAME);
        Id brandonUserId = brandon == null ? null : brandon.Id;
        User zach = getActiveUserByUsername(ZACHARY_FRITZ_USERNAME);
        Id zachUserId = zach == null ? null : zach.Id;
        List<TableColumn> leadColumns = buildLoanOfficerLeadColumns();
        List<TableColumn> preApprovalLeadColumns = buildPreApprovalLeadColumns();
        List<TableColumn> transactionColumns = buildLoanOfficerTransactionColumns();

        List<PipelineTab> tabs = new List<PipelineTab>{
            new PipelineTab('assigned', 'Active Leads', 'Your own active leads in contact, application, document, and contract statuses.', 'Lead', applyLoanOfficerLeadCells(ownActiveLeadRows), leadColumns),
            new PipelineTab('newLeadAlerts', 'New Leads Alert', 'Your own leads currently in New status.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'new', 50)), leadColumns),
            new PipelineTab('stagnant', 'Stagnant Leads', 'Your own open leads with no activity in the last 7 days.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'stagnant', 50)), leadColumns),
            new PipelineTab('activePreApprovals', 'Active Pre-Approvals', 'Your own leads currently in Pre-Approval status.', 'Lead', applyPreApprovalLeadCells(buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'activePreApproval', 100)), preApprovalLeadColumns),
            new PipelineTab('stagnantPreApprovals', 'Stagnant Pre-Approvals', 'Your own pre-approved leads without RingCentral call, SMS, or email activity for 6+ days.', 'Lead', applyPreApprovalLeadCells(buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'stagnantPreApproval', 50)), preApprovalLeadColumns),
            new PipelineTab('preApprovalCallsToday', 'Pre-Approval Calls Today', 'Your own pre-approved leads with an event today or no future event scheduled.', 'Lead', buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'preApprovalCallsToday', 100), buildPreApprovalCallsTodayColumns()),
            new PipelineTab('attention', 'Leads Needing Attention', 'Your own purchase leads matching the Lead Appointment Report attention criteria.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'attention', 50)), leadColumns),
            new PipelineTab('eventsToday', 'Leads with Events Today', 'Your own leads with calendar events scheduled today.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(meganUserIds, null, null, false, 'eventsToday', 50)), leadColumns),
            new PipelineTab('disclosuresNeedingSigned', 'Disclosures Needing Signed', 'Your own transactions in Disclosures Out status where disclosures have not been received.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(meganUserIds, null, null, false, 'disclosures', 100)), transactionColumns),
            new PipelineTab('loanOfficerActiveTransactions', 'My Active Transactions', 'Your own transactions that are still in active statuses.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(meganUserIds, null, null, false, 'active', 100)), transactionColumns),
            new PipelineTab('loanOfficerClosedThisMonth', 'Transactions Closed this Month', 'Your own funded, review, and post-closed files with a funding date in the current month.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(meganUserIds, null, null, false, 'closedThisMonth', 100)), transactionColumns)
        };

        if (brandonUserId != null) {
            tabs.add(new PipelineTab('brandonActiveLeads', 'Brandon Active Leads', 'Brandon Brotsky leads where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'active', 50)), leadColumns));
            tabs.add(new PipelineTab('brandonNewLeadAlerts', 'Brandon New Leads', 'Brandon Brotsky New status leads where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'new', 50)), leadColumns));
            tabs.add(new PipelineTab('brandonStagnantLeads', 'Brandon Stagnant Leads', 'Brandon Brotsky open leads with no activity in the last 7 days where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'stagnant', 50)), leadColumns));
            tabs.add(new PipelineTab('brandonActivePreApprovals', 'Brandon Active Pre-Approvals', 'Brandon Brotsky leads currently in Pre-Approval status where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'activePreApproval', 100)), leadColumns));
            tabs.add(new PipelineTab('brandonStagnantPreApprovals', 'Brandon Stagnant Pre-Approvals', 'Brandon Brotsky pre-approved leads without RingCentral call, SMS, or email activity for 6+ days where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'stagnantPreApproval', 50)), leadColumns));
            tabs.add(new PipelineTab('brandonPreApprovalCallsToday', 'Brandon Pre-Approval Calls Today', 'Brandon Brotsky pre-approved leads with an event today or no future event scheduled where you are the Loan Partner.', 'Lead', buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'preApprovalCallsToday', 100), buildPreApprovalCallsTodayColumns()));
            tabs.add(new PipelineTab('brandonAttentionLeads', 'Brandon Leads Needing Attention', 'Brandon Brotsky purchase leads matching the Lead Appointment Report attention criteria where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'attention', 50)), leadColumns));
            tabs.add(new PipelineTab('brandonEventsToday', 'Brandon Events Today', 'Brandon Brotsky leads with calendar events scheduled today where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'eventsToday', 50)), leadColumns));
            tabs.add(new PipelineTab('brandonDisclosuresNeedingSigned', 'Brandon Disclosures Needing Signed', 'Brandon Brotsky transactions in Disclosures Out status where disclosures have not been received and you are the Loan Partner.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'disclosures', 100)), transactionColumns));
            tabs.add(new PipelineTab('brandonActiveTransactions', 'Brandon Active Transactions', 'Brandon Brotsky transactions where you are the Loan Partner and the file is still active.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'active', 100)), transactionColumns));
            tabs.add(new PipelineTab('brandonClosedThisMonth', 'Brandon Transactions Closed this Month', 'Brandon Brotsky funded, review, and post-closed files this month where you are the Loan Partner.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(new Set<Id>(), brandonUserId, meganUserId, true, 'closedThisMonth', 100)), transactionColumns));
        }
        if (zachUserId != null) {
            tabs.add(new PipelineTab('zachFritzActiveLeads', 'Zach Active Leads', 'Zachary Fritz leads where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'active', 50)), leadColumns));
            tabs.add(new PipelineTab('zachFritzNewLeadAlerts', 'Zach New Leads', 'Zachary Fritz New status leads where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'new', 50)), leadColumns));
            tabs.add(new PipelineTab('zachFritzStagnantLeads', 'Zach Stagnant Leads', 'Zachary Fritz open leads with no activity in the last 7 days where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'stagnant', 50)), leadColumns));
            tabs.add(new PipelineTab('zachFritzActivePreApprovals', 'Zach Active Pre-Approvals', 'Zachary Fritz leads currently in Pre-Approval status where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'activePreApproval', 100)), leadColumns));
            tabs.add(new PipelineTab('zachFritzStagnantPreApprovals', 'Zach Stagnant Pre-Approvals', 'Zachary Fritz pre-approved leads without RingCentral call, SMS, or email activity for 6+ days where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'stagnantPreApproval', 50)), leadColumns));
            tabs.add(new PipelineTab('zachFritzPreApprovalCallsToday', 'Zach Pre-Approval Calls Today', 'Zachary Fritz pre-approved leads with an event today or no future event scheduled where you are the Loan Partner.', 'Lead', buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'preApprovalCallsToday', 100), buildPreApprovalCallsTodayColumns()));
            tabs.add(new PipelineTab('zachFritzAttentionLeads', 'Zach Leads Needing Attention', 'Zachary Fritz purchase leads matching the Lead Appointment Report attention criteria where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'attention', 50)), leadColumns));
            tabs.add(new PipelineTab('zachFritzEventsToday', 'Zach Events Today', 'Zachary Fritz leads with calendar events scheduled today where you are the Loan Partner.', 'Lead', applyLoanOfficerLeadCells(buildLeadRowsByOwnerScope(new Set<Id>(), zachUserId, meganUserId, true, 'eventsToday', 50)), leadColumns));
            tabs.add(new PipelineTab('zachFritzDisclosuresNeedingSigned', 'Zach Disclosures Needing Signed', 'Zachary Fritz transactions in Disclosures Out status where disclosures have not been received and you are the Loan Partner.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(new Set<Id>(), zachUserId, meganUserId, true, 'disclosures', 100)), transactionColumns));
            tabs.add(new PipelineTab('zachFritzActiveTransactions', 'Zach Active Transactions', 'Zachary Fritz transactions where you are the Loan Partner and the file is still active.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(new Set<Id>(), zachUserId, meganUserId, true, 'active', 100)), transactionColumns));
            tabs.add(new PipelineTab('zachFritzClosedThisMonth', 'Zach Transactions Closed this Month', 'Zachary Fritz funded, review, and post-closed files this month where you are the Loan Partner.', 'Transaction__c', applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(new Set<Id>(), zachUserId, meganUserId, true, 'closedThisMonth', 100)), transactionColumns));
        }
        tabs.add(buildMeganPreApprovalFollowUpTab(meganUserId, brandonUserId, zachUserId));
        return tabs;
    }

    private static List<PipelineTab> buildPastClientPipelineTabs() {
        List<TableColumn> columns = buildPastClientColumns(false);
        List<TableColumn> ratingColumns = buildPastClientColumns(true);
        List<PipelineTab> tabs = new List<PipelineTab>();
        for (Integer closingYear = Date.today().year(); closingYear >= PAST_CLIENT_MIN_CLOSED_DATE.year(); closingYear--) {
            Integer yearCount = countPastClientRowsForYear(closingYear);
            if (yearCount == 0) {
                continue;
            }
            PipelineTab tab = new PipelineTab(
                'benPastClients' + String.valueOf(closingYear),
                'Past Clients ' + String.valueOf(closingYear),
                'Showing the oldest ' + String.valueOf(PAST_CLIENT_VISIBLE_BATCH_SIZE) + ' contacts from the ' + String.valueOf(closingYear) + ' past-client call queue.',
                'Account',
                new List<PipelineRow>(),
                columns
            );
            tab.count = yearCount;
            tabs.add(tab);
        }
        PipelineTab hotFollowUpsTab = new PipelineTab(
            'benPastClientHotFollowUps',
            'Hot Follow Ups',
            'Past clients rated Hot and ready for follow-up.',
            'Account',
            buildPastClientRowsByRating('Hot'),
            ratingColumns
        );
        hotFollowUpsTab.count = countPastClientRowsByRating('Hot');
        tabs.add(hotFollowUpsTab);
        PipelineTab warmFollowUpsTab = new PipelineTab(
            'benPastClientWarmFollowUps',
            'Warm Follow Ups',
            'Past clients rated Warm and ready for follow-up.',
            'Account',
            buildPastClientRowsByRating('Warm'),
            ratingColumns
        );
        warmFollowUpsTab.count = countPastClientRowsByRating('Warm');
        tabs.add(warmFollowUpsTab);
        tabs.add(buildAgedPreApprovalTab(
            'benPreApprovalZachAged',
            'Zach\'s Aged Pre-approvals',
            'Zachary Fritz',
            'Zach'
        ));
        tabs.add(buildAgedPreApprovalTab(
            'benPreApprovalBrandonAged',
            'Brandon\'s Aged Pre-Approvals',
            'Brandon Brotsky',
            'Brandon'
        ));
        tabs.add(buildBenAssignedWebinarLeadTab());
        tabs.add(buildRealtorLeadTab('benRealtorMeetingComplete', 'Realtor - Meeting Complete', 'Realtor leads owned by Ben in Meeting Complete status.', 'Meeting Complete'));
        tabs.add(buildRealtorLeadTab('benRealtorActive', 'Realtor - Active', 'Realtor leads owned by Ben in Active status.', 'Active'));
        tabs.add(buildRealtorLeadTab('benRealtorWorking', 'Realtor - Working', 'Realtor leads owned by Ben in Working status.', 'Working'));
        return tabs;
    }

    private static List<StatusCard> buildPastClientStatusCards(List<PipelineTab> pastClientTabs) {
        Integer totalPrimaryPastClients = 0;
        Integer closedLastThreeYears = 0;
        Integer currentYear = Date.today().year();
        Integer availableYears = 0;
        for (PipelineTab tab : pastClientTabs) {
            Integer tabYear = pastClientYearFromTabKey(tab == null ? null : tab.key);
            if (tabYear == null) {
                continue;
            }
            totalPrimaryPastClients += tab.count == null ? 0 : tab.count;
            availableYears++;
            if (tabYear >= currentYear - 2) {
                closedLastThreeYears += tab.count == null ? 0 : tab.count;
            }
        }
        Integer purchaseClients = countPastClientRowsByPurpose('Purchase');
        return new List<StatusCard>{
            new StatusCard('Primary Past Clients', totalPrimaryPastClients, 'Closed primary-occupancy borrower accounts after 1/1/2019.'),
            new StatusCard('Available Years', availableYears, 'Closing-year call lists available on this Home Screen.'),
            new StatusCard('Closed Last 3 Years', closedLastThreeYears, 'Recent closed clients with fresher loan context.'),
            new StatusCard('Purchase Clients', purchaseClients, 'Past clients whose qualifying transaction was a purchase.')
        };
    }

    private static PipelineTab buildRealtorLeadTab(String key, String label, String subtitle, String statusValue) {
        PipelineTab tab = new PipelineTab(
            key,
            label,
            subtitle,
            'Lead',
            buildRealtorLeadRowsByStatus(statusValue),
            buildRealtorLeadColumns()
        );
        tab.count = countRealtorLeadRowsByStatus(statusValue);
        return tab;
    }

    private static Integer countRealtorLeadRowsByStatus(String statusValue) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE OwnerId = :UserInfo.getUserId()
            AND RecordType.DeveloperName = 'Realtor_Lead_record_type'
            AND Status = :statusValue
        ];
    }

    private static PipelineTab buildBenAssignedWebinarLeadTab() {
        List<PipelineRow> rows = buildBenAssignedWebinarLeadRows();
        return new PipelineTab(
            'benConsumerWebinarAssigned',
            'My Assigned Webinar Leads',
            'Consumer Webinar leads owned by Ben with event, loan, and referral context.',
            'Lead',
            rows,
            buildBenAssignedWebinarLeadColumns()
        );
    }

    private static List<TableColumn> buildBenAssignedWebinarLeadColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Client Name'),
            new TableColumn('phone', 'Phone'),
            new TableColumn('createdDate', 'Created'),
            new TableColumn('mostRecentEvent', 'Most Recent Event'),
            new TableColumn('nextScheduledEvent', 'Next Scheduled Event'),
            new TableColumn('status', 'Status'),
            new TableColumn('loanAmount', 'Loan Amount'),
            new TableColumn('loanPurpose', 'Purpose'),
            new TableColumn('realtorBuyingAgent', 'Buyer Agent'),
            new TableColumn('leadSource', 'Lead Source'),
            new TableColumn('appointmentDateTime', 'Appointment'),
            new TableColumn('loanDetails', 'Loan Details')
        };
    }

    private static PipelineTab buildAgedPreApprovalTab(String key, String label, String ownerName, String ownerDisplayName) {
        List<PipelineRow> rows = buildAgedPreApprovalRows(ownerName, ownerDisplayName);
        return new PipelineTab(
            key,
            label,
            ownerDisplayName + ' pre-approvals older than 60 days without a ' + ownerDisplayName + ' call in the last 5 business days or Ben call in the last 14 days.',
            'Lead',
            rows,
            buildAgedPreApprovalColumns(ownerDisplayName)
        );
    }

    // Megan's "Pre-Approval Follow Ups" cadence queue. Leads re-surface on a tightening schedule
    // measured from Pre_Approval_Date__c: every 6 days through day 30, every 14 days for days 31-60.
    // Past day 60 the lead leaves this queue entirely and becomes Ben's aged pre-approval work.
    private static final Integer MEGAN_FOLLOW_UP_EARLY_STAGE_MAX_AGE_DAYS = 30;
    private static final Integer MEGAN_FOLLOW_UP_MAX_AGE_DAYS = 60;
    private static final Integer MEGAN_FOLLOW_UP_EARLY_CALL_GAP_DAYS = 6;
    private static final Integer MEGAN_FOLLOW_UP_LATE_CALL_GAP_DAYS = 14;

    private static PipelineTab buildMeganPreApprovalFollowUpTab(Id meganUserId, Id brandonUserId, Id zachUserId) {
        List<PipelineRow> rows = buildMeganPreApprovalFollowUpRows(meganUserId, brandonUserId, zachUserId);
        return new PipelineTab(
            'meganPreApprovalFollowUps',
            'Pre-Approval Follow Ups',
            'Pre-approved leads owned by Megan, Zach, or Brandon that are due for a follow-up call: every 6 days through day 30 after pre-approval, every 14 days for days 31-60.',
            'Lead',
            rows,
            buildMeganPreApprovalFollowUpColumns()
        );
    }

    private static List<TableColumn> buildMeganPreApprovalFollowUpColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('ownerLO', 'Owner/LO'),
            new TableColumn('status', 'Status'),
            new TableColumn('preApprovalDate', 'Pre-Approval Date'),
            new TableColumn('phone', 'Phone Number'),
            new TableColumn('lastLoggedCall', 'Last Logged Call'),
            new TableColumn('lastLoggedSms', 'Last Logged SMS'),
            new TableColumn('loanDetails', 'Loan Details'),
            new TableColumn('nextAppointment', 'Next Appointment Date/Time')
        };
    }

    private static List<PipelineRow> buildMeganPreApprovalFollowUpRows(Id meganUserId, Id brandonUserId, Id zachUserId) {
        Set<Id> ownerIds = new Set<Id>();
        if (meganUserId != null) {
            ownerIds.add(meganUserId);
        }
        if (brandonUserId != null) {
            ownerIds.add(brandonUserId);
        }
        if (zachUserId != null) {
            ownerIds.add(zachUserId);
        }
        if (ownerIds.isEmpty() || meganUserId == null) {
            return new List<PipelineRow>();
        }

        Date oldestPreApprovalDate = Date.today().addDays(-MEGAN_FOLLOW_UP_MAX_AGE_DAYS);
        List<Lead> preApprovedLeads = [
            SELECT Id,
                Name,
                Status,
                Phone,
                Email,
                OwnerId,
                Owner.Name,
                CreatedDate,
                LastActivityDate,
                Loan_Amount__c,
                Loan_Purpose__c,
                Loan_Details__c,
                Pre_Approval_Date__c,
                Pre_Approval_Pass_At__c,
                Appointment_Date_Time__c,
                Realtor_Buying_Agent__r.Name
            FROM Lead
            WHERE OwnerId IN :ownerIds
            AND Status = 'Pre-Approval'
            AND Pre_Approval_Date__c != null
            AND Pre_Approval_Date__c >= :oldestPreApprovalDate
            ORDER BY Pre_Approval_Date__c ASC, Name ASC
            LIMIT 500
        ];

        Map<Id, Id> ownerIdByLeadId = new Map<Id, Id>();
        for (Lead leadRecord : preApprovedLeads) {
            ownerIdByLeadId.put(leadRecord.Id, leadRecord.OwnerId);
        }
        Set<Id> relevantTaskOwnerIds = new Set<Id>(ownerIds);
        Map<Id, Datetime> lastCallByLeadId = leadLastContactByOwnerOrPartner(
            ownerIdByLeadId,
            relevantTaskOwnerIds,
            meganUserId,
            true
        );
        Map<Id, Datetime> lastSmsByLeadId = leadLastContactByOwnerOrPartner(
            ownerIdByLeadId,
            relevantTaskOwnerIds,
            meganUserId,
            false
        );

        Date today = Date.today();
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Lead leadRecord : preApprovedLeads) {
            Date preApprovalDate = (Date) safeSObjectValue(leadRecord, 'Pre_Approval_Date__c');
            if (preApprovalDate == null) {
                continue;
            }
            Integer ageInDays = preApprovalDate.daysBetween(today);
            if (ageInDays < 0 || ageInDays > MEGAN_FOLLOW_UP_MAX_AGE_DAYS) {
                continue;
            }
            Integer requiredCallGapDays = ageInDays <= MEGAN_FOLLOW_UP_EARLY_STAGE_MAX_AGE_DAYS
                ? MEGAN_FOLLOW_UP_EARLY_CALL_GAP_DAYS
                : MEGAN_FOLLOW_UP_LATE_CALL_GAP_DAYS;
            Datetime lastCall = lastCallByLeadId.get(leadRecord.Id);
            // A Pass counts the same as a logged call for cadence purposes, so the lead drops out
            // now and cycles back once the applicable gap has elapsed.
            Datetime passedAt = (Datetime) safeSObjectValue(leadRecord, 'Pre_Approval_Pass_At__c');
            Datetime lastTouch = lastCall;
            if (passedAt != null && (lastTouch == null || passedAt > lastTouch)) {
                lastTouch = passedAt;
            }
            if (lastTouch != null && lastTouch > System.now().addDays(-requiredCallGapDays)) {
                continue;
            }
            rows.add(buildMeganPreApprovalFollowUpRow(
                leadRecord,
                lastCall,
                lastSmsByLeadId.get(leadRecord.Id)
            ));
        }
        return rows;
    }

    // Last call (or SMS) logged on each lead by either that lead's own owner or the loan partner.
    private static Map<Id, Datetime> leadLastContactByOwnerOrPartner(
        Map<Id, Id> ownerIdByLeadId,
        Set<Id> taskOwnerIds,
        Id partnerUserId,
        Boolean wantCallTasks
    ) {
        Map<Id, Datetime> lastContactByLeadId = new Map<Id, Datetime>();
        if (ownerIdByLeadId == null || ownerIdByLeadId.isEmpty() || taskOwnerIds == null || taskOwnerIds.isEmpty()) {
            return lastContactByLeadId;
        }
        Set<Id> leadIds = ownerIdByLeadId.keySet();
        Set<Id> eligibleTaskOwnerIds = new Set<Id>(taskOwnerIds);
        if (partnerUserId != null) {
            eligibleTaskOwnerIds.add(partnerUserId);
        }
        for (Task taskRecord : [
            SELECT WhoId, OwnerId, CreatedDate, Subject, Description, TaskSubtype, CallType
            FROM Task
            WHERE WhoId IN :leadIds
            AND OwnerId IN :eligibleTaskOwnerIds
            ORDER BY CreatedDate DESC
            LIMIT 50000
        ]) {
            Id leadOwnerId = ownerIdByLeadId.get(taskRecord.WhoId);
            Boolean loggedByOwnerOrPartner = taskRecord.OwnerId == leadOwnerId || taskRecord.OwnerId == partnerUserId;
            if (!loggedByOwnerOrPartner) {
                continue;
            }
            Boolean matchesType = wantCallTasks ? isCallTask(taskRecord) : isSmsTask(taskRecord);
            if (!matchesType) {
                continue;
            }
            Datetime currentDate = lastContactByLeadId.get(taskRecord.WhoId);
            if (currentDate == null || taskRecord.CreatedDate > currentDate) {
                lastContactByLeadId.put(taskRecord.WhoId, taskRecord.CreatedDate);
            }
        }
        return lastContactByLeadId;
    }

    private static Boolean isSmsTask(Task taskRecord) {
        if (taskRecord == null) {
            return false;
        }
        String subject = String.isBlank(taskRecord.Subject) ? '' : taskRecord.Subject.toLowerCase();
        return subject.contains('sms')
            || subject.contains('text message')
            || subject.contains('texted');
    }

    // RingCentral logs text messages as Tasks with CallType populated ('Outbound'/'Inbound'), and
    // email-logging Tasks can carry a subject containing "call". Both would otherwise satisfy the
    // call checks below, so they are ruled out before any call classification runs.
    private static Boolean isNonCallContactTask(Task taskRecord) {
        if (taskRecord == null) {
            return true;
        }
        if (isSmsTask(taskRecord)) {
            return true;
        }
        String subject = String.isBlank(taskRecord.Subject) ? '' : taskRecord.Subject.toLowerCase();
        return taskRecord.TaskSubtype == 'Email' || subject.startsWith('email:');
    }

    private static PipelineRow buildMeganPreApprovalFollowUpRow(Lead leadRecord, Datetime lastCall, Datetime lastSms) {
        PipelineRow row = new PipelineRow(leadRecord);
        Date preApprovalDate = (Date) safeSObjectValue(leadRecord, 'Pre_Approval_Date__c');
        row.displayDate = preApprovalDate;
        Datetime appointmentDateTime = (Datetime) safeSObjectValue(leadRecord, 'Appointment_Date_Time__c');
        String ownerName = row.ownerName;
        String loanDetails = (String) safeSObjectValue(leadRecord, 'Loan_Details__c');
        row.customCells = new List<TableCell>{
            new TableCell('name', leadRecord.Name, leadRecord.Name, true),
            new TableCell('ownerLO', ownerName, ownerName, false),
            new TableCell('status', leadRecord.Status, leadRecord.Status, false),
            new TableCell('preApprovalDate', formatDateForCell(preApprovalDate), formatDateSortValue(preApprovalDate), false),
            new TableCell('phone', row.phone, row.phone, false),
            new TableCell('lastLoggedCall', formatDatetimeForCell(lastCall), formatDatetimeSortValue(lastCall), false),
            new TableCell('lastLoggedSms', formatDatetimeForCell(lastSms), formatDatetimeSortValue(lastSms), false),
            new TableCell('loanDetails', loanDetails, loanDetails, false),
            new TableCell('nextAppointment', formatDatetimeForCell(appointmentDateTime), formatDatetimeSortValue(appointmentDateTime), false)
        };
        return row;
    }

    private static List<TableColumn> buildAgedPreApprovalColumns(String ownerDisplayName) {
        return new List<TableColumn>{
            new TableColumn('name', 'Client Name'),
            new TableColumn('phone', 'Phone'),
            new TableColumn('scheduledEvent', 'Scheduled Event'),
            new TableColumn('preApprovalDate', 'Pre-Approval Date'),
            new TableColumn('loanAmount', 'Loan Amount'),
            new TableColumn('realtorBuyingAgent', 'Realtor - Buying Agent'),
            new TableColumn('ownerLastCall', ownerDisplayName + ' Last RingCentral Call'),
            new TableColumn('benLastCall', 'Ben Last RingCentral Call')
        };
    }

    private static List<TableColumn> buildPreApprovalCallsTodayColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('phone', 'Phone Number'),
            new TableColumn('createdDate', 'Created Date'),
            new TableColumn('lastActivityDate', 'Last Activity'),
            new TableColumn('appointmentDateTime', 'Appointment Date/Time'),
            new TableColumn('preApprovalDate', 'Pre-Approval Date'),
            new TableColumn('loanDetails', 'Loan Details'),
            new TableColumn('loanPurpose', 'Loan Purpose'),
            new TableColumn('loanAmount', 'Loan Amount'),
            new TableColumn('bizDev', 'Biz Dev'),
            new TableColumn('realtorBuyingAgent', 'Realtor Buyers Agent')
        };
    }

    private static List<TableColumn> buildLoanOfficerLeadColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('phone', 'Phone Number'),
            new TableColumn('email', 'Email'),
            new TableColumn('leadSource', 'Lead Source'),
            new TableColumn('realtorBuyingAgent', 'Realtor - Buying Agent'),
            new TableColumn('lastActivityDate', 'Last Activity Date'),
            new TableColumn('appointmentDateTime', 'Next Appointment Date'),
            new TableColumn('loanDetails', 'Loan Details')
        };
    }

    private static List<TableColumn> buildPreApprovalLeadColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('phone', 'Phone Number'),
            new TableColumn('email', 'Email'),
            new TableColumn('leadSource', 'Lead Source'),
            new TableColumn('realtorBuyingAgent', 'Realtor - Buying Agent'),
            new TableColumn('lastActivityDate', 'Last Activity Date'),
            new TableColumn('appointmentDateTime', 'Next Appointment Date'),
            new TableColumn('preApprovalDate', 'Pre-Approval Date'),
            new TableColumn('loanDetails', 'Loan Details')
        };
    }

    private static List<TableColumn> buildLoanOfficerTransactionColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('processorName', 'Processor'),
            new TableColumn('detail', 'Processor Note'),
            new TableColumn('lastProcessorSms', 'Last Processor SMS'),
            new TableColumn('lastProcessorCall', 'Last Processor Call'),
            new TableColumn('lenderName', 'Lender'),
            new TableColumn('loanPurpose', 'Purpose'),
            new TableColumn('loanOfficerName', 'Loan Officer'),
            new TableColumn('loanAmount', 'Amount'),
            new TableColumn('easeLink', 'EASE Link')
        };
    }

    private static List<PipelineRow> applyLoanOfficerLeadCells(List<PipelineRow> rows) {
        if (rows == null) {
            return new List<PipelineRow>();
        }
        List<PipelineRow> displayRows = uniquePipelineRows(rows);
        for (PipelineRow row : displayRows) {
            if (row == null) {
                continue;
            }
            row.customCells = new List<TableCell>{
                new TableCell('name', row.name, row.name, true),
                new TableCell('status', row.status, row.status, false, 'Status'),
                new TableCell('phone', row.phone, row.phone, false, 'Phone'),
                new TableCell('email', row.email, row.email, false, 'Email'),
                new TableCell('leadSource', row.leadSource, row.leadSource, false, 'LeadSource'),
                new TableCell('realtorBuyingAgent', row.realtorBuyingAgentName, row.realtorBuyingAgentName, false, 'Realtor_Buying_Agent__c'),
                new TableCell('lastActivityDate', formatDateForCell(row.lastActivityDate), formatDateSortValue(row.lastActivityDate), false),
                new TableCell('appointmentDateTime', formatDatetimeForCell(row.appointmentDateTime), formatDatetimeSortValue(row.appointmentDateTime), false, 'Appointment_Date_Time__c'),
                new TableCell('loanDetails', row.loanDetails, row.loanDetails, false, 'Loan_Details__c')
            };
        }
        return displayRows;
    }

    private static List<PipelineRow> applyPreApprovalLeadCells(List<PipelineRow> rows) {
        if (rows == null) {
            return new List<PipelineRow>();
        }
        List<PipelineRow> displayRows = uniquePipelineRows(rows);
        for (PipelineRow row : displayRows) {
            if (row == null) {
                continue;
            }
            row.customCells = new List<TableCell>{
                new TableCell('name', row.name, row.name, true),
                new TableCell('status', row.status, row.status, false, 'Status'),
                new TableCell('phone', row.phone, row.phone, false, 'Phone'),
                new TableCell('email', row.email, row.email, false, 'Email'),
                new TableCell('leadSource', row.leadSource, row.leadSource, false, 'LeadSource'),
                new TableCell('realtorBuyingAgent', row.realtorBuyingAgentName, row.realtorBuyingAgentName, false, 'Realtor_Buying_Agent__c'),
                new TableCell('lastActivityDate', formatDateForCell(row.lastActivityDate), formatDateSortValue(row.lastActivityDate), false),
                new TableCell('appointmentDateTime', formatDatetimeForCell(row.appointmentDateTime), formatDatetimeSortValue(row.appointmentDateTime), false, 'Appointment_Date_Time__c'),
                new TableCell('preApprovalDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Pre_Approval_Date__c'),
                new TableCell('loanDetails', row.loanDetails, row.loanDetails, false, 'Loan_Details__c')
            };
        }
        return displayRows;
    }

    private static List<PipelineRow> applyLoanOfficerTransactionCells(List<PipelineRow> rows) {
        if (rows == null) {
            return new List<PipelineRow>();
        }
        List<PipelineRow> displayRows = uniquePipelineRows(rows);
        for (PipelineRow row : displayRows) {
            if (row == null) {
                continue;
            }
            row.customCells = new List<TableCell>{
                new TableCell('name', row.name, row.name, true),
                new TableCell('status', row.status, row.status, false, 'Status__c'),
                new TableCell('closingDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Closing_Date__c'),
                new TableCell('processorName', row.processorName, row.processorName, false, 'Processor__c'),
                new TableCell('detail', row.detail, row.detail, false, 'Processor_Note__c'),
                new TableCell('lastProcessorSms', formatDatetimeForCell(row.lastProcessorSms), formatDatetimeSortValue(row.lastProcessorSms), false),
                new TableCell('lastProcessorCall', formatDatetimeForCell(row.lastProcessorCall), formatDatetimeSortValue(row.lastProcessorCall), false),
                new TableCell('lenderName', row.lenderName, row.lenderName, false, 'Lender_lookup__c'),
                new TableCell('loanPurpose', row.loanPurpose, row.loanPurpose, false, 'Loan_Purpose__c'),
                new TableCell('loanOfficerName', row.loanOfficerName, row.loanOfficerName, false, 'Loan_Officer__c'),
                new TableCell('loanAmount', formatDecimalForCell(row.loanAmount), formatDecimalSortValue(row.loanAmount), false, 'Loan_Amount_1st__c'),
                easeLinkCell(row)
            };
        }
        return displayRows;
    }

    private static List<PipelineRow> uniquePipelineRows(List<PipelineRow> rows) {
        List<PipelineRow> uniqueRows = new List<PipelineRow>();
        Set<Id> seenIds = new Set<Id>();
        for (PipelineRow row : rows) {
            if (row == null) {
                continue;
            }
            if (row.id == null || !seenIds.contains(row.id)) {
                uniqueRows.add(row);
                if (row.id != null) {
                    seenIds.add(row.id);
                }
            }
        }
        return uniqueRows;
    }

    private static List<PipelineRow> buildBenAssignedWebinarLeadRows() {
        Map<String, Id> idsByUserName = userIdsByName(new Set<String>{ 'Benjamin Bondarevsky' });
        Id benId = idsByUserName.get('Benjamin Bondarevsky');
        if (benId == null) {
            return new List<PipelineRow>();
        }

        List<Lead> webinarLeads = [
            SELECT Id,
                Name,
                Status,
                Phone,
                Email,
                CreatedDate,
                LastActivityDate,
                Appointment_Date_Time__c,
                Loan_Details__c,
                Loan_Amount__c,
                Loan_Purpose__c,
                LeadSource,
                Realtor_Buying_Agent__r.Name,
                Owner.Name
            FROM Lead
            WHERE OwnerId = :benId
            AND IsConverted = false
            AND LeadSource = 'Consumer Webinar'
            ORDER BY CreatedDate DESC, Name ASC
            LIMIT 200
        ];

        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRecord : webinarLeads) {
            leadIds.add(leadRecord.Id);
        }
        Map<Id, Event> mostRecentEventsByLeadId = getLatestEventsByLeadId(leadIds);
        Map<Id, EventCell> nextEventsByLeadId = leadNextScheduledEvents(leadIds);

        List<PipelineRow> rows = new List<PipelineRow>();
        for (Lead leadRecord : webinarLeads) {
            rows.add(buildBenAssignedWebinarLeadRow(
                leadRecord,
                mostRecentEventsByLeadId.get(leadRecord.Id),
                nextEventsByLeadId.get(leadRecord.Id)
            ));
        }
        return rows;
    }

    private static PipelineRow buildBenAssignedWebinarLeadRow(Lead leadRecord, Event mostRecentEvent, EventCell nextScheduledEvent) {
        PipelineRow row = new PipelineRow(leadRecord);
        EventCell mostRecentEventCell = mostRecentEvent == null ? null : new EventCell(mostRecentEvent);
        row.customCells = new List<TableCell>{
            new TableCell('name', leadRecord.Name, leadRecord.Name, true),
            new TableCell('phone', row.phone, row.phone, false),
            new TableCell('createdDate', formatDatetimeForCell(leadRecord.CreatedDate), formatDatetimeSortValue(leadRecord.CreatedDate), false),
            new TableCell('mostRecentEvent', mostRecentEventCell == null ? '' : mostRecentEventCell.label, mostRecentEventCell == null ? '' : mostRecentEventCell.sortValue, false),
            new TableCell('nextScheduledEvent', nextScheduledEvent == null ? '' : nextScheduledEvent.label, nextScheduledEvent == null ? '' : nextScheduledEvent.sortValue, false),
            new TableCell('status', leadRecord.Status, leadRecord.Status, false),
            new TableCell('loanAmount', formatDecimalForCell((Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c')), formatDecimalSortValue((Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c')), false),
            new TableCell('loanPurpose', (String) safeSObjectValue(leadRecord, 'Loan_Purpose__c'), (String) safeSObjectValue(leadRecord, 'Loan_Purpose__c'), false),
            new TableCell('realtorBuyingAgent', row.realtorBuyingAgentName, row.realtorBuyingAgentName, false),
            new TableCell('leadSource', row.leadSource, row.leadSource, false),
            new TableCell('appointmentDateTime', formatDatetimeForCell(row.appointmentDateTime), formatDatetimeSortValue(row.appointmentDateTime), false),
            new TableCell('loanDetails', row.loanDetails, row.loanDetails, false)
        };
        return row;
    }

    private static List<PipelineRow> buildAgedPreApprovalRows(String ownerName, String ownerDisplayName) {
        Map<String, Id> idsByUserName = userIdsByName(new Set<String>{ ownerName, 'Benjamin Bondarevsky' });
        Id ownerId = idsByUserName.get(ownerName);
        Id benId = idsByUserName.get('Benjamin Bondarevsky');
        if (ownerId == null || benId == null) {
            return new List<PipelineRow>();
        }

        Date preApprovalCutoff = Date.today().addDays(-60);
        List<Lead> agedPreApprovals = [
            SELECT Id,
                Name,
                Status,
                Phone,
                Email,
                CreatedDate,
                LastActivityDate,
                Loan_Amount__c,
                Loan_Purpose__c,
                Pre_Approval_Date__c,
                Realtor_Buying_Agent__r.Name,
                Owner.Name
            FROM Lead
            WHERE OwnerId = :ownerId
            AND Status = 'Pre-Approval'
            AND Pre_Approval_Date__c != null
            AND Pre_Approval_Date__c <= :preApprovalCutoff
            ORDER BY Pre_Approval_Date__c ASC, Name ASC
            LIMIT 200
        ];
        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRecord : agedPreApprovals) {
            leadIds.add(leadRecord.Id);
        }

        Map<Id, Datetime> ownerRecentCallsByLeadId = leadRecentCallsByUser(leadIds, ownerId, DateTime.newInstance(businessDaysAgo(5), Time.newInstance(0, 0, 0, 0)));
        Map<Id, Datetime> benRecentCallsByLeadId = leadRecentOutboundCallsByUser(leadIds, benId, System.now().addDays(-14));
        Map<Id, Datetime> ownerLastCallsByLeadId = leadRecentCallsByUser(leadIds, ownerId, DateTime.newInstance(2000, 1, 1, 0, 0, 0));
        Map<Id, Datetime> benLastCallsByLeadId = leadRecentOutboundCallsByUser(leadIds, benId, DateTime.newInstance(2000, 1, 1, 0, 0, 0));
        Map<Id, EventCell> scheduledEventsByLeadId = leadNearestScheduledEvents(leadIds);
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Lead leadRecord : agedPreApprovals) {
            if (ownerRecentCallsByLeadId.containsKey(leadRecord.Id) || benRecentCallsByLeadId.containsKey(leadRecord.Id)) {
                continue;
            }
            rows.add(buildAgedPreApprovalRow(
                leadRecord,
                scheduledEventsByLeadId.get(leadRecord.Id),
                ownerLastCallsByLeadId.get(leadRecord.Id),
                benLastCallsByLeadId.get(leadRecord.Id),
                ownerDisplayName
            ));
        }
        return rows;
    }

    private static PipelineRow buildAgedPreApprovalRow(Lead leadRecord, EventCell scheduledEvent, Datetime ownerLastCall, Datetime benLastCall, String ownerDisplayName) {
        PipelineRow row = new PipelineRow(leadRecord);
        Date preApprovalDate = (Date) safeSObjectValue(leadRecord, 'Pre_Approval_Date__c');
        row.displayDate = preApprovalDate;
        String loanAmount = formatDecimalForCell((Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c'));
        String realtorBuyingAgent = row.realtorBuyingAgentName;
        row.customCells = new List<TableCell>{
            new TableCell('name', leadRecord.Name, leadRecord.Name, true),
            new TableCell('phone', row.phone, row.phone, false),
            new TableCell('scheduledEvent', scheduledEvent == null ? '' : scheduledEvent.label, scheduledEvent == null ? '' : scheduledEvent.sortValue, false),
            new TableCell('preApprovalDate', formatDateForCell(preApprovalDate), formatDateSortValue(preApprovalDate), false),
            new TableCell('loanAmount', loanAmount, formatDecimalSortValue((Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c')), false),
            new TableCell('realtorBuyingAgent', realtorBuyingAgent, realtorBuyingAgent, false),
            new TableCell('ownerLastCall', formatDatetimeForCell(ownerLastCall), formatDatetimeSortValue(ownerLastCall), false),
            new TableCell('benLastCall', formatDatetimeForCell(benLastCall), formatDatetimeSortValue(benLastCall), false)
        };
        return row;
    }

    private static Map<Id, EventCell> leadNearestScheduledEvents(Set<Id> leadIds) {
        Map<Id, EventCell> eventsByLeadId = new Map<Id, EventCell>();
        if (leadIds == null || leadIds.isEmpty()) {
            return eventsByLeadId;
        }

        Datetime nowDateTime = System.now();
        Date today = Date.today();
        for (Event eventRecord : [
            SELECT WhoId, Subject, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhoId IN :leadIds
            AND (
                ActivityDate >= :today
                OR ActivityDateTime >= :nowDateTime
                OR StartDateTime >= :nowDateTime
            )
            ORDER BY ActivityDate ASC NULLS LAST, ActivityDateTime ASC NULLS LAST, StartDateTime ASC NULLS LAST
            LIMIT 500
        ]) {
            if (eventsByLeadId.containsKey(eventRecord.WhoId)) {
                continue;
            }
            eventsByLeadId.put(eventRecord.WhoId, new EventCell(eventRecord));
        }

        Set<Id> missingLeadIds = new Set<Id>(leadIds);
        missingLeadIds.removeAll(eventsByLeadId.keySet());
        if (missingLeadIds.isEmpty()) {
            return eventsByLeadId;
        }

        for (Event eventRecord : [
            SELECT WhoId, Subject, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhoId IN :missingLeadIds
            ORDER BY ActivityDate DESC NULLS LAST, ActivityDateTime DESC NULLS LAST, StartDateTime DESC NULLS LAST
            LIMIT 500
        ]) {
            if (eventsByLeadId.containsKey(eventRecord.WhoId)) {
                continue;
            }
            eventsByLeadId.put(eventRecord.WhoId, new EventCell(eventRecord));
        }

        return eventsByLeadId;
    }

    private static Map<Id, EventCell> leadNextScheduledEvents(Set<Id> leadIds) {
        Map<Id, EventCell> eventsByLeadId = new Map<Id, EventCell>();
        if (leadIds == null || leadIds.isEmpty()) {
            return eventsByLeadId;
        }

        Datetime nowDateTime = System.now();
        Date today = Date.today();
        for (Event eventRecord : [
            SELECT WhoId, Subject, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhoId IN :leadIds
            AND (
                ActivityDate >= :today
                OR ActivityDateTime >= :nowDateTime
                OR StartDateTime >= :nowDateTime
            )
            ORDER BY ActivityDate ASC NULLS LAST, ActivityDateTime ASC NULLS LAST, StartDateTime ASC NULLS LAST
            LIMIT 500
        ]) {
            if (eventsByLeadId.containsKey(eventRecord.WhoId)) {
                continue;
            }
            eventsByLeadId.put(eventRecord.WhoId, new EventCell(eventRecord));
        }

        return eventsByLeadId;
    }

    private static PipelineRow buildPreApprovalCallsTodayRow(Lead leadRecord) {
        PipelineRow row = new PipelineRow(leadRecord);
        Date preApprovalDate = (Date) safeSObjectValue(leadRecord, 'Pre_Approval_Date__c');
        String bizDev = (String) safeSObjectValue(leadRecord, 'Biz_Dev__c');
        row.displayDate = preApprovalDate;
        row.customCells = new List<TableCell>{
            new TableCell('name', leadRecord.Name, leadRecord.Name, true),
            new TableCell('phone', row.phone, row.phone, false),
            new TableCell('status', leadRecord.Status, leadRecord.Status, false),
            new TableCell('createdDate', formatDatetimeForCell(leadRecord.CreatedDate), formatDatetimeSortValue(leadRecord.CreatedDate), false),
            new TableCell('lastActivityDate', formatDateForCell(leadRecord.LastActivityDate), formatDateSortValue(leadRecord.LastActivityDate), false),
            new TableCell('appointmentDateTime', formatDatetimeForCell((Datetime) safeSObjectValue(leadRecord, 'Appointment_Date_Time__c')), formatDatetimeSortValue((Datetime) safeSObjectValue(leadRecord, 'Appointment_Date_Time__c')), false),
            new TableCell('preApprovalDate', formatDateForCell(preApprovalDate), formatDateSortValue(preApprovalDate), false),
            new TableCell('loanDetails', (String) safeSObjectValue(leadRecord, 'Loan_Details__c'), (String) safeSObjectValue(leadRecord, 'Loan_Details__c'), false),
            new TableCell('loanPurpose', (String) safeSObjectValue(leadRecord, 'Loan_Purpose__c'), (String) safeSObjectValue(leadRecord, 'Loan_Purpose__c'), false),
            new TableCell('loanAmount', formatDecimalForCell((Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c')), formatDecimalSortValue((Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c')), false),
            new TableCell('bizDev', bizDev, bizDev, false),
            new TableCell('realtorBuyingAgent', row.realtorBuyingAgentName, row.realtorBuyingAgentName, false)
        };
        return row;
    }

    private static Map<String, Id> userIdsByName(Set<String> userNames) {
        Map<String, Id> idsByName = new Map<String, Id>();
        if (userNames == null || userNames.isEmpty()) {
            return idsByName;
        }
        for (User userRecord : [
            SELECT Id, Name
            FROM User
            WHERE Name IN :userNames
            AND IsActive = true
        ]) {
            idsByName.put(userRecord.Name, userRecord.Id);
        }
        return idsByName;
    }

    private static Map<Id, Datetime> leadRecentOutboundCallsByUser(Set<Id> leadIds, Id userId, Datetime cutoffDateTime) {
        Map<Id, Datetime> callsByLeadId = new Map<Id, Datetime>();
        if (leadIds == null || leadIds.isEmpty() || userId == null || cutoffDateTime == null) {
            return callsByLeadId;
        }
        for (Task taskRecord : [
            SELECT WhoId, CreatedDate, Subject, TaskSubtype, CallType
            FROM Task
            WHERE OwnerId = :userId
            AND WhoId IN :leadIds
            AND CreatedDate >= :cutoffDateTime
            AND (TaskSubtype = 'Call' OR CallType != null OR Subject LIKE '%Call%' OR Subject LIKE '%RingCentral%')
            ORDER BY CreatedDate DESC
            LIMIT 50000
        ]) {
            if (!isOutboundCallTask(taskRecord)) {
                continue;
            }
            Datetime currentDate = callsByLeadId.get(taskRecord.WhoId);
            if (currentDate == null || taskRecord.CreatedDate > currentDate) {
                callsByLeadId.put(taskRecord.WhoId, taskRecord.CreatedDate);
            }
        }
        return callsByLeadId;
    }

    private static Map<Id, Datetime> leadRecentCallsByUser(Set<Id> leadIds, Id userId, Datetime cutoffDateTime) {
        Map<Id, Datetime> callsByLeadId = new Map<Id, Datetime>();
        if (leadIds == null || leadIds.isEmpty() || userId == null || cutoffDateTime == null) {
            return callsByLeadId;
        }
        for (Task taskRecord : [
            SELECT WhoId, CreatedDate, Subject, TaskSubtype, CallType
            FROM Task
            WHERE OwnerId = :userId
            AND WhoId IN :leadIds
            AND CreatedDate >= :cutoffDateTime
            AND (TaskSubtype = 'Call' OR CallType != null OR Subject LIKE '%Call%' OR Subject LIKE '%RingCentral%')
            ORDER BY CreatedDate DESC
            LIMIT 50000
        ]) {
            if (!isCallTask(taskRecord)) {
                continue;
            }
            Datetime currentDate = callsByLeadId.get(taskRecord.WhoId);
            if (currentDate == null || taskRecord.CreatedDate > currentDate) {
                callsByLeadId.put(taskRecord.WhoId, taskRecord.CreatedDate);
            }
        }
        return callsByLeadId;
    }

    private static Boolean isOutboundCallTask(Task taskRecord) {
        if (isNonCallContactTask(taskRecord)) {
            return false;
        }
        String callType = taskRecord.CallType == null ? '' : String.valueOf(taskRecord.CallType).toLowerCase();
        String subject = String.isBlank(taskRecord.Subject) ? '' : taskRecord.Subject.toLowerCase();
        if (callType == 'outbound') {
            return true;
        }
        if (String.isBlank(callType) && (subject.contains('outgoing') || subject.contains('outbound') || subject.contains('ringcentral') || subject.contains('call'))) {
            return true;
        }
        return false;
    }

    private static Boolean isCallTask(Task taskRecord) {
        if (isNonCallContactTask(taskRecord)) {
            return false;
        }
        String callType = taskRecord.CallType == null ? '' : String.valueOf(taskRecord.CallType).toLowerCase();
        String subject = String.isBlank(taskRecord.Subject) ? '' : taskRecord.Subject.toLowerCase();
        return taskRecord.TaskSubtype == 'Call'
            || !String.isBlank(callType)
            || subject.contains('ringcentral')
            || subject.contains('call');
    }

    private static Date businessDaysAgo(Integer daysBack) {
        Date targetDate = Date.today();
        Integer remainingDays = daysBack == null ? 0 : daysBack;
        while (remainingDays > 0) {
            targetDate = targetDate.addDays(-1);
            if (!isWeekend(targetDate)) {
                remainingDays--;
            }
        }
        return targetDate;
    }

    private static Boolean isWeekend(Date candidateDate) {
        Integer dayOffset = Math.mod(Date.newInstance(1900, 1, 1).daysBetween(candidateDate), 7);
        return dayOffset == 5 || dayOffset == 6;
    }

    private static Integer countPastClientRowsForYear(Integer closingYear) {
        Date yearStart = Date.newInstance(closingYear, 1, 1);
        Date nextYearStart = yearStart.addYears(1);
        Set<Id> candidateAccountIds = new Set<Id>();
        for (Transaction__c transactionRecord : [
            SELECT Borrower_Name__c
            FROM Transaction__c
            WHERE Borrower_Name__c != null
            AND Borrower_Name__r.IsPersonAccount = true
            AND (Borrower_Name__r.Phone != null
                OR Borrower_Name__r.PersonMobilePhone != null)
            AND ((Funding_Date__c >= :yearStart AND Funding_Date__c < :nextYearStart)
                OR (Funding_Date__c = null AND Closing_Date__c >= :yearStart AND Closing_Date__c < :nextYearStart))
            AND Status__c != 'Cancelled'
            AND Occupancy__c IN :PAST_CLIENT_PRIMARY_OCCUPANCIES
            AND Loan_Purpose__c = :PAST_CLIENT_PURCHASE_PURPOSE
            AND (Loan_Officer__c = null OR Loan_Officer__r.Name NOT IN :PAST_CLIENT_EXCLUDED_LO_NAMES)
            AND (Biz_Dev__c = null OR Biz_Dev__c NOT IN :PAST_CLIENT_EXCLUDED_BIZ_DEV_VALUES)
            LIMIT 50000
        ]) {
            candidateAccountIds.add(transactionRecord.Borrower_Name__c);
        }
        if (candidateAccountIds.isEmpty()) {
            return 0;
        }
        Set<Id> recentlyCalledAccountIds = pastClientAccountsCalledByCurrentUser(candidateAccountIds, System.now().addDays(-90));
        Set<Id> todayEventAccountIds = pastClientAccountsWithTodayEventByCurrentUser(candidateAccountIds);
        Integer eligibleCount = 0;
        for (Id accountId : candidateAccountIds) {
            if (!recentlyCalledAccountIds.contains(accountId) || todayEventAccountIds.contains(accountId)) {
                eligibleCount++;
            }
        }
        return eligibleCount;
    }

    private static Integer countPastClientRowsByRating(String ratingValue) {
        return [
            SELECT COUNT()
            FROM Account
            WHERE IsPersonAccount = true
            AND Borrower_Rating__c = :ratingValue
        ];
    }

    private static Integer countPastClientRowsByPurpose(String loanPurpose) {
        AggregateResult result = [
            SELECT COUNT_DISTINCT(Borrower_Name__c) clientCount
            FROM Transaction__c
            WHERE Borrower_Name__c != null
            AND Borrower_Name__r.IsPersonAccount = true
            AND (Borrower_Name__r.Phone != null
                OR Borrower_Name__r.PersonMobilePhone != null)
            AND (Funding_Date__c >= :PAST_CLIENT_MIN_CLOSED_DATE OR (Funding_Date__c = null AND Closing_Date__c >= :PAST_CLIENT_MIN_CLOSED_DATE))
            AND Status__c != 'Cancelled'
            AND Occupancy__c IN :PAST_CLIENT_PRIMARY_OCCUPANCIES
            AND Loan_Purpose__c = :loanPurpose
            AND (Loan_Officer__c = null OR Loan_Officer__r.Name NOT IN :PAST_CLIENT_EXCLUDED_LO_NAMES)
            AND (Biz_Dev__c = null OR Biz_Dev__c NOT IN :PAST_CLIENT_EXCLUDED_BIZ_DEV_VALUES)
        ];
        return aggregateInteger(result.get('clientCount'));
    }

    private static Integer aggregateInteger(Object aggregateValue) {
        if (aggregateValue == null) {
            return 0;
        }
        if (aggregateValue instanceof Integer) {
            return (Integer) aggregateValue;
        }
        if (aggregateValue instanceof Long) {
            return ((Long) aggregateValue).intValue();
        }
        if (aggregateValue instanceof Decimal) {
            return ((Decimal) aggregateValue).intValue();
        }
        return Integer.valueOf(String.valueOf(aggregateValue));
    }

    private static List<TableColumn> buildPastClientColumns(Boolean includeRating) {
        List<TableColumn> columns = new List<TableColumn>{
            new TableColumn('name', 'Borrower'),
            new TableColumn('phone', 'Phone'),
            new TableColumn('lastContacted', 'Last Contacted'),
            new TableColumn('benLastCall', 'Ben Last Call'),
            new TableColumn('address', 'Mailing Address'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('birthday', 'Birthday')
        };
        if (includeRating) {
            columns.add(new TableColumn('rating', 'Rating'));
        }
        columns.addAll(new List<TableColumn>{
            new TableColumn('loanType', 'Loan Type'),
            new TableColumn('loanPurpose', 'Purpose'),
            new TableColumn('loanOfficer', 'Loan Officer')
        });
        return columns;
    }

    private static List<TableColumn> buildRealtorLeadColumns() {
        return new List<TableColumn>{
            new TableColumn('firstName', 'First Name'),
            new TableColumn('lastName', 'Last Name'),
            new TableColumn('phone', 'Phone'),
            new TableColumn('email', 'Email'),
            new TableColumn('status', 'Status'),
            new TableColumn('lastBenContact', 'Last Ben Contact'),
            new TableColumn('leadSource', 'Lead Source'),
            new TableColumn('realtorLeadSource', 'Realtor Source'),
            new TableColumn('realtorGroup', 'Realtor Group'),
            new TableColumn('buyerVolume', 'Buyer Volume'),
            new TableColumn('county', 'County'),
            new TableColumn('transactions', 'Transactions'),
            new TableColumn('appointmentDateTime', 'Appointment'),
            new TableColumn('comments', 'Further Info')
        };
    }

    private static List<PipelineRow> buildRealtorLeadRowsByStatus(String statusValue) {
        List<Lead> realtorLeads = [
            SELECT Id,
                FirstName,
                LastName,
                Name,
                Status,
                Phone,
                Email,
                LeadSource,
                Realtor_Lead_Source__c,
                Realtor_Group__c,
                Buyer_Volume__c,
                County_of_Operation__c,
                Number_of_Transactions__c,
                Appointment_Date_Time__c,
                Loan_Amount__c,
                Loan_Purpose__c,
                Comments__c,
                CreatedDate,
                LastActivityDate,
                Owner.Name
            FROM Lead
            WHERE OwnerId = :UserInfo.getUserId()
            AND RecordType.DeveloperName = 'Realtor_Lead_record_type'
            AND Status = :statusValue
            ORDER BY LastActivityDate ASC NULLS FIRST, CreatedDate ASC
            LIMIT 150
        ];
        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRecord : realtorLeads) {
            leadIds.add(leadRecord.Id);
        }
        Map<Id, Datetime> lastContactByLeadId = realtorLeadLastContactDateByCurrentUser(leadIds);
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Lead leadRecord : realtorLeads) {
            rows.add(buildRealtorLeadRow(leadRecord, lastContactByLeadId.get(leadRecord.Id)));
        }
        sortRowsByLastContact(rows);
        return rows;
    }

    private static Map<Id, Datetime> realtorLeadLastContactDateByCurrentUser(Set<Id> leadIds) {
        Map<Id, Datetime> lastContactByLeadId = new Map<Id, Datetime>();
        if (leadIds == null || leadIds.isEmpty()) {
            return lastContactByLeadId;
        }
        Id currentUserId = UserInfo.getUserId();
        for (AggregateResult result : [
            SELECT WhoId leadId, MAX(CreatedDate) lastDate
            FROM Task
            WHERE OwnerId = :currentUserId
            AND WhoId IN :leadIds
            GROUP BY WhoId
        ]) {
            lastContactByLeadId.put((Id) result.get('leadId'), (Datetime) result.get('lastDate'));
        }
        for (AggregateResult result : [
            SELECT WhoId leadId, MAX(CreatedDate) lastDate
            FROM Event
            WHERE OwnerId = :currentUserId
            AND WhoId IN :leadIds
            GROUP BY WhoId
        ]) {
            Id leadId = (Id) result.get('leadId');
            Datetime eventDate = (Datetime) result.get('lastDate');
            Datetime currentDate = lastContactByLeadId.get(leadId);
            if (currentDate == null || (eventDate != null && eventDate > currentDate)) {
                lastContactByLeadId.put(leadId, eventDate);
            }
        }
        return lastContactByLeadId;
    }

    private static PipelineRow buildRealtorLeadRow(Lead leadRecord, Datetime lastBenContactDate) {
        PipelineRow row = new PipelineRow(leadRecord);
        row.displayDateTime = lastBenContactDate;
        row.detail = (String) safeSObjectValue(leadRecord, 'Comments__c');
        String firstName = (String) safeSObjectValue(leadRecord, 'FirstName');
        String lastName = (String) safeSObjectValue(leadRecord, 'LastName');
        String buyerVolume = formatGenericCellValue(safeSObjectValue(leadRecord, 'Buyer_Volume__c'));
        String transactionCount = formatGenericCellValue(safeSObjectValue(leadRecord, 'Number_of_Transactions__c'));
        row.customCells = new List<TableCell>{
            new TableCell('firstName', blankToLabel(firstName, ''), blankToLabel(firstName, ''), true),
            new TableCell('lastName', blankToLabel(lastName, ''), blankToLabel(lastName, ''), false),
            new TableCell('phone', (String) safeSObjectValue(leadRecord, 'Phone'), (String) safeSObjectValue(leadRecord, 'Phone'), false),
            new TableCell('email', (String) safeSObjectValue(leadRecord, 'Email'), (String) safeSObjectValue(leadRecord, 'Email'), false),
            new TableCell('status', leadRecord.Status, leadRecord.Status, false),
            new TableCell('lastBenContact', formatDatetimeForCell(lastBenContactDate), formatDatetimeSortValue(lastBenContactDate), false),
            new TableCell('leadSource', (String) safeSObjectValue(leadRecord, 'LeadSource'), (String) safeSObjectValue(leadRecord, 'LeadSource'), false),
            new TableCell('realtorLeadSource', (String) safeSObjectValue(leadRecord, 'Realtor_Lead_Source__c'), (String) safeSObjectValue(leadRecord, 'Realtor_Lead_Source__c'), false),
            new TableCell('realtorGroup', (String) safeSObjectValue(leadRecord, 'Realtor_Group__c'), (String) safeSObjectValue(leadRecord, 'Realtor_Group__c'), false),
            new TableCell('buyerVolume', buyerVolume, buyerVolume, false),
            new TableCell('county', (String) safeSObjectValue(leadRecord, 'County_of_Operation__c'), (String) safeSObjectValue(leadRecord, 'County_of_Operation__c'), false),
            new TableCell('transactions', transactionCount, transactionCount, false),
            new TableCell('appointmentDateTime', formatDatetimeForCell((Datetime) safeSObjectValue(leadRecord, 'Appointment_Date_Time__c')), formatDatetimeSortValue((Datetime) safeSObjectValue(leadRecord, 'Appointment_Date_Time__c')), false),
            new TableCell('comments', row.detail, row.detail, false)
        };
        return row;
    }

    private static void sortRowsByLastContact(List<PipelineRow> rows) {
        if (rows == null || rows.size() < 2) {
            return;
        }
        for (Integer i = 0; i < rows.size() - 1; i++) {
            for (Integer j = i + 1; j < rows.size(); j++) {
                if (compareRowsByLastContact(rows[j], rows[i]) < 0) {
                    PipelineRow swapRow = rows[i];
                    rows[i] = rows[j];
                    rows[j] = swapRow;
                }
            }
        }
    }

    private static Integer compareRowsByLastContact(PipelineRow leftRow, PipelineRow rightRow) {
        Datetime leftDate = leftRow == null ? null : leftRow.displayDateTime;
        Datetime rightDate = rightRow == null ? null : rightRow.displayDateTime;
        if (leftDate == null && rightDate != null) {
            return -1;
        }
        if (leftDate != null && rightDate == null) {
            return 1;
        }
        if (leftDate != null && rightDate != null) {
            if (leftDate < rightDate) {
                return -1;
            }
            if (leftDate > rightDate) {
                return 1;
            }
        }
        String leftName = leftRow == null || leftRow.name == null ? '' : leftRow.name.toLowerCase();
        String rightName = rightRow == null || rightRow.name == null ? '' : rightRow.name.toLowerCase();
        return leftName.compareTo(rightName);
    }

    private static List<PipelineRow> buildPastClientRows(Integer closingYear) {
        Date yearStart = Date.newInstance(closingYear, 1, 1);
        Date nextYearStart = yearStart.addYears(1);
        List<PipelineRow> rows = new List<PipelineRow>();
        Set<Id> accountIdsSeen = new Set<Id>();
        List<Transaction__c> candidateTransactions = [
            SELECT Id,
                Name,
                Status__c,
                Funding_Date__c,
                Closing_Date__c,
                Loan_Type_1st_TD__c,
                Loan_Purpose__c,
                Loan_Amount_1st__c,
                Occupancy__c,
                Biz_Dev__c,
                Property_Address__c,
                Property_City__c,
                Property_State__c,
                Borrower_Name__c,
                Borrower_Name__r.Name,
                Borrower_Name__r.IsPersonAccount,
                Borrower_Name__r.Phone,
                Borrower_Name__r.PersonMobilePhone,
                Borrower_Name__r.Corrected_Mobile__pc,
                Borrower_Name__r.Corrected_Phone__pc,
                Borrower_Name__r.PersonEmail,
                Borrower_Name__r.PersonBirthdate,
                Borrower_Name__r.LastActivityDate,
                Borrower_Name__r.PersonMailingStreet,
                Borrower_Name__r.PersonMailingCity,
                Borrower_Name__r.PersonMailingState,
                Borrower_Name__r.PersonMailingPostalCode,
                Loan_Officer__r.Name
            FROM Transaction__c
            WHERE Borrower_Name__c != null
            AND Borrower_Name__r.IsPersonAccount = true
            AND (Borrower_Name__r.Phone != null
                OR Borrower_Name__r.PersonMobilePhone != null)
            AND ((Funding_Date__c >= :yearStart AND Funding_Date__c < :nextYearStart)
                OR (Funding_Date__c = null AND Closing_Date__c >= :yearStart AND Closing_Date__c < :nextYearStart))
            AND Status__c != 'Cancelled'
            AND Occupancy__c IN :PAST_CLIENT_PRIMARY_OCCUPANCIES
            AND Loan_Purpose__c = :PAST_CLIENT_PURCHASE_PURPOSE
            AND (Loan_Officer__c = null OR Loan_Officer__r.Name NOT IN :PAST_CLIENT_EXCLUDED_LO_NAMES)
            AND (Biz_Dev__c = null OR Biz_Dev__c NOT IN :PAST_CLIENT_EXCLUDED_BIZ_DEV_VALUES)
            ORDER BY Borrower_Name__r.LastActivityDate ASC NULLS FIRST, Funding_Date__c DESC NULLS LAST, Closing_Date__c DESC NULLS LAST, LastModifiedDate DESC
            LIMIT :PAST_CLIENT_CANDIDATE_SCAN_SIZE
        ];
        Set<Id> candidateAccountIds = new Set<Id>();
        for (Transaction__c transactionRecord : candidateTransactions) {
            candidateAccountIds.add(transactionRecord.Borrower_Name__c);
        }
        Set<Id> recentlyCalledAccountIds = pastClientAccountsCalledByCurrentUser(candidateAccountIds, System.now().addDays(-90));
        Set<Id> todayEventAccountIds = pastClientAccountsWithTodayEventByCurrentUser(candidateAccountIds);
        Map<Id, Datetime> lastCallByAccountId = pastClientLastOutboundCallsByCurrentUser(candidateAccountIds);
        for (Transaction__c transactionRecord : candidateTransactions) {
            if (rows.size() >= PAST_CLIENT_VISIBLE_BATCH_SIZE) {
                break;
            }
            if (recentlyCalledAccountIds.contains(transactionRecord.Borrower_Name__c)
                && !todayEventAccountIds.contains(transactionRecord.Borrower_Name__c)) {
                continue;
            }
            if (!accountIdsSeen.contains(transactionRecord.Borrower_Name__c)) {
                accountIdsSeen.add(transactionRecord.Borrower_Name__c);
                rows.add(buildPastClientRow(transactionRecord, lastCallByAccountId.get(transactionRecord.Borrower_Name__c), false));
            }
        }
        return rows;
    }

    private static List<PipelineRow> buildPastClientRowsByRating(String ratingValue) {
        List<PipelineRow> rows = new List<PipelineRow>();
        List<Account> ratedAccounts = [
            SELECT Id,
                Name,
                Phone,
                PersonMobilePhone,
                PersonEmail,
                PersonBirthdate,
                LastActivityDate,
                PersonMailingStreet,
                PersonMailingCity,
                PersonMailingState,
                PersonMailingPostalCode,
                Borrower_Rating__c
            FROM Account
            WHERE IsPersonAccount = true
            AND Borrower_Rating__c = :ratingValue
            ORDER BY LastActivityDate ASC NULLS FIRST, Name ASC
            LIMIT :PAST_CLIENT_VISIBLE_BATCH_SIZE
        ];
        Set<Id> candidateAccountIds = new Set<Id>();
        for (Account accountRecord : ratedAccounts) {
            candidateAccountIds.add(accountRecord.Id);
        }
        Map<Id, Datetime> lastCallByAccountId = pastClientLastOutboundCallsByCurrentUser(candidateAccountIds);
        for (Account accountRecord : ratedAccounts) {
            rows.add(buildPastClientRatingRow(accountRecord, lastCallByAccountId.get(accountRecord.Id)));
        }
        return rows;
    }

    private static PipelineRow buildPastClientRatingRow(Account accountRecord, Datetime benLastCall) {
        Date birthday = accountRecord.PersonBirthdate;
        Date lastContacted = accountRecord.LastActivityDate;
        String phone = firstNonBlank(new List<String>{
            accountRecord.PersonMobilePhone,
            accountRecord.Phone
        });
        String mailingAddress = buildAddress(new List<String>{
            accountRecord.PersonMailingStreet,
            buildCityStateZip(
                accountRecord.PersonMailingCity,
                accountRecord.PersonMailingState,
                accountRecord.PersonMailingPostalCode
            )
        });

        PipelineRow row = new PipelineRow();
        row.id = accountRecord.Id;
        row.name = accountRecord.Name;
        row.phone = phone;
        row.lastActivityDate = lastContacted;
        row.detail = 'Rating: ' + blankToLabel(accountRecord.Borrower_Rating__c, 'Not rated');
        row.customCells = new List<TableCell>{
            new TableCell('name', accountRecord.Name, accountRecord.Name, true),
            new TableCell('phone', phone, phone, false),
            new TableCell('lastContacted', formatDateForCell(lastContacted), formatDateSortValue(lastContacted), false),
            new TableCell('benLastCall', formatDatetimeForCell(benLastCall), formatDatetimeSortValue(benLastCall), false),
            new TableCell('address', mailingAddress, mailingAddress, false),
            new TableCell('closingDate', null, null, false),
            new TableCell('birthday', formatDateForCell(birthday), formatDateSortValue(birthday), false),
            new TableCell('rating', accountRecord.Borrower_Rating__c, accountRecord.Borrower_Rating__c, false),
            new TableCell('loanType', null, null, false),
            new TableCell('loanPurpose', null, null, false),
            new TableCell('loanOfficer', null, null, false)
        };
        return row;
    }

    private static Integer pastClientYearFromTabKey(String tabKey) {
        if (String.isBlank(tabKey) || !tabKey.startsWith('benPastClients')) {
            return null;
        }
        String suffix = tabKey.replace('benPastClients', '');
        if (String.isBlank(suffix) || suffix.length() != 4 || !Pattern.matches('^\\d{4}$', suffix)) {
            return null;
        }
        return Integer.valueOf(suffix);
    }

    private static Set<Id> pastClientAccountsCalledByCurrentUser(Set<Id> accountIds, Datetime cutoffDateTime) {
        Set<Id> calledAccountIds = new Set<Id>();
        if (accountIds == null || accountIds.isEmpty()) {
            return calledAccountIds;
        }
        Id currentUserId = UserInfo.getUserId();
        for (Task taskRecord : [
            SELECT WhatId, Subject, TaskSubtype, CallType
            FROM Task
            WHERE OwnerId = :currentUserId
            AND WhatId IN :accountIds
            AND CreatedDate >= :cutoffDateTime
            AND (TaskSubtype = 'Call' OR CallType != null OR Subject LIKE '%Call%' OR Subject LIKE '%RingCentral%')
            LIMIT 50000
        ]) {
            if (isOutboundCallTask(taskRecord)) {
                calledAccountIds.add(taskRecord.WhatId);
            }
        }
        return calledAccountIds;
    }

    private static Set<Id> pastClientAccountsWithTodayEventByCurrentUser(Set<Id> accountIds) {
        Set<Id> todayEventAccountIds = new Set<Id>();
        if (accountIds == null || accountIds.isEmpty()) {
            return todayEventAccountIds;
        }
        Id currentUserId = UserInfo.getUserId();
        Datetime todayStart = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        Datetime tomorrowStart = todayStart.addDays(1);
        for (Event eventRecord : [
            SELECT WhatId
            FROM Event
            WHERE OwnerId = :currentUserId
            AND WhatId IN :accountIds
            AND StartDateTime >= :todayStart
            AND StartDateTime < :tomorrowStart
            LIMIT 50000
        ]) {
            todayEventAccountIds.add(eventRecord.WhatId);
        }
        return todayEventAccountIds;
    }

    private static Map<Id, Datetime> pastClientLastOutboundCallsByCurrentUser(Set<Id> accountIds) {
        Map<Id, Datetime> callsByAccountId = new Map<Id, Datetime>();
        if (accountIds == null || accountIds.isEmpty()) {
            return callsByAccountId;
        }
        Id currentUserId = UserInfo.getUserId();
        for (Task taskRecord : [
            SELECT WhatId, CreatedDate, Subject, TaskSubtype, CallType
            FROM Task
            WHERE OwnerId = :currentUserId
            AND WhatId IN :accountIds
            AND (TaskSubtype = 'Call' OR CallType != null OR Subject LIKE '%Call%' OR Subject LIKE '%RingCentral%')
            ORDER BY CreatedDate DESC
            LIMIT 50000
        ]) {
            if (!isOutboundCallTask(taskRecord)) {
                continue;
            }
            Datetime currentDate = callsByAccountId.get(taskRecord.WhatId);
            if (currentDate == null || taskRecord.CreatedDate > currentDate) {
                callsByAccountId.put(taskRecord.WhatId, taskRecord.CreatedDate);
            }
        }
        return callsByAccountId;
    }

    private static PipelineRow buildPastClientRow(Transaction__c transactionRecord, Datetime benLastCall, Boolean includeRating) {
        SObject accountRecord = safeRelationshipValue(transactionRecord, 'Borrower_Name__r');
        Date fundingDate = (Date) safeSObjectValue(transactionRecord, 'Funding_Date__c');
        Date closingDate = (Date) safeSObjectValue(transactionRecord, 'Closing_Date__c');
        Date displayClosedDate = fundingDate == null ? closingDate : fundingDate;
        Date birthday = accountRecord == null ? null : (Date) safeSObjectValue(accountRecord, 'PersonBirthdate');
        Date lastContacted = accountRecord == null ? null : (Date) safeSObjectValue(accountRecord, 'LastActivityDate');
        String borrowerName = accountRecord == null ? transactionRecord.Name : (String) safeSObjectValue(accountRecord, 'Name');
        String phone = firstNonBlank(new List<String>{
            accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'PersonMobilePhone'),
            accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'Phone')
        });
        String mailingAddress = buildAddress(new List<String>{
            accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'PersonMailingStreet'),
            buildCityStateZip(
                accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'PersonMailingCity'),
                accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'PersonMailingState'),
                accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'PersonMailingPostalCode')
            )
        });
        String borrowerRating = accountRecord == null ? null : (String) safeSObjectValue(accountRecord, 'Borrower_Rating__c');
        String loanOfficerName = null;
        SObject loanOfficerRecord = safeRelationshipValue(transactionRecord, 'Loan_Officer__r');
        if (loanOfficerRecord != null) {
            loanOfficerName = (String) safeSObjectValue(loanOfficerRecord, 'Name');
        }
        String loanType = (String) safeSObjectValue(transactionRecord, 'Loan_Type_1st_TD__c');
        String loanPurpose = (String) safeSObjectValue(transactionRecord, 'Loan_Purpose__c');
        PipelineRow row = new PipelineRow();
        row.id = (Id) safeSObjectValue(transactionRecord, 'Borrower_Name__c');
        row.name = borrowerName;
        row.phone = phone;
        row.displayDate = displayClosedDate;
        row.lastActivityDate = lastContacted;
        row.loanType = loanType;
        row.loanPurpose = loanPurpose;
        row.loanOfficerName = loanOfficerName;
        row.detail = 'Closed ' + formatDateForCell(displayClosedDate) + ' | ' + blankToLabel(loanPurpose, 'Purpose not set') + ' | ' + blankToLabel(loanType, 'Loan type not set');
        row.customCells = new List<TableCell>{
            new TableCell('name', borrowerName, borrowerName, true),
            new TableCell('phone', phone, phone, false),
            new TableCell('lastContacted', formatDateForCell(lastContacted), formatDateSortValue(lastContacted), false),
            new TableCell('benLastCall', formatDatetimeForCell(benLastCall), formatDatetimeSortValue(benLastCall), false),
            new TableCell('address', mailingAddress, mailingAddress, false),
            new TableCell('closingDate', formatDateForCell(displayClosedDate), formatDateSortValue(displayClosedDate), false),
            new TableCell('birthday', formatDateForCell(birthday), formatDateSortValue(birthday), false)
        };
        if (includeRating) {
            row.customCells.add(new TableCell('rating', borrowerRating, borrowerRating, false));
        }
        row.customCells.addAll(new List<TableCell>{
            new TableCell('loanType', loanType, loanType, false),
            new TableCell('loanPurpose', loanPurpose, loanPurpose, false),
            new TableCell('loanOfficer', loanOfficerName, loanOfficerName, false)
        });
        return row;
    }

    private static List<PipelineTab> buildAssistedLoanOfficerTabs(User loanOfficer, String keyPrefix, String displayName) {
        return buildAssistedLoanOfficerTabs(loanOfficer, keyPrefix, displayName, null);
    }

    private static List<PipelineTab> buildAssistedLoanOfficerTabs(User loanOfficer, String keyPrefix, String displayName, Id partnerId) {
        Set<Id> leadScopeUserIds = loanOfficer == null ? new Set<Id>() : new Set<Id>{ loanOfficer.Id };
        Boolean requireLoanPartner = partnerId != null;
        List<TableColumn> leadColumns = buildLoanOfficerLeadColumns();
        List<TableColumn> transactionColumns = buildLoanOfficerTransactionColumns();
        return new List<PipelineTab>{
            new PipelineTab(
                keyPrefix + 'ActiveLeads',
                displayName + ' Active Leads',
                requireLoanPartner
                    ? displayName + ' active leads where you are the assigned Loan Partner.'
                    : displayName + ' active leads in contact, application, document, and contract statuses.',
                'Lead',
                applyLoanOfficerLeadCells(
                    requireLoanPartner
                        ? buildLeadRowsByOwnerScope(new Set<Id>(), loanOfficer == null ? null : loanOfficer.Id, partnerId, true, 'active', 50)
                        : buildAssignedLeads(leadScopeUserIds)
                ),
                leadColumns
            ),
            new PipelineTab(
                keyPrefix + 'NewLeadAlerts',
                displayName + ' New Leads',
                requireLoanPartner
                    ? displayName + ' New status leads where you are the assigned Loan Partner.'
                    : displayName + ' leads currently in New status.',
                'Lead',
                applyLoanOfficerLeadCells(
                    requireLoanPartner
                        ? buildLeadRowsByOwnerScope(new Set<Id>(), loanOfficer == null ? null : loanOfficer.Id, partnerId, true, 'new', 50)
                        : buildNewLeadAlerts(leadScopeUserIds)
                ),
                leadColumns
            ),
            new PipelineTab(
                keyPrefix + 'StagnantLeads',
                displayName + ' Stagnant Leads',
                requireLoanPartner
                    ? displayName + ' open leads with no activity in the last 7 days where you are the assigned Loan Partner.'
                    : displayName + ' open leads with no activity in the last 7 days.',
                'Lead',
                applyLoanOfficerLeadCells(
                    requireLoanPartner
                        ? buildLeadRowsByOwnerScope(new Set<Id>(), loanOfficer == null ? null : loanOfficer.Id, partnerId, true, 'stagnant', 50)
                        : buildStagnantLeads(leadScopeUserIds)
                ),
                leadColumns
            ),
            new PipelineTab(
                keyPrefix + 'AttentionLeads',
                displayName + ' Leads Needing Attention',
                requireLoanPartner
                    ? displayName + ' purchase leads matching the Lead Appointment Report attention criteria where you are the assigned Loan Partner.'
                    : displayName + ' purchase leads matching the Lead Appointment Report attention criteria.',
                'Lead',
                applyLoanOfficerLeadCells(
                    requireLoanPartner
                        ? buildLeadRowsByOwnerScope(new Set<Id>(), loanOfficer == null ? null : loanOfficer.Id, partnerId, true, 'attention', 50)
                        : buildLeadsNeedingAttention(leadScopeUserIds)
                ),
                leadColumns
            ),
            new PipelineTab(
                keyPrefix + 'EventsToday',
                displayName + ' Events Today',
                requireLoanPartner
                    ? displayName + ' leads with calendar events scheduled today where you are the assigned Loan Partner.'
                    : displayName + ' leads with calendar events scheduled today.',
                'Lead',
                applyLoanOfficerLeadCells(
                    requireLoanPartner
                        ? buildLeadRowsByOwnerScope(new Set<Id>(), loanOfficer == null ? null : loanOfficer.Id, partnerId, true, 'eventsToday', 50)
                        : buildLeadsWithEventsToday(leadScopeUserIds)
                ),
                leadColumns
            ),
            new PipelineTab(
                keyPrefix + 'DisclosuresNeedingSigned',
                displayName + ' Disclosures Needing Signed',
                requireLoanPartner
                    ? displayName + ' transactions in Disclosures Out status where disclosures have not been received and you are the assigned Loan Partner.'
                    : displayName + ' transactions in Disclosures Out status where disclosures have not been received.',
                'Transaction__c',
                applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(leadScopeUserIds, loanOfficer == null ? null : loanOfficer.Id, partnerId, requireLoanPartner, 'disclosures', 100)),
                transactionColumns
            ),
            new PipelineTab(
                keyPrefix + 'ActiveTransactions',
                displayName + ' Active Transactions',
                requireLoanPartner
                    ? displayName + ' transactions that are still in active statuses where you are the assigned Loan Partner.'
                    : displayName + ' transactions that are still in active statuses.',
                'Transaction__c',
                applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(leadScopeUserIds, loanOfficer == null ? null : loanOfficer.Id, partnerId, requireLoanPartner, 'active', 100)),
                transactionColumns
            ),
            new PipelineTab(
                keyPrefix + 'ClosedThisMonth',
                displayName + ' Transactions Closed this Month',
                requireLoanPartner
                    ? displayName + ' funded, review, and post-closed files with a funding date in the current month where you are the assigned Loan Partner.'
                    : displayName + ' funded, review, and post-closed files with a funding date in the current month.',
                'Transaction__c',
                applyLoanOfficerTransactionCells(buildTransactionRowsByLoanOfficerScope(leadScopeUserIds, loanOfficer == null ? null : loanOfficer.Id, partnerId, requireLoanPartner, 'closedThisMonth', 100)),
                transactionColumns
            )
        };
    }

    private static List<ConversionMetricRow> buildConversionMetricRows() {
        Date currentYearStart = Date.newInstance(Date.today().year(), 1, 1);
        DateTime currentYearStartDateTime = DateTime.newInstanceGmt(Date.today().year(), 1, 1, 0, 0, 0);
        List<User> loanOfficers = new List<User>();
        for (User userRecord : [
            SELECT Id, Name, Title, Profile.Name, UserRole.Name
            FROM User
            WHERE IsActive = true
            ORDER BY Name
        ]) {
            String normalizedUserName = String.isBlank(userRecord.Name) ? '' : userRecord.Name.toLowerCase();
            if (!EXCLUDED_CONVERSION_USER_NAMES.contains(normalizedUserName)
                && (userLooksLikeLoanOfficer(userRecord) || userRecord.Id == UserInfo.getUserId())) {
                loanOfficers.add(userRecord);
            }
        }

        Set<Id> loanOfficerIds = new Set<Id>();
        Map<Id, String> loanOfficerNamesById = new Map<Id, String>();
        for (User loanOfficer : loanOfficers) {
            loanOfficerIds.add(loanOfficer.Id);
            loanOfficerNamesById.put(loanOfficer.Id, loanOfficer.Name);
        }
        if (loanOfficerIds.isEmpty()) {
            return new List<ConversionMetricRow>();
        }

        Map<Id, Integer> newLeadCounts = new Map<Id, Integer>();
        Map<Id, Integer> newLeadToPreApprovalCounts = new Map<Id, Integer>();
        Map<Id, Set<Id>> newLeadIdsByLoanOfficerId = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> convertedAccountIdsByLoanOfficerId = new Map<Id, Set<Id>>();
        Map<Id, Id> convertedAccountToLeadId = new Map<Id, Id>();
        for (Lead leadRecord : [
            SELECT Id, OwnerId, Loan_Partner__c, Pre_Approval_Date__c, ConvertedAccountId
            FROM Lead
            WHERE CreatedDate >= :currentYearStart
            AND (OwnerId IN :loanOfficerIds OR Loan_Partner__c IN :loanOfficerIds)
            LIMIT 50000
        ]) {
            Set<Id> assignedUserIds = assignedLoanOfficerIds(leadRecord.OwnerId, leadRecord.Loan_Partner__c, loanOfficerIds);
            for (Id assignedUserId : assignedUserIds) {
                addIdToSet(newLeadIdsByLoanOfficerId, assignedUserId, leadRecord.Id);
                incrementCount(newLeadCounts, assignedUserId);
                if (leadRecord.Pre_Approval_Date__c != null && leadRecord.Pre_Approval_Date__c >= currentYearStart) {
                    incrementCount(newLeadToPreApprovalCounts, assignedUserId);
                }
                if (leadRecord.ConvertedAccountId != null) {
                    addIdToSet(convertedAccountIdsByLoanOfficerId, assignedUserId, leadRecord.ConvertedAccountId);
                    convertedAccountToLeadId.put(leadRecord.ConvertedAccountId, leadRecord.Id);
                }
            }
        }
        Map<Id, Integer> preApprovalLeadCounts = new Map<Id, Integer>();
        Map<Id, Set<Id>> preApprovalLeadIdsByLoanOfficerId = new Map<Id, Set<Id>>();
        for (Lead leadRecord : [
            SELECT Id, OwnerId, Loan_Partner__c, ConvertedAccountId
            FROM Lead
            WHERE Pre_Approval_Date__c >= :currentYearStart
            AND (OwnerId IN :loanOfficerIds OR Loan_Partner__c IN :loanOfficerIds)
            LIMIT 50000
        ]) {
            Set<Id> assignedUserIds = assignedLoanOfficerIds(leadRecord.OwnerId, leadRecord.Loan_Partner__c, loanOfficerIds);
            for (Id assignedUserId : assignedUserIds) {
                addIdToSet(preApprovalLeadIdsByLoanOfficerId, assignedUserId, leadRecord.Id);
                incrementCount(preApprovalLeadCounts, assignedUserId);
                if (leadRecord.ConvertedAccountId != null) {
                    addIdToSet(convertedAccountIdsByLoanOfficerId, assignedUserId, leadRecord.ConvertedAccountId);
                    convertedAccountToLeadId.put(leadRecord.ConvertedAccountId, leadRecord.Id);
                }
            }
        }

        Map<Id, Integer> transactionCounts = new Map<Id, Integer>();
        Map<Id, Integer> postClosedTransactionCounts = new Map<Id, Integer>();
        Map<Id, Set<Id>> transactionLeadIdsByLoanOfficerId = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> postClosedLeadIdsByLoanOfficerId = new Map<Id, Set<Id>>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Loan_Officer__c, Account__c, Borrower_Name__c, New_Follow_Up_Lead__c, Status__c, Closing_Date__c
            FROM Transaction__c
            WHERE (CreatedDate >= :currentYearStartDateTime OR Closing_Date__c >= :currentYearStart)
            AND Loan_Officer__c IN :loanOfficerIds
            AND Status__c != 'Cancelled'
        ]) {
            if (transactionRecord.Status__c == 'Post-Closed' && transactionRecord.Closing_Date__c >= currentYearStart) {
                Id postClosedClientId = transactionRecord.Borrower_Name__c != null
                    ? transactionRecord.Borrower_Name__c
                    : (transactionRecord.Account__c != null ? transactionRecord.Account__c : transactionRecord.Id);
                addIdToSet(postClosedLeadIdsByLoanOfficerId, transactionRecord.Loan_Officer__c, postClosedClientId);
            }

            Id convertedLeadId = convertedLeadIdForTransaction(transactionRecord, convertedAccountToLeadId);
            if (convertedLeadId == null
                || !setContainsId(preApprovalLeadIdsByLoanOfficerId, transactionRecord.Loan_Officer__c, convertedLeadId)) {
                continue;
            }
            addIdToSet(transactionLeadIdsByLoanOfficerId, transactionRecord.Loan_Officer__c, convertedLeadId);
        }
        for (Id loanOfficerId : transactionLeadIdsByLoanOfficerId.keySet()) {
            transactionCounts.put(loanOfficerId, transactionLeadIdsByLoanOfficerId.get(loanOfficerId).size());
        }
        for (Id loanOfficerId : postClosedLeadIdsByLoanOfficerId.keySet()) {
            postClosedTransactionCounts.put(loanOfficerId, postClosedLeadIdsByLoanOfficerId.get(loanOfficerId).size());
        }

        Date activeDaysStartDate = Date.today().addMonths(-12);
        Map<Id, Decimal> averageActiveDaysByUserId = buildAverageActiveDaysByLoanOfficer(loanOfficerIds, activeDaysStartDate);
        List<ConversionMetricRow> rows = new List<ConversionMetricRow>();
        for (User loanOfficer : loanOfficers) {
            Integer newLeadCount = countFor(newLeadCounts, loanOfficer.Id);
            Integer newLeadToPreApprovalCount = countFor(newLeadToPreApprovalCounts, loanOfficer.Id);
            Integer preApprovalCount = countFor(preApprovalLeadCounts, loanOfficer.Id);
            Integer transactionCount = countFor(transactionCounts, loanOfficer.Id);
            Integer postClosedCount = countFor(postClosedTransactionCounts, loanOfficer.Id);
            rows.add(new ConversionMetricRow(
                loanOfficer.Id,
                loanOfficerNamesById.get(loanOfficer.Id),
                percent(newLeadToPreApprovalCount, newLeadCount),
                percent(transactionCount, preApprovalCount),
                percent(postClosedCount, newLeadCount),
                averageActiveDaysByUserId.get(loanOfficer.Id)
            ));
        }
        return rows;
    }

    private static Boolean userLooksLikeLoanOfficer(User userRecord) {
        List<String> descriptorParts = new List<String>();
        if (String.isNotBlank(userRecord.Title)) {
            descriptorParts.add(userRecord.Title);
        }
        if (userRecord.Profile != null && String.isNotBlank(userRecord.Profile.Name)) {
            descriptorParts.add(userRecord.Profile.Name);
        }
        if (userRecord.UserRole != null && String.isNotBlank(userRecord.UserRole.Name)) {
            descriptorParts.add(userRecord.UserRole.Name);
        }
        String descriptor = String.join(descriptorParts, ' ').toLowerCase();
        return !descriptor.contains('processor')
            && (
                descriptor.contains('loan officer')
                || descriptor.contains('loan originator')
                || descriptor.contains('outside lo')
                || descriptor.contains('inside lo')
            );
    }

    private static Set<Id> assignedLoanOfficerIds(Id ownerId, Id loanPartnerId, Set<Id> loanOfficerIds) {
        Set<Id> assignedUserIds = new Set<Id>();
        if (loanOfficerIds.contains(ownerId)) {
            assignedUserIds.add(ownerId);
        }
        if (loanOfficerIds.contains(loanPartnerId)) {
            assignedUserIds.add(loanPartnerId);
        }
        return assignedUserIds;
    }

    private static void addIdToSet(Map<Id, Set<Id>> valuesByOwnerId, Id ownerId, Id value) {
        if (ownerId == null || value == null) {
            return;
        }
        if (!valuesByOwnerId.containsKey(ownerId)) {
            valuesByOwnerId.put(ownerId, new Set<Id>());
        }
        valuesByOwnerId.get(ownerId).add(value);
    }

    private static Boolean setContainsId(Map<Id, Set<Id>> valuesByOwnerId, Id ownerId, Id value) {
        return valuesByOwnerId.containsKey(ownerId) && valuesByOwnerId.get(ownerId).contains(value);
    }

    private static Id convertedLeadIdForTransaction(Transaction__c transactionRecord, Map<Id, Id> convertedAccountToLeadId) {
        if (transactionRecord.New_Follow_Up_Lead__c != null) {
            return transactionRecord.New_Follow_Up_Lead__c;
        }
        if (transactionRecord.Borrower_Name__c != null && convertedAccountToLeadId.containsKey(transactionRecord.Borrower_Name__c)) {
            return convertedAccountToLeadId.get(transactionRecord.Borrower_Name__c);
        }
        if (transactionRecord.Account__c != null && convertedAccountToLeadId.containsKey(transactionRecord.Account__c)) {
            return convertedAccountToLeadId.get(transactionRecord.Account__c);
        }
        return null;
    }

    private static Map<Id, Decimal> buildAverageActiveDaysByLoanOfficer(Set<Id> loanOfficerIds, Date startDate) {
        Map<Id, Decimal> totalDaysByUserId = new Map<Id, Decimal>();
        Map<Id, Integer> leadCountsByUserId = new Map<Id, Integer>();
        Set<Id> processedLeadIds = new Set<Id>();
        for (LeadHistory historyRecord : [
            SELECT LeadId, CreatedDate, NewValue, Lead.CreatedDate, Lead.OwnerId, Lead.Loan_Partner__c
            FROM LeadHistory
            WHERE Field = 'Status'
            AND Lead.CreatedDate >= :startDate
            AND (Lead.OwnerId IN :loanOfficerIds OR Lead.Loan_Partner__c IN :loanOfficerIds)
            ORDER BY LeadId ASC, CreatedDate ASC
            LIMIT 50000
        ]) {
            if (processedLeadIds.contains(historyRecord.LeadId)
                || !isAverageActiveDaysDestinationStatus(String.valueOf(historyRecord.NewValue))) {
                continue;
            }
            processedLeadIds.add(historyRecord.LeadId);
            Decimal activeDays = historyRecord.Lead.CreatedDate.date().daysBetween(historyRecord.CreatedDate.date());
            for (Id assignedUserId : assignedLoanOfficerIds(historyRecord.Lead.OwnerId, historyRecord.Lead.Loan_Partner__c, loanOfficerIds)) {
                totalDaysByUserId.put(assignedUserId, (totalDaysByUserId.containsKey(assignedUserId) ? totalDaysByUserId.get(assignedUserId) : 0) + activeDays);
                incrementCount(leadCountsByUserId, assignedUserId);
            }
        }

        Map<Id, Decimal> averagesByUserId = new Map<Id, Decimal>();
        for (Id userId : totalDaysByUserId.keySet()) {
            Integer leadCount = countFor(leadCountsByUserId, userId);
            if (leadCount > 0) {
                averagesByUserId.put(userId, (totalDaysByUserId.get(userId) / leadCount).setScale(1));
            }
        }
        return averagesByUserId;
    }

    private static Boolean isAverageActiveDaysDestinationStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }
        String normalizedStatus = statusValue.toLowerCase();
        return normalizedStatus.contains('nurtur')
            || normalizedStatus == 'pre-approval'
            || normalizedStatus == 'preapproval'
            || normalizedStatus == 'pre approval';
    }

    private static void incrementCount(Map<Id, Integer> countsById, Id recordId) {
        countsById.put(recordId, countFor(countsById, recordId) + 1);
    }

    private static Integer countFor(Map<Id, Integer> countsById, Id recordId) {
        return countsById.containsKey(recordId) ? countsById.get(recordId) : 0;
    }

    private static Decimal percent(Integer numerator, Integer denominator) {
        if (denominator == null || denominator == 0 || numerator == null) {
            return 0;
        }
        return (Decimal.valueOf(numerator) * 100 / Decimal.valueOf(denominator)).setScale(1);
    }

    private static Date currentQuarterStart(Date value) {
        Integer quarterStartMonth = (((value.month() - 1) / 3) * 3) + 1;
        return Date.newInstance(value.year(), quarterStartMonth, 1);
    }

    private static Date nextQuarterStart(Date value) {
        return currentQuarterStart(value).addMonths(3);
    }

    private static List<TableColumn> buildMetricColumns(String first, String second, String third, String fourth, String fifth) {
        return new List<TableColumn>{
            new TableColumn('metric0', first),
            new TableColumn('metric1', second),
            new TableColumn('metric2', third),
            new TableColumn('metric3', fourth),
            new TableColumn('metric4', fifth)
        };
    }

    private static PipelineRow metricRow(List<String> values) {
        return metricRow(values, new Map<Integer, String>());
    }

    private static PipelineRow metricRow(List<String> values, Map<Integer, String> urlsByIndex) {
        PipelineRow row = new PipelineRow();
        row.name = values == null || values.isEmpty() ? 'Metric' : values[0];
        row.customCells = new List<TableCell>();
        Integer valueCount = values == null ? 0 : values.size();
        for (Integer i = 0; i < valueCount; i++) {
            String key = 'metric' + String.valueOf(i);
            String url = urlsByIndex == null ? null : urlsByIndex.get(i);
            row.customCells.add(new TableCell(key, values[i], values[i], false, null, url));
        }
        return row;
    }

    private static Map<Integer, String> reportLinkOnMetric(String reportId) {
        return new Map<Integer, String>{ 0 => reportUrl(reportId, null) };
    }

    private static Integer aggregateInteger(AggregateResult result, String aliasName) {
        Object rawValue = result == null ? null : result.get(aliasName);
        if (rawValue == null) {
            return 0;
        }
        return Integer.valueOf(String.valueOf(rawValue));
    }

    private static Decimal aggregateDecimal(AggregateResult result, String aliasName) {
        Object rawValue = result == null ? null : result.get(aliasName);
        if (rawValue == null) {
            return 0;
        }
        return Decimal.valueOf(String.valueOf(rawValue));
    }

    private static String blankToLabel(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }

    private static String formatCurrency(Decimal value) {
        Decimal safeValue = value == null ? 0 : value;
        return '$' + safeValue.setScale(0).format();
    }

    private static String leadFunnelBucket(String statusValue) {
        if (String.isBlank(statusValue)) {
            return null;
        }
        String normalized = statusValue.toLowerCase();
        if (normalized == 'new') {
            return 'New';
        }
        if (normalized.contains('contact')) {
            return 'Contacted';
        }
        if (normalized.contains('application')) {
            return 'Application';
        }
        if (normalized.contains('document')) {
            return 'Docs';
        }
        if (normalized == 'under contract') {
            return 'Under Contract';
        }
        if (normalized.contains('pre-approval') || normalized.contains('preapproval') || normalized.contains('pre approval')) {
            return 'Pre-Approval';
        }
        return null;
    }

    private static Integer countStaleLeads(Integer daysUntouched) {
        Date staleDate = Date.today().addDays(-daysUntouched);
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND Status IN :ACTIVE_LEAD_STATUSES
            AND (LastActivityDate = null OR LastActivityDate <= :staleDate)
        ];
    }

    private static Integer fundedUnits(Date startDate, Date endDate) {
        return [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
    }

    private static Decimal fundedVolume(Date startDate, Date endDate) {
        List<AggregateResult> results = [
            SELECT SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        return results.isEmpty() ? 0 : aggregateDecimal(results[0], 'volume');
    }

    private static Integer closingUnits(Date startDate, Date endDate) {
        return [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Closing_Date__c >= :startDate
            AND Closing_Date__c < :endDate
            AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
    }

    private static Decimal closingVolume(Date startDate, Date endDate) {
        List<AggregateResult> results = [
            SELECT SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Closing_Date__c >= :startDate
            AND Closing_Date__c < :endDate
            AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        return results.isEmpty() ? 0 : aggregateDecimal(results[0], 'volume');
    }

    private static Decimal averageLoanSize(Date startDate, Date endDate) {
        List<AggregateResult> results = [
            SELECT AVG(Loan_Amount_1st__c) averageAmount
            FROM Transaction__c
            WHERE Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        return results.isEmpty() ? 0 : aggregateDecimal(results[0], 'averageAmount');
    }

    private static void addCycleTimeRows(List<PipelineRow> rows) {
        Decimal processingDays = 0;
        Decimal underwritingDays = 0;
        Decimal totalCycleDays = 0;
        Integer processingCount = 0;
        Integer underwritingCount = 0;
        Integer totalCycleCount = 0;
        for (Transaction__c transactionRecord : [
            SELECT CreatedDate, Submitted_to_Processing_Date__c, Submitted_to_Underwriting_Date__c,
                Conditionally_Approved_Date__c, Approved_Date__c, Funding_Date__c
            FROM Transaction__c
            WHERE Funding_Date__c = LAST_N_DAYS:365
            AND Status__c != 'Cancelled'
            LIMIT 2000
        ]) {
            Date createdDate = transactionRecord.CreatedDate.date();
            if (transactionRecord.Submitted_to_Processing_Date__c != null
                && transactionRecord.Submitted_to_Underwriting_Date__c != null) {
                processingDays += transactionRecord.Submitted_to_Processing_Date__c.daysBetween(transactionRecord.Submitted_to_Underwriting_Date__c.date());
                processingCount++;
            }
            Date underwritingEndDate = transactionRecord.Approved_Date__c == null
                ? transactionRecord.Conditionally_Approved_Date__c
                : transactionRecord.Approved_Date__c;
            if (transactionRecord.Submitted_to_Underwriting_Date__c != null && underwritingEndDate != null) {
                underwritingDays += transactionRecord.Submitted_to_Underwriting_Date__c.date().daysBetween(underwritingEndDate);
                underwritingCount++;
            }
            if (transactionRecord.Funding_Date__c != null) {
                totalCycleDays += createdDate.daysBetween(transactionRecord.Funding_Date__c);
                totalCycleCount++;
            }
        }
        rows.add(metricRow(new List<String>{ 'Cycle Time', 'Avg days in processing', '', averageText(processingDays, processingCount), 'Funded files from the last 365 days.' }));
        rows.add(metricRow(new List<String>{ 'Cycle Time', 'Avg days in underwriting', '', averageText(underwritingDays, underwritingCount), 'Submitted to underwriting through approval/CLA.' }));
        rows.add(metricRow(new List<String>{ 'Cycle Time', 'Avg total cycle time', '', averageText(totalCycleDays, totalCycleCount), 'Transaction created date through funding.' }));
    }

    private static String averageText(Decimal totalValue, Integer countValue) {
        if (countValue == null || countValue == 0) {
            return '0.0 days';
        }
        return String.valueOf((totalValue / countValue).setScale(1)) + ' days';
    }

    private static Integer transactionUnitsCreated(Date startDate, Date endDate) {
        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0));
        return [
            SELECT COUNT()
            FROM Transaction__c
            WHERE CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            AND Status__c != 'Cancelled'
        ];
    }

    private static Integer leadUnitsCreated(Date startDate, Date endDate) {
        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0));
        return [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
        ];
    }

    private static Map<Id, Integer> fundedUnitsByLoanOfficer(Set<Id> loanOfficerIds, Date startDate, Date endDate) {
        Map<Id, Integer> valuesByLoanOfficerId = new Map<Id, Integer>();
        for (AggregateResult result : [
            SELECT Loan_Officer__c loanOfficerId, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE Loan_Officer__c IN :loanOfficerIds
            AND Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
            GROUP BY Loan_Officer__c
        ]) {
            valuesByLoanOfficerId.put((Id) result.get('loanOfficerId'), aggregateInteger(result, 'recordCount'));
        }
        return valuesByLoanOfficerId;
    }

    private static Map<Id, Decimal> fundedVolumeByLoanOfficer(Set<Id> loanOfficerIds, Date startDate, Date endDate) {
        Map<Id, Decimal> valuesByLoanOfficerId = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Loan_Officer__c loanOfficerId, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Loan_Officer__c IN :loanOfficerIds
            AND Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND Status__c != 'Cancelled'
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
            GROUP BY Loan_Officer__c
        ]) {
            valuesByLoanOfficerId.put((Id) result.get('loanOfficerId'), aggregateDecimal(result, 'volume'));
        }
        return valuesByLoanOfficerId;
    }

    private static Map<Id, Decimal> pipelineVolumeByLoanOfficer(Set<Id> loanOfficerIds) {
        Map<Id, Decimal> valuesByLoanOfficerId = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Loan_Officer__c loanOfficerId, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Loan_Officer__c IN :loanOfficerIds
            AND Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            GROUP BY Loan_Officer__c
        ]) {
            valuesByLoanOfficerId.put((Id) result.get('loanOfficerId'), aggregateDecimal(result, 'volume'));
        }
        return valuesByLoanOfficerId;
    }

    private static Integer integerFor(Map<Id, Integer> valuesById, Id recordId) {
        return valuesById != null && valuesById.containsKey(recordId) ? valuesById.get(recordId) : 0;
    }

    private static Decimal decimalFor(Map<Id, Decimal> valuesById, Id recordId) {
        return valuesById != null && valuesById.containsKey(recordId) ? valuesById.get(recordId) : 0;
    }

    private static Integer integerFor(Map<String, Integer> valuesByKey, String key) {
        return valuesByKey != null && valuesByKey.containsKey(key) ? valuesByKey.get(key) : 0;
    }

    private static Decimal decimalFor(Map<String, Decimal> valuesByKey, String key) {
        return valuesByKey != null && valuesByKey.containsKey(key) ? valuesByKey.get(key) : 0;
    }

    private static String monthKey(Integer yearValue, Integer monthValue) {
        return String.valueOf(yearValue) + '-' + String.valueOf(monthValue);
    }

    private static Boolean userLooksOutsideLoanOfficer(User userRecord) {
        String combinedText = (
            blankToLabel(userRecord.Title, '') + ' ' +
            (userRecord.UserRole == null ? '' : blankToLabel(userRecord.UserRole.Name, '')) + ' ' +
            (userRecord.Profile == null ? '' : blankToLabel(userRecord.Profile.Name, ''))
        ).toLowerCase();
        return combinedText.contains('outside');
    }

    private static String reportUrl(String reportId, String loanOfficerName) {
        return '/lightning/r/Report/' + reportId + '/view';
    }

    private static List<PipelineTab> buildOpenerPipelineTabs(List<PipelineRow> readyForDisclosureRows) {
        return new List<PipelineTab>{
            new PipelineTab(
                'readyForDisclosures',
                'Ready for Disclosures',
                'Files in Submission Form Complete status. Open the file to work the Opener Checklist in the Activity tab.',
                'Transaction__c',
                readyForDisclosureRows
            ),
            new PipelineTab(
                'waitingOnSignatures',
                'Waiting on Signatures',
                'Files in Disclosures Out status waiting for signed disclosures.',
                'Transaction__c',
                buildOpenerTransactionsByStatus('Disclosures Out')
            ),
            new PipelineTab(
                'readyToOpen',
                'Ready to Open',
                'Files in Pre-Processing status ready for opening review.',
                'Transaction__c',
                buildOpenerTransactionsByStatus('Pre-Processing')
            ),
            new PipelineTab(
                'myPersonalLeads',
                'My personal Leads',
                'Leads where you are listed as the Lead Owner.',
                'Lead',
                applyLoanOfficerLeadCells(
                    buildLeadRowsByOwnerScope(new Set<Id>{ UserInfo.getUserId() }, null, null, false, 'active', 50)
                ),
                buildLoanOfficerLeadColumns()
            ),
            new PipelineTab(
                'appraisalsOutstanding',
                'Appraisals Outstanding',
                'Files with ordered appraisals still waiting on received/completed status.',
                'Transaction__c',
                buildOpenerAppraisalsOutstandingTransactions(),
                buildOpenerAppraisalsOutstandingColumns()
            ),
            new PipelineTab(
                'brokerChecksOutstanding',
                'Broker Checks Outstanding',
                'Broker channel files with broker checks still outstanding.',
                'Transaction__c',
                buildBrokerChecksOutstandingTransactions(),
                buildBrokerChecksOutstandingColumns()
            )
        };
    }

    private static List<PipelineTab> buildCeoPipelineTabs() {
        return new List<PipelineTab>{
            new PipelineTab(
                'ceoLeads',
                'Leads',
                'Where leads are coming from, who owns them, and how they are moving through the funnel.',
                'Metric',
                buildCeoLeadRows(),
                buildMetricColumns('Metric', 'Segment', 'Count', 'Rate / Value', 'Notes')
            ),
            new PipelineTab(
                'ceoTransactions',
                'Transactions',
                'Pipeline stage, loan mix, pull-through, production periods, and cycle-time signals.',
                'Metric',
                buildCeoTransactionRows(),
                buildMetricColumns('Metric', 'Segment', 'Count', 'Rate / Value', 'Notes')
            ),
            new PipelineTab(
                'ceoTrends',
                'Trends',
                'Rolling 12-month production, lead flow, application flow, and mix momentum.',
                'Metric',
                buildCeoTrendRows(),
                buildMetricColumns('Trend', 'Period / Segment', 'Units', 'Volume / Value', 'Notes')
            ),
            new PipelineTab(
                'ceoLoanOfficers',
                'Loan Officers',
                'Inside vs. outside LO production, pipeline value, lead conversion, and referral activity.',
                'Metric',
                buildCeoLoanOfficerRows(),
                new List<TableColumn>{
                    new TableColumn('metric0', 'Loan Officer'),
                    new TableColumn('metric1', 'Segment'),
                    new TableColumn('metric2', 'Funded MTD'),
                    new TableColumn('metric3', 'Funded QTD'),
                    new TableColumn('metric4', 'Funded YTD'),
                    new TableColumn('metric5', 'Pipeline $'),
                    new TableColumn('metric6', 'Avg Loan'),
                    new TableColumn('metric7', 'Notes')
                }
            ),
            new PipelineTab(
                'ceoRealtorPartners',
                'Realtor Partners',
                'Top referral partners by lead volume, assigned LO, and pre-approval conversion.',
                'Metric',
                buildCeoRealtorPartnerRows(),
                new List<TableColumn>{
                    new TableColumn('metric0', 'Referral Partner'),
                    new TableColumn('metric1', 'Loan Officer'),
                    new TableColumn('metric2', 'Lead Count'),
                    new TableColumn('metric3', 'Pre-Approval Rate'),
                    new TableColumn('metric4', 'Last Referral')
                }
            ),
            new PipelineTab(
                'ceoFalloutLost',
                'Fallout & Lost Business',
                'Withdrawn, denied, cancelled, and lost transaction patterns.',
                'Metric',
                buildCeoFalloutRows(),
                buildMetricColumns('Metric', 'Segment', 'Count', 'Rate / Value', 'Notes')
            ),
            new PipelineTab(
                'ceoOperationalHealth',
                'Operational Health',
                'Processing, underwriting, closing, commitment, lock, and stale-work risk indicators.',
                'Metric',
                buildCeoOperationalHealthRows(),
                buildMetricColumns('Metric', 'Segment', 'Count', 'Rate / Value', 'Notes')
            )
        };
    }

    private static List<PipelineRow> buildCeoLeadRows() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Integer totalBizDevLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND Biz_Dev__c != null
        ];
        for (AggregateResult result : [
            SELECT LeadSource sourceValue, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND Biz_Dev__c != null
            GROUP BY LeadSource
            ORDER BY COUNT(Id) DESC
            LIMIT 12
        ]) {
            Integer sourceCount = aggregateInteger(result, 'recordCount');
            rows.add(metricRow(new List<String>{
                'Lead Source Mix',
                blankToLabel((String) result.get('sourceValue'), 'Unspecified'),
                String.valueOf(sourceCount),
                String.valueOf(percent(sourceCount, totalBizDevLeads)) + '%',
                'Biz Dev pipeline, created since 2024.'
            }, reportLinkOnMetric(REPORT_MARKETING_LEADS_BY_SOURCE)));
        }

        Map<String, Integer> funnelCountsByBucket = new Map<String, Integer>{
            'New' => 0,
            'Contacted' => 0,
            'Application' => 0,
            'Docs' => 0,
            'Under Contract' => 0,
            'Pre-Approval' => 0
        };
        Integer funnelTotal = 0;
        for (AggregateResult result : [
            SELECT Status statusValue, COUNT(Id) recordCount
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :MIN_LEAD_CREATED_DATE
            GROUP BY Status
        ]) {
            Integer statusCount = aggregateInteger(result, 'recordCount');
            String bucket = leadFunnelBucket((String) result.get('statusValue'));
            if (String.isBlank(bucket)) {
                continue;
            }
            funnelCountsByBucket.put(bucket, funnelCountsByBucket.get(bucket) + statusCount);
            funnelTotal += statusCount;
        }
        for (String bucket : new List<String>{ 'New', 'Contacted', 'Application', 'Docs', 'Under Contract', 'Pre-Approval' }) {
            Integer bucketCount = funnelCountsByBucket.get(bucket);
            rows.add(metricRow(new List<String>{
                'Lead Status Funnel',
                bucket,
                String.valueOf(bucketCount),
                String.valueOf(percent(bucketCount, funnelTotal)) + '%',
                'Open leads created since 2024.'
            }, reportLinkOnMetric(REPORT_CONVERSION_RATE)));
        }

        rows.add(metricRow(new List<String>{
            'Stale / Aging Leads',
            '> 7 days untouched',
            String.valueOf(countStaleLeads(7)),
            '',
            'Active leads with no activity in more than 7 days.'
        }, reportLinkOnMetric(REPORT_LEAD_APPOINTMENT)));
        rows.add(metricRow(new List<String>{
            'Stale / Aging Leads',
            '> 14 days untouched',
            String.valueOf(countStaleLeads(14)),
            '',
            'Active leads with no activity in more than 14 days.'
        }, reportLinkOnMetric(REPORT_LEAD_APPOINTMENT)));
        rows.add(metricRow(new List<String>{
            'Stale / Aging Leads',
            '> 30 days untouched',
            String.valueOf(countStaleLeads(30)),
            '',
            'Active leads with no activity in more than 30 days.'
        }, reportLinkOnMetric(REPORT_LEAD_APPOINTMENT)));

        for (AggregateResult result : [
            SELECT Owner.Name ownerName, COUNT(Id) recordCount
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND Status IN :ACTIVE_LEAD_STATUSES
            GROUP BY Owner.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 15
        ]) {
            rows.add(metricRow(new List<String>{
                'Leads by Assigned LO',
                blankToLabel((String) result.get('ownerName'), 'Unassigned'),
                String.valueOf(aggregateInteger(result, 'recordCount')),
                '',
                'Active statuses only.'
            }, reportLinkOnMetric(REPORT_MARKETING_LEADS_BY_SOURCE)));
        }

        Integer nickleyLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND Branch__c = 'Nickley'
        ];
        rows.add(metricRow(new List<String>{
            'Nickley Office Leads',
            'Nickley',
            String.valueOf(nickleyLeads),
            '',
            'Isolated by Lead Branch = Nickley.'
        }, reportLinkOnMetric(REPORT_NICKLEY_LEADS)));
        rows.add(metricRow(new List<String>{
            'Webinar Metrics',
            'GHL appointment show rate',
            '',
            'Sync required',
            'Show-rate data is not reliable until GHL attendance/appointment status syncs cleanly to Salesforce.'
        }, reportLinkOnMetric(REPORT_CONSUMER_WEBINAR_LEADS)));
        return rows;
    }

    private static List<PipelineRow> buildCeoTransactionRows() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date todayDate = Date.today();
        Date currentMonthStart = todayDate.toStartOfMonth();
        Date lastMonthStart = currentMonthStart.addMonths(-1);
        Date nextMonthStart = currentMonthStart.addMonths(1);
        Date followingMonthStart = currentMonthStart.addMonths(2);
        Date quarterStart = currentQuarterStart(todayDate);
        Date nextQuarterStart = nextQuarterStart(todayDate);
        Date yearStart = Date.newInstance(todayDate.year(), 1, 1);
        DateTime currentYearStartDateTime = DateTime.newInstanceGmt(todayDate.year(), 1, 1, 0, 0, 0);
        Date tomorrowDate = todayDate.addDays(1);

        for (AggregateResult result : [
            SELECT Status__c statusValue, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            GROUP BY Status__c
            ORDER BY COUNT(Id) DESC
            LIMIT 20
        ]) {
            rows.add(metricRow(new List<String>{
                'Pipeline by Stage',
                blankToLabel((String) result.get('statusValue'), 'Unspecified'),
                String.valueOf(aggregateInteger(result, 'recordCount')),
                formatCurrency(aggregateDecimal(result, 'volume')),
                'Transactions created since 2024.'
            }));
        }
        for (AggregateResult result : [
            SELECT Loan_Type_1st_TD__c loanType, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            GROUP BY Loan_Type_1st_TD__c
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ]) {
            rows.add(metricRow(new List<String>{
                'Loan Type Mix',
                blankToLabel((String) result.get('loanType'), 'Unspecified'),
                String.valueOf(aggregateInteger(result, 'recordCount')),
                '',
                'Active transactions.'
            }));
        }
        for (AggregateResult result : [
            SELECT Loan_Purpose__c purpose, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            GROUP BY Loan_Purpose__c
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ]) {
            rows.add(metricRow(new List<String>{
                'Purpose Mix',
                blankToLabel((String) result.get('purpose'), 'Unspecified'),
                String.valueOf(aggregateInteger(result, 'recordCount')),
                '',
                'Active transactions.'
            }));
        }

        Integer appsYtd = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE CreatedDate >= :currentYearStartDateTime
            AND Status__c != 'Cancelled'
        ];
        Integer fundedYtd = [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Funding_Date__c >= :yearStart
            AND Funding_Date__c <= :todayDate
            AND Status__c != 'Cancelled'
        ];
        rows.add(metricRow(new List<String>{ 'Pull-Through Rate', 'Apps funding YTD', String.valueOf(fundedYtd) + ' / ' + String.valueOf(appsYtd), String.valueOf(percent(fundedYtd, appsYtd)) + '%', 'Uses transaction CreatedDate as application proxy.' }, reportLinkOnMetric(REPORT_NEW_TO_POST_CLOSED)));
        rows.add(metricRow(new List<String>{ 'Funded Volume', 'Last Month', '', formatCurrency(fundedVolume(lastMonthStart, currentMonthStart)), String.valueOf(fundedUnits(lastMonthStart, currentMonthStart)) + ' units.' }));
        rows.add(metricRow(new List<String>{ 'Funded Volume', 'This Month', '', formatCurrency(fundedVolume(currentMonthStart, nextMonthStart)), String.valueOf(fundedUnits(currentMonthStart, nextMonthStart)) + ' units.' }));
        rows.add(metricRow(new List<String>{ 'Projected Pipeline', 'Next Month Closing Dates', '', formatCurrency(closingVolume(nextMonthStart, followingMonthStart)), String.valueOf(closingUnits(nextMonthStart, followingMonthStart)) + ' scheduled units.' }));
        rows.add(metricRow(new List<String>{ 'Funded Volume', 'QTD', '', formatCurrency(fundedVolume(quarterStart, nextQuarterStart)), String.valueOf(fundedUnits(quarterStart, nextQuarterStart)) + ' units.' }));
        rows.add(metricRow(new List<String>{ 'Funded Volume', 'YTD', '', formatCurrency(fundedVolume(yearStart, tomorrowDate)), String.valueOf(fundedYtd) + ' units.' }));

        Decimal averageLoanSize = averageLoanSize(yearStart, todayDate.addDays(1));
        rows.add(metricRow(new List<String>{ 'Average Loan Size', 'YTD Funded', '', formatCurrency(averageLoanSize), 'Funded-date basis.' }));
        addCycleTimeRows(rows);
        return rows;
    }

    private static List<PipelineRow> buildCeoTrendRows() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date monthCursor = Date.today().toStartOfMonth().addMonths(-11);
        DateTime monthCursorDateTime = DateTime.newInstance(monthCursor, Time.newInstance(0, 0, 0, 0));
        Map<String, Integer> fundedUnitsByMonth = new Map<String, Integer>();
        Map<String, Decimal> fundedVolumeByMonth = new Map<String, Decimal>();
        for (AggregateResult result : [
            SELECT CALENDAR_YEAR(Funding_Date__c) yearValue, CALENDAR_MONTH(Funding_Date__c) monthValue,
                COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Funding_Date__c >= :monthCursor
            AND Status__c != 'Cancelled'
            GROUP BY CALENDAR_YEAR(Funding_Date__c), CALENDAR_MONTH(Funding_Date__c)
        ]) {
            String key = monthKey(aggregateInteger(result, 'yearValue'), aggregateInteger(result, 'monthValue'));
            fundedUnitsByMonth.put(key, aggregateInteger(result, 'recordCount'));
            fundedVolumeByMonth.put(key, aggregateDecimal(result, 'volume'));
        }
        Map<String, Integer> transactionUnitsByMonth = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT CALENDAR_YEAR(CreatedDate) yearValue, CALENDAR_MONTH(CreatedDate) monthValue, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE CreatedDate >= :monthCursorDateTime
            AND Status__c != 'Cancelled'
            GROUP BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            transactionUnitsByMonth.put(
                monthKey(aggregateInteger(result, 'yearValue'), aggregateInteger(result, 'monthValue')),
                aggregateInteger(result, 'recordCount')
            );
        }
        Map<String, Integer> leadUnitsByMonth = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT CALENDAR_YEAR(CreatedDate) yearValue, CALENDAR_MONTH(CreatedDate) monthValue, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :monthCursorDateTime
            GROUP BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            leadUnitsByMonth.put(
                monthKey(aggregateInteger(result, 'yearValue'), aggregateInteger(result, 'monthValue')),
                aggregateInteger(result, 'recordCount')
            );
        }
        for (Integer i = 0; i < 12; i++) {
            Date periodStart = monthCursor.addMonths(i);
            String key = monthKey(periodStart.year(), periodStart.month());
            rows.add(metricRow(new List<String>{
                'Monthly Funded Volume',
                periodStart.format(),
                String.valueOf(integerFor(fundedUnitsByMonth, key)),
                formatCurrency(decimalFor(fundedVolumeByMonth, key)),
                'Rolling 12 months.'
            }));
            rows.add(metricRow(new List<String>{
                'Application Volume Trend',
                periodStart.format(),
                String.valueOf(integerFor(transactionUnitsByMonth, key)),
                '',
                'Transaction created-date basis.'
            }));
            rows.add(metricRow(new List<String>{
                'Lead Volume Trend',
                periodStart.format(),
                String.valueOf(integerFor(leadUnitsByMonth, key)),
                '',
                'Lead created-date basis.'
            }));
        }
        rows.add(metricRow(new List<String>{ 'Conversion Rate Trend', 'Lead to close', '', 'Report mapping recommended', 'Use existing conversion report drilldown when finalized for CEO tab.' }, reportLinkOnMetric(REPORT_CONVERSION_RATE)));
        rows.add(metricRow(new List<String>{ 'Referral Partner Trend', 'Realtor relationships', '', 'Available in Realtor Partners tab', 'Shows top referral partners and last referral date.' }, reportLinkOnMetric(REPORT_REALTOR_REFERRAL_LEADS)));
        rows.add(metricRow(new List<String>{ 'State-Level Volume', 'Licensing footprint', '', 'Field mapping needed', 'Add property state API mapping to include reliable state rollups.' }));
        return rows;
    }

    private static List<PipelineRow> buildCeoLoanOfficerRows() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date todayDate = Date.today();
        Date currentMonthStart = todayDate.toStartOfMonth();
        Date quarterStart = currentQuarterStart(todayDate);
        Date yearStart = Date.newInstance(todayDate.year(), 1, 1);
        Date nextMonthStart = currentMonthStart.addMonths(1);
        Date nextQuarterStart = nextQuarterStart(todayDate);
        Date tomorrowDate = todayDate.addDays(1);

        List<User> loanOfficers = [
            SELECT Id, Name, Title, Profile.Name, UserRole.Name
            FROM User
            WHERE IsActive = true
            ORDER BY Name
            LIMIT 200
        ];
        Set<Id> loanOfficerIds = new Set<Id>();
        Map<Id, User> usersById = new Map<Id, User>();
        for (User userRecord : loanOfficers) {
            String normalizedName = String.isBlank(userRecord.Name) ? '' : userRecord.Name.toLowerCase();
            if (EXCLUDED_CONVERSION_USER_NAMES.contains(normalizedName)
                || !userLooksLikeLoanOfficer(userRecord)) {
                continue;
            }
            loanOfficerIds.add(userRecord.Id);
            usersById.put(userRecord.Id, userRecord);
        }
        if (loanOfficerIds.isEmpty()) {
            return rows;
        }

        Map<Id, Integer> mtdUnitsByLo = fundedUnitsByLoanOfficer(loanOfficerIds, currentMonthStart, nextMonthStart);
        Map<Id, Decimal> mtdVolumeByLo = fundedVolumeByLoanOfficer(loanOfficerIds, currentMonthStart, nextMonthStart);
        Map<Id, Integer> qtdUnitsByLo = fundedUnitsByLoanOfficer(loanOfficerIds, quarterStart, nextQuarterStart);
        Map<Id, Decimal> qtdVolumeByLo = fundedVolumeByLoanOfficer(loanOfficerIds, quarterStart, nextQuarterStart);
        Map<Id, Integer> ytdUnitsByLo = fundedUnitsByLoanOfficer(loanOfficerIds, yearStart, tomorrowDate);
        Map<Id, Decimal> ytdVolumeByLo = fundedVolumeByLoanOfficer(loanOfficerIds, yearStart, tomorrowDate);
        Map<Id, Decimal> activePipelineByLo = pipelineVolumeByLoanOfficer(loanOfficerIds);

        for (Id loanOfficerId : loanOfficerIds) {
            User loanOfficer = usersById.get(loanOfficerId);
            Decimal ytdVolume = decimalFor(ytdVolumeByLo, loanOfficerId);
            Integer ytdUnits = integerFor(ytdUnitsByLo, loanOfficerId);
            rows.add(metricRow(new List<String>{
                loanOfficer.Name,
                userLooksOutsideLoanOfficer(loanOfficer) ? 'Outside LO' : 'Inside LO',
                String.valueOf(integerFor(mtdUnitsByLo, loanOfficerId)) + ' / ' + formatCurrency(decimalFor(mtdVolumeByLo, loanOfficerId)),
                String.valueOf(integerFor(qtdUnitsByLo, loanOfficerId)) + ' / ' + formatCurrency(decimalFor(qtdVolumeByLo, loanOfficerId)),
                String.valueOf(ytdUnits) + ' / ' + formatCurrency(ytdVolume),
                formatCurrency(decimalFor(activePipelineByLo, loanOfficerId)),
                formatCurrency(ytdUnits == 0 ? 0 : ytdVolume / ytdUnits),
                loanOfficer.Name == 'Brandon Brotsky' ? 'Brandon isolated executive producer row.' : ''
            }));
        }
        return rows;
    }

    private static List<PipelineRow> buildCeoRealtorPartnerRows() {
        Map<String, RealtorPartnerMetric> metricsByPartnerAndOwner = new Map<String, RealtorPartnerMetric>();
        for (Lead leadRecord : [
            SELECT Id, Owner.Name, Realtor_Buying_Agent__c, Realtor_Buying_Agent__r.Name, Pre_Approval_Date__c, CreatedDate
            FROM Lead
            WHERE CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND LeadSource = 'Realtor Referral'
            AND Realtor_Buying_Agent__c != null
            ORDER BY CreatedDate DESC
            LIMIT 5000
        ]) {
            String partnerName = leadRecord.Realtor_Buying_Agent__r == null ? 'Unknown Partner' : leadRecord.Realtor_Buying_Agent__r.Name;
            String ownerName = leadRecord.Owner == null ? 'Unassigned' : leadRecord.Owner.Name;
            String key = partnerName + '|' + ownerName;
            if (!metricsByPartnerAndOwner.containsKey(key)) {
                metricsByPartnerAndOwner.put(key, new RealtorPartnerMetric(partnerName, ownerName));
            }
            RealtorPartnerMetric metric = metricsByPartnerAndOwner.get(key);
            metric.leadCount++;
            if (leadRecord.Pre_Approval_Date__c != null) {
                metric.preApprovalCount++;
            }
            Date referralDate = leadRecord.CreatedDate.date();
            if (metric.lastReferralDate == null || referralDate > metric.lastReferralDate) {
                metric.lastReferralDate = referralDate;
            }
        }

        List<RealtorPartnerMetric> partnerMetrics = metricsByPartnerAndOwner.values();
        partnerMetrics.sort();
        List<PipelineRow> rows = new List<PipelineRow>();
        Integer visibleCount = Math.min(20, partnerMetrics.size());
        for (Integer i = 0; i < visibleCount; i++) {
            RealtorPartnerMetric metric = partnerMetrics[i];
            rows.add(metricRow(new List<String>{
                metric.partnerName,
                metric.loanOfficerName,
                String.valueOf(metric.leadCount),
                String.valueOf(percent(metric.preApprovalCount, metric.leadCount)) + '%',
                metric.lastReferralDate == null ? '' : metric.lastReferralDate.format()
            }, reportLinkOnMetric(REPORT_REALTOR_REFERRAL_LEADS)));
        }
        return rows;
    }

    private static List<PipelineRow> buildCeoFalloutRows() {
        List<PipelineRow> rows = new List<PipelineRow>();
        List<String> falloutStatuses = new List<String>{ 'Cancelled', 'Denied', 'Withdrawn', 'Lost' };
        Integer totalFallout = 0;
        Map<String, Integer> countsByStatus = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT Status__c statusValue, COUNT(Id) recordCount
            FROM Transaction__c
            WHERE CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            AND Status__c IN :falloutStatuses
            GROUP BY Status__c
        ]) {
            Integer recordCount = aggregateInteger(result, 'recordCount');
            countsByStatus.put((String) result.get('statusValue'), recordCount);
            totalFallout += recordCount;
        }
        for (String statusValue : falloutStatuses) {
            Integer recordCount = countsByStatus.containsKey(statusValue) ? countsByStatus.get(statusValue) : 0;
            rows.add(metricRow(new List<String>{
                'Fallout Status',
                statusValue,
                String.valueOf(recordCount),
                String.valueOf(percent(recordCount, totalFallout)) + '%',
                'Created since 2024.'
            }));
        }
        rows.add(metricRow(new List<String>{ 'Lost Reason Detail', 'Reason codes', '', 'Mapping recommended', 'Add reason field mapping once leadership chooses the final reason taxonomy.' }));
        return rows;
    }

    private static List<PipelineRow> buildCeoOperationalHealthRows() {
        Date todayDate = Date.today();
        Date sevenDaysAgo = todayDate.addDays(-7);
        Date lockWindowEnd = todayDate.addDays(7);
        Date commitmentWindowEnd = addBusinessDays(todayDate, 3);
        Date warehouseWindowEnd = todayDate.addDays(14);
        List<PipelineRow> rows = new List<PipelineRow>();
        rows.add(metricRow(new List<String>{
            'Past Expected Close',
            'Closing date before today',
            String.valueOf([
                SELECT COUNT()
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND Closing_Date__c < :todayDate
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ]),
            '',
            'Active statuses only.'
        }));
        rows.add(metricRow(new List<String>{
            'Processing Aging',
            'Processing > 7 days',
            String.valueOf([
                SELECT COUNT()
                FROM Transaction__c
                WHERE Status__c = 'Processing'
                AND Submitted_to_Processing_Date__c <= :sevenDaysAgo
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ]),
            '',
            'Uses Submitted to Processing Date.'
        }));
        rows.add(metricRow(new List<String>{
            'Underwriting Aging',
            'Submitted/UW > 7 days',
            String.valueOf([
                SELECT COUNT()
                FROM Transaction__c
                WHERE Status__c = 'Submitted'
                AND Submitted_to_Underwriting_Date__c <= :sevenDaysAgo
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ]),
            '',
            'Uses Submitted to Underwriting Date.'
        }));
        rows.add(metricRow(new List<String>{
            'Commitment Risk',
            'Commitment date in next 3 business days',
            String.valueOf([
                SELECT COUNT()
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND Loan_Commitment_Date__c >= :todayDate
                AND Loan_Commitment_Date__c <= :commitmentWindowEnd
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ]),
            '',
            'Active transactions only.'
        }));
        rows.add(metricRow(new List<String>{
            'Rate Lock Risk',
            'Locks expiring within 7 days',
            String.valueOf([
                SELECT COUNT()
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND Rate_Lock_Exp_Date__c >= :todayDate
                AND Rate_Lock_Exp_Date__c <= :lockWindowEnd
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ]),
            '',
            'Calendar-day basis.'
        }));
        rows.add(metricRow(new List<String>{
            'Warehouse Assignment',
            'Correspondent closings next 14 days with no warehouse bank',
            String.valueOf([
                SELECT COUNT()
                FROM Transaction__c
                WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
                AND Closing_Date__c >= :todayDate
                AND Closing_Date__c <= :warehouseWindowEnd
                AND Channel__c = 'Correspondent'
                AND Warehouse_Bank_Picklist__c = null
                AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ]),
            '',
            'Matches Jamie warehouse exception rule.'
        }));
        return rows;
    }

    private static List<TableColumn> buildOpenerAppraisalsOutstandingColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('appraisalOrderedDate', 'Appraisal Ordered Date'),
            new TableColumn('valueLinkOrderedDate', 'ValueLink Ordered Date'),
            new TableColumn('appraisalStatus', 'Appraisal Order Status'),
            new TableColumn('appraisalDueDate', 'Due Date'),
            new TableColumn('lenderName', 'Lender'),
            new TableColumn('loanOfficerName', 'Loan Officer'),
            new TableColumn('processorName', 'Processor'),
            new TableColumn('ownerName', 'Owner')
        };
    }

    private static List<TableColumn> buildBrokerChecksOutstandingColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('fundingDate', 'Funding Date')
        };
    }

    private static List<PipelineTab> buildCloserPipelineTabs(List<PipelineRow> activeRows) {
        return new List<PipelineTab>{
            new PipelineTab(
                'closerActivePipeline',
                'Active Pipeline',
                'All active files created since 2024 for closer review.',
                'Transaction__c',
                activeRows
            ),
            new PipelineTab(
                'correspondentCloserView',
                'Correspondent Closer View',
                'Matches the Transaction list view Correspondent Closer View.',
                'Transaction__c',
                buildCorrespondentCloserViewTransactions(),
                buildCloserListViewColumns()
            ),
            new PipelineTab(
                'brokeredCloserView',
                'Brokered Closer View',
                'Matches the Transaction list view Brokered Closer View.',
                'Transaction__c',
                buildBrokeredCloserViewTransactions(),
                buildCloserListViewColumns()
            ),
            new PipelineTab(
                'closerFilesInClosing',
                'Files in Closing',
                'Files in Approved or Closing status.',
                'Transaction__c',
                buildCloserFilesInClosing()
            ),
            new PipelineTab(
                'closerFilesInFunding',
                'Files in Funding',
                'Files in Funding status.',
                'Transaction__c',
                buildCloserFilesInFunding()
            ),
            new PipelineTab(
                'closerFilesClosingToday',
                'Files Closing Today',
                'Files with a closing date of today.',
                'Transaction__c',
                buildCloserFilesClosingToday()
            )
        };
    }

    private static List<TableColumn> buildCloserListViewColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('loanPurpose', 'Loan Purpose'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('cdSentByDate', 'CD Sent By Date'),
            new TableColumn('cdSentDate', 'CD Sent Date'),
            new TableColumn('closingInstructionsSent', 'Closing Instructions Sent'),
            new TableColumn('vestingConfirmed', 'Vesting Confirmed'),
            new TableColumn('cdIsBalanced', 'CD Is Balanced'),
            new TableColumn('lenderName', 'Lender'),
            new TableColumn('managerNotes', 'Closing Notes for Closers'),
            new TableColumn('easeLink', 'EASE Link')
        };
    }

    private static List<PipelineTab> buildFundingLockDeskPipelineTabs(List<PipelineRow> fundingRows) {
        return new List<PipelineTab>{
            new PipelineTab(
                'fundingLockDeskActivePipeline',
                'Active Pipeline',
                'All active files created since 2024.',
                'Transaction__c',
                fundingRows
            ),
            new PipelineTab(
                'fundingQueue',
                'Funding Queue',
                'Files currently in Funding status with funding checklist visibility.',
                'Transaction__c',
                buildJamieCorrespondentFunderViewTransactions(),
                buildJamieCorrespondentFunderColumns()
            ),
            new PipelineTab(
                'funderActionRequired',
                'Funder Action Required',
                'Matches the Transaction list view Funder Action Required.',
                'Transaction__c',
                buildFunderActionRequiredTransactions(),
                buildFunderActionRequiredColumns()
            ),
            new PipelineTab(
                'jamieCorrespondentCloserView',
                'Jamie - Correspondent Closer View',
                'Matches the Transaction list view Jamie - Correspondent Closer View.',
                'Transaction__c',
                buildJamieCorrespondentCloserViewTransactions(),
                buildJamieCorrespondentCloserColumns()
            ),
            new PipelineTab(
                'pcReviewPipeline',
                'PC Review Pipeline',
                'Files currently in PC Review status.',
                'Transaction__c',
                buildPcReviewPipeline()
            ),
            new PipelineTab(
                'needingWarehouseAssignment',
                'Needing Warehouse Assignment',
                'Correspondent files closing within the next two weeks with no Warehouse Bank assigned.',
                'Transaction__c',
                buildNeedingWarehouseAssignmentTransactions()
            ),
            new PipelineTab(
                'locksExpiring',
                'Locks Expiring within a Week',
                'Active files with rate locks expiring within the next 7 calendar days. Locks expiring today appear first and highlighted.',
                'Transaction__c',
                buildLocksExpiringTransactions(),
                buildLocksExpiringColumns()
            ),
            new PipelineTab(
                'openCocRequests',
                'Open COC Requests',
                'Transactions tied to open Change of Circumstance request cases.',
                'Transaction__c',
                buildOpenCocRequestTransactions()
            )
        };
    }

    private static List<PipelineRow> buildCorrespondentCloserViewTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Status__c,
                Loan_Purpose__c,
                Closing_Date__c,
                CD_Sent_By_Date__c,
                CD_Sent_Date__c,
                Closing_Instructions_Sent__c,
                Vesting_Confirmed__c,
                CD_Is_Balanced__c,
                Lender_lookup__r.Name,
                Ease_Link__c,
                Manager_Notes__c
            FROM Transaction__c
            WHERE RecordType.DeveloperName = 'Correspondent'
            AND Status__c != 'Cancelled'
            AND Lender_lookup__r.Name IN :CLOSER_LENDER_NAMES
            AND (
                Status__c = 'Closing'
                OR (
                    Status__c NOT IN ('Funding', 'Post-Closed')
                    AND Add_to_Closing_Queue__c = true
                )
            )
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ]) {
            rows.add(buildCloserListViewRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildBrokeredCloserViewTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Status__c,
                Loan_Purpose__c,
                Closing_Date__c,
                CD_Sent_By_Date__c,
                CD_Sent_Date__c,
                Closing_Instructions_Sent__c,
                Vesting_Confirmed__c,
                CD_Is_Balanced__c,
                Lender_lookup__r.Name,
                Ease_Link__c,
                Manager_Notes__c
            FROM Transaction__c
            WHERE RecordType.DeveloperName = 'Brokered'
            AND Status__c NOT IN ('Cancelled', 'Post-Closed')
            AND Lender_lookup__r.Name IN :CLOSER_LENDER_NAMES
            AND (
                Status__c = 'Closing'
                OR Add_to_Closing_Queue__c = true
            )
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
        ]) {
            rows.add(buildCloserListViewRow(transactionRecord));
        }
        return rows;
    }

    private static List<TableColumn> buildJamieCorrespondentCloserColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('lenderName', 'Lender'),
            new TableColumn('status', 'Status'),
            new TableColumn('loanPurpose', 'Loan Purpose'),
            new TableColumn('loanType', 'Loan Type'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('rateLockExpDate', 'Rate Lock Exp Date'),
            new TableColumn('mersRegistrationComplete', 'MERS Registration Complete'),
            new TableColumn('cdIsBalanced', 'CD Is Balanced'),
            new TableColumn('closingPackageSent', 'Closing Package Sent'),
            new TableColumn('managerNotes', 'Closing Notes for Closers'),
            new TableColumn('easeLink', 'EASE Link')
        };
    }

    private static List<TableColumn> buildJamieCorrespondentFunderColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('loanPurpose', 'Loan Purpose'),
            new TableColumn('fundingDate', 'Funding Date'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('rateLockExpDate', 'Rate Lock Exp Date'),
            new TableColumn('warehouseBankName', 'Warehouse Bank'),
            new TableColumn('mersRegistrationComplete', 'MERS Registration Complete'),
            new TableColumn('closingType', 'Closing Type'),
            new TableColumn('fundingWireRequested', 'Funding Wire Requested'),
            new TableColumn('federalReferenceNumber', 'Federal Reference Number'),
            new TableColumn('fundingAuthorization', 'Funding Authorization'),
            new TableColumn('mersUploadedActivated', 'MERS Uploaded/Activated'),
            new TableColumn('noteReceivedDate', 'Note Received by Investor'),
            new TableColumn('easeLink', 'EASE Link')
        };
    }

    private static List<TableColumn> buildFunderActionRequiredColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('actionRequiredReason', 'Action Required Reason'),
            new TableColumn('status', 'Status'),
            new TableColumn('closingType', 'Closing Type'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('fundingDate', 'Funding Date'),
            new TableColumn('rateLockExpDate', 'Rate Lock Exp Date'),
            new TableColumn('warehouseBankName', 'Warehouse Bank'),
            new TableColumn('mersActivated', 'MERS Activated'),
            new TableColumn('fundingAuthorization', 'Funding Authorization'),
            new TableColumn('mersUploadedActivated', 'MERS Uploaded/Activated'),
            new TableColumn('managerNotes', 'Manager Notes')
        };
    }

    private static List<TableColumn> buildLocksExpiringColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'Name'),
            new TableColumn('status', 'Status'),
            new TableColumn('rateLockExpDate', 'Rate Lock Exp Date'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('fundingDate', 'Funding Date'),
            new TableColumn('detail', 'Review Detail'),
            new TableColumn('lenderName', 'Lender'),
            new TableColumn('loanPurpose', 'Purpose'),
            new TableColumn('ownerName', 'Owner'),
            new TableColumn('loanOfficerName', 'Loan Officer'),
            new TableColumn('loanAmount', 'Amount'),
            new TableColumn('easeLink', 'EASE Link')
        };
    }

    private static List<TableColumn> buildGoldStarTransactionColumns() {
        return new List<TableColumn>{
            new TableColumn('name', 'File Name'),
            new TableColumn('processorName', 'Processor'),
            new TableColumn('closingDate', 'Closing Date'),
            new TableColumn('loanAmount', 'Loan Amount'),
            new TableColumn('lenderName', 'Lender'),
            new TableColumn('rateLockStatus', 'Rate Lock Status'),
            new TableColumn('rateLockExpDate', 'Lock Expiration Date'),
            new TableColumn('status', 'Transaction Status')
        };
    }

    private static List<PipelineRow> buildJamieCorrespondentCloserViewTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Status__c,
                Lender_lookup__r.Name,
                Loan_Purpose__c,
                Loan_Type_1st_TD__c,
                Closing_Date__c,
                Rate_Lock_Exp_Date__c,
                MERS_Registration_Complete__c,
                CD_Is_Balanced__c,
                Closing_Package_Sent__c,
                Ease_Link__c,
                Manager_Notes__c
            FROM Transaction__c
            WHERE RecordType.DeveloperName = 'Correspondent'
            AND Status__c != 'Cancelled'
            AND Lender_lookup__r.Name IN :CLOSER_LENDER_NAMES
            AND (
                Status__c = 'Closing'
                OR (
                    Status__c NOT IN ('Funding', 'Post-Closed')
                    AND Add_to_Closing_Queue__c = true
                )
            )
            ORDER BY Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(buildJamieCorrespondentCloserRow(transactionRecord));
        }
        return rows;
    }

    private static List<PipelineRow> buildJamieCorrespondentFunderViewTransactions() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Transaction__c transactionRecord : [
            SELECT Id,
                Name,
                Status__c,
                Loan_Purpose__c,
                Funding_Date__c,
                Closing_Date__c,
                Rate_Lock_Exp_Date__c,
                Warehouse_Bank_Picklist__c,
                MERS_Registration_Complete__c,
                Closing_Type__c,
                Funding_Wire_Requested__c,
                Federal_Reference_Number__c,
                Funding_Authorization__c,
                MERSUploadedActivated__c,
                Note_Received_Date__c,
                Ease_Link__c
            FROM Transaction__c
            WHERE RecordType.DeveloperName = 'Correspondent'
            AND Status__c = 'Funding'
            AND CreatedDate >= :MIN_TRANSACTION_CREATED_DATETIME
            ORDER BY Funding_Date__c ASC NULLS LAST, Closing_Date__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 100
        ]) {
            rows.add(buildJamieCorrespondentFunderRow(transactionRecord));
        }
        return rows;
    }

    private static PipelineRow buildJamieCorrespondentCloserRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('lenderName', row.lenderName, row.lenderName, false, 'Lender_lookup__c'),
            new TableCell('status', row.status, row.status, false, 'Status__c'),
            new TableCell('loanPurpose', row.loanPurpose, row.loanPurpose, false, 'Loan_Purpose__c'),
            new TableCell('loanType', row.loanType, row.loanType, false, 'Loan_Type_1st_TD__c'),
            new TableCell('closingDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Closing_Date__c'),
            new TableCell('rateLockExpDate', formatDateForCell(row.rateLockExpDate), formatDateSortValue(row.rateLockExpDate), false, 'Rate_Lock_Exp_Date__c'),
            new TableCell('mersRegistrationComplete', formatDateForCell(row.mersRegistrationComplete), formatDateSortValue(row.mersRegistrationComplete), false, 'MERS_Registration_Complete__c'),
            new TableCell('cdIsBalanced', formatDateForCell(row.cdIsBalanced), formatDateSortValue(row.cdIsBalanced), false, 'CD_Is_Balanced__c'),
            new TableCell('closingPackageSent', formatDateForCell(row.closingPackageSent), formatDateSortValue(row.closingPackageSent), false, 'Closing_Package_Sent__c'),
            new TableCell('managerNotes', row.closerNotes, row.closerNotes, false, 'Manager_Notes__c'),
            easeLinkCell(row)
        };
        return row;
    }

    private static PipelineRow buildCloserListViewRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('status', row.status, row.status, false, 'Status__c'),
            new TableCell('loanPurpose', row.loanPurpose, row.loanPurpose, false, 'Loan_Purpose__c'),
            new TableCell('closingDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Closing_Date__c'),
            new TableCell('cdSentByDate', formatDateForCell(row.cdSentByDate), formatDateSortValue(row.cdSentByDate), false, 'CD_Sent_By_Date__c'),
            new TableCell('cdSentDate', formatDateForCell(row.cdSentDate), formatDateSortValue(row.cdSentDate), false, 'CD_Sent_Date__c'),
            new TableCell('closingInstructionsSent', formatDateForCell(row.closingInstructionsSent), formatDateSortValue(row.closingInstructionsSent), false, 'Closing_Instructions_Sent__c'),
            new TableCell('vestingConfirmed', formatDateForCell(row.vestingConfirmed), formatDateSortValue(row.vestingConfirmed), false, 'Vesting_Confirmed__c'),
            new TableCell('cdIsBalanced', formatDateForCell(row.cdIsBalanced), formatDateSortValue(row.cdIsBalanced), false, 'CD_Is_Balanced__c'),
            new TableCell('lenderName', row.lenderName, row.lenderName, false, 'Lender_lookup__c'),
            new TableCell('managerNotes', row.closerNotes, row.closerNotes, false, 'Manager_Notes__c'),
            easeLinkCell(row)
        };
        return row;
    }

    private static PipelineRow buildJamieCorrespondentFunderRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('loanPurpose', row.loanPurpose, row.loanPurpose, false, 'Loan_Purpose__c'),
            new TableCell('fundingDate', formatDateForCell(row.fundingDate), formatDateSortValue(row.fundingDate), false, 'Funding_Date__c'),
            new TableCell('closingDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Closing_Date__c'),
            new TableCell('rateLockExpDate', formatDateForCell(row.rateLockExpDate), formatDateSortValue(row.rateLockExpDate), false, 'Rate_Lock_Exp_Date__c'),
            new TableCell('warehouseBankName', row.warehouseBankName, row.warehouseBankName, false, 'Warehouse_Bank_Picklist__c'),
            new TableCell('mersRegistrationComplete', formatDateForCell(row.mersRegistrationComplete), formatDateSortValue(row.mersRegistrationComplete), false, 'MERS_Registration_Complete__c'),
            new TableCell('closingType', row.closingType, row.closingType, false, 'Closing_Type__c'),
            new TableCell('fundingWireRequested', formatDateForCell(row.fundingWireRequested), formatDateSortValue(row.fundingWireRequested), false, 'Funding_Wire_Requested__c'),
            new TableCell('federalReferenceNumber', row.federalReferenceNumber, row.federalReferenceNumber, false, 'Federal_Reference_Number__c'),
            new TableCell('fundingAuthorization', formatDateForCell(row.fundingAuthorization), formatDateSortValue(row.fundingAuthorization), false, 'Funding_Authorization__c'),
            new TableCell('mersUploadedActivated', formatDateForCell(row.mersUploadedActivated), formatDateSortValue(row.mersUploadedActivated), false, 'MERSUploadedActivated__c'),
            new TableCell('noteReceivedDate', formatDateForCell(row.noteReceivedDate), formatDateSortValue(row.noteReceivedDate), false, 'Note_Received_Date__c'),
            easeLinkCell(row)
        };
        return row;
    }

    private static PipelineRow buildFunderActionRequiredRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        Object mersActivated = safeSObjectValue(transactionRecord, 'MERS_Activated__c');
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('actionRequiredReason', (String) safeSObjectValue(transactionRecord, 'Action_Required_Reason__c'), (String) safeSObjectValue(transactionRecord, 'Action_Required_Reason__c'), false, 'Action_Required_Reason__c'),
            new TableCell('status', row.status, row.status, false, 'Status__c'),
            new TableCell('closingType', row.closingType, row.closingType, false, 'Closing_Type__c'),
            new TableCell('closingDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Closing_Date__c'),
            new TableCell('fundingDate', formatDateForCell(row.fundingDate), formatDateSortValue(row.fundingDate), false, 'Funding_Date__c'),
            new TableCell('rateLockExpDate', formatDateForCell(row.rateLockExpDate), formatDateSortValue(row.rateLockExpDate), false, 'Rate_Lock_Exp_Date__c'),
            new TableCell('warehouseBankName', row.warehouseBankName, row.warehouseBankName, false, 'Warehouse_Bank_Picklist__c'),
            new TableCell('mersActivated', formatGenericCellValue(mersActivated), formatGenericCellValue(mersActivated), false, 'MERS_Activated__c'),
            new TableCell('fundingAuthorization', formatDateForCell(row.fundingAuthorization), formatDateSortValue(row.fundingAuthorization), false, 'Funding_Authorization__c'),
            new TableCell('mersUploadedActivated', formatDateForCell(row.mersUploadedActivated), formatDateSortValue(row.mersUploadedActivated), false, 'MERSUploadedActivated__c'),
            new TableCell('managerNotes', row.closerNotes, row.closerNotes, false, 'Manager_Notes__c')
        };
        row.displayDate = row.fundingDate;
        return row;
    }

    private static PipelineRow buildLocksExpiringRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        Date closingDate = row.displayDate;
        Date rateLockExpDate = row.rateLockExpDate;
        String lockStatus = (String) safeSObjectValue(transactionRecord, 'Rate_Lock_Status__c');
        row.detail = String.isBlank(lockStatus) ? 'Rate lock expiring' : 'Rate Lock Status: ' + lockStatus;
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('status', row.status, row.status, false, 'Status__c'),
            new TableCell('rateLockExpDate', formatDateForCell(rateLockExpDate), formatDateSortValue(rateLockExpDate), false, 'Rate_Lock_Exp_Date__c'),
            new TableCell('closingDate', formatDateForCell(closingDate), formatDateSortValue(closingDate), false, 'Closing_Date__c'),
            new TableCell('fundingDate', formatDateForCell(row.fundingDate), formatDateSortValue(row.fundingDate), false, 'Funding_Date__c'),
            new TableCell('detail', row.detail, row.detail, false),
            new TableCell('lenderName', row.lenderName, row.lenderName, false, 'Lender_lookup__c'),
            new TableCell('loanPurpose', row.loanPurpose, row.loanPurpose, false, 'Loan_Purpose__c'),
            new TableCell('ownerName', row.ownerName, row.ownerName, false),
            new TableCell('loanOfficerName', row.loanOfficerName, row.loanOfficerName, false),
            new TableCell('loanAmount', formatDecimalForCell(row.loanAmount), formatDecimalSortValue(row.loanAmount), false),
            easeLinkCell(row)
        };
        row.displayDate = rateLockExpDate;
        return row;
    }

    private static PipelineRow buildGoldStarTransactionRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        String rateLockStatus = (String) safeSObjectValue(transactionRecord, 'Rate_Lock_Status__c');
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('processorName', row.processorName, row.processorName, false, 'Processor__c'),
            new TableCell('closingDate', formatDateForCell(row.displayDate), formatDateSortValue(row.displayDate), false, 'Closing_Date__c'),
            new TableCell('loanAmount', formatDecimalForCell(row.loanAmount), formatDecimalSortValue(row.loanAmount), false, 'Loan_Amount_1st__c'),
            new TableCell('lenderName', row.lenderName, row.lenderName, false, 'Lender_lookup__c'),
            new TableCell('rateLockStatus', rateLockStatus, rateLockStatus, false, 'Rate_Lock_Status__c'),
            new TableCell('rateLockExpDate', formatDateForCell(row.rateLockExpDate), formatDateSortValue(row.rateLockExpDate), false, 'Rate_Lock_Exp_Date__c'),
            new TableCell('status', row.status, row.status, false, 'Status__c')
        };
        return row;
    }

    private static PipelineRow buildOpenerAppraisalOutstandingRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        Date orderedDate = (Date) safeSObjectValue(transactionRecord, 'Appraisal_1_Ordered_Date__c');
        Datetime valueLinkOrderedDate = (Datetime) safeSObjectValue(transactionRecord, 'Appraisal_Ordered_Date_ValueLink__c');
        SObject appraisalOrder = safeRelationshipValue(transactionRecord, 'Appraisal_Order__r');
        String appraisalStatus = appraisalOrder == null
            ? 'Ordered - no active ValueLink order'
            : (String) safeSObjectValue(appraisalOrder, 'Appraisal_Status__c');
        Date appraisalDueDate = appraisalOrder == null
            ? null
            : (Date) safeSObjectValue(appraisalOrder, 'EstimatedCompletionDate__c');
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('status', row.status, row.status, false, 'Status__c'),
            new TableCell('appraisalOrderedDate', formatDateForCell(orderedDate), formatDateSortValue(orderedDate), false, 'Appraisal_1_Ordered_Date__c'),
            new TableCell('valueLinkOrderedDate', formatDatetimeForCell(valueLinkOrderedDate), formatDatetimeSortValue(valueLinkOrderedDate), false, 'Appraisal_Ordered_Date_ValueLink__c'),
            new TableCell('appraisalStatus', appraisalStatus, appraisalStatus, false),
            new TableCell('appraisalDueDate', formatDateForCell(appraisalDueDate), formatDateSortValue(appraisalDueDate), false),
            new TableCell('lenderName', row.lenderName, row.lenderName, false, 'Lender_lookup__c'),
            new TableCell('loanOfficerName', row.loanOfficerName, row.loanOfficerName, false),
            new TableCell('processorName', row.processorName, row.processorName, false),
            new TableCell('ownerName', row.ownerName, row.ownerName, false)
        };
        row.displayDate = orderedDate;
        row.displayDateTime = valueLinkOrderedDate;
        row.appraisalOrderedDate = orderedDate;
        row.valueLinkOrderedDate = valueLinkOrderedDate;
        row.appraisalStatus = appraisalStatus;
        row.appraisalDueDate = appraisalDueDate;
        return row;
    }

    private static PipelineRow buildBrokerChecksOutstandingRow(Transaction__c transactionRecord) {
        PipelineRow row = new PipelineRow(transactionRecord);
        row.customCells = new List<TableCell>{
            new TableCell('name', row.name, row.name, true),
            new TableCell('fundingDate', formatDateForCell(row.fundingDate), formatDateSortValue(row.fundingDate), false, 'Funding_Date__c')
        };
        row.displayDate = row.fundingDate;
        return row;
    }

    private static TableCell easeLinkCell(PipelineRow row) {
        String url = row == null ? null : row.easeLink;
        String lenderName = row == null ? null : row.lenderName;
        Boolean showLink = !String.isBlank(url) && lenderName == 'UWM';
        return new TableCell('easeLink', showLink ? 'EASE' : '', showLink ? 'EASE' : '', false, null, showLink ? url : null);
    }

    private static String formatGenericCellValue(Object value) {
        if (value == null) {
            return '';
        }
        if (value instanceof Date) {
            return formatDateForCell((Date) value);
        }
        if (value instanceof Datetime) {
            return formatDatetimeForCell((Datetime) value);
        }
        if (value instanceof Boolean) {
            return (Boolean) value ? 'Yes' : 'No';
        }
        return String.valueOf(value);
    }

    private static String formatDateForCell(Date dateValue) {
        return dateValue == null ? '' : String.valueOf(dateValue);
    }

    private static String formatDateSortValue(Date dateValue) {
        return dateValue == null ? '' : String.valueOf(dateValue);
    }

    private static String formatDatetimeForCell(Datetime datetimeValue) {
        return datetimeValue == null ? '' : datetimeValue.format('M/d/yyyy h:mm a');
    }

    private static String formatDatetimeSortValue(Datetime datetimeValue) {
        return datetimeValue == null ? '' : String.valueOf(datetimeValue.getTime());
    }

    private static String formatDecimalForCell(Decimal decimalValue) {
        return decimalValue == null ? '' : String.valueOf(decimalValue);
    }

    private static String formatDecimalSortValue(Decimal decimalValue) {
        return decimalValue == null ? '' : String.valueOf(decimalValue);
    }

    private static List<PipelineRow> buildStagnantLeads() {
        return buildStagnantLeads(getScopedLeadUserIds());
    }

    private static List<PipelineRow> buildStagnantLeads(Set<Id> leadScopeUserIds) {
        return buildStagnantLeads(leadScopeUserIds, 50);
    }

    private static List<PipelineRow> buildStagnantLeads(Set<Id> leadScopeUserIds, Integer rowLimit) {
        return buildStagnantLeads(leadScopeUserIds, rowLimit, MIN_LEAD_CREATED_DATE);
    }

    private static List<PipelineRow> buildStagnantLeads(Set<Id> leadScopeUserIds, Integer rowLimit, Date minimumCreatedDate) {
        List<PipelineRow> rows = new List<PipelineRow>();
        Date staleDate = Date.today().addDays(-7);
        DateTime staleCreatedDateTime = System.now().addDays(-7);
        for (Lead leadRecord : [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND Status NOT IN (
                'Closed',
                'Closed - Converted',
                'Converted',
                'Dead',
                'Duplicate',
                'Lost',
                'Withdrawn',
                'Submitted For Disclosures',
                'Submitted for Disclosures',
                'Nurtured',
                'Nurturing',
                'Pre-Approved',
                'Pre-Approval',
                'Nurture-Preapproval',
                'Nurture - Preapproval',
                'Nurture-Pre-Approval',
                '30 Day + Follow Up',
                'Credit Repair'
            )
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND CreatedDate >= :minimumCreatedDate
            AND CreatedDate <= :staleCreatedDateTime
            AND (LastActivityDate = null OR LastActivityDate <= :staleDate)
            ORDER BY LastActivityDate ASC NULLS FIRST, LastModifiedDate ASC
            LIMIT :rowLimit
        ]) {
            rows.add(new PipelineRow(leadRecord, leadRecord.LastActivityDate, null));
        }
        return rows;
    }

    private static List<PipelineRow> buildStagnantLeadsForBizDev(Set<Id> leadScopeUserIds, Integer rowLimit, Date minimumCreatedDate, String bizDevValue) {
        List<PipelineRow> rows = new List<PipelineRow>();
        if (String.isBlank(bizDevValue)) {
            return rows;
        }

        Date staleDate = Date.today().addDays(-7);
        DateTime staleCreatedDateTime = System.now().addDays(-7);
        for (Lead leadRecord : [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND Status NOT IN (
                'Closed',
                'Closed - Converted',
                'Converted',
                'Dead',
                'Duplicate',
                'Lost',
                'Withdrawn',
                'Submitted For Disclosures',
                'Submitted for Disclosures',
                'Nurtured',
                'Nurturing',
                'Pre-Approved',
                'Pre-Approval',
                'Nurture-Preapproval',
                'Nurture - Preapproval',
                'Nurture-Pre-Approval',
                '30 Day + Follow Up',
                'Credit Repair'
            )
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND Biz_Dev__c = :bizDevValue
            AND CreatedDate >= :minimumCreatedDate
            AND CreatedDate <= :staleCreatedDateTime
            AND (LastActivityDate = null OR LastActivityDate <= :staleDate)
            ORDER BY LastActivityDate ASC NULLS FIRST, LastModifiedDate ASC
            LIMIT :rowLimit
        ]) {
            rows.add(new PipelineRow(leadRecord, leadRecord.LastActivityDate, null));
        }
        return rows;
    }

    private static List<PipelineRow> buildStagnantPreApprovals() {
        return buildStagnantPreApprovals(getScopedLeadUserIds());
    }

    private static List<PipelineRow> buildStagnantPreApprovals(Set<Id> leadScopeUserIds) {
        DateTime staleDateTime = System.now().addDays(-6);
        List<Lead> candidateLeads = new List<Lead>();
        for (Lead leadRecord : [
            SELECT Id, Name, Status, CreatedDate, LastActivityDate, LeadSource, Phone, Email,
                Appointment_Date_Time__c, Loan_Details__c, Loan_Amount__c, Loan_Purpose__c,
                Last_Call_Attempt_RingCentral__c, Last_SMS_Attempt_RingCentral__c,
                Biz_Dev__c, Realtor_Buying_Agent__r.Name, Loan_Partner__r.Name, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND Status = 'Pre-Approval'
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            AND CreatedDate >= :MIN_LEAD_CREATED_DATE
            AND (Last_Call_Attempt_RingCentral__c = NULL OR Last_Call_Attempt_RingCentral__c <= :staleDateTime)
            AND (Last_SMS_Attempt_RingCentral__c = NULL OR Last_SMS_Attempt_RingCentral__c <= :staleDateTime)
            ORDER BY LastActivityDate ASC NULLS FIRST, LastModifiedDate ASC
            LIMIT 100
        ]) {
            candidateLeads.add(leadRecord);
        }

        Set<Id> recentlyEmailedLeadIds = leadIdsWithRecentEmail(new Map<Id, Lead>(candidateLeads).keySet(), staleDateTime);
        List<PipelineRow> rows = new List<PipelineRow>();
        for (Lead leadRecord : candidateLeads) {
            if (recentlyEmailedLeadIds.contains(leadRecord.Id)) {
                continue;
            }
            rows.add(new PipelineRow(leadRecord, leadRecord.LastActivityDate, null, 'No RingCentral call, SMS, or email in 6+ days'));
            if (rows.size() == 50) {
                break;
            }
        }
        return rows;
    }

    private static Set<Id> leadIdsWithRecentEmail(Set<Id> leadIds, DateTime staleDateTime) {
        Set<Id> recentlyEmailedLeadIds = new Set<Id>();
        if (leadIds == null || leadIds.isEmpty()) {
            return recentlyEmailedLeadIds;
        }

        for (EmailMessage emailRecord : [
            SELECT RelatedToId
            FROM EmailMessage
            WHERE RelatedToId IN :leadIds
            AND MessageDate > :staleDateTime
            LIMIT 500
        ]) {
            recentlyEmailedLeadIds.add(emailRecord.RelatedToId);
        }

        Date staleDate = Date.today().addDays(-6);
        for (Task taskRecord : [
            SELECT WhoId
            FROM Task
            WHERE WhoId IN :leadIds
            AND ActivityDate >= :staleDate
            AND (Type = 'Email' OR Subject LIKE '%Email%')
            LIMIT 500
        ]) {
            recentlyEmailedLeadIds.add(taskRecord.WhoId);
        }

        return recentlyEmailedLeadIds;
    }

    private static List<PipelineRow> buildLeadsNeedingAttention() {
        return buildLeadsNeedingAttention(getScopedLeadUserIds());
    }

    private static List<PipelineRow> buildLeadsNeedingAttention(Set<Id> leadScopeUserIds) {
        return buildLeadsNeedingAttention(leadScopeUserIds, 50);
    }

    private static List<PipelineRow> buildLeadsNeedingAttention(Set<Id> leadScopeUserIds, Integer rowLimit) {
        List<PipelineRow> rows = new List<PipelineRow>();
        DateTime startOfToday = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        List<Lead> candidateLeads = new List<Lead>();
        for (Lead leadRecord : [
            SELECT Id,
                Name,
                Status,
                CreatedDate,
                Appointment_Date_Time__c,
                Last_Call_Date__c,
                Last_Call_Attempt_RingCentral__c,
                Last_SMS_Attempt_RingCentral__c,
                Loan_Amount__c,
                Loan_Purpose__c,
                Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND Status IN :ATTENTION_LEAD_STATUSES
            AND (Appointment_Date_Time__c = null OR Appointment_Date_Time__c < :startOfToday)
            AND Biz_Dev__c IN :ATTENTION_BIZ_DEV_VALUES
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            ORDER BY Appointment_Date_Time__c ASC NULLS FIRST, LastModifiedDate ASC
            LIMIT 100
        ]) {
            if (!shouldIncludeAttentionLead(leadRecord)) {
                continue;
            }
            candidateLeads.add(leadRecord);
            if (candidateLeads.size() == rowLimit) {
                break;
            }
        }

        Map<Id, Event> latestEventsByLeadId = getLatestEventsByLeadId(new Map<Id, Lead>(candidateLeads).keySet());
        for (Lead leadRecord : candidateLeads) {
            Event latestEvent = latestEventsByLeadId.get(leadRecord.Id);
            Date latestEventDate = latestEvent == null ? null : latestEvent.ActivityDate;
            DateTime latestEventDateTime = latestEvent == null
                ? null
                : latestEvent.ActivityDateTime == null ? latestEvent.StartDateTime : latestEvent.ActivityDateTime;
            rows.add(new PipelineRow(
                leadRecord,
                latestEventDate,
                latestEventDateTime,
                latestEvent == null ? null : latestEvent.Subject
            ));
        }
        return rows;
    }

    private static List<PipelineRow> buildLeadsNeedingAttentionForBizDev(Set<Id> leadScopeUserIds, Integer rowLimit, String bizDevValue) {
        List<PipelineRow> rows = new List<PipelineRow>();
        if (String.isBlank(bizDevValue)) {
            return rows;
        }

        DateTime startOfToday = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        List<Lead> candidateLeads = new List<Lead>();
        for (Lead leadRecord : [
            SELECT Id,
                Name,
                Status,
                CreatedDate,
                Appointment_Date_Time__c,
                Last_Call_Date__c,
                Last_Call_Attempt_RingCentral__c,
                Last_SMS_Attempt_RingCentral__c,
                Loan_Amount__c,
                Loan_Purpose__c,
                Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND RecordType.DeveloperName IN :CONSUMER_LEAD_RECORD_TYPES
            AND Status IN :ATTENTION_LEAD_STATUSES
            AND (Appointment_Date_Time__c = null OR Appointment_Date_Time__c < :startOfToday)
            AND Biz_Dev__c = :bizDevValue
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            ORDER BY Appointment_Date_Time__c ASC NULLS FIRST, LastModifiedDate ASC
            LIMIT 100
        ]) {
            if (!shouldIncludeAttentionLead(leadRecord)) {
                continue;
            }
            candidateLeads.add(leadRecord);
            if (candidateLeads.size() == rowLimit) {
                break;
            }
        }

        Map<Id, Event> latestEventsByLeadId = getLatestEventsByLeadId(new Map<Id, Lead>(candidateLeads).keySet());
        for (Lead leadRecord : candidateLeads) {
            Event latestEvent = latestEventsByLeadId.get(leadRecord.Id);
            Date latestEventDate = latestEvent == null ? null : latestEvent.ActivityDate;
            DateTime latestEventDateTime = latestEvent == null
                ? null
                : latestEvent.ActivityDateTime == null ? latestEvent.StartDateTime : latestEvent.ActivityDateTime;
            rows.add(new PipelineRow(
                leadRecord,
                latestEventDate,
                latestEventDateTime,
                latestEvent == null ? null : latestEvent.Subject
            ));
        }
        return rows;
    }

    private static Map<Id, Event> getLatestEventsByLeadId(Set<Id> leadIds) {
        Map<Id, Event> latestEventsByLeadId = new Map<Id, Event>();
        if (leadIds == null || leadIds.isEmpty()) {
            return latestEventsByLeadId;
        }

        for (Event eventRecord : [
            SELECT Id, Subject, WhoId, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhoId IN :leadIds
            ORDER BY ActivityDate DESC NULLS LAST, ActivityDateTime DESC NULLS LAST, StartDateTime DESC NULLS LAST
            LIMIT 500
        ]) {
            if (!latestEventsByLeadId.containsKey(eventRecord.WhoId)) {
                latestEventsByLeadId.put(eventRecord.WhoId, eventRecord);
            }
        }
        return latestEventsByLeadId;
    }

    private static Boolean shouldIncludeAttentionLead(Lead leadRecord) {
        String leadName = String.isBlank(leadRecord.Name) ? '' : leadRecord.Name.toLowerCase();
        String ownerName = leadRecord.Owner == null || String.isBlank(leadRecord.Owner.Name)
            ? ''
            : leadRecord.Owner.Name.toLowerCase();

        return !leadName.contains('test')
            && !ownerName.contains('brotsky')
            && !ownerName.contains('stephens')
            && !ownerName.contains('queue')
            && (
                String.isBlank(leadRecord.Loan_Purpose__c)
                || !EXCLUDED_ATTENTION_PURPOSES.contains(leadRecord.Loan_Purpose__c)
            );
    }

    private static List<PipelineRow> buildLeadsWithEventsToday() {
        return buildLeadsWithEventsToday(getScopedLeadUserIds());
    }

    private static List<PipelineRow> buildLeadsWithEventsToday(Set<Id> leadScopeUserIds) {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        Boolean assistantScopedView = currentUserUsesLoanOfficerAssistantPipeline();
        Map<Id, Lead> leadsById = new Map<Id, Lead>([
            SELECT Id, Name, Status, CreatedDate, Loan_Amount__c, Loan_Purpose__c, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND (OwnerId IN :leadScopeUserIds OR Loan_Partner__c IN :leadScopeUserIds)
            LIMIT 1000
        ]);

        Set<Id> leadIdsFromOwnedEvents = new Set<Id>();
        if (!assistantScopedView) {
            for (Event eventRecord : [
                SELECT WhoId
                FROM Event
                WHERE OwnerId = :currentUserId
                AND ActivityDate = TODAY
                AND WhoId != null
                LIMIT 500
            ]) {
                if (String.valueOf(eventRecord.WhoId).startsWith(Lead.SObjectType.getDescribe().getKeyPrefix())) {
                    leadIdsFromOwnedEvents.add(eventRecord.WhoId);
                }
            }
        }

        Set<Id> eventLeadIds = new Set<Id>();
        eventLeadIds.addAll(leadsById.keySet());
        eventLeadIds.addAll(leadIdsFromOwnedEvents);
        if (eventLeadIds.isEmpty()) {
            return rows;
        }

        for (Lead leadRecord : [
            SELECT Id, Name, Status, CreatedDate, Loan_Amount__c, Loan_Purpose__c, Owner.Name
            FROM Lead
            WHERE Id IN :leadIdsFromOwnedEvents
        ]) {
            leadsById.put(leadRecord.Id, leadRecord);
        }

        for (Event eventRecord : [
            SELECT Id, Subject, WhoId, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhoId IN :eventLeadIds
            AND ActivityDate = TODAY
            ORDER BY ActivityDateTime ASC NULLS LAST, StartDateTime ASC NULLS LAST
            LIMIT 100
        ]) {
            Lead leadRecord = leadsById.get(eventRecord.WhoId);
            if (leadRecord == null) {
                continue;
            }
            DateTime eventDateTime = eventRecord.ActivityDateTime == null
                ? eventRecord.StartDateTime
                : eventRecord.ActivityDateTime;
            rows.add(new PipelineRow(leadRecord, eventRecord.ActivityDate, eventDateTime, eventRecord.Subject));
        }
        return rows;
    }

    private static List<PipelineRow> buildTransactionsWithEventsToday() {
        List<PipelineRow> rows = new List<PipelineRow>();
        Id currentUserId = UserInfo.getUserId();
        Map<Id, Transaction__c> assignedTransactionsById = new Map<Id, Transaction__c>([
            SELECT Id, Name, Status__c, Closing_Date__c, Loan_Amount_1st__c, Loan_Purpose__c, Ease_Link__c, Lender_lookup__r.Name, Owner.Name
            FROM Transaction__c
            WHERE Status__c NOT IN :EXCLUDED_ACTIVE_PIPELINE_STATUSES
            AND (OwnerId = :currentUserId
                OR Transaction_Owner__c = :currentUserId
                OR Processor__c = :currentUserId
                OR Additional_Processor__c = :currentUserId
                OR Loan_Officer__c = :currentUserId
                OR Loan_Partner__c = :currentUserId)
            LIMIT 500
        ]);
        if (assignedTransactionsById.isEmpty()) {
            return rows;
        }

        for (Event eventRecord : [
            SELECT Id, Subject, WhatId, ActivityDate, ActivityDateTime, StartDateTime
            FROM Event
            WHERE WhatId IN :assignedTransactionsById.keySet()
            AND ActivityDate = TODAY
            ORDER BY ActivityDateTime ASC NULLS LAST, StartDateTime ASC NULLS LAST
            LIMIT 12
        ]) {
            Transaction__c transactionRecord = assignedTransactionsById.get(eventRecord.WhatId);
            if (transactionRecord == null) {
                continue;
            }
            DateTime eventDateTime = eventRecord.ActivityDateTime == null
                ? eventRecord.StartDateTime
                : eventRecord.ActivityDateTime;
            rows.add(new PipelineRow(transactionRecord, eventRecord.ActivityDate, eventDateTime, eventRecord.Subject));
        }
        return rows;
    }

    private static List<PipelineRow> buildDocsCommentsPendingReview() {
        List<PipelineRow> rows = new List<PipelineRow>();
        for (ConditionReviewQueueService.LoanQueueDto loanQueueItem : ConditionReviewQueueService.buildQueue()) {
            rows.add(new PipelineRow(loanQueueItem));
            if (rows.size() == 50) {
                break;
            }
        }
        return rows;
    }

    private static String buildPendingReviewDetail(ConditionReviewQueueService.LoanQueueDto loanQueueItem) {
        Integer conditionCount = loanQueueItem.pendingConditionsCount == null
            ? 0
            : loanQueueItem.pendingConditionsCount;
        Integer unreadCommentCount = loanQueueItem.unreadCommentsCount == null
            ? 0
            : loanQueueItem.unreadCommentsCount;
        Integer documentCount = 0;
        for (ConditionReviewQueueService.ConditionDto conditionItem : loanQueueItem.conditions) {
            documentCount += conditionItem.documentCount == null ? 0 : conditionItem.documentCount;
        }

        List<String> parts = new List<String>{
            conditionCount + ' ' + (conditionCount == 1 ? 'condition' : 'conditions')
        };
        if (documentCount > 0) {
            parts.add(documentCount + ' ' + (documentCount == 1 ? 'document' : 'documents'));
        }
        if (unreadCommentCount > 0) {
            parts.add(unreadCommentCount + ' unread ' + (unreadCommentCount == 1 ? 'comment' : 'comments'));
        }
        return String.join(parts, ' / ');
    }

    public class DashboardData {
        @AuraEnabled public String headerTitle { get; set; }
        @AuraEnabled public Id currentUserId { get; set; }
        @AuraEnabled public String headerSubtitle { get; set; }
        @AuraEnabled public String columnPreferencesJson { get; set; }
        @AuraEnabled public Boolean isCeoDashboard { get; set; }
        @AuraEnabled public List<StatusCard> statusCards { get; set; }
        @AuraEnabled public List<PipelineRow> pipelineRows { get; set; }
        @AuraEnabled public String pipelineTitle { get; set; }
        @AuraEnabled public String pipelineSubtitle { get; set; }
        @AuraEnabled public String pipelineObjectApiName { get; set; }
        @AuraEnabled public List<PipelineTab> pipelineTabs { get; set; }
        @AuraEnabled public List<QuickButton> quickButtons { get; set; }
        @AuraEnabled public List<QuickButton> queueShortcuts { get; set; }
        @AuraEnabled public Boolean canEditPipelineTabRows { get; set; }
        @AuraEnabled public Boolean canEditQuickButtons { get; set; }
        @AuraEnabled public Boolean canCreateLead { get; set; }
        @AuraEnabled public Boolean canAssignNewLeadOwner { get; set; }
        @AuraEnabled public Boolean canCreateTitleAgent { get; set; }
        @AuraEnabled public Boolean isPastClientDashboard { get; set; }
        @AuraEnabled public Boolean isRhettDelaney { get; set; }
    }

    public class NewLeadFormOptions {
        @AuraEnabled public List<PicklistOption> leadSourceOptions { get; set; }
        @AuraEnabled public List<PicklistOption> loanPurposeOptions { get; set; }
        @AuraEnabled public List<PicklistOption> bizDevOptions { get; set; }
        @AuraEnabled public List<PicklistOption> ownerOptions { get; set; }

        public NewLeadFormOptions() {
            leadSourceOptions = new List<PicklistOption>();
            loanPurposeOptions = new List<PicklistOption>();
            bizDevOptions = new List<PicklistOption>();
            ownerOptions = new List<PicklistOption>();
        }
    }

    public class RealtorPartnerMetric implements Comparable {
        public String partnerName;
        public String loanOfficerName;
        public Integer leadCount = 0;
        public Integer preApprovalCount = 0;
        public Date lastReferralDate;

        public RealtorPartnerMetric(String partnerName, String loanOfficerName) {
            this.partnerName = partnerName;
            this.loanOfficerName = loanOfficerName;
        }

        public Integer compareTo(Object otherObject) {
            RealtorPartnerMetric otherMetric = (RealtorPartnerMetric) otherObject;
            Integer otherCount = otherMetric == null || otherMetric.leadCount == null ? 0 : otherMetric.leadCount;
            Integer thisCount = leadCount == null ? 0 : leadCount;
            if (otherCount != thisCount) {
                return otherCount - thisCount;
            }
            String thisName = String.isBlank(partnerName) ? '' : partnerName;
            String otherName = otherMetric == null || String.isBlank(otherMetric.partnerName) ? '' : otherMetric.partnerName;
            return thisName.compareTo(otherName);
        }
    }

    public class StatusCard {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public String valueText { get; set; }
        @AuraEnabled public String helperText { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String filterName { get; set; }

        public StatusCard(String label, Integer count, String helperText) {
            this.label = label;
            this.count = count == null ? 0 : count;
            this.valueText = String.valueOf(this.count);
            this.helperText = helperText;
        }

        public StatusCard(String label, Integer count, String valueText, String helperText) {
            this.label = label;
            this.count = count == null ? 0 : count;
            this.valueText = String.isBlank(valueText) ? String.valueOf(this.count) : valueText;
            this.helperText = helperText;
        }

        public StatusCard(String label, Integer count, String helperText, String objectApiName, String filterName) {
            this(label, count, helperText);
            this.objectApiName = objectApiName;
            this.filterName = filterName;
        }
    }

    public class PipelineRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date displayDate { get; set; }
        @AuraEnabled public Date cdSentDate { get; set; }
        @AuraEnabled public Date fundingDate { get; set; }
        @AuraEnabled public Datetime displayDateTime { get; set; }
        @AuraEnabled public Decimal loanAmount { get; set; }
        @AuraEnabled public String loanPurpose { get; set; }
        @AuraEnabled public Datetime tridDateTime { get; set; }
        @AuraEnabled public Datetime disclosuresOutDate { get; set; }
        @AuraEnabled public Datetime disclosuresSignedDate { get; set; }
        @AuraEnabled public String closerNotes { get; set; }
        @AuraEnabled public String lenderName { get; set; }
        @AuraEnabled public String loanOfficerName { get; set; }
        @AuraEnabled public String loanPartnerName { get; set; }
        @AuraEnabled public String processorName { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Datetime lastProcessorSms { get; set; }
        @AuraEnabled public Datetime lastProcessorCall { get; set; }
        @AuraEnabled public String detail { get; set; }
        @AuraEnabled public String leadSource { get; set; }
        @AuraEnabled public String bizDev { get; set; }
        @AuraEnabled public Id borrowerAccountId { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String propertyAddress { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public Datetime createdDateTime { get; set; }
        @AuraEnabled public Date lastActivityDate { get; set; }
        @AuraEnabled public Datetime appointmentDateTime { get; set; }
        @AuraEnabled public String realtorBuyingAgentName { get; set; }
        @AuraEnabled public String loanDetails { get; set; }
        @AuraEnabled public Date cdSentByDate { get; set; }
        @AuraEnabled public Date closingInstructionsSent { get; set; }
        @AuraEnabled public Date vestingConfirmed { get; set; }
        @AuraEnabled public Date cdIsBalanced { get; set; }
        @AuraEnabled public String loanType { get; set; }
        @AuraEnabled public Date rateLockExpDate { get; set; }
        @AuraEnabled public Date mersRegistrationComplete { get; set; }
        @AuraEnabled public Date closingPackageSent { get; set; }
        @AuraEnabled public String warehouseBankName { get; set; }
        @AuraEnabled public String closingType { get; set; }
        @AuraEnabled public Date fundingWireRequested { get; set; }
        @AuraEnabled public String federalReferenceNumber { get; set; }
        @AuraEnabled public Date fundingAuthorization { get; set; }
        @AuraEnabled public Date mersUploadedActivated { get; set; }
        @AuraEnabled public Date noteReceivedDate { get; set; }
        @AuraEnabled public Date appraisalOrderedDate { get; set; }
        @AuraEnabled public Datetime valueLinkOrderedDate { get; set; }
        @AuraEnabled public String appraisalStatus { get; set; }
        @AuraEnabled public Date appraisalDueDate { get; set; }
        @AuraEnabled public String easeLink { get; set; }
        @AuraEnabled public List<TableCell> customCells { get; set; }

        public PipelineRow() {
            customCells = new List<TableCell>();
        }

        public PipelineRow(Transaction__c transactionRecord) {
            id = transactionRecord.Id;
            name = transactionRecord.Name;
            status = (String) safeSObjectValue(transactionRecord, 'Status__c');
            displayDate = (Date) safeSObjectValue(transactionRecord, 'Closing_Date__c');
            cdSentByDate = (Date) safeSObjectValue(transactionRecord, 'CD_Sent_By_Date__c');
            cdSentDate = (Date) safeSObjectValue(transactionRecord, 'CD_Sent_Date__c');
            fundingDate = (Date) safeSObjectValue(transactionRecord, 'Funding_Date__c');
            closingInstructionsSent = (Date) safeSObjectValue(transactionRecord, 'Closing_Instructions_Sent__c');
            vestingConfirmed = (Date) safeSObjectValue(transactionRecord, 'Vesting_Confirmed__c');
            cdIsBalanced = (Date) safeSObjectValue(transactionRecord, 'CD_Is_Balanced__c');
            loanType = (String) safeSObjectValue(transactionRecord, 'Loan_Type_1st_TD__c');
            rateLockExpDate = (Date) safeSObjectValue(transactionRecord, 'Rate_Lock_Exp_Date__c');
            mersRegistrationComplete = (Date) safeSObjectValue(transactionRecord, 'MERS_Registration_Complete__c');
            closingPackageSent = (Date) safeSObjectValue(transactionRecord, 'Closing_Package_Sent__c');
            closingType = (String) safeSObjectValue(transactionRecord, 'Closing_Type__c');
            fundingWireRequested = (Date) safeSObjectValue(transactionRecord, 'Funding_Wire_Requested__c');
            federalReferenceNumber = (String) safeSObjectValue(transactionRecord, 'Federal_Reference_Number__c');
            fundingAuthorization = (Date) safeSObjectValue(transactionRecord, 'Funding_Authorization__c');
            mersUploadedActivated = (Date) safeSObjectValue(transactionRecord, 'MERSUploadedActivated__c');
            noteReceivedDate = (Date) safeSObjectValue(transactionRecord, 'Note_Received_Date__c');
            easeLink = (String) safeSObjectValue(transactionRecord, 'Ease_Link__c');
            loanAmount = (Decimal) safeSObjectValue(transactionRecord, 'Loan_Amount_1st__c');
            loanPurpose = (String) safeSObjectValue(transactionRecord, 'Loan_Purpose__c');
            tridDateTime = (Datetime) safeSObjectValue(transactionRecord, 'TRID_Date__c');
            disclosuresOutDate = (Datetime) safeSObjectValue(transactionRecord, 'Disclosures_Out_Date__c');
            disclosuresSignedDate = (Datetime) safeSObjectValue(transactionRecord, 'Disclosures_Received_Date__c');
            closerNotes = (String) safeSObjectValue(transactionRecord, 'Manager_Notes__c');
            detail = (String) safeSObjectValue(transactionRecord, 'Processor_Note__c');
            if (String.isBlank(detail)) {
                detail = (String) safeSObjectValue(transactionRecord, 'Processor_Note_For_Display__c');
            }
            SObject lenderRecord = safeRelationshipValue(transactionRecord, 'Lender_lookup__r');
            lenderName = lenderRecord == null ? null : (String) safeSObjectValue(lenderRecord, 'Name');
            warehouseBankName = (String) safeSObjectValue(transactionRecord, 'Warehouse_Bank_Picklist__c');
            if (String.isBlank(warehouseBankName)) {
                SObject warehouseBankRecord = safeRelationshipValue(transactionRecord, 'Warehouse_Bank__r');
                warehouseBankName = warehouseBankRecord == null ? null : (String) safeSObjectValue(warehouseBankRecord, 'Name');
            }
            SObject loanOfficerRecord = safeRelationshipValue(transactionRecord, 'Loan_Officer__r');
            loanOfficerName = loanOfficerRecord == null ? null : (String) safeSObjectValue(loanOfficerRecord, 'Name');
            SObject loanPartnerRecord = safeRelationshipValue(transactionRecord, 'Loan_Partner__r');
            loanPartnerName = loanPartnerRecord == null ? null : (String) safeSObjectValue(loanPartnerRecord, 'Name');
            bizDev = (String) safeSObjectValue(transactionRecord, 'Biz_Dev__c');
            SObject processorRecord = safeRelationshipValue(transactionRecord, 'Processor__r');
            processorName = processorRecord == null ? null : (String) safeSObjectValue(processorRecord, 'Name');
            SObject ownerRecord = safeRelationshipValue(transactionRecord, 'Owner');
            ownerName = ownerRecord == null ? null : (String) safeSObjectValue(ownerRecord, 'Name');
            lastProcessorSms = (Datetime) safeSObjectValue(transactionRecord, 'Last_Processor_RC_SMS__c');
            lastProcessorCall = (Datetime) safeSObjectValue(transactionRecord, 'Last_Processor_RC_Call__c');
            borrowerAccountId = (Id) safeSObjectValue(transactionRecord, 'Borrower_Name__c');
            SObject borrowerRecord = safeRelationshipValue(transactionRecord, 'Borrower_Name__r');
            phone = firstNonBlank(new List<String>{
                borrowerRecord == null ? null : (String) safeSObjectValue(borrowerRecord, 'Corrected_Mobile__pc'),
                borrowerRecord == null ? null : (String) safeSObjectValue(borrowerRecord, 'PersonMobilePhone'),
                borrowerRecord == null ? null : (String) safeSObjectValue(borrowerRecord, 'Phone'),
                borrowerRecord == null ? null : (String) safeSObjectValue(borrowerRecord, 'Corrected_Phone__pc')
            });
            propertyAddress = composePropertyAddress(
                (String) safeSObjectValue(transactionRecord, 'Property_Address__c'),
                (String) safeSObjectValue(transactionRecord, 'Property_City__c'),
                (String) safeSObjectValue(transactionRecord, 'Property_State__c')
            );
            email = borrowerRecord == null ? null : (String) safeSObjectValue(borrowerRecord, 'PersonEmail');
            customCells = new List<TableCell>();
        }

        public PipelineRow(Transaction__c transactionRecord, Date overrideDate, DateTime overrideDateTime, String detailText) {
            this(transactionRecord);
            if (overrideDate != null) {
                displayDate = overrideDate;
            }
            displayDateTime = overrideDateTime;
            detail = detailText;
        }

        public PipelineRow(ConditionReviewQueueService.LoanQueueDto loanQueueItem) {
            id = loanQueueItem.loanId;
            name = String.isBlank(loanQueueItem.loanName) ? loanQueueItem.borrowerName : loanQueueItem.loanName;
            status = loanQueueItem.stage;
            loanAmount = loanQueueItem.loanAmount;
            lenderName = loanQueueItem.lenderName;
            ownerName = loanQueueItem.borrowerName;
            detail = buildPendingReviewDetail(loanQueueItem);
        }

        public PipelineRow(Lead leadRecord) {
            id = leadRecord.Id;
            name = leadRecord.Name;
            status = leadRecord.Status;
            createdDateTime = leadRecord.CreatedDate;
            displayDate = leadRecord.CreatedDate == null ? null : Date.newInstance(leadRecord.CreatedDate.year(), leadRecord.CreatedDate.month(), leadRecord.CreatedDate.day());
            lastActivityDate = (Date) safeSObjectValue(leadRecord, 'LastActivityDate');
            loanAmount = (Decimal) safeSObjectValue(leadRecord, 'Loan_Amount__c');
            loanPurpose = (String) safeSObjectValue(leadRecord, 'Loan_Purpose__c');
            ownerName = leadRecord.Owner == null ? null : leadRecord.Owner.Name;
            loanOfficerName = ownerName;
            SObject loanPartnerRecord = safeRelationshipValue(leadRecord, 'Loan_Partner__r');
            loanPartnerName = loanPartnerRecord == null ? null : (String) safeSObjectValue(loanPartnerRecord, 'Name');
            leadSource = (String) safeSObjectValue(leadRecord, 'LeadSource');
            bizDev = (String) safeSObjectValue(leadRecord, 'Biz_Dev__c');
            phone = (String) safeSObjectValue(leadRecord, 'Phone');
            email = (String) safeSObjectValue(leadRecord, 'Email');
            appointmentDateTime = (Datetime) safeSObjectValue(leadRecord, 'Appointment_Date_Time__c');
            loanDetails = (String) safeSObjectValue(leadRecord, 'Loan_Details__c');
            SObject realtorBuyingAgentRecord = safeRelationshipValue(leadRecord, 'Realtor_Buying_Agent__r');
            realtorBuyingAgentName = realtorBuyingAgentRecord == null ? null : (String) safeSObjectValue(realtorBuyingAgentRecord, 'Name');
        }

        public PipelineRow(Lead leadRecord, Date overrideDate, DateTime overrideDateTime) {
            this(leadRecord);
            if (overrideDate != null) {
                displayDate = overrideDate;
            }
            displayDateTime = overrideDateTime;
        }

        public PipelineRow(Lead leadRecord, Date overrideDate, DateTime overrideDateTime, String detailText) {
            this(leadRecord, overrideDate, overrideDateTime);
            detail = detailText;
        }
    }

    public class PipelineTab {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public List<PipelineRow> rows { get; set; }
        @AuraEnabled public List<ConversionMetricRow> metricRows { get; set; }
        @AuraEnabled public List<TableColumn> customColumns { get; set; }
        @AuraEnabled public Integer count { get; set; }

        public PipelineTab(String key, String label, String subtitle, String objectApiName, List<PipelineRow> rows) {
            this.key = key;
            this.label = label;
            this.subtitle = subtitle;
            this.objectApiName = objectApiName;
            this.rows = rows == null ? new List<PipelineRow>() : rows;
            this.metricRows = new List<ConversionMetricRow>();
            this.customColumns = new List<TableColumn>();
            this.count = this.rows.size();
        }

        public PipelineTab(String key, String label, String subtitle, String objectApiName, List<PipelineRow> rows, List<TableColumn> customColumns) {
            this(key, label, subtitle, objectApiName, rows);
            this.customColumns = customColumns == null ? new List<TableColumn>() : customColumns;
        }

        public PipelineTab(String key, String label, String subtitle, String objectApiName, List<ConversionMetricRow> metricRows, Boolean isMetricTab) {
            this.key = key;
            this.label = label;
            this.subtitle = subtitle;
            this.objectApiName = objectApiName;
            this.rows = new List<PipelineRow>();
            this.metricRows = metricRows == null ? new List<ConversionMetricRow>() : metricRows;
            this.customColumns = new List<TableColumn>();
            this.count = this.metricRows.size();
        }
    }

    public class TableColumn {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }

        public TableColumn(String key, String label) {
            this.key = key;
            this.label = label;
        }
    }

    private class EventCell {
        String label { get; set; }
        String sortValue { get; set; }

        EventCell(Event eventRecord) {
            Datetime eventDateTime = eventDisplayDateTime(eventRecord);
            String dateText = eventDateTime == null ? formatDateForCell(eventRecord.ActivityDate) : formatDatetimeForCell(eventDateTime);
            String subjectText = String.isBlank(eventRecord.Subject) ? 'Scheduled Event' : eventRecord.Subject;
            label = String.isBlank(dateText) ? subjectText : dateText + ' - ' + subjectText;
            sortValue = eventDateTime == null ? formatDateSortValue(eventRecord.ActivityDate) : formatDatetimeSortValue(eventDateTime);
        }

        private Datetime eventDisplayDateTime(Event eventRecord) {
            if (eventRecord == null) {
                return null;
            }
            if (eventRecord.ActivityDateTime != null) {
                return eventRecord.ActivityDateTime;
            }
            if (eventRecord.StartDateTime != null) {
                return eventRecord.StartDateTime;
            }
            return null;
        }
    }

    public class LookupOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String subtitle { get; set; }

        public LookupOption(Id value, String label, String subtitle) {
            this.value = value == null ? null : String.valueOf(value);
            this.label = label;
            this.subtitle = subtitle;
        }
    }

    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class TableCell {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String sortValue { get; set; }
        @AuraEnabled public Boolean isRecordLink { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public Boolean editable { get; set; }
        @AuraEnabled public String url { get; set; }
        @AuraEnabled public Boolean isExternalLink { get; set; }

        public TableCell(String key, String value, String sortValue, Boolean isRecordLink) {
            this(key, value, sortValue, isRecordLink, null);
        }

        public TableCell(String key, String value, String sortValue, Boolean isRecordLink, String fieldApiName) {
            this(key, value, sortValue, isRecordLink, fieldApiName, null);
        }

        public TableCell(String key, String value, String sortValue, Boolean isRecordLink, String fieldApiName, String url) {
            this.key = key;
            this.value = value;
            this.sortValue = sortValue;
            this.isRecordLink = isRecordLink == true;
            this.fieldApiName = fieldApiName;
            this.editable = !String.isBlank(fieldApiName);
            this.url = url;
            this.isExternalLink = !String.isBlank(url);
        }
    }

    public class ConversionMetricRow {
        @AuraEnabled public Id loanOfficerId { get; set; }
        @AuraEnabled public String loanOfficerName { get; set; }
        @AuraEnabled public Decimal newToPreApprovalPercent { get; set; }
        @AuraEnabled public Decimal preApprovalToTransactionPercent { get; set; }
        @AuraEnabled public Decimal newToPostClosedPercent { get; set; }
        @AuraEnabled public Decimal averageActiveDays { get; set; }
        @AuraEnabled public String newToPreApprovalReportUrl { get; set; }
        @AuraEnabled public String preApprovalToTransactionReportUrl { get; set; }
        @AuraEnabled public String newToPostClosedReportUrl { get; set; }
        @AuraEnabled public String averageActiveDaysReportUrl { get; set; }

        public ConversionMetricRow(
            Id loanOfficerId,
            String loanOfficerName,
            Decimal newToPreApprovalPercent,
            Decimal preApprovalToTransactionPercent,
            Decimal newToPostClosedPercent,
            Decimal averageActiveDays
        ) {
            this.loanOfficerId = loanOfficerId;
            this.loanOfficerName = loanOfficerName;
            this.newToPreApprovalPercent = newToPreApprovalPercent;
            this.preApprovalToTransactionPercent = preApprovalToTransactionPercent;
            this.newToPostClosedPercent = newToPostClosedPercent;
            this.averageActiveDays = averageActiveDays == null ? 0 : averageActiveDays;
            this.newToPreApprovalReportUrl = reportUrl(REPORT_NEW_TO_PREAPPROVAL, loanOfficerName);
            this.preApprovalToTransactionReportUrl = reportUrl(REPORT_PREAPPROVAL_TO_TRANSACTION, loanOfficerName);
            this.newToPostClosedReportUrl = reportUrl(REPORT_NEW_TO_POST_CLOSED, loanOfficerName);
            this.averageActiveDaysReportUrl = reportUrl(REPORT_ACTIVE_DAYS, loanOfficerName);
        }
    }

    public class QuickButton {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String filterName { get; set; }

        public QuickButton() {}

        public QuickButton(String label, String objectApiName, String filterName) {
            this.label = label;
            this.objectApiName = objectApiName;
            this.filterName = filterName;
        }
    }

    public class ListViewOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String filterName { get; set; }

        public ListViewOption(ListView viewRecord) {
            label = viewRecord.Name;
            objectApiName = viewRecord.SobjectType;
            filterName = viewRecord.DeveloperName;
        }
    }

    private class OpenerChecklistItem {
        String label;
        String fieldName;
        Boolean hasValidation;
        String validationField;
        String validationType;
        String validationValue;

        OpenerChecklistItem(ChecklistItem__mdt itemRecord) {
            label = String.isBlank(itemRecord.Custom_Label__c) ? itemRecord.MasterLabel : itemRecord.Custom_Label__c;
            fieldName = itemRecord.FieldName__c;
            hasValidation = itemRecord.HasValidation__c;
            validationField = itemRecord.ValidationField__c;
            validationType = itemRecord.ValidationType__c;
            validationValue = itemRecord.ValidationValue__c;
        }
    }
}
