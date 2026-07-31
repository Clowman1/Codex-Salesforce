/**
 * Created by MSI Laptop on 8/8/2022.
 */

@IsTest
private class MersUtilityTest {
    @IsTest
    static void testBehavior() {
        MersUtility.InvocableRequest req = new MersUtility.InvocableRequest();
        req.numberRepresentation = '95945670123456789';
        List<String> mersResponse = MersUtility.generateMers(new List<MersUtility.InvocableRequest>{req}) ;
        System.assertEquals('959456701234567898',mersResponse[0]);
    }
}