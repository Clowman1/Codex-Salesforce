/**
 * Created by yar on 08.02.2023.
 */

global class ScheduleConditions implements Schedulable{
    public void execute(SchedulableContext sc) {
        UWM_Conditions_API_Batch.executeBatch();
    }
}