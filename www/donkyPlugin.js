var channel = require('cordova/channel'),
    utils = require('cordova/utils');

channel.createSticky('onCordovaInfoReady');
// Tell cordova channel to wait on the CordovaInfoReady event
channel.waitForInitialization('onCordovaInfoReady');

/**
 * DonkyPlugin constructor
 */
function DonkyPlugin(){

    var AppStates = {
        active: 0,
        inactive: 1,
        background: 2       
    };

    function pluginLog(message){
        console.log(message);
    }

    function pluginError(message){
        console.error(message);
    }

    function pluginWarn(message){
        console.warn(message);
    }

    var self = this;

    // TODO: need to ensure this is called if an interactive  push is received and the dismiss button is clicked (for iOS)  
    function syncBadgeCount(){
        // set badge count 
        
        var badgeCount = 0;

        if(window.donkyPushLogic){
            var pushCount = donkyPushLogic.getMessageCount();
            pluginLog("pushCount: " + pushCount ); 
            badgeCount += pushCount;                                        
        }                                
        
        if(window.donkyRichLogic){
            var unreadRichCount = donkyRichLogic.getMessageCount().unreadRichMessageCount
            pluginLog("unreadRichCount: " + unreadRichCount ); 
            badgeCount += unreadRichCount;                                        
        }                                
                                
        if(window.donkyMessagingCommon){
            pluginLog("setBadgeCount(" + badgeCount + ")");
            donkyMessagingCommon.setBadgeCount(badgeCount, true);                            
        }
        
        self.setBadgeCount(function(){},function(){},badgeCount);        
    }

    /**
     * FUnction to quere an AppSession notification
     */
    function queueAppSession(){

        var sessionClientNotification = {
            Type: "AppSession",
            "startTimeUtc": self.launchTimeUtc,
            "endTimeUtc": new Date().toISOString(),
            "operatingSystem": donkyCore.donkyAccount.getOperatingSystem(),
            "sessionTrigger" : (self.applicationStateOnPush !== undefined && self.applicationStateOnPush !== AppStates.active) ? "Notification" : "None"
        };
        
        self.applicationStateOnPush = undefined;

        pluginLog("queueAppSession: " + JSON.stringify(sessionClientNotification));
        
        donkyCore.queueClientNotifications(sessionClientNotification);                    
    }
                
    /**
     * FUnction to quere an AppLaunch notification 
     */
    function queueAppLaunch(){
                                                
        var launchClientNotification = {
            Type: "AppLaunch",
            "launchTimeUtc": self.launchTimeUtc,
            "operatingSystem": donkyCore.donkyAccount.getOperatingSystem(),
            "sessionTrigger" : (self.applicationStateOnPush !== undefined && self.applicationStateOnPush !== AppStates.active) ? "Notification" : "None"
        };

        pluginLog("queueAppLaunch: " + JSON.stringify(launchClientNotification));

        donkyCore.queueClientNotifications(launchClientNotification);
    }         

    /**
     *
     */                
    function procesGCMPushMessage(result){
                                    
        var notificationId = result.additionalData.notificationId;
                                                
        // need to synthesise a server notification so we can call _processServerNotifications() if neessary ...                    
        var notification = {
            id: notificationId,
            type: result.additionalData.notificationType,
            data: result.additionalData.payload,
            // TODO: get from GCM payload
            createdOn: result.additionalData.notificationCreatedOn ? result.additionalData.notificationCreatedOn : new Date().toISOString()
        };
        
        // Is this a button click                                        
        if(result.additionalData.ButtonClicked){
            
            pluginLog("procesGCMPushMessage: ButtonClicked=" + result.additionalData.ButtonClicked);
            
            donkyCore.addNotificationToRecentCache(notificationId);
            // used to calculate stats
            notification.displayed = new Date().valueOf();
            // this will mark as received and fire a local event so not sure I want to add in like this ...
            // flag to not publish a local event !!!                            

            donkyPushLogic.processPushMessage(notification, false);

            donkyPushLogic.setSimplePushResult(notification.id, result.additionalData.ButtonClicked);
            
        }else{
            // TODO: need to apply more logic than this ...
            donkyCore._processServerNotifications([notification]);                        
        }
    }     
    
    channel.onCordovaReady.subscribe(function() {
        pluginLog("onCordovaReady");
        
        self.getPlatformInfo(function(info){

            pluginLog("getPlatformInfo() succeeed: " + JSON.stringify(info));

            self.available = true;

            self.manufacturer = info.manufacturer;
            self.model = info.model;
            self.platform = info.platform;
            self.version = info.version;
            self.cordova = info.cordova;
            self.bundleId = info.bundleId;
            self.deviceId = info.deviceId;
            self.launchTimeUtc = info.launchTimeUtc;
                
            // These need to be available ... (integrators responsibility to load)        
            if(window.donkyCore){
                
                try{
                    // These need to be set BEFORE integrator calls  calls donkyCore.initialise() - hence it is occurring in  onCordovaReady callback
                    donkyCore.donkyAccount.setOperatingSystem(self.platform);
                    donkyCore.donkyAccount._setDeviceId(self.deviceId);
                }catch(e){
                    utils.alert("[ERROR] Error initialising donky: " + e);                    
                }

                /**
                 *  new push notification has arrived (iOS)
                 */
                donkyCore.subscribeToLocalEvent("pushNotification", function (event) {
                    pluginLog("pushNotification: " + JSON.stringify(event.data, null, 4));
                    var notificationId = event.data.notificationId;
                    
                    if(self.applicationStateOnPush === undefined){
                        self.applicationStateOnPush = event.data.applicationState;                    
                    }
                                                                                                   
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){

                        if(notification){                            
                            // Haver we already processed this ? doubt it ....
                            if(!donkyCore.findNotificationInRecentCache(notification.id)){
                                
                                // need to handle the case when a push message has been received when the app was not active (and noty display it again)                                                                              
                                if( notification.type === "SimplePushMessage" && event.data.applicationState !== AppStates.active){
                                    donkyCore.addNotificationToRecentCache(notification.id);
                                }else{
                                    donkyCore._processServerNotifications([notification]);    
                                }
                                
                                if(notification.type === "SimplePushMessage" || notification.type === "RichMessage"){
                                    syncBadgeCount();
                                }                                                                                          
                            }                            
                        }                                                
                    });
                });      
                
                /**
                 * 
                 */
                donkyCore.subscribeToLocalEvent("PushMessageDeleted", function (event) {
                    syncBadgeCount();
                });                
                
                /**
                 * 
                 */
                donkyCore.subscribeToLocalEvent("RichMessageRead", function (event) {
                    syncBadgeCount();
                });                

                /**
                 * A button has been clicked (iOS)
                 * TODO: Honour the action - URL / Deep Link
                 */
                donkyCore.subscribeToLocalEvent("handleButtonAction", function (event) {
                    pluginLog("handleButtonAction", JSON.stringify(event.data, null, 4));
                    
                    // If SDK not initialised, we can't make rest calls (even if we have a token)  should I change this ?
                    
                    var buttonText = event.data.identifier;
                    var notificationId = event.data.userInfo.notificationId;
                    donkyCore.addNotificationToRecentCache(notificationId);
                                        
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){
                        if(notification){
                            
                            switch(notification.type){
                                case "SimplePushMessage":
                                    if(window.donkyPushLogic){

                                        notification.displayed = new Date().valueOf();
                                        // this will mark as received and fire a local event so not sure I want to add in like this ...
                                        // flag to not publish a local event !!!                            
                                        donkyPushLogic.processPushMessage(notification, false);
                                        // this will delete the message                                                    
                                        donkyPushLogic.setSimplePushResult(notification.id, buttonText);
                                    }                                                        
                                break;
                            }                                                       
                        }
                    });
                    
                });                            



                function doPushRegistation(){

                    // Assumption is that Donky is initialised now as we need the button sets
                    self.registerForPush(function(result){
                        pluginLog("registerForPush success callback: " + JSON.stringify(result));

                        // success callback re-used for push notifications and returning device token
                                                 
                        if(result.deviceToken){
                            
                            var pushConfig = {
                                registrationId : result.deviceToken,
                                // will be undefined on Android
                                bundleId : self.bundleId
                            }
                                                    
                            // always query and store this token
                            donkyCore.donkyData.set("pushConfig", pushConfig); 
                            
                            // ONLY do this if enabled or null
                            // integrator can control this with donkyCore.donkyAccount.enablePush()
                            if(donkyCore.donkyAccount.isPushEnabled() !== false){
                                
                                pluginLog("sending push Configuration: " + JSON.stringify(pushConfig, null, 4));

                                donkyCore.donkyAccount.sendPushConfiguration(pushConfig, function(result){            
                                    pluginLog("sendPushConfiguration result: " + JSON.stringify(result, null, 4));
                                });                                    
                            }
                            
                        }else{
                            
                            var notification = {}; 
                            
                            switch( self.platform ){
                                case "iOS":
                                {
                                    notification.notificationId = result.userInfo.notificationId;
                                    notification.applicationState = result.applicationState;
                                    // TODO: publish event or just call method ?
                                    donkyCore.publishLocalEvent({ type: "pushNotification", data: notification });
                                    
                                }
                                break;
                                
                                /**
                                 * We have the entire payload on Android so no need to get the notification 
                                 * Also if a button has been clicked, we have that info too. 
                                 * We should have all we need to call setSimplePushResult() 
                                 */                                
                                case "Android":
                                {
                                    procesGCMPushMessage(result);
                                    //notification.notificationId = result.additionalData.notificationId;
                                    // TODO: implement this for android ...
                                    //notification.applicationState = AppStates.active;
                                }
                                break;
                            } 
                        }
                        
                                                
                    }, function(error){
                        pluginLog("registerForPush failed" + JSON.stringify(error));
                    },
                    self.platform === "iOS" ? JSON.stringify(donkyCore.getiOSButtonCategories()) : undefined);

                }
                
                                                          
                pluginLog("subscribing to DonkyInitialised");
                // This event is ALWAYS published on succesful initialisation - hook into it and run our analysis ...
                donkyCore.subscribeToLocalEvent("DonkyInitialised", function(event) {

                    pluginLog("DonkyInitialised event received in DonkyPlugin()");   
                    
                    queueAppLaunch();
                                        
                    setTimeout(function(){
                        doPushRegistation();
                    },10);
                    
                });
                
               /**
                *
                */            
                donkyCore.subscribeToLocalEvent("AppBackgrounded", function(event) {
                    // queue an AppSession 
                    queueAppSession();
                });        
                
               /**
                * Need to determine whether app was foregrounded / launched due to a push or just opened.
                * Foreground event comes in before push event (which contains app state) 
                */            
                donkyCore.subscribeToLocalEvent("AppForegrounded", function(event) {
                    self.launchTimeUtc = new Date().toISOString();

                    setTimeout(function(){
                        queueAppLaunch();
                    },1000);
                                        
                });        
            }else{
                pluginError("window.donkyCore not set in donkyPlugin");
            }


            pluginLog("==> channel.onCordovaInfoReady.fire();");

            channel.onCordovaInfoReady.fire();

            pluginLog("<== channel.onCordovaInfoReady.fire();");

        },function(e){
            self.available = false;
            pluginError("[ERROR] Error initializing donkyPlugin: " + e);            
        });
    });
}


