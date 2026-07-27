/**
 * Created by MSI Laptop on 5/20/2022.
 */

({
    doInit: function (c, e, h) {
        // Initialize PWA support
        if (!window.pwaInitialized) {
            window.pwaInitialized = true;
            try {
                const prefixPathMatch = location.pathname.match(/(^.*?)\/s/i);
                const prefixPath = prefixPathMatch ? prefixPathMatch[1] : '';
                const urlPrefix = prefixPath ? encodeURIComponent(prefixPath) : '';
                const email = new URLSearchParams(window.location.search).get("email");
                
                // Add manifest link immediately
                if (!document.querySelector('link[rel="manifest"]')) {
                    let manifestUrl = prefixPath + '/pwa_LeadIntakeFormManifest';
                    if (urlPrefix) {
                        manifestUrl += '?urlPrefix=' + urlPrefix;
                        if (email) {
                            manifestUrl += '&email=' + encodeURIComponent(email);
                        }
                    } else if (email) {
                        manifestUrl += '?email=' + encodeURIComponent(email);
                    }
                    
                    const manifestLink = document.createElement('link');
                    manifestLink.rel = 'manifest';
                    manifestLink.href = manifestUrl;
                    document.head.appendChild(manifestLink);
                }
                
                // Inline PWA loader functionality to avoid Aura script loading conflicts
                setTimeout($A.getCallback(function() {
                    if (!window.pwaServiceWorkerRegistered) {
                        window.pwaServiceWorkerRegistered = true;
                        const serviceWorkerPath = prefixPath + '/pwa_LeadIntakeFormServiceWorker';
                        
                        // Locker-safe standalone detection via CSS variable (Salesforce-safe approach)
                        function isStandaloneViaCssVar(component) {
                            try {
                                const el = component.getElement();   // <-- Aura root element
                                if (!el) return false;
                                const v = window.getComputedStyle(el).getPropertyValue('--pwa-standalone').trim();
                                return v === '1';
                            } catch (e) {
                                return false;
                            }
                        }
                        
                        // Robust standalone detection function
                        var updateStandaloneFlags = $A.getCallback(function() {
                            const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || 
                                         (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
                            
                            const isStandalone = isStandaloneViaCssVar(c);

                            c.set('v.isStandalone', isStandalone);
                            c.set('v.isIOS', isIOS);
                            c.set('v.showIOSInstructions', false);
                            if (isStandalone) {
                                c.set('v.showInstallButton', false);
                                c.set('v.showIOSInstructions', false);
                            }
                        });
                        
                        setTimeout($A.getCallback(updateStandaloneFlags), 0);
                        setTimeout($A.getCallback(updateStandaloneFlags), 800);
                        window.addEventListener('pageshow', $A.getCallback(updateStandaloneFlags));
                        
                        // Save the app installation prompt event (Android/Chrome)
                        window.addEventListener('beforeinstallprompt', $A.getCallback(function(event) {
                            event.preventDefault();
                            window.deferredInstallPrompt = event;
                            // Show install button for Android/Chrome
                            c.set('v.showInstallButton', true);
                        }));
                        
                        // Register service worker when page loads
                        window.addEventListener('load', function() {
                            if ('serviceWorker' in navigator) {
                                navigator.serviceWorker.register(serviceWorkerPath).catch(function(err) {
                                    console.error('Service Worker registration failed:', err);
                                });
                            }
                        });
                    }
                }), 500);
            } catch (e) {
                console.error('PWA initialization error:', e);
            }
        }
        
        const params = new Proxy(new URLSearchParams(window.location.search), {
            get: (searchParams, prop) => searchParams.get(prop)
        });
        let value = params.email; // "some_value"

        /*let realtorEmails = ['alex@thenickleygroup.com', 'antonia@thenickleygroup.com', 'arianna@thenickleygroup.com', 'bret@thenickleygroup.com', 'cody@thenickleygroup.com',
                             'eric@thenickleygroup.com', 'katie@thenickleygroup.com', 'micaela@thenickleygroup.com' , 'nick@thenickleygroup.com', 'nicole@thenickleygroup.com',
                             'nicoles@thenickleygroup.com', 'ross@thenickleygroup.com', 'ryan@thenickleygroup.com', 'shaun@thenickleygroup.com', 'tiss@thenickleygroup.com', 
                             'eleanor@thenickleygroup.com', 'kayla@thenickleygroup.com', 'adam@thenickleygroup.com', 'carolina@thenickleygroup.com', 'daniel@thenickleygroup.com',
                             'nani@thenickleygroup.com', 'simone@thenickleygroup.com', 'tristan@thenickleygroup.com', 'katelyn@thenickleygroup.com'];*/
        
        
        var action = c.get("c.getLoanOfficers");
        action.setParams({ realtorEmail: value });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (state == 'SUCCESS') {
                var loanOfficers = response.getReturnValue() || [];
                var preferredOrder = {
                    'Zach Fritz': 0,
                    'Zachary Fritz': 0,
                    'Rhett Delaney': 1,
                    'Joe Olmsted': 2,
                    'Alaina Pugh': 3,
                    'Alaina Clare Pugh': 3,
                    'Berkeley Peterson': 4
                };
                loanOfficers.sort(function(a, b) {
                    var aName = [a.FirstName, a.LastName].filter(Boolean).join(' ');
                    var bName = [b.FirstName, b.LastName].filter(Boolean).join(' ');
                    var aRank = preferredOrder[aName] !== undefined ? preferredOrder[aName] : 99;
                    var bRank = preferredOrder[bName] !== undefined ? preferredOrder[bName] : 99;
                    if (aRank !== bRank) {
                        return aRank - bRank;
                    }
                    return aName.localeCompare(bName);
                });
                console.log(loanOfficers);
                if (loanOfficers && loanOfficers.length > 0) {
                    c.set("v.selectedLoanOfficer", loanOfficers[0].Id);
                    console.log(loanOfficers[0].Name);
                    c.set("v.loanOfficers", loanOfficers);
                	c.set("v.showLoanOfficerSelection", true);
                }
            }
        });
        $A.enqueueAction(action);
        
        /*if (realtorEmails.includes(value)) {
            c.set('v.showAgentSelection', true);
        }*/
        
        c.set('v.referralEmail', value);
        //c.set('v.emailValue', value);
    },
    showSuccessMessage: function (c, e, h) {
        c.set("v.spinner", false);
        c.set("v.submitingForm", false);
        c.set('v.isModalOpen', true);
    },
    submitRecord: function(c,e,h){
        c.set("v.spinner", true);
        e.preventDefault();       // stop the form from submitting
        var fields = e.getParam('fields');
        var selectedLoanOfficer = c.get('v.selectedLoanOfficer');

        // Priority: selected LO, then Spanish routing, otherwise the Intake Form Queue flow.
        if (c.get('v.showLoanOfficerSelection') && selectedLoanOfficer) {
            fields['Preferred_LO__c'] = selectedLoanOfficer;
        } else if (c.get('v.spanishSpeaker') === 'Yes') {
            fields['Preferred_LO__c'] = '005Qi00000H09nuIAB';
        } else {
            fields['Preferred_LO__c'] = null;
        }
        
        fields['Spanish_Speaker_Intake_Form__c'] = c.get('v.spanishSpeaker');
        
        fields.ReferralFormSourceEmail__c = c.get('v.referralEmail');
        c.find('myrecordform').submit(fields);
    },
    handleSubmit: function (c, e, h) {
        c.set("v.submitingForm", true);
    },
    handleOnLoad: function (c, e, h) {
        let contactOwnerId = c.get("v.userRec").OwnerId;
        let contactOwnerName = c.get("v.userRec").Owner.Name;
        c.set("v.selectedUser", contactOwnerId);
    },
    handleLoanOfficerChange: function (c, e, h) {
        let selectedValue = e.getSource().get("v.value");
        c.set("v.selectedLoanOfficer", selectedValue);
        console.log(c.get("v.selectedLoanOfficer"));
    },
    handleLoanOfficerTileClick: function (c, e, h) {
        let selectedValue = e.currentTarget.dataset.id;
        c.set("v.selectedLoanOfficer", selectedValue);
    },
    handleSpanishSpeakerChange: function (c, e, h) {
        let selectedValue = e.getSource().get("v.value");
        console.log(selectedValue);
        c.set("v.spanishSpeaker", selectedValue);
    },
    handleError: function (c, e, h) {
        var eventName = e.getName();
        var eventDetails = e.getParam("error");
        c.set("v.submitingForm", false);
        console.log('Error Event received' + JSON.stringify(eventDetails));
        c.set("v.submitingForm", false);
        c.set('v.isModalOpen', true);
    },
    refreshModel: function (component, event, helper) {
        // Set isModalOpen attribute to false
        component.set("v.isModalOpen", false);
        $A.get('e.force:refreshView').fire();
    },
    
    handleInstallClick: function (c, e, h) {
        if (window.deferredInstallPrompt) {
            // Show the install prompt
            window.deferredInstallPrompt.prompt();
            
            // Wait for the user to respond to the prompt
            window.deferredInstallPrompt.userChoice.then(function(choiceResult) {
                if (choiceResult.outcome === 'accepted') {
                    console.log('User accepted the install prompt');
                } else {
                    console.log('User dismissed the install prompt');
                }
                // Clear the deferred prompt
                window.deferredInstallPrompt = null;
                c.set('v.showInstallButton', false);
            });
        }
    },
    
    showIOSInstructionsAction: function (c, e, h) {
        // Only show instructions if not in standalone mode (using CSS variable)
        function isStandaloneViaCssVar(component) {
            try {
                const el = component.getElement();   // <-- Aura root element
                if (!el) return false;
                const v = window.getComputedStyle(el).getPropertyValue('--pwa-standalone').trim();
                return v === '1';
            } catch (e) {
                return false;
            }
        }
        var isStandalone = isStandaloneViaCssVar(c);

        if (!isStandalone) {
            c.set('v.showIOSInstructions', true);
        }
    },
    
    closeIOSInstructions: function (c, e, h) {
        c.set('v.showIOSInstructions', false);
    }
});
