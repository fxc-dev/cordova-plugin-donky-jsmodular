
var channel = require('cordova/channel'),
    utils = require('cordova/utils');

channel.createSticky('onCordovaInfoReady');
// Tell cordova channel to wait on the CordovaInfoReady event
channel.waitForInitialization('onCordovaInfoReady');

/**
 * DonkyPlugin constructor
 */
function DonkyPlugin(){

    var self = this;

    function syncBadgeCount(){
        // set badge count 
        
        var badgeCount = 0;

        if(window.donkyPushLogic){
            badgeCount += donkyPushLogic.getMessageCount();                                        
        }                                
        
        if(window.donkyRichLogic){
            badgeCount += donkyRichLogic.getMessageCount().unreadRichMessageCount;                                        
        }                                
                                
        if(window.donkyMessagingCommon){
            donkyMessagingCommon.setBadgeCount(badgeCount, true);                            
        }
        
        self.setBadgeCount(function(){},function(){},badgeCount);
        
    }

    channel.onCordovaReady.subscribe(function() {
        console.log("onCordovaReady ;-)");
        
        self.getPlatformInfo(function(info){
            self.available = true;

            self.manufacturer = info.manufacturer;
            self.model = info.model;
            self.platform = info.platform;
            self.version = info.version;
            self.cordova = info.cordova;
            self.bundleId = info.bundleId;
            self.deviceId = info.deviceId;
            self.coldstart = info.coldstart;
            self.launchTimeUtc = info.launchTimeUtc;
                
            // These need to be available ... (integrators responsibility to load)        
            if(window.donkyCore){
                
                try{
                    donkyCore.donkyAccount.setOperatingSystem(self.platform);
                    donkyCore.donkyAccount._setDeviceId(self.deviceId);
                }catch(e){
                    utils.alert("[ERROR] Error initialising donky: " + e);                    
                }

                /**
                 * A new push notification has arrived
                 *
                 */
                donkyCore.subscribeToLocalEvent("pushNotification", function (event) {
                    console.log("pushNotification: " + JSON.stringify(event.data, null, 4));
                    var notificationId = event.data.userInfo.notificationId;
                                       
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){
                        if(notification){
                            // this could be a push or a rich message ...
                            switch(notification.type){
                                case "SimplePushMessage":
                                    if(window.donkyPushLogic){
                                        donkyPushLogic.processPushMessage(notification);                                        
                                    }
                                break;
                                
                                case "RichMessage":
                                    if(window.donkyRichLogic){
                                        donkyRichLogic.processRichMessage(notification);                                        
                                    }                                
                                break;
                            }                           
                        }
                        
                        syncBadgeCount();
                        
                    });
                });        
                
                /**
                 * 
                 */
                donkyCore.subscribeToLocalEvent("RichMessageRead", function (event) {
                    syncBadgeCount();
                });                

                /**
                 * A button has been clicked (iOS)
                 * TODO: User is done with this msg so make sure it doesn't get displayed a second time ...
                 * !!! POTENTIAL RACE CONDITION CENTRAL HERE !!!  
                 */
                donkyCore.subscribeToLocalEvent("handleButtonAction", function (event) {
                    console.log("handleButtonAction", JSON.stringify(event.data, null, 4));
                    
                    // If SDK not initialised, we can't make rest calls (even if we have a token)  should I change this ?
                    
                    var buttonText = event.data.identifier;
                    var notificationId = event.data.userInfo.notificationId;
                    
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){
                        if(notification){
                            
                            switch(notification.type){
                                case "SimplePushMessage":
                                    if(window.donkyPushLogic){
                                        // this will mark as received and fire a local event so not sure I want to add in like this ...
                                        // flag to not publish a local event !!!                            
                                        donkyPushLogic.processPushMessage(notification, false);
                                        // this will delete the message                            
                                        donkyPushLogic.setSimplePushResult(notificationId, buttonText);
                                    }                                                        
                                break;
                            }                                                       
                        }
                    });
                    
                });                            
                
                /**
                 * We have a device token now which needs to be sent to donky
                 */
                donkyCore.subscribeToLocalEvent("pushRegistrationSucceeded", function (event) {
                    console.log("pushRegistrationSucceeded", JSON.stringify(event.data.deviceToken, null, 4));

                    var pushConfigurationRequest = {
                        registrationId: event.data.deviceToken,
                        bundleId: window.cordova.plugins.donky.bundleId
                    };

                    console.log("pushConfigurationRequest", JSON.stringify(pushConfigurationRequest, null, 4));

                    donkyCore.donkyAccount.sendPushConfiguration(pushConfigurationRequest, function(result){
                        
                        console.log("sendPushConfiguration result: ", JSON.stringify(result, null, 4));
                    });
                                                                                                                           
                }, false);

                donkyCore.subscribeToLocalEvent("pushRegistrationFailed", function (event) {
                    console.error("pushRegistrationFailed", JSON.stringify(event.data.error, null, 4));                        
                }, false);
                          

                /**
                 * 
                 */
                function queueAppSession(){

                    var sessionClientNotification = {
                        Type: "AppSession",
                        "startTimeUtc": self.launchTimeUtc,
                        "endTimeUtc": new Date().toISOString(),
                        "operatingSystem": donkyCore.donkyAccount.getOperatingSystem(),
                        "sessionTrigger": self.coldstart ? "Notification" : "None" 
                    };
                    
                    donkyCore.queueClientNotifications(sessionClientNotification);                    
                }
                          
                /**
                 * 
                 */
                function queueAppLaunch(){
                    var launchClientNotification = {
                        Type: "AppLaunch",
                        "launchTimeUtc": self.launchTimeUtc,
                        "operatingSystem": donkyCore.donkyAccount.getOperatingSystem(),
                        "sessionTrigger" : self.coldstart ? "Notification" : "None"
                    };

                    donkyCore.queueClientNotifications(launchClientNotification);                    
                }          
                          
                                
                // This event is ALWAYS published on succesful initialisation - hook into it and run our analysis ...
                donkyCore.subscribeToLocalEvent("DonkyInitialised", function(event) {

                    console.log("DonkyInitialised event received in DonkyPlugin()");   
                    
                    queueAppLaunch();                 
                    
                    var buttonSets = donkyCore.getiOSButtonCategories();                                                            

                    self.registerForPush(function(result){
                        console.log("registerForPush succeeded");
                    }, function(error){
                        consloe.log("registerForPush failed");
                    },
                    buttonSets);
                });
                
                /**
                *
                */            
                donkyCore.subscribeToLocalEvent("AppBackgrounded", function(event) {
                    // queue an AppSession 
                    queueAppSession();
                });        
                
                /**
                *
                */            
                donkyCore.subscribeToLocalEvent("AppForegrounded", function(event) {
                    self.launchTimeUtc = new Date().toISOString();
                    
                    queueAppLaunch();
                });        
                
                                
            }
            
            channel.onCordovaInfoReady.fire();                        
        },function(e){
            self.available = false;
            utils.alert("[ERROR] Error initializing Cordova: " + e);            
        });
    });
}


