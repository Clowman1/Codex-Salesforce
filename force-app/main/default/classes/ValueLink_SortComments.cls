/**
 * Created by toma on 12/22/2022.
 */

public class ValueLink_SortComments {
    private class Wrapper implements Comparable {

        AppraisalOrderController.OrderComment record;

        Wrapper(AppraisalOrderController.OrderComment record) {
            this.record = record;
        }

        public Integer compareTo(Object o) {

            Wrapper compareTo = (Wrapper) o;

            Datetime thisValue = this.record.CreatedOn;
            Datetime thatValue = compareTo.record.CreatedOn;

            // Assumes dates never null
            if (thisValue < thatValue) return -1;
            else if (thisValue > thatValue) return 1;
            else return 0;
        }
    }

    public static List<AppraisalOrderController.OrderComment> sort(List<AppraisalOrderController.OrderComment> records) {

        // Wrap
        List<Wrapper> wrappers = new List<Wrapper>();
        for (AppraisalOrderController.OrderComment record : records) wrappers.add(new Wrapper(record));

        // Use the platform's built in sort algorithm
        wrappers.sort();

        // Unwrap
        List<AppraisalOrderController.OrderComment> results = new List<AppraisalOrderController.OrderComment>();
        for (Wrapper wrapper : wrappers) results.add(wrapper.record);

        return results;
    }
}