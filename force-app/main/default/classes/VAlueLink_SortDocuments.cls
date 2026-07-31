/**
 * Created by toma on 12/22/2022.
 */

public class VAlueLink_SortDocuments{
    private class Wrapper implements Comparable {

        AppraisalOrderController.OrderDocument record;

        Wrapper(AppraisalOrderController.OrderDocument record) {
            this.record = record;
        }

        public Integer compareTo(Object o) {

            Wrapper compareTo = (Wrapper) o;

            Datetime thisValue = this.record.DocumentSubmittedOn;
            Datetime thatValue = compareTo.record.DocumentSubmittedOn;

            // Assumes dates never null
            if (thisValue < thatValue) return 1;
            else if (thisValue > thatValue) return -1;
            else return 0;
        }
    }

    public static List<AppraisalOrderController.OrderDocument> sort(List<AppraisalOrderController.OrderDocument> records) {

        // Wrap
        List<Wrapper> wrappers = new List<Wrapper>();
        for (AppraisalOrderController.OrderDocument record : records) wrappers.add(new Wrapper(record));

        // Use the platform's built in sort algorithm
        wrappers.sort();

        // Unwrap
        List<AppraisalOrderController.OrderDocument> results = new List<AppraisalOrderController.OrderDocument>();
        for (Wrapper wrapper : wrappers) results.add(wrapper.record);

        return results;
    }
}