/**
 * Appraisal tab controller for the Transaction page ValueLink workspace.
 */
public class AppraisalOrderController {
    public static String apiUsername = ValueLinkController.getAPIUsername();
    public static String apiPassword = ValueLinkController.getAPIPassword();

    public class ReturnModel {
        @AuraEnabled public String appraisalOrderId;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String zip;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String orderId;
        @AuraEnabled public Date estCompletionDate;
        @AuraEnabled public Date inspectionScheduledDate;
        @AuraEnabled public Date inspectionCompletedDate;
        @AuraEnabled public Date dateNeeded;
        @AuraEnabled public Boolean inspectionCompleted;
        @AuraEnabled public String appraisalStatus;
        @AuraEnabled public String productOrdered;
        @AuraEnabled public Datetime lastReportFetch;
        @AuraEnabled public Integer appraisalFolderDocumentCount;
    }

    public class TimelineItem implements Comparable {
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public String status;
        @AuraEnabled public String iconName;
        @AuraEnabled public Datetime occurredOn;

        public TimelineItem(String title, String detail, String status, String iconName, Datetime occurredOn) {
            this.title = title;
            this.detail = detail;
            this.status = status;
            this.iconName = iconName;
            this.occurredOn = occurredOn;
        }

        public Integer compareTo(Object otherObject) {
            TimelineItem other = (TimelineItem) otherObject;
            if (occurredOn == null && other.occurredOn == null) {
                return 0;
            }
            if (occurredOn == null) {
                return 1;
            }
            if (other.occurredOn == null) {
                return -1;
            }
            if (occurredOn == other.occurredOn) {
                return 0;
            }
            return occurredOn > other.occurredOn ? -1 : 1;
        }
    }

    public class OrderComment {
        @AuraEnabled
        public String Comment {
            get {
                return Comment;
            }
            set {
                if (value != null && value.contains('was uploaded for the Appraisal Number')) {
                    this.CommentType = 'document';
                    this.UserTypeName = ' ';
                    this.Comment = value.substring(0, (value.indexOf('for'))) + ' ' + this.CreatedOn;
                } else {
                    this.Comment = value;
                }
            }
        }
        @AuraEnabled public Datetime CreatedOn;
        @AuraEnabled public String UserTypeName;
        @AuraEnabled public String CreatedBy;
        @AuraEnabled public String CommentType;
    }

