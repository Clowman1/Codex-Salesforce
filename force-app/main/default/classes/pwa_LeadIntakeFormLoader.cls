/**
 * @author Andrei Karanko
 * @date 8/8/2024
 * description
 */
public with sharing class pwa_LeadIntakeFormLoader {
    public String getContent() {
        StaticResource loader = [
            SELECT Body FROM StaticResource WHERE Name = 'pwa_LeadIntakeFormLoader' LIMIT 1
        ];
        return loader.Body.toString();
    }
}