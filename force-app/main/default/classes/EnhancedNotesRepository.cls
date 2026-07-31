/**
 * Created by J9 on 8/19/2021.
 */

public with sharing class EnhancedNotesRepository {
    private static List<String> ENHANCED_NOTES_FIELDS;
    private static EnhancedNotesRepository self;
    static{
        List<String> fields = new List<String>();
        fields.addAll(Schema.getGlobalDescribe().get('Enhanced_Note__c').getDescribe().fields.getMap().keySet());
        fields.add('CreatedBy.Name');
        fields.add('CreatedBy.MediumPhotoUrl');
        ENHANCED_NOTES_FIELDS = fields;
    }
    public static EnhancedNotesRepository getInstance(){
        if(self == null){
            self = new EnhancedNotesRepository();
        } 
        return self;
    }
    public List<Enhanced_Note__c> getEnhancedNotedByLoanId(String loanId){
        String lookupField = getLookupField(loanId);
        string query = 'SELECT ' + String.join(ENHANCED_NOTES_FIELDS, ',') + ' FROM Enhanced_Note__c WHERE ' + lookupField + '=:loanId AND IsDeleted__c = false' + ' ORDER BY CreatedDate DESC';
        List<Enhanced_Note__c> enhancedNotes = (List<Enhanced_Note__c>)database.query(query);
        return enhancedNotes;
    }

    public static String getLookupField(Id recordId){
        Schema.SObjectType objectType =recordId.getSobjectType();
        SObjectType markerObject = Schema.getGlobalDescribe().get('Enhanced_Note__c');
        Map<String,Schema.SObjectField> mfields = markerObject.getDescribe().fields.getMap();
        for(Schema.SObjectField s: mfields.values()){
            //System.debug('Values:'+s.getDescribe().getReferenceTo().toString());
            if(s.getDescribe().getType() == Schema.DisplayType.REFERENCE){
                if(s.getDescribe().getReferenceTo().toString().contains(objectType.getDescribe().getName())){
                    return s.getDescribe().getName();
                }
            }
        }
        return null;
    }
}