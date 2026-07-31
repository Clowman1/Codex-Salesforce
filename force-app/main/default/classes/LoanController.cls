/**
 * Created by zeyad on 6/26/2020.
 */

public without sharing class LoanController {
    enum FormType{SUBMISSION,WIRE}

    @AuraEnabled
    public static void generateWireCalculator(Id recordId){
        Loan loan = LoanRepository.getInstance().getLoanById(recordId);
        createAndAttachSubmissionForm(loan, FormType.WIRE);
    }

    private static void createAndAttachSubmissionForm(Loan loan, FormType form){
        if(form === FormType.SUBMISSION && loan.getSubmissionFormGeneratedDate() != null) {
            throw new InvalidStateException('Loan has already had Loan Disclosures Requested. You can not submit a second form.');
        }
        PageReference pdfPage = Page.Wire_Calculator_PDF;
        pdfPage.getParameters().put('id', loan.getId());
        Blob pdf = (Test.isRunningTest()) ? Blob.valueOf('Unit Test') : pdfPage.getContentAsPDF();
        String wireCalculatorName = 'Wire Breakdown - ' + loan.getData().Loan_Number__c + ' - ' + loan.getData().Present_Address_Line_1__c;
        system.debug(wireCalculatorName);
        Attachment a = new Attachment(ParentId=loan.getId(),Body=pdf,Name= (form == FormType.Submission) ? 'Loan Submission Form' : wireCalculatorName,ContentType='application/pdf', IsPrivate=false);
        system.debug(a);
        insert a;
    }

    public class InvalidStateException extends Exception{}

}