/**
 * Internal callback function for native code to call to trigger an event for the client.
 * A CustomEvent is created which can be intercepted as follows:
 * 
 *  document.addEventListener("donkyevent", function (e) {
 *      console.log("donkyevent: " + JSON.stringify(e.detail));
 *  }, false);      
 * 
 * current events:
 * 
 * 1) pushRegistrationSucceeded
 * 2) pushRegistrationFailed
 * 3) pushNotification
 * 4) handleButtonAction
 * 
 * @param  {String} eventName - the name of the event
 * @param  {Object} eventData - the object data associated with the event
 */
DonkyPlugin.prototype.callback = function(eventName, eventData){
                
    if(window.donkyCore){
        donkyCore.publishLocalEvent({ type: eventName, data: eventData });
    }                   
}

/**
 * Method to query platform related info
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 */
DonkyPlugin.prototype.getPlatformInfo = function(successCallback, errorCallback){
    cordova.exec(successCallback, errorCallback, "donky", "getPlatformInfo",[]);        
}

/**
 * Method to register for push notifications
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {Object[]} buttonSets - buttonset details from donky config
 */
DonkyPlugin.prototype.registerForPush = function(successCallback, errorCallback, buttonSets){
    cordova.exec(successCallback, errorCallback, "donky", "registerForPush",[JSON.stringify(buttonSets)]);        
}

/**
 * Method to allow integrator to explicitly set the application badge count
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {Nimber} count - the count to set to
 */
DonkyPlugin.prototype.setBadgeCount = function(successCallback, errorCallback, count){
    cordova.exec(successCallback, errorCallback, "donky", "setBadgeCount", [count]);        
}


module.exports = new DonkyPlugin();



