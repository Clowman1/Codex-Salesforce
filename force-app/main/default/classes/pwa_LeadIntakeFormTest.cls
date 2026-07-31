/**
 * @author Andrei Karanko
 * @date 8/9/2024
 * description
 */
@IsTest
private with sharing class pwa_LeadIntakeFormTest {

    @IsTest
    static void getStaticResources() {
        Test.startTest();
        String loaderContent = new pwa_LeadIntakeFormLoader().getContent();
        String manifestContent = new pwa_LeadIntakeFormManifestController().getContent();
        String serviceWorkerContent = new pwa_LeadIntakeFormServiceWorker().getContent();
        Test.stopTest();

        Assert.isTrue(String.isNotBlank(loaderContent), 'Loader content is null');
        Assert.isTrue(String.isNotBlank(manifestContent), 'Manifest content is null');
        Assert.isTrue(String.isNotBlank(serviceWorkerContent), 'Service worker content is null');
    }
}