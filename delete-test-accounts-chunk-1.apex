List<Id> ids = new List<Id>{ '001Qi00001EWw8OIAT', '001Qi00001Dw5X7IAJ', '001Qi00001AmK7CIAV', '001Qi00001A4ijgIAB', '001Qi000015aFARIA2', '001Qi000013SEqcIAG', '001Qi000012hq09IAA', '001Qi000012DrZCIA0', '001Qi0000126JJWIA2', '001Qi000010UhqGIAS', '001Qi0000101KCIIA2', '001Qi0000101NJtIAM', '001Qi00000uYBa7IAG', '001Qi00000sKde4IAC', '001Qi00000nRsbFIAS', '001Qi00000nS64jIAC', '001Qi00000k56lRIAQ', '001Qi00000jSTYEIA4', '001Qi00000jSP9tIAG', '001Qi00000hHIO0IAO', '001Qi00000dKvlGIAS', '001Qi00000cGZITIA4', '001Qi00000c2fZ3IAI', '001Qi00000XZd3bIAD', '001Qi00000XZd3aIAD', '001Qi00000WQ4iKIAT', '001Qi00000VH8liIAD', '001Qi00000VGKKJIA5', '001Qi00000TugLjIAJ', '001Qi00000TonCyIAJ', '001Qi00000Sz8bfIAB', '001Qi00000SxyWKIAZ', '001Qi00000Rf1eyIAB', '001Qi00000RKj39IAD', '001Qi00000RKj3AIAT', '001Qi00000RKq69IAD', '001Qi00000RKq6AIAT', '001Qi00000QimA5IAJ', '001Qi00000QbYa4IAF', '001Qi00000QbROwIAN' };
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
System.debug('DELETE_SUMMARY|chunk=1|success=' + successCount + '|failed=' + failCount + '|requested=' + ids.size());
