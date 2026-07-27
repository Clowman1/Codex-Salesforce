User laura = [
    SELECT Id
    FROM User
    WHERE Username = 'laura@reachhomeloans.com'
    LIMIT 1
];

Set<String> requiredPermissionSetNames = new Set<String>{
    'All_Visualforce_Pages',
    'Condition_Files_Permissions',
    'ConditionPermissions',
    'Enhances_Notes',
    'Pipeline_Command_Center_Pilot_Access',
    'UWMPermissions',
    'UserActionsPermissions'
};

Map<String, PermissionSet> permissionSetsByName = new Map<String, PermissionSet>();
for (PermissionSet permissionSetRecord : [
    SELECT Id, Name
    FROM PermissionSet
    WHERE Name IN :requiredPermissionSetNames
]) {
    permissionSetsByName.put(permissionSetRecord.Name, permissionSetRecord);
}

Set<Id> assignedPermissionSetIds = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT PermissionSetId
    FROM PermissionSetAssignment
    WHERE AssigneeId = :laura.Id
]) {
    assignedPermissionSetIds.add(assignment.PermissionSetId);
}

List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
for (String permissionSetName : requiredPermissionSetNames) {
    PermissionSet permissionSetRecord = permissionSetsByName.get(permissionSetName);
    if (permissionSetRecord != null && !assignedPermissionSetIds.contains(permissionSetRecord.Id)) {
        assignmentsToInsert.add(new PermissionSetAssignment(
            AssigneeId = laura.Id,
            PermissionSetId = permissionSetRecord.Id
        ));
    }
}

if (!assignmentsToInsert.isEmpty()) {
    insert assignmentsToInsert;
}

System.debug('Assigned Laura permission sets: ' + assignmentsToInsert.size());
