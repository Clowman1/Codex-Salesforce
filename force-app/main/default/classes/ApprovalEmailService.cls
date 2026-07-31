/**
 * Created by Akram on 7/27/2020.
 */

global class ApprovalEmailService implements Messaging.InboundEmailHandler{

    public class ApprovalEmailServiceException extends Exception {}

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        //try{
            String trackingNumber = parseEmailBody(email);
            Loan l = getLoan(trackingNumber);
            l.setFedExTenderedDate(Date.today()); l.persist();
       // }
//catch(Exception e){
       //     throw e;
      //  }
     //   finally{
     //   }
        return result;
    }

    public static String parseEmailBody(Messaging.InboundEmail email){
        String emailTextSubject = email.subject;
        String trackingNumber;
        if(emailTextSubject.containsIgnoreCase('shipment')) {
            trackingNumber = emailTextSubject.toLowerCase().substringBetween('shipment', '.');
            if (String.isEmpty(trackingNumber)) {
                throw new ApprovalEmailServiceException('Tracking Number Could Not Be Found');
            }

            trackingNumber = trackingNumber.trim();
        }
        return trackingNumber;
    }

    public static Loan getLoan(String loanNumber){
        Loan l = null;
        try {
            l = LoanRepository.getInstance().getLoanByFedexTrackingNumber(loanNumber);
        } catch (Exception e) {
        }
        if(l == null){throw new ApprovalEmailServiceException('Loan Not Found with following number:' + loanNumber);}
        return l;
    }
}