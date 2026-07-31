/**
 * Created by toma on 12/15/2022.
 */

public class ValueLink_GetCommentsList {
    private static String requestXML = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:GetOrderCommentList>\n' +
            '         <!--Optional:-->\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <!--Optional:-->\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:OrderID>{2}</val:OrderID>\n' +
            '      </val:GetOrderCommentList>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';

    public static List<AppraisalOrderController.OrderComment> getOrderComments(String username, String password, String orderId){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        //production endpoint https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        //uat https://esusauat.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setBody(String.format(requestXML,new List<String>{username, password, orderId}));
        HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
        List<AppraisalOrderController.OrderComment> comments = parseResponse(response.getBody());
        System.debug('comments: '+comments);
        return comments;
    }
    private static List<AppraisalOrderController.OrderComment> parseResponse(String xmlResponse){
        List<AppraisalOrderController.OrderComment> output = new List<AppraisalOrderController.OrderComment>();
        XMLSerializer manipulateXMLString = new XMLSerializer();
        Object deserializedJSON = (Object) manipulateXMLString.deSerializeUnTyped(xmlResponse);
        System.debug('map xml: '+JSON.serializePretty(deserializedJSON));
        System.debug('map xml2: '+deserializedJSON);
        Map<String,Object> resMap = (Map<String,Object>) deserializedJSON;
        Map<String,Object> envelope = (Map<String,Object>) resMap.get('Envelope');
        Map<String,Object> body = (Map<String,Object>) envelope.get('Body');
        Map<String,Object> getOrderCommentsResponse = (Map<String,Object>) body.get('GetOrderCommentListResponse');
        Map<String,Object> result = (Map<String,Object>) getOrderCommentsResponse.get('GetOrderCommentListResult');
        Map<String,Object> comments;
        List<AppraisalOrderController.OrderComment> commentsList;
        AppraisalOrderController.OrderComment comment;
        try{
            if(result.get('VLOrderComments') != null || result.get('VLOrderComments') != '')
                comments = (Map<String,Object>) result.get('VLOrderComments');
            try{
                commentsList = (List<AppraisalOrderController.OrderComment>) JSON.deserialize(JSON.serialize(comments.get('VLOrderComment')),List<AppraisalOrderController.OrderComment>.class );
                if(commentsList.size() > 0){
                    for(AppraisalOrderController.OrderComment comm : commentsList){
                        output.add(comm);
                    }
                }
            }catch (Exception e){
                System.debug('one comment res'+e.getMessage());
                if(e.getMessage().contains('Malformed JSON: Expected \'[\' at the beginning of List/Set')){
                    System.debug('this is hit');
                    comment = (AppraisalOrderController.OrderComment) JSON.deserialize(JSON.serialize(comments.get('VLOrderComment')),AppraisalOrderController.OrderComment.class );
                    output.add(comment);
                }
            }finally {
                if(output.size() > 1){
                    return ValueLink_SortComments.sort(output);
                }else{
                    return output;
                }
            }
        }catch (Exception e){
            System.debug('no comments res '+e.getMessage());
            if(e.getMessage().contains('Invalid conversion from runtime type String to Map<String,ANY>')){
                return null;
            }
        }
        System.debug('output: '+output);
        if(output.size() > 1){
            return ValueLink_SortComments.sort(output);
        }else{
            return output;
        }
    }
}