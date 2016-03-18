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

            self.deviceId = info.deviceId; 
            self.bundleId = info.bundleId; 
            self.platform = info.platform; 
            self.systemVersion = info.systemVersion; 
            
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

module.exports = new DonkyPlugin();

