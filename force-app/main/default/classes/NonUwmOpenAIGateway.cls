public with sharing class NonUwmOpenAIGateway {
    public class OpenAiGatewayException extends Exception {
    }
    private static final String PDF_DATA_URL_PREFIX = 'data:application/pdf;base64,';
    private static final Integer OPENAI_TIMEOUT_MS = 120000;

    private class ResponsesConsumer extends RestApiConsumer {
        public ResponsesConsumer(String endpoint) {
            super(endpoint, 'POST');
            request.setTimeout(OPENAI_TIMEOUT_MS);
        }

        public void setPayload(String payload) {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(payload);
        }

        public HttpResponse consume() {
            send();
            return response;
        }
    }

    private class ChatCompletionsConsumer extends RestApiConsumer {
        public ChatCompletionsConsumer(String endpoint) {
            super(endpoint, 'POST');
            request.setTimeout(OPENAI_TIMEOUT_MS);
        }

        public void setPayload(String payload) {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(payload);
        }

        public HttpResponse consume() {
            send();
            return response;
        }
    }

    public static List<Map<String, Object>> parseConditions(
        String rawText,
        String model,
        String instructions,
        String requestTemplate
    ) {
        if (String.isBlank(rawText)) {
            return new List<Map<String, Object>>();
        }

        ChatCompletionsConsumer consumer = new ChatCompletionsConsumer('callout:OpenAI/v1/chat/completions');

        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => String.isBlank(model) ? 'gpt-5' : model,
            'response_format' => new Map<String, Object>{ 'type' => 'json_object' },
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'system',
                    'content' => (String.isBlank(instructions) ? '' : instructions + '\n\n') +
                    'Return only JSON with key "conditions", an array of objects. ' +
                    'Each object should include: name, description, type, status, category, confidence.'
                },
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => (String.isBlank(requestTemplate) ? '' : requestTemplate + '\n\n') + rawText
                }
            }
        };

        consumer.setPayload(JSON.serialize(requestBody));
        HttpResponse httpResponse;
        try {
            httpResponse = consumer.consume();
        } catch (RestApiConsumer.HttpException ex) {
            throw new OpenAiGatewayException(ex.getMessage());
        }

        if (httpResponse.getStatusCode() < 200 || httpResponse.getStatusCode() > 299) {
            throw new OpenAiGatewayException('OpenAI parsing failed with status ' + httpResponse.getStatusCode());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
        if (responseMap == null || !responseMap.containsKey('choices')) {
            return new List<Map<String, Object>>();
        }

        List<Object> choices = (List<Object>) responseMap.get('choices');
        if (choices.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        Map<String, Object> choice0 = (Map<String, Object>) choices[0];
        if (choice0 == null || !choice0.containsKey('message')) {
            return new List<Map<String, Object>>();
        }

        Map<String, Object> message = (Map<String, Object>) choice0.get('message');
        String content = message == null ? null : (String) message.get('content');
        return parseConditionJson(content);
    }

    public static List<Map<String, Object>> parseConditionsFromPdf(
        Blob pdfData,
        String fileName,
        String model,
        String instructions,
        String requestTemplate
    ) {
        if (pdfData == null) {
            return new List<Map<String, Object>>();
        }

        ResponsesConsumer consumer = new ResponsesConsumer('callout:OpenAI/v1/responses');

        String promptText =
            (String.isBlank(instructions) ? '' : instructions + '\n\n') +
            (String.isBlank(requestTemplate) ? '' : requestTemplate + '\n\n') +
            'Extract conditions from the attached PDF. Return JSON only with key "conditions".';
        String safeFileName = normalizePdfFileName(fileName);
        String base64Data = EncodingUtil.base64Encode(pdfData);

        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => String.isBlank(model) ? 'gpt-5' : model,
            'input' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'input_file',
                            'filename' => safeFileName,
                            'file_data' => PDF_DATA_URL_PREFIX + base64Data
                        },
                        new Map<String, Object>{
                            'type' => 'input_text',
                            'text' => promptText
                        }
                    }
                }
            }
        };

        consumer.setPayload(JSON.serialize(requestBody));
        HttpResponse httpResponse;
        try {
            httpResponse = consumer.consume();
        } catch (RestApiConsumer.HttpException ex) {
            throw new OpenAiGatewayException(ex.getMessage());
        }

        if (httpResponse.getStatusCode() < 200 || httpResponse.getStatusCode() > 299) {
            throw new OpenAiGatewayException(
                'OpenAI responses parsing failed with status ' + httpResponse.getStatusCode()
            );
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
        String content = extractResponseText(responseMap);
        return parseConditionJson(content);
    }

    private static List<Map<String, Object>> parseConditionJson(String content) {
        if (String.isBlank(content)) {
            return new List<Map<String, Object>>();
        }

        Object parsed = JSON.deserializeUntyped(content);
        if (parsed instanceof List<Object>) {
            return toMapList((List<Object>) parsed);
        }

        if (!(parsed instanceof Map<String, Object>)) {
            return new List<Map<String, Object>>();
        }

        Map<String, Object> parsedMap = (Map<String, Object>) parsed;
        if (parsedMap.containsKey('conditions') && parsedMap.get('conditions') instanceof List<Object>) {
            return toMapList((List<Object>) parsedMap.get('conditions'));
        }

        return new List<Map<String, Object>>();
    }

    private static String extractResponseText(Map<String, Object> responseMap) {
        if (responseMap == null) {
            return null;
        }

        if (responseMap.containsKey('output_text')) {
            Object outputText = responseMap.get('output_text');
            if (outputText instanceof String) {
                return (String) outputText;
            }
            if (outputText instanceof List<Object>) {
                List<String> outputTextParts = new List<String>();
                for (Object outputTextPart : (List<Object>) outputText) {
                    if (outputTextPart != null) {
                        outputTextParts.add(String.valueOf(outputTextPart));
                    }
                }
                if (!outputTextParts.isEmpty()) {
                    return String.join(outputTextParts, '\n');
                }
            }
        }

        if (!responseMap.containsKey('output') || !(responseMap.get('output') instanceof List<Object>)) {
            return null;
        }

        List<String> textParts = new List<String>();
        for (Object outputObj : (List<Object>) responseMap.get('output')) {
            if (!(outputObj instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> outputItem = (Map<String, Object>) outputObj;
            if (!outputItem.containsKey('content') || !(outputItem.get('content') instanceof List<Object>)) {
                continue;
            }
            for (Object contentObj : (List<Object>) outputItem.get('content')) {
                if (!(contentObj instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> contentItem = (Map<String, Object>) contentObj;
                if (contentItem.containsKey('text') && contentItem.get('text') != null) {
                    textParts.add(String.valueOf(contentItem.get('text')));
                }
            }
        }
        return textParts.isEmpty() ? null : String.join(textParts, '\n');
    }

    private static String normalizePdfFileName(String fileName) {
        if (String.isBlank(fileName)) {
            return 'conditions.pdf';
        }
        String trimmed = fileName.trim();
        return trimmed.toLowerCase().endsWith('.pdf') ? trimmed : trimmed + '.pdf';
    }

    private static List<Map<String, Object>> toMapList(List<Object> rawItems) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Object item : rawItems) {
            if (item instanceof Map<String, Object>) {
                results.add((Map<String, Object>) item);
            }
        }
        return results;
    }
}