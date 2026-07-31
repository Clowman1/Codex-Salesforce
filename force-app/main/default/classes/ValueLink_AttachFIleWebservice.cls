@RestResource(UrlMapping='/valueLink/attachFile/v1')
global class ValueLink_AttachFIleWebservice {
    private static final String APPRAISAL_FOLDER = 'Appraisal';

	public class ValueLinkObj{
		public String orderId;
		public String fileName;
		public String data;
	}

	@HttpPost
	global static void doPost(){
		RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
		try{
			String fileName = req.params.get('fileName');
			String orderId = req.params.get('orderId');
			System.debug('orderId =========== '+orderId);
			if(orderId != null){
				attachFileToTransaction(req.requestBody, fileName, orderId);
				res.responseBody = Blob.valueOf('File has been attached.');
				res.statusCode = 200;
			}else{
				res.responseBody = Blob.valueOf('Invalid OrderId.');
				res.statusCode = 400;
			}	

		}catch(Exception e){
			res.statusCode = 500;
            res.responseBody = Blob.valueOf('There was an error: ' + e.getMessage());
		}

	}
	@future
	public static void attachFileToTransaction(Blob payload,  String filename, String orderId){
		List<Appraisal_Order__c> appraisalOrders = [SELECT Id,Loan__c FROM Appraisal_Order__c WHERE Order_ID__c =: orderId];
		Blob fileData = EncodingUtil.base64Decode(payload.toString());
		if(appraisalOrders.size() == 1 && appraisalOrders[0].Loan__c != null){
			try{
				FilesRecipes.createFileAttachedToRecord(fileData, appraisalOrders[0].Loan__c, filename, APPRAISAL_FOLDER);
			}catch(Exception e){
				System.debug('Error Message '+e.getMessage());
				throw e;
			}
		}
	}
}