/**
 * Created by toma on 12/12/2022.
 */

public class ValueLinkSoapService_PostComment {
    private static String requestXML = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:AddOrderComment>\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:Comment>\n' +
            '            <val:OrderID>{2}</val:OrderID>\n' +
            '            <val:Comment>{3}</val:Comment>\n' +
            '            <val:AccessibleByLender>true</val:AccessibleByLender>\n' +
            '            <val:AccessibleByAppraiser>true</val:AccessibleByAppraiser>\n'+
            '         </val:Comment>\n' +
            '       </val:AddOrderComment>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';

    public static void sendComment(String username, String password, String orderId, String comment){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        //production endpoint https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        //uat https://esusauat.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setBody(String.format(requestXML,new List<String>{username, password,orderId,comment}));
        HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
    }
    public class Comment{
        public String comment;
        public String orderId;
    }
}