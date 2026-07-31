/**
 * @author Andrei Karanko
 * @date 8/8/2024
 * description
 */
public without sharing class pwa_LeadIntakeFormManifestController {
    public String getContent() {
        StaticResource manifest = [
            SELECT Body FROM StaticResource WHERE Name = 'pwa_LeadIntakeFormManifest' LIMIT 1
        ];
        System.debug('Processed manifest: ' + replaceResourcesLastModified(replaceUrlPrefix(manifest.Body.toString())));
        return replaceResourcesLastModified(replaceUrlPrefix(manifest.Body.toString()));
    }

    private static String replaceUrlPrefix(String content) {
        PageReference currentPage = ApexPages.currentPage();
        System.debug('currentPage: ' + currentPage);

        if (currentPage == null || currentPage.getParameters() == null || String.isBlank(currentPage.getParameters().get('urlPrefix'))) {
            return content.replace('{urlPrefix}', '');
        }

        if (currentPage.getParameters().get('email') != null) {
            content = content.replace('{referralEmail}', currentPage.getParameters().get('email'));
        }

        return content.replace('{urlPrefix}', currentPage.getParameters().get('urlPrefix').replace('"', '\\"'));
    }

    private static String replaceResourcesLastModified(String content) {
        StaticResource resources = [
            SELECT LastModifiedDate FROM StaticResource WHERE Name = 'pwa_LeadIntakeFormResources' LIMIT 1
        ];
        return content.replace('{resourcesLastModified}', String.valueOf(resources.LastModifiedDate.getTime()));
    }
}