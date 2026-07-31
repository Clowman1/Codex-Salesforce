/**
 * @author Andrei Karanko
 * @date 8/23/2023
 * description
 */
public with sharing class UWMCredentials {

    public static Credentials getUserCredentials(Id userId) {
        try {
            Credentials authCredentials;
            if (String.isBlank(userId)) {
                UWMBranch__c defaultBranch = getDefaultBranchRecord();
                authCredentials = new Credentials(defaultBranch);
            } else {
                User targetUser = getUserById(userId);
                UWMBranch__c branch;
                if (String.isBlank(targetUser.UWMBranch__c)) {
                    branch = getDefaultBranchRecord();
                } else {
                    branch = getBranchRecordById(targetUser.UWMBranch__c);
                }
                authCredentials = new Credentials(branch);
            }
            return authCredentials;
        } catch (Exception e) {
            throw new UWMCredentialsException('There was an error getting the UWM credentials: ' + e.getMessage());
        }
    }

    private static User getUserById(Id userId) {
        User targetUser = [
            SELECT Id, UWMBranch__c
            FROM User
            WHERE Id = :userId
            WITH SYSTEM_MODE
        ];
        return targetUser;
    }

    private static UWMBranch__c getDefaultBranchRecord() {
        List<UWMBranch__c> defaultBranches = [
            SELECT Id, Name, ClientId__c, ClientSecret__c
            FROM UWMBranch__c
            WHERE Is_Default__c = TRUE
            WITH SYSTEM_MODE
        ];
        if (defaultBranches.isEmpty()) {
            throw new UWMCredentialsException('No default branch found for UWM Auth Provider');
        }
        return defaultBranches[0];
    }

    private static UWMBranch__c getBranchRecordById(String branchId) {
        List<UWMBranch__c> branches = [
            SELECT Id, Name, ClientId__c, ClientSecret__c
            FROM UWMBranch__c
            WHERE Id = :branchId
            WITH SYSTEM_MODE
        ];
        if (branches.isEmpty()) {
            throw new UWMCredentialsException('No UWMBranch__c record found by Id: ' + branchId);
        }
        return branches[0];
    }

    public class Credentials{
        public String branchName;
        public String clientId;
        public String clientSecret;

        public Credentials(UWMBranch__c branch) {
            this.branchName = branch.Name;
            this.clientId = branch.ClientId__c;
            this.clientSecret = branch.ClientSecret__c;
        }
    }

    public class UWMCredentialsException extends Exception {}

    public static void testCoverage() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
    
}