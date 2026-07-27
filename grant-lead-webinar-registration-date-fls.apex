List<PermissionSet> profilePermissionSets = [
    SELECT Id, Name
    FROM PermissionSet
    WHERE IsOwnedByProfile = true
];

Map<Id, FieldPermissions> existingByParentId = new Map<Id, FieldPermissions>();
for (FieldPermissions fp : [
    SELECT Id, ParentId, PermissionsRead, PermissionsEdit
    FROM FieldPermissions
    WHERE SObjectType = 'Lead'
    AND Field = 'Lead.Webinar_Registration_Date__c'
]) {
    existingByParentId.put(fp.ParentId, fp);
}

List<FieldPermissions> permissionsToUpdate = new List<FieldPermissions>();
Integer insertedCount = 0;
Integer skippedCount = 0;
List<String> skippedProfiles = new List<String>();
for (PermissionSet ps : profilePermissionSets) {
    FieldPermissions existing = existingByParentId.get(ps.Id);
    if (existing == null) {
        try {
            insert new FieldPermissions(
                ParentId = ps.Id,
                SObjectType = 'Lead',
                Field = 'Lead.Webinar_Registration_Date__c',
                PermissionsRead = true,
                PermissionsEdit = false
            );
            insertedCount++;
        } catch (DmlException e) {
            skippedCount++;
            skippedProfiles.add(ps.Name + ': ' + e.getDmlMessage(0));
        }
    } else if (!existing.PermissionsRead) {
        existing.PermissionsRead = true;
        permissionsToUpdate.add(existing);
    }
}

if (!permissionsToUpdate.isEmpty()) {
    update permissionsToUpdate;
}

System.debug('Inserted Lead.Webinar_Registration_Date__c read access rows: ' + insertedCount);
System.debug('Updated Lead.Webinar_Registration_Date__c read access rows: ' + permissionsToUpdate.size());
System.debug('Skipped license-ineligible profile rows: ' + skippedCount);
System.debug('Skipped profiles: ' + skippedProfiles);
