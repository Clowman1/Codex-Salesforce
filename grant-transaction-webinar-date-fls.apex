List<PermissionSet> profilePermissionSets = [
    SELECT Id, Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
];

Set<Id> existingParentIds = new Set<Id>();
for (FieldPermissions fp : [
    SELECT ParentId
    FROM FieldPermissions
    WHERE SObjectType = 'Transaction__c'
    AND Field = 'Transaction__c.Webinar_Date__c'
]) {
    existingParentIds.add(fp.ParentId);
}

List<FieldPermissions> permissionsToInsert = new List<FieldPermissions>();
for (PermissionSet ps : profilePermissionSets) {
    if (!existingParentIds.contains(ps.Id)) {
        permissionsToInsert.add(new FieldPermissions(
            ParentId = ps.Id,
            SObjectType = 'Transaction__c',
            Field = 'Transaction__c.Webinar_Date__c',
            PermissionsRead = true,
            PermissionsEdit = false
        ));
    }
}

if (!permissionsToInsert.isEmpty()) {
    insert permissionsToInsert;
}

System.debug('Inserted Transaction__c.Webinar_Date__c read access rows: ' + permissionsToInsert.size());
