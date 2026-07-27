PermissionSet commandCenterPermission = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'Pipeline_Command_Center_Pilot_Access'
    LIMIT 1
];

Set<Id> existingAssigneeIds = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :commandCenterPermission.Id
]) {
    existingAssigneeIds.add(assignment.AssigneeId);
}

List<PermissionSetAssignment> assignmentsToCreate = new List<PermissionSetAssignment>();
for (User userRecord : [
    SELECT Id
    FROM User
    WHERE IsActive = true
    AND Profile.UserType = 'Standard'
]) {
    if (!existingAssigneeIds.contains(userRecord.Id)) {
        assignmentsToCreate.add(new PermissionSetAssignment(
            AssigneeId = userRecord.Id,
            PermissionSetId = commandCenterPermission.Id
        ));
    }
}

if (!assignmentsToCreate.isEmpty()) {
    insert assignmentsToCreate;
}

System.debug('Pipeline Command Center assignments created: ' + assignmentsToCreate.size());
