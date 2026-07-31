/**
 * @author Andrei Karanko
 * @date 8/1/2023
 * description
 */
@IsTest
public class TestDataFactory {
    public static String getOpportunityStageName() {
        String testOpportunityStageName;
        Schema.DescribeFieldResult opportunityStageName = Transaction__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> opportunityStageNameValues = opportunityStageName.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : opportunityStageNameValues){
            if (pickListVal.isActive()) {
                testOpportunityStageName = pickListVal.getValue();
                break;
            }
        }

        return testOpportunityStageName;
    }


	/*public static ContentVersion createContentVersion(Id linkedEntityId) {
		ContentVersion contentVersion = getContentVersion();
		insert contentVersion;
		ContentDocumentLink contentlink = getContentDocLink(contentVersion.Id, linkedEntityId);
		insert contentlink;
		return contentVersion;
	}*/

	/*public static ContentVersion getContentVersion() {
		Blob bodyBlob = Blob.valueOf('Unit Test ContentVersion Body');

		ContentVersion contentVersion = new ContentVersion(
			Title='SampleTitle',
			PathOnClient ='SampleTitle.jpg',
			VersionData = bodyBlob,
			origin = 'H'
		);

		return contentVersion;
	}

	public static ContentDocumentLink getContentDocLink(Id contentVersionId, Id linkedEntityId) {
		ContentVersion contentVersion = [
			SELECT Id, Title, ContentDocumentId, ContentDocument.Title, Folder__c,
			Loan_Condition__r.Name, ContentDocument.CreatedBy.Name, ContentDocument.CreatedDate
			FROM ContentVersion
			WHERE Id = :contentVersionId
			LIMIT 1
		];

		ContentDocumentLink contentlink = new ContentDocumentLink(
			LinkedEntityId = linkedEntityId,
			ContentDocumentId = contentVersion.ContentDocumentId,
			ShareType = 'V'
		);

		return contentlink;
	}*/

    public static User getUserByProfileName(String profileName) {
        return [
            SELECT Id, UserRoleId, IsActive
            FROM User
            WHERE Profile.Name = :profileName AND IsActive = TRUE
            LIMIT 1
        ];
    }

    public static List<Transaction__c> createTransactions(Map<String,Object> parameters) {
        List<Transaction__c> opportunities = new List<Transaction__c>();
        Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
        String name = (String)parameters.get('name');
        String stageName = (String)parameters.get('stageName');
        String loanNumber = (String) parameters.get('loanNumber');
        Date closeDate = Date.valueOf(parameters.get('closeDate'));

        for (Integer i = 0; i < numberOfRecords; i++) {
            Transaction__c opportunity = new Transaction__c();
            opportunity.Name = name + i;
            opportunity.Status__c = stageName;
            opportunity.Loan_Number__c = loanNumber;
            //opportunity.CloseDate = closeDate;
            opportunities.add(opportunity);
        }

        return opportunities;
    }

    public static List<Condition__c> createLoanConditions(Map<String,Object> parameters) {
        List<Condition__c> loanConditions = new List<Condition__c>();
        Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
        String name = (String)parameters.get('name');
        String type = (String)parameters.get('type');

        for (Integer i = 0; i < numberOfRecords; i++) {
            Condition__c lc = new Condition__c();
            lc.Type__c = type;
            if (parameters.containsKey('transactionId')) {
                lc.Transaction__c = (Id) parameters.get('transactionId');
            }
            if (parameters.containsKey('description')) {
                lc.Description__c = (String) parameters.get('description');
            }
            loanConditions.add(lc);
        }

        return loanConditions;
    }

    public static List<Lead> createLeads(Map<String,Object> parameters) {
        List<Lead> leads = new List<Lead>();
        Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
        String firstName = (String)parameters.get('firstName');
        String lastName = (String)parameters.get('lastName');
        String email = (String)parameters.get('email');

        for (Integer i = 0; i < numberOfRecords; i++) {
            Lead l = new Lead();
            l.FirstName = firstName;
            l.LastName = lastName + i;
            l.Email = email;
            leads.add(l);
        }

        return leads;
    }

    public static List<Case> createCasesByOwnerId(
            Integer numberOfCases,
            String ownerId) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < numberOfCases; i++) {
            Case c = new Case();
            c.OwnerId = ownerId;

            cases.add(c);
        }
        return cases;
    }

    public static List<Transaction_Condition_Reference__c> createLoanConditionsReferences(Map<String,Object> parameters) {
        List<Transaction_Condition_Reference__c> loanConditionsReferences = new List<Transaction_Condition_Reference__c>();
        Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
        String label = (String)parameters.get('label');
        String type = (String)parameters.get('type');
        String referenceId = (String)parameters.get('referenceId');
        String conditionGroupKey = (String)parameters.get('conditionGroupKey');

        for (Integer i = 0; i < numberOfRecords; i++) {
            Transaction_Condition_Reference__c lcr = new Transaction_Condition_Reference__c();
            lcr.Borrower_Label__c = label + i;
            lcr.Type__c = type;
            lcr.Reference_Id__c = referenceId;
            lcr.Condition_Group_Key__c = conditionGroupKey;
            loanConditionsReferences.add(lcr);
        }

        return loanConditionsReferences;
    }

    // public static List<Milestone_Marker__c> createMilestoneMarkers(Map<String,Object> parameters) {
    //     List<Milestone_Marker__c> markers = new List<Milestone_Marker__c>();
    //     Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
    //     String name = (String)parameters.get('name');
    //     String parentId = (String)parameters.get('parentId');

    //     for (Integer i = 0; i < numberOfRecords; i++) {
    //         Milestone_Marker__c marker = new Milestone_Marker__c();
    //         marker.Name = name + i;
    //         marker.Loan__c = parentId;
    //         marker.Order__c = i;
    //         markers.add(marker);
    //     }

    //     return markers;
    // }

    // public static List<Milestone_Recipient__c> createMilestoneRecipients(Map<String,Object> parameters) {
    //     List<Milestone_Recipient__c> recipients = new List<Milestone_Recipient__c>();
    //     Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
    //     String name = (String)parameters.get('name');
    //     String type = (String)parameters.get('type');
    //     String email = (String)parameters.get('email');
    //     String channels = (String)parameters.get('channels');

    //     for (Integer i = 0; i < numberOfRecords; i++) {
    //         Milestone_Recipient__c recipient = new Milestone_Recipient__c();
    //         recipient.Name = name + i;
    //         recipient.Type__c = type;
    //         recipient.Number_to_Use__c = email;
    //         recipient.Channel__c = channels;
    //         recipients.add(recipient);
    //     }

    //     return recipients;
    // }

    // public static RecipientMarkerAssociation__c createMilestoneRecipientMarkerAssociation(
    //     String markerId,
    //     String milestoneRecipientId,
    //     String channels
    // ) {
    //     RecipientMarkerAssociation__c rma = new RecipientMarkerAssociation__c();
    //     rma.Milestone_Marker__c = markerId;
    //     rma.Milestone_Recipient__c = milestoneRecipientId;
    //     rma.Channel__c = channels;

    //     return rma;
    // }

    // public static List<Liability__c> createLiabilities(Map<String,Object> parameters) {
    //     List<Liability__c> liabilities = new List<Liability__c>();
    //     Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
    //     String name = (String)parameters.get('name');
    //     String applicationId = (String)parameters.get('applicationId');
    //     String type = (String)parameters.get('type');
    //     Decimal payment = (Decimal)parameters.get('payment');
    //     Decimal balance = (Decimal)parameters.get('balance');
    //     Boolean isPaidOff = (Boolean)parameters.get('isPaidOff');

    //     for (Integer i = 0; i < numberOfRecords; i++) {
    //         Liability__c liability = new Liability__c();
    //         liability.Name = name + i;
    //         liability.Application__c = applicationId;
    //         liability.Type__c = type;
    //         liability.Payment__c = payment;
    //         liability.Balance__c = balance;
    //         liability.IsPaidOff__c = isPaidOff;
    //         liabilities.add(liability);
    //     }

    //     return liabilities;
    // }

    public class SingleRequestMock implements HttpCalloutMock {
        protected Integer code;
        protected String body;
        protected Map<String, String> responseHeaders;

        public SingleRequestMock(Integer code, String body, Map<String, String> responseHeaders) {
            this.code = code;
            this.body = body;
            this.responseHeaders = responseHeaders;
            System.debug('INITIATING');
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(this.code);
            response.setBody(this.body);

            if (responseHeaders != null) {
                for (String key : responseHeaders.keySet()) {
                    response.setHeader(key, responseHeaders.get(key));
                }
            }
            System.debug('BODY ->>>>>>>>' + this.body);
            
            return response;
        }
    }

    public class AuthMock implements HttpCalloutMock{
        private String authResponsePayload = '{' +
            '  "token_type": "Bearer",' +
            '  "access_token" : "abc123"' +
            '}';
        public HttpResponse respond(HttpRequest req){
            HttpResponse response = new HttpResponse();
            response.setBody(authResponsePayload);
            response.setStatusCode(200);
            return response;
        }
    }

    public static List<UWMBranch__c> createUWMBranches(Map<String,Object> parameters) {
        List<UWMBranch__c> branches = new List<UWMBranch__c>();
        Integer numberOfRecords = (Integer)parameters.get('numberOfRecords');
        String name = (String)parameters.get('name');
        String clientId = (String)parameters.get('clientId');
        String clientSecret = (String)parameters.get('clientSecret');
        Boolean isDefault = Boolean.valueOf(parameters.get('isDefault'));

        for (Integer i = 0; i < numberOfRecords; i++) {
            UWMBranch__c branch = new UWMBranch__c();
            branch.Name = name + i;
            branch.ClientId__c = clientId;
            branch.ClientSecret__c = clientSecret;
            branch.Is_Default__c = isDefault;
            branches.add(branch);
        }

        return branches;
    }

    public static User createUser(Map<String,Object> parameters) {
        String profileName = (String)parameters.get('profileName');
        String userName = (String)parameters.get('userName');
        String email = (String)parameters.get('email');
        String lastName = (String)parameters.get('lastName');

        Profile p = [SELECT Id, Name FROM Profile WHERE Name = :profileName LIMIT 1];

        return new User(
            ProfileId = p.Id,
            Username = userName,
            Email = email,
            EmailEncodingKey = 'UTF-8',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Alias = 'tpu23',
            LastName = lastName
        );
    }

    public static EmailTemplate createEmailTemplate(Map<String,Object> parameters) {
        String name = (String)parameters.get('name');
        String type = (String)parameters.get('type');
        String folderId = (String)parameters.get('folderId');

        return new EmailTemplate(
            IsActive = true,
            Name = name,
            DeveloperName = name,
            TemplateType = type,
            FolderId = folderId
        );
    }
}