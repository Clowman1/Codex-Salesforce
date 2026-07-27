public with sharing class Loan extends PersistentObject{
    private Transaction__c data;
    public SObject getDataAsSObject(){
        return (SObject)this.data;
    }
    public Loan(Transaction__c opp){
        this.data = opp;
        setPersistenceStrategy(new PersistenceStrategy.BasicSave());
    }
    public Transaction__c getData(){
        return this.data;
    }
    public String getActiveAppraisalID(){
        return this.data.Appraisal_Order__c;
    }
    public String getLoanType(){
        return this.data.Loan_Type_1st_TD__c;
    }
    public String getProcessorName(){
        return this.data.Additional_Processor__c;
    }
    public String getLoanPurpose(){
        return this.data.Loan_Purpose__c;
    }
    public String getPropertyType(){
        return this.data.Property_Type__c;
    }
    public String getLoanNumber(){
        return this.data.Loan_Number__c;
    }
    public String getPropertyCity(){
        return this.data.Property_City__c;
    }
    public String getPropertyZipcode(){
        return this.data.Property_Postal_Code__c;
    }
    public String getPropertyState(){
        return this.data.Property_State__c;
    }
    public String getPropertyStreet(){
        return this.data.Property_Address__c;
    }
    public String getPropertyCounty(){
        return this.data.County__c;
    }
    public String getAppraisalType(){
        return this.data.ValueLink_Appraisal_Type__c;
    }
    public String getFHACaseNumber(){
        return this.data.FHA_Case_Number__c;
    }
    public Datetime getSubmissionFormGeneratedDate(){
        return this.data.Submission_Form_Date__c;
    }
    public String getPrimaryBorrowerEmail(){ 
		return this.data.Borrower_Name__r.PersonEmail;
	}
    public String getPersonAccountId(){
        return this.data.Borrower_Name__c;
    }
    public String getOneDriveLink(){
        return this.data.Conditions_One_Drive_Link__c;
    }
	
//    public String getSubmissionNotes(){
//        return this.data.Submission_Notes__c;
//    }
    public Id getId(){
        return this.data.Id;
    }
    public Id getOwnerId(){
        return this.data.OwnerId;
    }
    public String getOwnerEmail(){
        return this.data.Owner.Email;
    }
    public void setFedExTenderedDate(Date dtime){
        this.data.FedEx_Labels_Received__c = dtime;
    }
    
//    public String getWireNotes(){
//        return this.data.Wire_Notes__c;
//    }
    public String getPrimaryBorrowerName(){
        return this.data.Borrower_First_Name__c + ' ' + this.data.Borrower_Last_Name__c;
    }
    public String getBorrowerName(){
        return this.data.Borrower_Name__r.Name;
    }
    public String getPrimaryBorrowerFirstName(){
        return this.data.Borrower_First_Name__c;
    }
    public String getPrimaryBorrowerLastName(){
        return this.data.Borrower_Last_Name__c;
    }
    public String getPrimaryBorrowerPhone(){
        return this.data.Borrowers_Phone__c;
    }
//    public Decimal getLoanAmount(){
//        return this.data.Loan_Amount__c;
//    }
//    public void setSubmissionFormGeneratedDate(Datetime dt){
//        this.data.Submission_Form_Date__c = dt;
//    }
//    public void setStageAndWorkflowStatus(String status, String workflow){
//        this.data.StageName=status;
//        this.data.Workflow_Status__c=workflow;
//    }
    public override void persist(){
        if(this.getPersistenceStrategy()==null){
            upsert this.data;
        }else{
            this.getPersistenceStrategy().persist(data);
        }
    }
}