List<String> parentIds = new List<String>{
    '0PS5x000001UIQdGAO',
    '0PSAJ0000000Dnz4AE',
    '0PSf2000000Br4QGAS',
    '0PSf2000001ZcMAGA0',
    '0PSf2000001iizZGAQ'
};

List<String> fields = new List<String>{
    'Contact.Borrower_Has_Spouse__c',
    'Contact.Borrower_Spouse_Email__c',
    'Contact.Borrower_Spouse_Name__c',
    'Contact.Borrower_Spouse_Phone__c',
    'Contact.Borrower_and_Co_Borrower_Spouses__c',
    'Contact.Co_Borrower_Has_Spouse__c',
    'Contact.Co_Borrower_Spouse_Email__c',
    'Contact.Co_Borrower_Spouse_Name__c',
    'Contact.Co_Borrower_Spouse_Phone__c'
};

Map<String, FieldPermissions> existing = new Map<String, FieldPermissions>();
for (FieldPermissions permissionItem : [
    SELECT Id, ParentId, Field, PermissionsRead, PermissionsEdit
    FROM FieldPermissions
    WHERE ParentId IN :parentIds
    AND Field IN :fields
]) {
    existing.put(permissionItem.ParentId + ':' + permissionItem.Field, permissionItem);
}

List<FieldPermissions> toInsert = new List<FieldPermissions>();
List<FieldPermissions> toUpdate = new List<FieldPermissions>();

for (String parentId : parentIds) {
    for (String fieldName : fields) {
        String key = parentId + ':' + fieldName;
        if (existing.containsKey(key)) {
            FieldPermissions permissionItem = existing.get(key);
            permissionItem.PermissionsRead = true;
            permissionItem.PermissionsEdit = true;
            toUpdate.add(permissionItem);
        } else {
            toInsert.add(new FieldPermissions(
                ParentId = parentId,
                SobjectType = 'Contact',
                Field = fieldName,
                PermissionsRead = true,
                PermissionsEdit = true
            ));
        }
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
}
if (!toUpdate.isEmpty()) {
    update toUpdate;
}

System.debug('Borrower relationship FieldPermissions inserted=' + toInsert.size() + ', updated=' + toUpdate.size());
