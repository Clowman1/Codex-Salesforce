public with sharing class FileUploaderController {
    public class DefaultFolderOption {
        @AuraEnabled public String MasterLabel;
        @AuraEnabled public String DeveloperName;
        @AuraEnabled public Decimal sortOrder;

        public DefaultFolderOption(String masterLabel, String developerName, Decimal order) {
            this.MasterLabel = masterLabel;
            this.DeveloperName = developerName;
            this.sortOrder = order;
        }
    }

    @AuraEnabled
    public static List<DefaultFolderOption> getDefaultFolders() {
        try {
            if (!Schema.getGlobalDescribe().containsKey('Default_Document_Folder__mdt')) {
                return new List<DefaultFolderOption>{ new DefaultFolderOption('No Category', 'No_Category', 0) };
            }

            List<DefaultFolderOption> folders = new List<DefaultFolderOption>();
            String query =
                'SELECT MasterLabel, DeveloperName, Order__c' +
                ' FROM Default_Document_Folder__mdt' +
                ' ORDER BY Order__c ASC';
            for (SObject folder : Database.query(query)) {
                folders.add(
                    new DefaultFolderOption(
                        (String) folder.get('MasterLabel'),
                        (String) folder.get('DeveloperName'),
                        (Decimal) folder.get('Order__c')
                    )
                );
            }
            if (folders.isEmpty()) {
                folders.add(new DefaultFolderOption('No Category', 'No_Category', 0));
            }
            return folders;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveFolder(List<String> contentVersionIds, String selectedFolder) {
        try {
            List<ContentVersion> versions = retrieveContentVersions(contentVersionIds);
            for (ContentVersion version : versions) {
                version.Folder__c = selectedFolder;
            }
            if (!versions.isEmpty()) {
                Database.update(versions, false, AccessLevel.USER_MODE);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<ContentVersion> retrieveContentVersions(List<String> contentVersionIds) {
        return [
            SELECT Id, Folder__c
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
            WITH USER_MODE
        ];
    }
}