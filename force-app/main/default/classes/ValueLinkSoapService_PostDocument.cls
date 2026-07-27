/**
 * Created by toma on 12/13/2022.
 */

public class ValueLinkSoapService_PostDocument {
    private static String requestXML = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:AddOrderDocuments>\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:OrderDocuments>\n' +
            '            <val:VLOrderDocument>\n' +
            '               <val:OrderID>{2}</val:OrderID>\n' +
            '               <val:OrderNumber></val:OrderNumber>\n' +
            '               <val:DocumentTypeName></val:DocumentTypeName>\n' +
            '               <val:DocumentTypeDescription></val:DocumentTypeDescription>\n' +
            '               <val:DocumentFileName>{3}</val:DocumentFileName>\n' +
            '               <val:OrderDocument>{4}</val:OrderDocument>\n' +
            '               <val:AccessibleByClient>true</val:AccessibleByClient>\n' +
            '               <val:AccessibleByAppraiser>true</val:AccessibleByAppraiser>\n' +
            '            </val:VLOrderDocument>\n' +
            '         </val:OrderDocuments>\n' +
            '      </val:AddOrderDocuments>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';

    public static void sendDocument(String username, String password, RequestModel requestModel){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        //production endpoint https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        //uat https://esusauat.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setBody(String.format(requestXML,new List<String>{username, password, requestModel.orderId, requestModel.fileName, requestModel.fileData
        }));
        HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
    }
    public class RequestModel{
        public String fileData;
        public String orderId;
        public String fileName;
    }
}