List<Id> ids = new List<Id>{ '001Qi00000O6SzuIAF', '001Qi00000MO7YLIA1', '001Qi00000IobGZIAZ', '001Qi00000HYBiPIAX', '001Qi00000Gzf29IAB', '001Qi00000Gw9xnIAB', '001Qi00000Gw1wzIAB', '001Qi00000GvzQXIAZ', '001Qi00000Gvt6eIAB', '001Qi00000GrrzRIAR', '001Qi00000GrTqgIAF', '001Qi00000GrqP4IAJ', '001Qi00000FxDyIIAV', '001Qi00000DxY6PIAV', '001Qi00000D1Lz2IAF', '001AJ000005v2gJYAQ', '001AJ000005nmm6YAA', '001AJ000005E6jZYAS', '001AJ0000044mR3YAI', '001AJ000003i3VhYAI', '001AJ000003i37uYAA', '001AJ000003NEtEYAW', '001AJ000003Hu2GYAS', '001AJ000002kotWYAQ', '001AJ000002fPuYYAU', '001AJ000002bfenYAA', '001AJ000002ZN0HYAW', '001AJ000002ZG2IYAW', '0015x00002HGaJRAA1', '0015x00002GSnszAAD', '0015x00002GRp7cAAD', '0015x00002GRkjSAAT', '0015x00002FOLbBAAX', '0015x00002FMtTXAA1', '0015x00002FMjvFAAT', '0015x00002Eko9VAAR', '0015x00002Eko9LAAR', '0015x00002Ekny5AAB', '0015x00002EQg8pAAD', '0015x00002EQXN8AAP' };
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
System.debug('DELETE_SUMMARY|chunk=2|success=' + successCount + '|failed=' + failCount + '|requested=' + ids.size());
