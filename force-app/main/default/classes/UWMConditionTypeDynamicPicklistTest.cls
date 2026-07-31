@IsTest
private class UWMConditionTypeDynamicPicklistTest {
    @IsTest
    static void getValuesReturnsRowsAndDefaultValueIsNull() {
        UWMConditionTypeDynamicPicklist picklist = new UWMConditionTypeDynamicPicklist();

        Test.startTest();
        VisualEditor.DataRow defaultValue = picklist.getDefaultValue();
        VisualEditor.DynamicPickListRows values = picklist.getValues();
        Test.stopTest();

        System.assertEquals(null, defaultValue);
        System.assertNotEquals(null, values);
    }
}