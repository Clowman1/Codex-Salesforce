/**
 * @author Andrei Karanko
 * @date 8/8/2024
 * description
 */
public with sharing class pwa_LeadIntakeFormServiceWorker {
    public String getContent() {
        StaticResource worker = [
            SELECT Body FROM StaticResource WHERE Name = 'pwa_LeadIntakeFormServiceWorker' LIMIT 1
        ];
        return worker.Body.toString();
    }
}