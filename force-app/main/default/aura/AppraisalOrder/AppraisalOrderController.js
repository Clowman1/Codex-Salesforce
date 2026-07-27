/**
 * Created by toma on 12/13/2022.
 */

({
    init : function(c,e,h){
        c.set('v.isLoading',true);
        let GET_APPRAISAL_ORDER = c.get('c.getActiveAppraisalOrder');
        GET_APPRAISAL_ORDER.setParams({loanId:c.get('v.recordId')});
        GET_APPRAISAL_ORDER.setCallback(this,function(res){
            if(res.getState() == 'SUCCESS'){
                c.set('v.isLoading',false);
                c.set('v.dataModel',res.getReturnValue());
                h.configureMapUrls(c);
                h.loadTimeline(c);
                console.log(res.getReturnValue());
                // console.log(res.getReturnValue().comments);
                // c.set("v.orderComments", res.getReturnValue().comments);
            }else{
                var errors = res.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                    errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
                c.set('v.hasOrder',false);
                c.set('v.isLoading',false);
            }
        });
        $A.enqueueAction(GET_APPRAISAL_ORDER);
    },
    setMapView : function(component, event, helper) {
        component.set('v.activeMapView', event.currentTarget.dataset.view);
    },
    toggleFlyOutSection : function(component, event, helper) {
        let sectionName = event.getSource ? event.getSource().get('v.name') : event.currentTarget.name;
        let attribute = 'v.' + sectionName;
        component.set(attribute, !component.get(attribute));
        let GET_COMMENTS = component.get("c.callGetCommentsList");
        let GET_DOCUMENTS = component.get("c.callGetDocumentsList");
        GET_COMMENTS.setParams({loanId: component.get("v.recordId")});
        GET_DOCUMENTS.setParams({loanId: component.get("v.recordId")});
        GET_COMMENTS.setCallback(this, (res) => {
            component.set("v.fetchingOrderComments",false);
            if(res.getState() == 'SUCCESS'){
                component.set("v.orderComments", res.getReturnValue());
            }
        });
        GET_DOCUMENTS.setCallback(this, (res) =>{
            component.set("v.fetchingOrderDocs",false);
            if(res.getState() == 'SUCCESS'){
                console.log('documents: ',res.getReturnValue());
                component.set("v.orderDocuments", res.getReturnValue());
            }
        });
        if(attribute == 'v.showConversationLog'){
            component.set("v.fetchingOrderComments",true);
            $A.enqueueAction(GET_COMMENTS);
        }else if(attribute == 'v.showStatusHistory'){
            component.set("v.fetchingOrderDocs",true);
            $A.enqueueAction(GET_DOCUMENTS);
        }
    },
    fetchReports : function(component,event,helper){
        component.set("v.isLoading", true);
        let action = component.get("c.fetchCompletedReports");
        action.setParams({loanId: component.get("v.recordId")});
        action.setCallback(this, function(res){
            component.set("v.isLoading", false);
            if(res.getState() == 'SUCCESS'){
                helper.showToast(component,event,helper,res.getReturnValue(), 'success');
                $A.enqueueAction(component.get('c.init'));
            }else{
                let errors = res.getError();
                let message = errors && errors[0] && errors[0].message ? errors[0].message : 'Unable to queue ValueLink report download.';
                helper.showToast(component,event,helper,message, 'error');
            }
        });
        $A.enqueueAction(action);
    },
    openCancelModal : function(component,event,helper){
        component.set("v.cancelReason", "");
        component.set("v.showCancelModal", true);
    },
    closeCancelModal : function(component,event,helper){
        component.set("v.showCancelModal", false);
        component.set("v.cancelReason", "");
    },
    cancelAppraisalOrder : function(component,event,helper){
        let reason = component.get("v.cancelReason");
        let reasonInput = component.find("cancelReasonInput");
        if (reasonInput) {
            reason = reasonInput.get("v.value");
            component.set("v.cancelReason", reason);
        }
        if(!reason || !reason.trim()){
            helper.showToast(component,event,helper,'Please enter a cancellation reason before cancelling the ValueLink order.', 'error');
            return;
        }
        reason = reason.trim();
        component.set("v.isLoading", true);
        let action = component.get("c.cancelAppraisalOrder");
        action.setParams({
            loanId: component.get("v.recordId"),
            reason: reason
        });
        action.setCallback(this, function(res){
            component.set("v.isLoading", false);
            if(res.getState() == 'SUCCESS'){
                component.set("v.showCancelModal", false);
                component.set("v.cancelReason", "");
                helper.showToast(component,event,helper,res.getReturnValue(), 'success');
                $A.enqueueAction(component.get('c.init'));
            }else{
                let errors = res.getError();
                let message = errors && errors[0] && errors[0].message ? errors[0].message : 'Unable to cancel ValueLink appraisal order.';
                helper.showToast(component,event,helper,message, 'error');
            }
        });
        $A.enqueueAction(action);
    },
    sendMessage : function(component,event,helper){
         let messages = component.get('v.orderComments');
         if(messages !== null && messages.length > 0){
             messages.push({Comment : component.get('v.newMessage'), CreatedOn : new Date(), UserTypeName: 'Client'});
         }else{
             messages = [];
             messages.push({Comment : component.get('v.newMessage'), CreatedOn : new Date(), UserTypeName: 'Client'});
         }
        let ADD_ORDER_COMMENT = component.get("c.callAddOrderComment");
        ADD_ORDER_COMMENT.setParams({loanId: component.get("v.recordId"),comment:component.get('v.newMessage')});
        ADD_ORDER_COMMENT.setCallback(this,function(res){
            if(res.getState() == 'SUCCESS'){
                $A.enqueueAction(component.get('c.init'));
            }
        })
        $A.enqueueAction(ADD_ORDER_COMMENT);
        component.set('v.newMessage', '');
        component.set('v.orderComments', messages);
    },
    handleChangeOnUpload: function (cmp, event, helper) {
        let filesList = event.getParam("files");
        const fileName = filesList[0].name;
        const fileType = filesList[0].type;
        let arrayOfDataChunks = [];
        const fr = new FileReader();
        fr.readAsDataURL(filesList[0]);
        fr.onload = $A.getCallback(function() {
            let fileContents = fr.result;
            const base64Mark = 'base64,';
            const dataStart = fileContents.indexOf(base64Mark) + base64Mark.length;
            fileContents = fileContents.substring(dataStart);
            helper.sendDocumentDataToOrder(fileContents,fileName,filesList[0],cmp,event,helper);
        });
    },
	downloadFile : function(c,e,h){
        c.set("v.isLoading", true);
        function base64ToBlob(base64) {
			const binaryString = window.atob(base64);
			const len = binaryString.length;
			const bytes = new Uint8Array(len);
			for (let i = 0; i < len; ++i) {
				bytes[i] = binaryString.charCodeAt(i);
			}
 
			return new Blob([bytes], { type: 'application/pdf' });
		};
        console.log(e.currentTarget.dataset);
		let fileToDownload = e.currentTarget.dataset.fileid;
		let FILE_ACTION = c.get('c.downloadSingleFile');
        FILE_ACTION.setParams({
            fileId : fileToDownload
        });
		FILE_ACTION.setCallback(this, function(res){
            try {
                c.set("v.isLoading", false);
                var link = document.createElement("a");
                document.body.appendChild(link);
                link.setAttribute("type", "hidden");
                link.href = "data:text/plain;base64," + res.getReturnValue().OrderDocument;
                link.download =  res.getReturnValue().DocumentFileName;
                link.click();
                document.body.removeChild(link);
            } catch (e) {
                h.showToast(c,e,h, 'Error occured downloading file. File might be too big.');
            }
		});
		$A.enqueueAction(FILE_ACTION);
	}
});
