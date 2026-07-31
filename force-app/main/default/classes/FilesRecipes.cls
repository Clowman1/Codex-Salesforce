/**
 * Created by toma on 12/20/2022.
 */

public class FilesRecipes {
    /**
         * An inner class representing a file to be created and linked to a given record.
         * Useful for bulk-creating files and linking them.
         */
    public class FileAndLinkObject {
        public Blob fileContents { get; set; }
        public Id attachedTo { get; set; }
        public String fileName { get; set; }
    }

    /**
     * @description Internal exception class
     */
    public class FilesRecipesException extends Exception {
    }
    /**
     * @description This enum encapsulates a 'generic' filetype a 'filetype'
     * that may have multiple file extension and mime types associated with it.
     * For instance, IMAGE encapsulates: jpg, gif, jpeg, & png this allows
     * developers to say, 'give me all *image* attachments' without worrying
     * about the actual file extension.
     */
    public enum GenericFileType {
        IMAGE,
        AUDIO,
        DOCUMENT,
        ALL
    }

    /**
     * @description creates a file attachment containing the given string and
     * links it to the object specified in firstLocation
     * @param  text          String to write to the file
     * @param  firstLocation object to immediately link this file to
     * @example
     * Account acct = [SELECT id FROM Account LIMIT 1];
     * FilesRecipes.createFileFromStringAttachedToRecord('Hello World', acct.Id);
     * System.debug('Look for files assoicated with account: ' + acct.id);
     */
    public static void createFileFromStringAttachedToRecord(
            String text,
            Id firstLocation,
            String fileName
    ) {
        Blob fileContents = Blob.valueOf(text);
        FilesRecipes.createFileAttachedToRecord(
                fileContents,
                firstLocation,
                fileName
        );
    }

    /**
     * @description        Creates a file and links it to a given record
     * @param fileContents the binary blob of the files contents
     * @param attachedTo   the record to link this file to, initially
     * @param fileName     the name of the file. Note that the system determines
     *  the filetype from the file extension here
     * @return            `Database.SaveResult`
     * @example
     * Blob fileContents = Blob.valueOf('Hello World 2');
     * Account acct = [SELECT id FROM Account LIMIT 1];
     *  FilesRecipes.createFileAttachedToRecord(
     *      fileContents,
     *      firstLocation,
     *      'AwesomeFile1'
     *  );
     * System.debug('Look for files assoicated with account: ' + acct.id);
     */
    public static Database.SaveResult createFileAttachedToRecord(
            Blob fileContents,
            Id attachedTo,
            String fileName
    ) {
        return createFileAttachedToRecord(fileContents, attachedTo, fileName, null);
    }

    public static Database.SaveResult createFileAttachedToRecord(
            Blob fileContents,
            Id attachedTo,
            String fileName,
            String folderName
    ) {
        ContentVersion fileToUpload = new ContentVersion();
        // S = Salesforce. The other options are: 'E' (external)
        // and 'L' (social customer service)
        fileToUpload.ContentLocation = 'S';
        fileToUpload.PathOnClient = fileName;
        fileToUpload.Title = fileName;
        fileToUpload.VersionData = fileContents;
        fileToUpload.FirstPublishLocationId = attachedTo;
        Database.SaveResult saveResult = Database.insert(fileToUpload, false, AccessLevel.SYSTEM_MODE);
        if (!saveResult.isSuccess()) {
            throw new FilesRecipesException('Failed to insert fileToUpload, error is: ' + formatSaveErrors(saveResult));
        }

        if (String.isNotBlank(folderName)) {
            Database.SaveResult folderUpdateResult = Database.update(
                new ContentVersion(
                    Id = saveResult.getId(),
                    Folder__c = folderName
                ),
                false,
                AccessLevel.SYSTEM_MODE
            );
            if (!folderUpdateResult.isSuccess()) {
                throw new FilesRecipesException('Failed to update file folder, error is: ' + formatSaveErrors(folderUpdateResult));
            }
        }
        return saveResult;
    }

    private static String formatSaveErrors(Database.SaveResult saveResult) {
        if (saveResult == null || saveResult.getErrors() == null || saveResult.getErrors().isEmpty()) {
            return 'Unknown error';
        }

        List<String> errors = new List<String>();
        for (Database.Error error : saveResult.getErrors()) {
            errors.add(error.getStatusCode() + ': ' + error.getMessage());
        }
        return String.join(errors, '; ');
    }

    /**
     * @description    Convenience method for creating a file and linking it to a given record
     * @param toCreate a FileAndLinkObject (inner class above) object representing the file to be created and linked
     * @return         `Database.SaveResult`
     */
    public static Database.SaveResult createFileAttachedToRecord(
            FilesRecipes.FileAndLinkObject toCreate
    ) {
        return createFileAttachedToRecord(
                toCreate.fileContents,
                toCreate.attachedTo,
                toCreate.fileName
        );
    }

    /**
     * @description    Bulk method for inserting multiple files and link them to records
     * @param toCreate List<FilesRecipes.FileAndLinkObject>
     * @return         `List<Database.SaveResult>`
     */
    public static List<Database.SaveResult> createFilesAttachedToRecords(
            List<FilesRecipes.FileAndLinkObject> toCreate
    ) {
        List<ContentVersion> filesToCreate = new List<ContentVersion>();
        for (FilesRecipes.FileAndLinkObject files : toCreate) {
            ContentVersion fileToUpload = new ContentVersion();
            fileToUpload.ContentLocation = 'S';
            fileToUpload.PathOnClient = files.fileName;
            fileToUpload.Title = files.fileName;
            fileToUpload.VersionData = files.fileContents;
            fileToUpload.FirstPublishLocationId = files.attachedTo;
            filesToCreate.add(fileToUpload);
        }

        List<Database.SaveResult> saveResult = new List<Database.SaveResult>();
        try {
            saveResult = Database.insert(filesToCreate);
        } catch (DmlException DMLE) {
            System.debug(
                    LoggingLevel.INFO,
                    'Failed to insert filesToUpload, error is: ' + DMLE.getMessage()
            );
        }
        return saveResult;
    }
}