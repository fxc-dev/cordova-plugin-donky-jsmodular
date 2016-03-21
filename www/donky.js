
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
                
            // These need to be available ... (integrators responsibility to load)        
            if(window.donkyCore && window.donkyPushLogic){
                
                try{
                    donkyCore.donkyAccount.setOperatingSystem(self.platform);
                }catch(e){
                    utils.alert("[ERROR] Error calling donkyCore.donkyAccount.setOperatingSystem(" + self.platform + ") : " + e);                    
                }

                /**
                 * A new push notification has arrived
                 *
                 */
                document.addEventListener("pushNotification", function (e) {
                    console.log("pushNotification: " + JSON.stringify(e.detail, null, 4));
                    var notificationId = e.detail.data.userInfo.notificationId;
                    
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){
                        if(notification){
                            donkyPushLogic.processPushMessage(notification);                            
                        }
                    });
                });                            


                /**
                 * A button has been clicked (iOS)
                 * TODO: User is done with this msg so make sure it doesn't get displayed a second time ...
                 * !!! POTENTIAL RACE CONDITION CENTRAL HERE !!!  
                 */
                document.addEventListener("handleButtonAction", function (e) {
                    console.log("handleButtonAction", JSON.stringify(e.detail, null, 4));
                    
                    // If SDK not initialised, we can't make rest calls (even if we have a token)  should I change this ?
                    
                    var buttonText = e.detail.data.identifier;
                    var notificationId = e.detail.data.userInfo.notificationId;
                    
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){
                        if(notification){
                            
                            // this will mark as received and fire a local event so not sure I want to add in like this ...
                            // flag to not publish a local event !!!                            
                            donkyPushLogic.processPushMessage(notification, false);

                            // this will delete the message                            
                            donkyPushLogic.setSimplePushResult(notificationId, buttonText);                                                        
                        }
                    });
                    
                });                            
                
                /**
                 * We have a device token now which needs to be sent to donky
                 */
                document.addEventListener("pushRegistrationSucceeded", function (e) {
                    console.log("pushRegistrationSucceeded", JSON.stringify(e.detail.deviceToken, null, 4));

                    var pushConfigurationRequest = {
                        registrationId: e.detail.data.deviceToken,
                        bundleId: window.cordova.plugins.donky.bundleId
                    };

                    console.log("pushConfigurationRequest", JSON.stringify(pushConfigurationRequest, null, 4));

                    donkyCore.donkyAccount.sendPushConfiguration(pushConfigurationRequest, function(result){
                        
                        console.log("sendPushConfiguration result: ", JSON.stringify(result, null, 4));
                    });
                                                                                                                           
                }, false);

                document.addEventListener("pushRegistrationFailed", function (e) {
                    console.error("pushRegistrationFailed", JSON.stringify(e.detail.data.error, null, 4));                        
                }, false);
                
                
                // This event is ALWAYS published on succesful initialisation - hook into it and run our analysis ...
                donkyCore.subscribeToLocalEvent("DonkyInitialised", function(event) {

                    console.log("DonkyInitialised event received in DonkyPlugin()");                    
                    
                    var buttonSets = donkyCore.getiOSButtonCategories();                                                            

                    self.registerForPush(function(result){
                        console.log("registerForPush succeeded");
                    }, function(error){
                        consloe.log("registerForPush failed");
                    },
                    buttonSets);
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
        
    var event = new CustomEvent(eventName, {
        detail: {
            data: eventData
        }
    });

    document.dispatchEvent(event);    
    
    // TODO: Should I just use this ?
    /*
    if(window.donkyCore){
        donkyCore.publishLocalEvent({ type: eventName, data: eventData });
    }*/   
                
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
 * Method to set the badge count
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {Nimber} count - the count to set to
 */
DonkyPlugin.prototype.setBadgeCount = function(successCallback, errorCallback, count){
    cordova.exec(successCallback, errorCallback, "donky", "setBadgeCount", [count]);        
}


module.exports = new DonkyPlugin();



