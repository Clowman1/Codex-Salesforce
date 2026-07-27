@isTest
private class ScheduleInsightsTest {
    static testMethod void myTestMethod() {        
         test.starttest();
         ScheduleInsights myClass = new ScheduleInsights();   
         String chron = '0 0 23 * * ?';        
         system.schedule('Test Sched', chron, myClass);
         test.stopTest();
    }
    static testMethod void myTestMethod2() {        
         test.starttest();
         ScheduleInsights myClass = new ScheduleInsights();   
         String chron = '20 30 8 10 2 ?';        
         system.schedule('Test Sched 2', chron, myClass);
         test.stopTest();
    }
    static testMethod void myTestMethod3() {        
         test.starttest();
         ScheduleInsights myClass = new ScheduleInsights();   
         String chron = '0 0 23 * * ?';        
         system.schedule('Test Sched 3', chron, myClass);
         test.stopTest();
    }
}