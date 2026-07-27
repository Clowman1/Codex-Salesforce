PermissionSet propertySoldAccess = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'Property_Sold_Access'
    LIMIT 1
];

List<User> activeInternalUsers = [
    SELECT Id
    FROM User
    WHERE IsActive = true
    AND UserType = 'Standard'
    AND Email LIKE '%@reachhomeloans.com'
];

Set<Id> activeInternalUserIds = new Set<Id>();
for (User userRecord : activeInternalUsers) {
    activeInternalUserIds.add(userRecord.Id);
}

Set<Id> alreadyAssignedUserIds = new Set<Id>();
for (PermissionSetAssignment assignmentRecord : [
    SELECT AssigneeId
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :propertySoldAccess.Id
    AND AssigneeId IN :activeInternalUserIds
]) {
    alreadyAssignedUserIds.add(assignmentRecord.AssigneeId);
}

List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
for (Id userId : activeInternalUserIds) {
    if (!alreadyAssignedUserIds.contains(userId)) {
        assignmentsToInsert.add(new PermissionSetAssignment(
            PermissionSetId = propertySoldAccess.Id,
            AssigneeId = userId
        ));
    }
}

Integer failedCount = 0;
if (!assignmentsToInsert.isEmpty()) {
    Database.SaveResult[] results = Database.insert(assignmentsToInsert, false);
    for (Database.SaveResult result : results) {
        if (!result.isSuccess()) {
            failedCount++;
        }
    }
}

System.debug('PROPERTY_SOLD_ACCESS_ATTEMPTED=' + activeInternalUsers.size());
System.debug('PROPERTY_SOLD_ACCESS_ASSIGNED=' + assignmentsToInsert.size());
System.debug('PROPERTY_SOLD_ACCESS_FAILED=' + failedCount);
