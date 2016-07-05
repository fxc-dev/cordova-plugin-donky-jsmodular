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

    function fireDonkyPluginReadyEvent(){
        window.DonkyPluginReady = true;

        setTimeout(function(){
            var event = new Event('DonkyPluginReady');
            document.dispatchEvent(event);        
        }, 0);
    }

    function pluginLog(message){
        if(window.donkyCore){
            donkyCore.donkyLogging.infoLog(message);
        }
        console.log(message);
    }

    function pluginError(message){
        if(window.donkyCore){
            donkyCore.donkyLogging.infoLog(message);
        }
        console.error(message);
    }

    function pluginWarn(message){
        if(window.donkyCore){
            donkyCore.donkyLogging.infoLog(message);
        }
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
            "operatingSystem": donkyCore.donkyAccount._getOperatingSystem(),
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
            "operatingSystem": donkyCore.donkyAccount._getOperatingSystem(),
            "sessionTrigger" : (self.applicationStateOnPush !== undefined && self.applicationStateOnPush !== AppStates.active) ? "Notification" : "None"
        };

        pluginLog("queueAppLaunch: " + JSON.stringify(launchClientNotification));

        donkyCore.queueClientNotifications(launchClientNotification);
    }         

    /**
     * There are two  properties in the bundle  to use to map to applicationState ...
     * 1) result.additionalData.isInForeground ("Yes" | "No") (is app in BG or FG)
     * 2) result.additionalData.isActive ("Yes" | "No") - (is the app even running)

        var AppStates = {
            active: 0,
            inactive: 1,
            background: 2       
        }; 
     */ 
    function mapAndroidAppState(bundle){

        var applicationState = AppStates.inactive;

        if(bundle.isActive === "Yes"){

            if(bundle.isInForeground === "Yes"){
                applicationState = AppStates.active;
            }else{
                applicationState = AppStates.background;
            }
        }

        return applicationState;
    }

    /**
     *
     */                
    function procesGCMPushMessage(result){

        var applicationState = mapAndroidAppState(result.additionalData);
        
        if(self.applicationStateOnPush === undefined){
            self.applicationStateOnPush = applicationState;                    
        }

        var notificationId = result.additionalData.notificationId;

        if(!donkyCore.findNotificationInRecentCache(notificationId)){
            // need to synthesise a server notification so we can call _processServerNotifications() if neessary ...                    
            var notification = {
                id: notificationId,
                type: result.additionalData.notificationType,
                data: result.additionalData.payload,
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

                if( result.additionalData.notificationType === "SimplePushMessage" && applicationState !== AppStates.active){
                    donkyCore.addNotificationToRecentCache(notification.id);
                    // TODO: need to TEST this ...
                    donkyCore._queueAcknowledgement(notification, "Delivered");
                }
                else{
                    donkyCore._processServerNotifications([notification]);    
                }                                     
            }
        }                              
    }     

    /**
     * 
     */
    function procesAPNSPushMessage(notificationId, applicationState){
        
        if(self.applicationStateOnPush === undefined){
            self.applicationStateOnPush = applicationState;                    
        }

        donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){

            if(notification){

                if(!donkyCore.findNotificationInRecentCache(notificationId)){
                    // need to handle the case when a push message has been received when the app was not active (and noty display it again)                                                                              
                    if( notification.type === "SimplePushMessage" && applicationState !== AppStates.active){
                        donkyCore.addNotificationToRecentCache(notification.id);
                        // TODO: need to TEST this ...
                        donkyCore._queueAcknowledgement(notification, "Delivered");                            
                    }else{
                        donkyCore._processServerNotifications([notification]);    
                    }
                    
                    if(notification.type === "SimplePushMessage" || notification.type === "RichMessage"){
                        syncBadgeCount();
                    }                                                                                          
                }
            }                                                
        });        
    }

    /**
     * 
     */
    function handleButtonAction(notificationId, buttonText, clicked, addToRecent){
        // If SDK not initialised, we can't make rest calls (even if we have a token)  should I change this ?            
        if(donkyCore.isInitialised()){

            if(addToRecent){
                donkyCore.addNotificationToRecentCache(notificationId);
            }
            
                                
            donkyCore.donkyNetwork.getServerNotification(notificationId, function(notification){
                if(notification){
                    
                    switch(notification.type){
                        case "SimplePushMessage":
                            if(window.donkyPushLogic){

                                notification.displayed = clicked;
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
            
        }else{
            pluginError("handleButtonAction() called when not initialised");
        }
    }


    /**
     * 
     */
    function subscribeToDonkyEvents(){


        document.addEventListener("pause", function(){
            // queue an AppSession 
            queueAppSession();

            if(donkyCore.donkyNetwork._usingSignalR()){
                donkyCore.donkyNetwork._stopSignalR(function(){
                    pluginLog("signalR stopped");
                });
            }

        }, false);
                
        /**
        * Need to determine whether app was foregrounded / launched due to a push or just opened.
        * Foreground event comes in before push event (which contains app state) - hence the setTimeout() usage 
        */            
        document.addEventListener("resume", function(){
            self.launchTimeUtc = new Date().toISOString();

            if(donkyCore.donkyNetwork._usingSignalR()){
                donkyCore.donkyNetwork._startSignalR(function(){
                    pluginLog("signalR started");
                });
            }

            setTimeout(function(){
                queueAppLaunch();
            },1000);
        }, false);

    
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
         * App stae would have been UIApplicationStateInactive
         */
        donkyCore.subscribeToLocalEvent("handleButtonAction", function (event) {
            pluginLog("handleButtonAction", JSON.stringify(event.data, null, 4));
            

            self.applicationStateOnPush = event.data.state;
            var buttonText = event.data.identifier;
            var notificationId = event.data.userInfo.notificationId;
            var clicked = event.data.clicked;

            handleButtonAction(notificationId, buttonText, clicked, true);
            
        });     
    }

    /**
     * 
     */
    function sendPushConfiguration(deviceToken){
        var pushConfig = {
            registrationId : deviceToken,
            // will be undefined on Android
            bundleId : self.bundleId
        }

        if(window.donkyCore){
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
            pluginError("window.donkyCore not set in donkyPlugin::sendPushConfiguration");
        }
    }

    /**
     * 
     */
    function doPushRegistation(){

        // Assumption is that Donky is initialised now as we need the button sets
        cordova.exec(function(result){
            pluginLog("registerForPush success callback: " + JSON.stringify(result));

            // success callback re-used for push notifications and returning device token                                                 
            if(result.deviceToken){                            
                sendPushConfiguration(result.deviceToken);                            
            }else{
                
                switch( self.platform ){
                    case "iOS":
                        procesAPNSPushMessage(result.userInfo.notificationId, result.applicationState);
                    break;
                    
                    /**
                     * We have the entire payload on Android so no need to get the notification 
                     * Also if a button has been clicked, we have that info too. 
                     * We should have all we need to call setSimplePushResult() 
                     */                                
                    case "Android":
                        procesGCMPushMessage(result);
                    break;
                } 
            }
                                                            
        }, function(error){
            pluginLog("registerForPush failed" + JSON.stringify(error));
        },
        "donky", "registerForPush",
        self.platform === "iOS" ? [JSON.stringify(donkyCore.getiOSButtonCategories())] : []);

    }

    /**
     * 
     *
    function processDismissedNotifications(notifications){
        if(notifications && notifications !== ""){

            var existing = JSON.parse(localStorage.getItem("dismissedNotificationIds"));

            var additional = notifications.split(",").filter(function(el) {return el.length !== 0}); 

            var dismissed = existing !==null ? existing.concat(additional) : additional;

            if(window.donkyCore){
                donkyCore._each(dismissed, function(index, notificationId){
                    donkyCore.addNotificationToRecentCache(notificationId);
                });
                localStorage.removeItem("dismissedNotificationIds");
            }else{
                pluginError("processDismissedNotifications - no donkyCore");
                // set them for next time ?
                localStorage.setItem("dismissedNotificationIds", JSON.stringify(dismissed));
            }
        }
    }*/

    /**
     * These are button clicks that occurred when the app was inactive 
     * Process, the data, store it and add the notifications to the recent cache so we don't 
     * inadvertantly get them again.  
     */
    function processColdstartNotifications(notifications){

        pluginLog("processColdstartNotifications: " + notifications);

        var existing = JSON.parse(localStorage.getItem("coldstartNotifications"));

        var additional = [];

        if(notifications && notifications !== ""){
            donkyCore._each(notifications.split("|").filter(function(el) {return el.length !== 0}), function(index, val){
                additional.push(JSON.parse(val));
            });

        }

        var coldStartActions = existing !==null ? existing.concat(additional) : additional;

        if(coldStartActions.length > 0){

            pluginLog("coldStartActions: " + JSON.stringify(coldStartActions));

            // How do we know if this was an influences app open ? (i.e a recent notification not some old one
            // We can look at the notification.clicked timestamp and if < say 1 minute we can say this was what triggered the open
            // check the age in the each loop below...
            var now = new Date();

            if(window.donkyCore){

                donkyCore._each(coldStartActions, function(index, notification){
                    // handleButtonAction(notification.notificationId, notification.label);
                    // This should prevent the notification getting reprocessed
                    donkyCore.addNotificationToRecentCache(notification.notificationId);

                    var dif = (now - new Date(notification.clicked)) / 1000;

                    if(dif < 10){
                        self.applicationStateOnPush = AppStates.inactive;
                        pluginLog("notification.clicked caused an influenced open: " + dif);
                    }else{
                        pluginLog("notification.clicked didnt cause an influenced open: " + dif);
                    }

                });
                // localStorage.removeItem("coldstartNotifications");
            }
            
            // These need to be picked up when we see the donkyInitialised event 
            localStorage.setItem("coldstartNotifications", JSON.stringify(coldStartActions));
            
        }

    }

    /**
     * 
     */
    function queueColdstartAnalytics(){

        var notifications = JSON.parse(localStorage.getItem("coldstartNotifications"));

        if(notifications){

            donkyCore._each(notifications, function(index, notification){
                handleButtonAction(notification.notificationId, notification.label, notification.clicked, false);
            });

            localStorage.removeItem("coldstartNotifications");
        }
    }

    /**
     * Operations to perform when donky SDK initialised event occurs ...
     */
    function onDonkyInitialised(){

        queueAppLaunch();

        doPushRegistation();

        queueColdstartAnalytics();

    }


    /**
     * 
     */    
    channel.onCordovaReady.subscribe(function() {
        pluginLog("onCordovaReady");
        
        cordova.exec(function(info){

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

            // processDismissedNotifications(info.dismissedNotifications);
            
            processColdstartNotifications(info.coldstartNotifications);

            // Set this so it can safely be picked up in donkyAccount on registration 
            // NOTE: this only gets looked at in donkyCore.donkyAccount._register
            window.donkyDeviceOverrides = {
                operatingSystem: self.platform,
                deviceId: self.deviceId
            };

            // These need to be available ... (integrators responsibility to load)        
            // TODO: race condition spotted using raw cordova when referring to js files on a CDN on first install
            // window.donkyCore was not set during the first installateion
            // net effect of this is the device gets registered as "Web"

            if(window.donkyCore){

                // These need to be set BEFORE integrator calls  calls donkyCore.initialise() - hence it is occurring in  onCordovaReady callback
                // >>>
                // shall I sniff donkyDeviceOverrides in initialise ?
                // or shall I fire an event pluginReady ?
                // <<<
                donkyCore.donkyAccount._setOperatingSystem(self.platform);
                donkyCore.donkyAccount._setDeviceId(self.deviceId);

                subscribeToDonkyEvents();

                if(window.DonkyInitialised === true){                    
                    pluginLog("Missed the DonkyInitialised event ...");
                    onDonkyInitialised();
                }else{
                    // This event is ALWAYS published on succesful initialisation - hook into it and run our analysis ...
                    donkyCore.subscribeToLocalEvent("DonkyInitialised", function(event) {
                        pluginLog("DonkyInitialised event received in DonkyPlugin()");                           
                        onDonkyInitialised();
                    });
                }
                
            }else{
                pluginWarn("window.donkyCore not set in donkyPlugin, will poll for window.DonkyInitialised");

                var interval = 
                setInterval(function(){

                    if(window.DonkyInitialised === true){
                        clearInterval(interval);
                        pluginLog("DonkyInitialised set to true ...");
                        subscribeToDonkyEvents();
                        onDonkyInitialised();
                    }else{
                        pluginLog("polling for DonkyInitialised ...");
                    }
                }, 500);
            }

            channel.onCordovaInfoReady.fire();
            fireDonkyPluginReadyEvent();            

        },function(e){

            self.available = false;
            pluginError("[ERROR] Error initializing donkyPlugin: " + e);            
        },
        "donky", "initialise", []);
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
 * 3) handleButtonAction
 * 
 * @param  {String} eventName - the name of the event
 * @param  {Object} eventData - the object data associated with the event
 */
DonkyPlugin.prototype.callback = function(eventName, eventData){                
    if(window.donkyCore){        
        donkyCore.publishLocalEvent({ type: eventName, data: eventData });            
    }else{
        pluginError("callback(" + eventName + ") : window.donkyCore not set" );
    }                   
}

/**
 * Method to initialise donky plugin
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {String} options
 */
DonkyPlugin.prototype.initialise = function(successCallback, errorCallback, options){
    cordova.exec(successCallback, errorCallback, "donky", "initialise", [options]);        
}



/**
 * Method to register for push notifications - NOTE: this is called internallo on donkyReady event 
 * TODO: should this even be exposed ? 
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {String} options - stringified buttonset details from donky config if ios
 */
/*
DonkyPlugin.prototype.registerForPush = function(successCallback, errorCallback, options){
    cordova.exec(successCallback, errorCallback, "donky", "registerForPush",[options]);        
}*/



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
 * @param {String} options - JSon object ontaining the options
 */

DonkyPlugin.prototype.setPushOptions = function(successCallback, errorCallback, options){
    cordova.exec(successCallback, errorCallback, "donky", "setPushOptions",[options]);        
}



/**
 * Method to register for push notifications
 * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
 * @param {Callback} errorCallback - callback to call if method failed with the error messag
 * @param {String} arg1 - stringified buttonset details from donky config if ios or senderId if Android
 */
/*
DonkyPlugin.prototype.unregisterForPush = function(successCallback, errorCallback){
    cordova.exec(successCallback, errorCallback, "donky", "unregisterForPush");        
}*/


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
