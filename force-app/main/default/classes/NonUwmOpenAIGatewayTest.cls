@IsTest
private class NonUwmOpenAIGatewayTest {
    private class ChatCompletionsSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assert(
                request.getEndpoint().contains('/v1/chat/completions'),
                'Chat completions endpoint should be used.'
            );

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"choices":[{"message":{"content":"{\\"conditions\\":[{\\"name\\":\\"Title Docs\\",\\"description\\":\\"Provide title commitment\\",\\"type\\":\\"Processor\\",\\"status\\":\\"New\\",\\"category\\":\\"Title\\",\\"confidence\\":88}]}"}}]}'
            );
            return response;
        }
    }

    private class ResponsesSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('POST', request.getMethod(), 'OpenAI request should be POST.');
            System.assert(
                request.getEndpoint().contains('/v1/responses'),
                'Responses API endpoint should be used.'
            );
            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            List<Object> input = (List<Object>) requestBody.get('input');
            Map<String, Object> inputItem = (Map<String, Object>) input[0];
            List<Object> content = (List<Object>) inputItem.get('content');
            Map<String, Object> inputFile = (Map<String, Object>) content[0];

            String filename = (String) inputFile.get('filename');
            String fileData = (String) inputFile.get('file_data');
            System.assert(filename != null && filename.toLowerCase().endsWith('.pdf'), 'Filename should end with .pdf');
            System.assert(
                fileData != null && fileData.startsWith('data:application/pdf;base64,'),
                'file_data should be sent as a PDF data URL.'
            );

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"output":[{"type":"message","content":[{"type":"output_text","text":"{\\"conditions\\":[{\\"name\\":\\"Income Docs\\",\\"description\\":\\"Provide two pay stubs\\",\\"type\\":\\"Processor\\",\\"status\\":\\"New\\",\\"category\\":\\"Income\\",\\"confidence\\":92}]}"}]}]}'
            );
            return response;
        }
    }

    private class ResponsesErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setBody('{"error":{"message":"Bad request"}}');
            return response;
        }
    }

    @IsTest
    static void testParseConditionsUsesChatCompletionsJsonResponse() {
        Test.setMock(HttpCalloutMock.class, new ChatCompletionsSuccessMock());
        List<Map<String, Object>> conditions = NonUwmOpenAIGateway.parseConditions(
            'Sample extracted text',
            'gpt-5',
            'System instructions',
            'Request template'
        );

        System.assertEquals(1, conditions.size(), 'One condition should be parsed from chat completions payload.');
        System.assertEquals('Title Docs', (String) conditions[0].get('name'));
        System.assertEquals('Title', (String) conditions[0].get('category'));
    }

    @IsTest
    static void testParseConditionsFromPdfReturnsConditionRows() {
        Test.setMock(HttpCalloutMock.class, new ResponsesSuccessMock());
        List<Map<String, Object>> conditions = NonUwmOpenAIGateway.parseConditionsFromPdf(
            Blob.valueOf('%PDF-1.4 test document'),
            'conditions',
            'gpt-5',
            'System instructions',
            'Request template'
        );

        System.assertEquals(1, conditions.size(), 'One condition should be parsed from responses payload.');
        System.assertEquals('Income Docs', (String) conditions[0].get('name'));
        System.assertEquals('Processor', (String) conditions[0].get('type'));
    }

    @IsTest
    static void testParseConditionsFromPdfThrowsOnNon2xx() {
        Test.setMock(HttpCalloutMock.class, new ResponsesErrorMock());

        try {
            NonUwmOpenAIGateway.parseConditionsFromPdf(
                Blob.valueOf('%PDF-1.4 test document'),
                'conditions.pdf',
                'gpt-5',
                null,
                null
            );
            System.assert(false, 'Expected OpenAiGatewayException to be thrown.');
        } catch (NonUwmOpenAIGateway.OpenAiGatewayException ex) {
            System.assert(
                ex.getMessage().contains('400'),
                'Exception should include HTTP 400 context.'
            );
        }
    }
}