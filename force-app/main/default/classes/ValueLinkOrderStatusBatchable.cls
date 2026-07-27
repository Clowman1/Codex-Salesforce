global class ValueLinkOrderStatusBatchable implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, Order_ID__c, Appraisal_Status__c, Loan__c FROM Appraisal_Order__c WHERE Is_Complete__c = false AND Order_ID__c != null';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Appraisal_Order__c> appraisalOrders) {
        List<Appraisal_Order__c> appraisalOrdersToUpdate = new List<Appraisal_Order__c>();
        List<String> newlyCompletedOrderIds = new List<String>();

        for (Appraisal_Order__c appraisalOrder : appraisalOrders) {
            try {
                String priorStatus = appraisalOrder.Appraisal_Status__c;
                String orderStatusName = ValueLinkSoapService.consumeGetOrderStatus(
                    ValueLinkController.getAPIUsername(),
                    ValueLinkController.getAPIPassword(),
                    appraisalOrder.Order_ID__c
                );

                appraisalOrder.Appraisal_Status__c = orderStatusName;
                appraisalOrdersToUpdate.add(appraisalOrder);

                if (orderStatusName == 'Completed' && priorStatus != 'Completed' && appraisalOrder.Loan__c != null) {
                    newlyCompletedOrderIds.add(appraisalOrder.Order_ID__c);
                }
            } catch (Exception e) {
                System.debug('ERROR Message ' + e.getMessage());
                if (Test.isRunningTest()) {
                    throw e;
                }
            }
        }

        if (!appraisalOrdersToUpdate.isEmpty()) {
            update appraisalOrdersToUpdate;
        }

        for (String orderId : newlyCompletedOrderIds) {
            ValueLinkDataFetchQueueable.fetchReports(new List<String>{ orderId });
        }
    }

    global void finish(Database.BatchableContext BC) {
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ValueLinkOrderStatusBatchable(), 20);
    }
}
