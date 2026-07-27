/**
 * Created by BTB12 on 9/22/2022.
 */

({
    doInit: function(cmp) {
        var record = cmp.get("v.simpleRecord");
        var ariveId = record && record.AriveId__c;
        if (!ariveId) {
            cmp.set("v.url", null);
            cmp.set("v.frameLoaded", false);
            cmp.set("v.loadFrame", false);
            cmp.set("v.showFrameFallback", false);
            return;
        }

        cmp.set("v.url", "https://98765.myarive.com/app/loans/" + encodeURIComponent(ariveId) + "/loan-info");
        cmp.set("v.frameLoaded", false);
        cmp.set("v.showFrameFallback", false);
        cmp.set("v.loadFrame", true);
    },

    loadEmbeddedFrame: function(cmp) {
        cmp.set("v.frameLoaded", false);
        cmp.set("v.showFrameFallback", false);
        cmp.set("v.loadFrame", true);
    },

    handleFrameLoad: function(cmp) {
        cmp.set("v.frameLoaded", true);
        cmp.set("v.showFrameFallback", false);
    }
})
