/**
 * Dynamic design-time picklist for `ConditionsViewer`.
 */
public with sharing class UWMConditionTypeDynamicPicklist extends VisualEditor.DynamicPickList {
    public override VisualEditor.DataRow getDefaultValue() {
        return null;
    }

    public override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows values = new VisualEditor.DynamicPickListRows();
        List<Schema.PicklistEntry> picklistEntries = Condition__c.Type__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : picklistEntries) {
            values.addRow(new VisualEditor.DataRow(entry.getLabel(), entry.getValue()));
        }
        return values;
    }
}