/**
 * Created by toma on 3/11/2022.
 */

public class RingCentralApi_Models {

    public class GetAccessTokenRequest{
        public String username;
        public String grant_type;
        public String jvtToken;
    }

    public class TokenResponse{
        public String access_token;
        public String token_type ;
        public String getAccessToken(){
            return this.access_token;
        }
        public String getTokenType(){
            return this.token_type;
        }
    }
	
	public class GetUserCallRecordsResponse{
		public List<Records> records;
		public Paging paging;
		public Navigation navigation;
	}
	public class Records{ 
		public String id;
		public String result;
		public To to;
		public FromObj fromObj;
		public String direction;
        public String startTime;
	}
	public class To{
		public String phoneNumber;
		public String name;
        public String extensionId;
	}
	public class Paging{
		public Integer page;
		public Integer perPage;
		public Integer pageStart;
		public Integer pageEnd;
	}
	public class Navigation {
		public WhichPage firstPage;
		public WhichPage nextPage;
		public WhichPage previousPage;
	}
	public class WhichPage{
		public String uri;
	}
	public class FromObj{
		public String phoneNumber;
		public String name;
        public String extensionId;
	}
	/*
    public class SendSMSRequest{
        public String text;
        public  PartyInformation cls_from;
        public List<PartyInformation> to = new List<PartyInformation>();

        public SendSMSRequest(String cls_from, String[] toList, String text){
            this.text = text;
            this.cls_from = new PartyInformation(cls_from);
            for(String toNumber : toList){
                to.add(new PartyInformation(toNumber));
            }
        }
    }
    public class PartyInformation{
        String phoneNumber;

        public PartyInformation(String phoneNumber){
            this.phoneNumber = phoneNumber;
        }
    }
    public class SendSMSResponse{
        public String uri;	//https://platform.ringcentral.com/account/1346632010/extension/1346632010/message-store/315450330010
        public String id;	//315450330010
        public PartyInformation[] to;
        public PartyInformation cls_from;
        public String type;	//SMS
        public String creationTime;	//2012-09-13T15:21:08.000Z
        public String readStatus;	//Unread
        public String priority;	//Normal
        public cls_attachments[] attachments;
        public String direction;	//Outbound
        public String availability;	//Alive
        public String subject;	//Test SMS message from Platform server
        public String messageStatus;	//Sent
        public String conversationId;	//4481650717038104600
        public String lastModifiedTime;	//2012-09-13T15:21:09.000Z
    }
    class cls_attachments {
        public String id;	//1
        public String uri;	//https://platform.ringcentral.com/account/1346632010/extension/1346632010/message-store/315450330010/content/1
        public String contentType;	//text/plain
    }
	*/

    public class MessageStoreResponse {
        public String uri;
        public List<MessageRecord> records;
        public PagingInfo paging;
        public Navigation navigation;
    }

    public class MessageRecord {
        public String uri;
        public Long id;
        public String extensionId;
        public List<Recipient> to;
        public Sender fromObj;
        public String type;
        public String creationTime;
        public String readStatus;
        public String priority;
        public List<Attachment> attachments;
        public String direction;
        public String availability;
        public String subject;
        public String messageStatus;
        public Long conversationId;
        public Conversation conversation;
        public String lastModifiedTime;
        public Integer smsSendingAttemptsCount;
    }

    public class Recipient {
        public String phoneNumber;
        public String name;
        public String location;
    }

    public class Sender {
        public String phoneNumber;
        public String name;
        public String location;
    }

    public class Attachment {
        public Long id;
        public String uri;
        public String type;
        public String contentType;
    }

    public class Conversation {
        public String id;
        public String uri;
    }

    public class PagingInfo {
        public Integer page;
        public Integer totalPages;
        public Integer perPage;
        public Integer totalElements;
        public Integer pageStart;
        public Integer pageEnd;
    }

    public static DateTime parseRCTime(String rcDateTime){
        DateTime dt = (DateTime) JSON.deserialize('"' + rcDateTime + '"', DateTime.class);
    return(DateTime.newInstance( dt.getTime()));
    }
}