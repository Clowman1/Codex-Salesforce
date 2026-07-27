/**
 * Created by yar on 08.02.2023.
 */

global class ScheduleInsights implements Schedulable{
    global void execute(SchedulableContext sc) {
        UWM_Insights_PipelineUpdateWebservice.doPing();
    }
}