    @AuraEnabled
    public static ReturnModel getActiveAppraisalOrder(String loanId) {
        ReturnModel model = new ReturnModel();
        Loan l = LoanRepository.getInstance().getLoanById(loanId);
        String activeAppraisalOrder = l.getActiveAppraisalID();
        model.appraisalOrderId = activeAppraisalOrder;

        Appraisal_Order__c order = [
            SELECT Id, Comment__c, Order_ID__c, Order_Number__c, Date_Needed__c,
                EstimatedCompletionDate__c, InspectionCompleteAt__c, InspectionScheduledAt__c,
                Is_Complete__c, Appraisal_Status__c
            FROM Appraisal_Order__c
            WHERE Id = :activeAppraisalOrder
        ];

        Transaction__c loan = [
            SELECT Id, ValueLink_Appraisal_Type__c, ValueLink_Last_Report_Fetch__c
            FROM Transaction__c
            WHERE Id = :loanId
        ];

        model.estCompletionDate = order.EstimatedCompletionDate__c;
        model.inspectionCompletedDate = order.InspectionCompleteAt__c;
        model.inspectionScheduledDate = order.InspectionScheduledAt__c;
        model.dateNeeded = order.Date_Needed__c;
        model.zip = l.getPropertyZipcode();
        model.state = l.getPropertyState();
        model.city = l.getPropertyCity();
        model.street = l.getPropertyStreet();
        model.inspectionCompleted = order.Is_Complete__c;
        model.orderNumber = order.Order_Number__c;
        model.orderId = order.Order_ID__c;
        model.appraisalStatus = order.Appraisal_Status__c;
        model.productOrdered = loan.ValueLink_Appraisal_Type__c;
        model.lastReportFetch = loan.ValueLink_Last_Report_Fetch__c;
        model.appraisalFolderDocumentCount = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE FirstPublishLocationId = :loanId
                AND IsLatest = true
                AND Folder__c = 'Appraisal'
        ];
        return model;
    }

    @AuraEnabled
    public static List<TimelineItem> getAppraisalTimeline(String loanId) {
        List<TimelineItem> timeline = new List<TimelineItem>();
        Loan l = LoanRepository.getInstance().getLoanById(loanId);
        String activeAppraisalOrder = l.getActiveAppraisalID();

        Appraisal_Order__c order = [
            SELECT Id, Order_ID__c, Order_Number__c, CreatedDate, Appraisal_Status__c,
                Date_Needed__c, EstimatedCompletionDate__c, InspectionScheduledAt__c,
                InspectionCompleteAt__c
            FROM Appraisal_Order__c
            WHERE Id = :activeAppraisalOrder
        ];

        timeline.add(new TimelineItem(
            'Appraisal order created',
            String.isBlank(order.Order_Number__c) ? 'ValueLink order was created.' : 'Order # ' + order.Order_Number__c,
            'Order',
            'standard:orders',
            order.CreatedDate
        ));

        if (order.InspectionScheduledAt__c != null) {
            timeline.add(new TimelineItem(
                'Inspection scheduled',
                'Inspection scheduled for this appraisal order.',
                'Scheduled',
                'utility:event',
                Datetime.newInstance(order.InspectionScheduledAt__c, Time.newInstance(0, 0, 0, 0))
            ));
        }

        if (order.InspectionCompleteAt__c != null) {
            timeline.add(new TimelineItem(
                'Inspection completed',
                'ValueLink indicates the inspection is complete.',
                'Complete',
                'utility:success',
                Datetime.newInstance(order.InspectionCompleteAt__c, Time.newInstance(0, 0, 0, 0))
            ));
        }

        if (order.EstimatedCompletionDate__c != null) {
            timeline.add(new TimelineItem(
                'Estimated completion',
                'Current estimated completion date from ValueLink.',
                'ETA',
                'utility:clock',
                Datetime.newInstance(order.EstimatedCompletionDate__c, Time.newInstance(0, 0, 0, 0))
            ));
        }

        if (order.Appraisal_Status__c == 'Completed') {
            timeline.add(new TimelineItem(
                'Order marked completed',
                'Completed orders are queued for automatic document download into the Appraisal folder.',
                'Completed',
                'utility:check',
                System.now()
            ));
        }

        for (ValueLink_Log__c logItem : [
            SELECT CreatedDate, Event_Type__c, Processing_Status__c, Error_Message__c,
                Document_File_Name__c, Document_Folder__c, Order_ID__c
            FROM ValueLink_Log__c
            WHERE Transaction__c = :loanId
                OR Appraisal_Order__c = :activeAppraisalOrder
                OR Order_ID__c = :order.Order_ID__c
            ORDER BY CreatedDate DESC
            LIMIT 25
        ]) {
            String title = String.isBlank(logItem.Event_Type__c) ? 'ValueLink activity' : logItem.Event_Type__c;
            String detail = '';
            if (String.isNotBlank(logItem.Document_File_Name__c)) {
                detail = logItem.Document_File_Name__c;
                if (String.isNotBlank(logItem.Document_Folder__c)) {
                    detail += ' routed to ' + logItem.Document_Folder__c + ' folder';
                }
            } else if (String.isNotBlank(logItem.Error_Message__c)) {
                detail = logItem.Error_Message__c;
            } else if (String.isNotBlank(logItem.Order_ID__c)) {
                detail = 'Order ID ' + logItem.Order_ID__c;
            }

            String iconName = logItem.Processing_Status__c == 'Failed' ? 'utility:error' : 'utility:record';
            timeline.add(new TimelineItem(title, detail, logItem.Processing_Status__c, iconName, logItem.CreatedDate));
        }

        timeline.sort();
        return timeline;
    }

    @AuraEnabled
    public static String fetchCompletedReports(String loanId) {
        String activeAppraisalOrder = LoanRepository.getInstance().getLoanById(loanId).getActiveAppraisalID();
        Appraisal_Order__c order = [
            SELECT Id, Order_ID__c
            FROM Appraisal_Order__c
            WHERE Id = :activeAppraisalOrder
        ];

        if (String.isBlank(order.Order_ID__c)) {
            throw new AuraHandledException('This appraisal order is missing the ValueLink Order ID.');
        }

        ValueLinkDataFetchQueueable.fetchReports(new List<String>{ order.Order_ID__c });
        return 'ValueLink report download has been queued. Files will route to the Appraisal folder when available.';
    }

    @AuraEnabled
    public static String cancelAppraisalOrder(String loanId, String reason) {
        reason = reason == null ? null : reason.trim();
        if (String.isBlank(reason)) {
            throw new AuraHandledException('Please enter a cancellation reason before cancelling the ValueLink order.');
        }

        String activeAppraisalOrder = LoanRepository.getInstance().getLoanById(loanId).getActiveAppraisalID();
        Appraisal_Order__c order = [
            SELECT Id, Order_ID__c, Order_Number__c, Appraisal_Status__c
            FROM Appraisal_Order__c
            WHERE Id = :activeAppraisalOrder
        ];

        if (String.isBlank(order.Order_ID__c)) {
            throw new AuraHandledException('This appraisal order is missing the ValueLink Order ID.');
        }
        if (order.Appraisal_Status__c == 'Completed' || order.Appraisal_Status__c == 'Order Complete') {
            throw new AuraHandledException('Completed appraisal orders cannot be cancelled from Salesforce.');
        }
        if (order.Appraisal_Status__c == 'Cancelled') {
            return 'This appraisal order is already marked Cancelled in Salesforce.';
        }

        String message;
        try {
            message = ValueLinkSoapService.cancelOrder(apiUsername, apiPassword, order.Order_ID__c, reason);
        } catch (Exception e) {
            safeInsertValueLinkCancellationLog(loanId, order, 'Failed', e.getMessage());
            throw new AuraHandledException('Unable to cancel ValueLink order: ' + e.getMessage());
        }

        order.Appraisal_Status__c = 'Cancelled';
        Database.SaveResult updateResult = Database.update(order, false);
        if (!updateResult.isSuccess()) {
            String localError = firstDmlError(updateResult);
            safeInsertValueLinkCancellationLog(
                loanId,
                order,
                'Processed',
                message + ' Salesforce could not mark the order Cancelled: ' + localError
            );
            return message + ' Salesforce could not mark the order Cancelled automatically. Please refresh the Appraisal tab or contact an admin.';
        }

        safeInsertValueLinkCancellationLog(loanId, order, 'Processed', message);
        return message;
    }

    private static void insertValueLinkCancellationLog(String loanId, Appraisal_Order__c order, String status, String message) {
        insert new ValueLink_Log__c(
            Transaction__c = loanId,
            Appraisal_Order__c = order.Id,
            Order_ID__c = order.Order_ID__c,
            Event_Type__c = 'Cancel Order',
            Processing_Status__c = status,
            Error_Message__c = message
        );
    }

    @TestVisible
    private static void safeInsertValueLinkCancellationLog(String loanId, Appraisal_Order__c order, String status, String message) {
        try {
            insertValueLinkCancellationLog(loanId, order, status, message);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Unable to insert ValueLink cancellation log: ' + e.getMessage());
        }
    }

    @TestVisible
    private static String firstDmlError(Database.SaveResult saveResult) {
        if (saveResult == null || saveResult.getErrors().isEmpty()) {
            return 'Unknown Salesforce save error.';
        }
        return saveResult.getErrors()[0].getMessage();
    }

    @AuraEnabled
    public static void callPostOrderDocument(String loanId, String fileName, String encodedBlob) {
        String activeAppraisalOrder = LoanRepository.getInstance().getLoanById(loanId).getActiveAppraisalID();
        ValueLinkSoapService_PostDocument.RequestModel req = new ValueLinkSoapService_PostDocument.RequestModel();
        req.fileName = fileName;
        req.fileData = encodedBlob;
        req.orderId = [SELECT Id, Order_ID__c FROM Appraisal_Order__c WHERE Id = :activeAppraisalOrder].Order_ID__c;
        try {
            ValueLinkSoapService_PostDocument.sendDocument(apiUsername, apiPassword, req);
        } catch (Exception e) {
            System.debug('There was a problem while creating document for appraisal order: ' + e.getMessage());
            throw e;
        }
    }

    @AuraEnabled
    public static void callAddOrderComment(String loanId, String comment) {
        String activeAppraisalOrder = LoanRepository.getInstance().getLoanById(loanId).getActiveAppraisalID();
        String orderId = [SELECT Id, Order_ID__c FROM Appraisal_Order__c WHERE Id = :activeAppraisalOrder].Order_ID__c;
        try {
            ValueLinkSoapService_PostComment.sendComment(apiUsername, apiPassword, orderId, comment);
        } catch (Exception e) {
            System.debug('There was a problem while creating comment for appraisal order: ' + e.getMessage());
            throw e;
        }
    }

    @AuraEnabled
    public static List<OrderComment> callGetCommentsList(String loanId) {
        List<OrderComment> output;
        String activeAppraisalOrder = LoanRepository.getInstance().getLoanById(loanId).getActiveAppraisalID();
        String orderId = [SELECT Id, Order_ID__c FROM Appraisal_Order__c WHERE Id = :activeAppraisalOrder].Order_ID__c;
        try {
            output = ValueLink_GetCommentsList.getOrderComments(apiUsername, apiPassword, orderId);
        } catch (Exception e) {
            System.debug('There was a problem while getting comments for appraisal order: ' + e.getMessage());
            throw e;
        }
        return output;
    }

    @AuraEnabled
    public static List<OrderDocument> callGetDocumentsList(String loanId) {
        List<OrderDocument> output;
        String activeAppraisalOrder = LoanRepository.getInstance().getLoanById(loanId).getActiveAppraisalID();
        String orderId = [SELECT Id, Order_ID__c FROM Appraisal_Order__c WHERE Id = :activeAppraisalOrder].Order_ID__c;
        try {
            output = ValueLink_GetOrderDocumentsList.getOrderDocuments(apiUsername, apiPassword, orderId);
        } catch (Exception e) {
            System.debug('There was a problem while getting documents for appraisal order: ' + e.getMessage());
            throw e;
        }
        return output;
    }

    @AuraEnabled
    public static OrderDocument downloadSingleFile(String fileId) {
        OrderDocument output;
        try {
            output = ValueLink_GetOrderDocumentsList.getSingleDocument(apiUsername, apiPassword, fileId);
        } catch (Exception e) {
            System.debug('There was a problem while getting documents for appraisal order: ' + e.getMessage());
            throw e;
        }
        return output;
    }

    public class OrderDocument {
        @AuraEnabled public String OrderDocumentID;
        @AuraEnabled public String DocumentFileName;
        @AuraEnabled public Datetime DocumentSubmittedOn;
        @AuraEnabled public String OrderDocument;
    }
}