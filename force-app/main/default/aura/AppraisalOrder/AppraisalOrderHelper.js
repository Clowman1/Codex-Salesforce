/**
 * Created by toma on 12/13/2022.
 */

({
    SAVE_DATA_CHUNK_SIZE: 1000,
    GOOGLE_MAPS_KEY: 'AIzaSyDliLquGXGts9S8YtkWVolSQEJdBL1ZuWc',
    configureMapUrls : function(component) {
        const model = component.get('v.dataModel') || {};
        const address = [
            model.street,
            model.city,
            model.state,
            model.zip
        ].filter((part) => !!part).join(', ');
        const encodedAddress = encodeURIComponent(address);

        component.set(
            'v.satelliteViewUrl',
            `https://www.google.com/maps/embed/v1/place?key=${this.GOOGLE_MAPS_KEY}&q=${encodedAddress}&zoom=20&maptype=satellite`
        );
        component.set(
            'v.streetViewUrl',
            `https://www.google.com/maps/embed/v1/streetview?key=${this.GOOGLE_MAPS_KEY}&location=${encodedAddress}&fov=80`
        );

        if (!address) {
            component.set('v.activeMapView', 'satellite');
        }
    },
    loadTimeline : function(component) {
        let action = component.get("c.getAppraisalTimeline");
        action.setParams({loanId: component.get("v.recordId")});
        action.setCallback(this, function(res){
            if(res.getState() == 'SUCCESS'){
                component.set("v.timelineItems", res.getReturnValue());
            }
        });
        $A.enqueueAction(action);
    },
    showToast : function(component, event, helper, message, type) {
        let toastEvent = $A.get("e.force:showToast");
        if(type === 'success' || message == null){
            toastEvent.setParams({
                "title": "Success!",
                "message": message || "Your document was posted to order successfully!",
                "type":"success",
                "mode":"dismissible"
            });
        }
        else{
            toastEvent.setParams({
                "title": "Error!",
                "message": message,
                "type":"error",
                "mode":"sticky"
            });
        }
        toastEvent.fire();
    },
    sendDocumentDataToOrder: function(fileData,fileName,fileObject,c,e,h){
        let documents = c.get('v.orderDocuments');
        documents.unshift({DocumentFileName : fileName, DocumentSubmittedOn : new Date()});
        let action = c.get("c.callPostOrderDocument");
        action.setParams({
            loanId: c.get("v.recordId"),
            fileName:fileName,
            encodedBlob: fileData
        });
        action.setCallback(this, function(res){
            c.set("v.isLoading",false);
            if(res.getState() == 'SUCCESS'){
                h.showToast(c,e,h,null, 'success');
                c.set('v.orderDocuments', documents);
                $A.enqueueAction(c.get("c.init"));
            }else{
                h.showToast(c,e,h,"Something went wrong while sending doc to ValueLink: " + res.getError()[0].message, 'error');
            }
        });
        $A.enqueueAction(action);
        c.set("v.isLoading",true);
    }
});