/**
 * Internal callback function for iOS native code to call to trigger an event for the client.
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
 * Method to query platform related info - intenal (executed on onCordovaReady)
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
 * @param {String} arg1 - stringified buttonset details from donky config if ios or senderId if Android
 */
DonkyPlugin.prototype.registerForPush = function(successCallback, errorCallback, arg1){
    cordova.exec(successCallback, errorCallback, "donky", "registerForPush",[arg1]);        
}



/**
 * Method to set push options 
 * 
 * 
            // TODO: don't ned these callbacks ...
            window.cordova.plugins.donkyPlugin.setPushOptions(function(){}, function(){}, {
                ios: {
                    
                },
                android:{
                    environment: "dev-",
                    vibrate: true,
                    iconId: 0,
                    color: 0xff0000FF,
                    senderId: "793570521924"                 
                }
            });
 * 
 * 
 * 
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {String} arg1 - JSon object ontaining the options
 */
DonkyPlugin.prototype.setPushOptions = function(successCallback, errorCallback, arg1){
    cordova.exec(successCallback, errorCallback, "donky", "setPushOptions",[arg1]);        
}



/**
 * Method to register for push notifications
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {String} arg1 - stringified buttonset details from donky config if ios or senderId if Android
 */
DonkyPlugin.prototype.unregisterForPush = function(successCallback, errorCallback){
    cordova.exec(successCallback, errorCallback, "donky", "unregisterForPush");        
}


/**
 * Method to allow integrator to explicitly set the application badge count
 * @param {Callback} successCallback - callback to call if method was succsful
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {Number} count - the count to set to
 */
DonkyPlugin.prototype.setBadgeCount = function(successCallback, errorCallback, count){
    cordova.exec(successCallback, errorCallback, "donky", "setBadgeCount", [count]);        
}

/**
 * Method to allow integrator to open a deep link
 * @param {Callback} successCallback - callback to call if method was succsful
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {String} link - the link to open
 */
DonkyPlugin.prototype.openDeepLink = function(successCallback, errorCallback, link){
    cordova.exec(successCallback, errorCallback, "donky", "openDeepLink", [link]);        
}


DonkyPlugin.prototype.log = function(message){
    console.log(message);
}



module.exports = new DonkyPlugin();
