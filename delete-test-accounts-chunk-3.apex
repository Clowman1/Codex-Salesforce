List<Id> ids = new List<Id>{ '0015x00002AecdBAAR', '0015x00002AdIhRAAV', '0015x00002AdIVfAAN', '0015x00002AcLXyAAN', '0015x00002AcLJIAA3', '0015x000024u2fLAAQ', '001f200001fwFVrAAM', '001f200001fNVFLAA4', '001f200001fNUHSAA4', '001f200001fLoGWAA0', '001f200001fLoGMAA0', '001f200001fLD2JAAW', '001f200001fL9gSAAS', '001f200001eYBxuAAG', '001f200001eYBsgAAG', '001f200001eYBpGAAW', '001f200001eYABuAAO', '001f200001eY9xoAAC', '001f200001eY9zVAAS', '001f200001eY9vEAAS', '001f200001eY9vGAAS', '001f200001eY9vCAAS', '001f200001eY9vFAAS', '001f200001eY9vDAAS', '001f200001eY897AAC', '001f200001eY7fAAAS', '001f200001eY79tAAC', '001f200001eY79ZAAS', '001f200001eY7AoAAK', '001f200001eY73pAAC', '001f200001eY69OAAS', '001f200001eY63KAAS', '001f200001eY60ZAAS', '001f200001eY63JAAS', '001f200001eY5zOAAS' };
Integer successCount = 0;
Integer failCount = 0;
for (Id accountId : ids) {
    Database.DeleteResult result = Database.delete(new Account(Id = accountId), false);
    if (result.isSuccess()) {
        successCount++;
    } else {
        failCount++;
        for (Database.Error err : result.getErrors()) {
            System.debug('DELETE_FAILED|' + accountId + '|' + err.getStatusCode() + '|' + err.getMessage());
        }
    }
}
System.debug('DELETE_SUMMARY|chunk=3|success=' + successCount + '|failed=' + failCount + '|requested=' + ids.size());
