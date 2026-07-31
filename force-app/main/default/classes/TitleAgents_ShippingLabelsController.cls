/**
 * Created by toma on 6/17/2022.
 */

public without sharing class TitleAgents_ShippingLabelsController {
	public String fileName { get; set; }
	public Boolean isConfirmed { get; set; }
	public Boolean isError { get; set; }
	public String msg { get; set; }
	public String notes { get; set; }
	public Transaction__c t;

	public TitleAgents_ShippingLabelsController() {
		isError = false;
		try {
			String transactionRecord = ApexPages.currentPage().getParameters().get('rid');
			t = [SELECT Id, Name, Borrower_Name__r.Name, FedEx_Labels_Received__c,Closing_Package_Status__c, Closing_Package_Rejection_Notes__c FROM Transaction__c WHERE Id = :transactionRecord];
			this.fileName = t.Borrower_Name__r.Name;
			this.isConfirmed = t.Closing_Package_Status__c == 'Accepted';
		} catch(Exception e) {
			isError = true;
		}
	}
	//Method that can is called from the Visual Force page action attribute
	public PageReference updateConfirmation() {
		t.FedEx_Labels_Received__c = Date.today();
		update t;
		this.isConfirmed = true;
		PageReference p = ApexPages.currentPage();
		p.getParameters().put('rid', t.Id);
		return p; //Returns to the case page
	}
	
	//Method that can is called from the Visual Force page action attribute
	public PageReference rejectClosingPackage() {
		t.Closing_Package_Status__c = 'Rejected';
		t.Closing_Package_Rejection_Notes__c = notes;
		update t;
		this.isConfirmed = false;
        //sendRejectionEmail();
		PageReference p = ApexPages.currentPage();
		p.getParameters().put('rid', t.Id);
		return p; //Returns to the case page
	}
    
    // REPLACED WITH FLOW
    /*
    public void sendRejectionEmail() {
        OrgWideEmailAddress owea = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'reachus@reachhomeloans.com'];

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] { 'postclosing@reachhomeloans.com' };
                
        mail.setOrgWideEmailAddressId(owea.Id);
        mail.setToAddresses(toAddresses);
        mail.setSubject('Closing Package Was Rejected: ' + t.Name);
        
        String htmlTemplate = 'Rejection Notes: ' + t.Closing_Package_Rejection_Notes__c +
            				  '<br/><a href="https://reachhomeloans.lightning.force.com/lightning/r/Transaction__c/' + t.Id + '/view">' + t.Name + '</a>';
        
        mail.setHtmlBody(htmlTemplate);
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
   */
    
	//Method that can is called from the Visual Force page action attribute
	public PageReference acceptClosingPackage() {
		t.Closing_Package_Status__c = 'Accepted';
		update t;
		this.isConfirmed = true;
		PageReference p = ApexPages.currentPage();
		p.getParameters().put('rid', t.Id);
		return p; //Returns to the case page
	}
	public void sendMessage() {
		Task t = new Task(WhatId = t.Id, Subject = 'New Note From Title for ' + fileName, ActivityDate = Date.today(), Description = msg);
		insert t;
	}
}