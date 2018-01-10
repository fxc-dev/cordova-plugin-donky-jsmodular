/**
 * DonkyPlugin constructor
 */
function DonkyPlugin() {

    // NOTE: ensure this remains in sync with the value in package.json
    var pluginVersion = "1.0.9";

    var AppStates = {
        active: 0,
        inactive: 1,
        background: 2
    };

    function pluginLog(message) {
        if (window.donkyCore) {
            donkyCore.donkyLogging.infoLog(message);
        }
        console.log(message);
    }

    function pluginError(message) {
        if (window.donkyCore) {
            donkyCore.donkyLogging.infoLog(message);
        }
        console.error(message);
    }

    function pluginWarn(message) {
        if (window.donkyCore) {
            donkyCore.donkyLogging.infoLog(message);
        }
        console.warn(message);
    }

    var self = this;

    function syncBadgeCount() {

        if (self.platform === "iOS") {

            var badgeCount = 0;

            if (window.donkyPushLogic) {
                var pushCount = donkyPushLogic.getMessageCount();
                pluginLog("pushCount: " + pushCount);
                badgeCount += pushCount;
            }

            if (window.donkyRichLogic) {
                var unreadRichCount = donkyRichLogic.getMessageCount().unreadRichMessageCount;
                pluginLog("unreadRichCount: " + unreadRichCount);
                badgeCount += unreadRichCount;
            }

            if (window.donkyMessagingCommon) {
                pluginLog("setBadgeCount(" + badgeCount + ")");
                donkyMessagingCommon.setBadgeCount(badgeCount, true);
            }

            self.setBadgeCount(function () { }, function () { }, badgeCount);
        }

    }

    /**
     * FUnction to quere an AppSession notification
     */
    function queueAppSession() {

        var sessionClientNotification = {
            Type: "AppSession",
            "startTimeUtc": self.launchTimeUtc,
            "endTimeUtc": new Date().toISOString(),
            "operatingSystem": donkyCore.donkyAccount._getOperatingSystem(),
            "sessionTrigger": (self.applicationStateOnPush !== undefined && self.applicationStateOnPush !== AppStates.active) ? "Notification" : "None"
        };

        self.applicationStateOnPush = undefined;

        pluginLog("queueAppSession: " + JSON.stringify(sessionClientNotification));

        donkyCore.queueClientNotifications(sessionClientNotification);
    }

    /**
     * Function to queue an AppLaunch notification 
     */
    function queueAppLaunch() {

        // To correctly identify whether this was an influenced launch, we need to look at the applicationStateOnPush which is getting set when the notification arrives
        // need to defer this logic to so this is called AFTER the push message has been processed

        setTimeout(function () {

            var launchClientNotification = {
                Type: "AppLaunch",
                "launchTimeUtc": self.launchTimeUtc,
                "operatingSystem": donkyCore.donkyAccount._getOperatingSystem(),
                "sessionTrigger": (self.applicationStateOnPush !== undefined && self.applicationStateOnPush !== AppStates.active) ? "Notification" : "None"
            };

            pluginLog("queueAppLaunch: " + JSON.stringify(launchClientNotification));

            donkyCore.queueClientNotifications(launchClientNotification);

            donkyCore.donkyNetwork.synchronise(function (result) { });
        }, 1000);

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
    function mapAndroidAppState(bundle) {

        var applicationState = AppStates.inactive;

        if (bundle.isActive === "Yes") {

            if (bundle.isInForeground === "Yes") {
                applicationState = AppStates.active;
            } else {
                applicationState = AppStates.background;
            }
        }

        return applicationState;
    }

    /**
     *
     */
    function processGCMPushMessage(result) {

        pluginLog("processGCMPushMessage: " + JSON.stringify(result));

        var notificationId = result.additionalData.notificationId;

        if (notificationId !== undefined) {

            var applicationState = mapAndroidAppState(result.additionalData);

            if (self.applicationStateOnPush === undefined) {
                self.applicationStateOnPush = applicationState;
            }

            if (!donkyCore.findNotificationInRecentCache(notificationId)) {

                if (result.additionalData.type !== "NOTIFICATIONPENDING") {
                    // need to synthesise a server notification so we can call _processServerNotifications() if neessary ...                    
                    var notification = {
                        id: notificationId,
                        type: result.additionalData.notificationType,
                        data: result.additionalData.payload,
                        createdOn: result.additionalData.notificationCreatedOn ? result.additionalData.notificationCreatedOn : new Date().toISOString()
                    };

                    // Is this a button click                                        
                    if (result.additionalData.ButtonClicked) {

                        pluginLog("processGCMPushMessage: ButtonClicked=" + result.additionalData.ButtonClicked);

                        donkyCore.addNotificationToRecentCache(notificationId);
                        // used to calculate stats
                        notification.displayed = new Date().valueOf();
                        // this will mark as received and fire a local event so not sure I want to add in like this ...
                        // flag to not publish a local event !!!                            

                        donkyPushLogic.processPushMessage(notification, false);

                        donkyPushLogic.setSimplePushResult(notification.id, result.additionalData.ButtonClicked);

                    } else {

                        if (result.additionalData.notificationType === "SimplePushMessage" && applicationState !== AppStates.active) {
                            donkyCore.addNotificationToRecentCache(notification.id);
                            donkyCore._queueAcknowledgement(notification, "Delivered");
                        }
                        else {
                            donkyCore._processServerNotifications([notification]);
                        }
                    }
                } else {

                    // some messages not currently coming through s direct delivery so need to be got 
                    donkyCore.donkyNetwork.getServerNotification(notificationId, function (notification) {
                        donkyCore._processServerNotifications([notification]);
                    });
                }
            }
        }
    }

    /**
     * 
     */
    function processAPNSPushMessage(userInfo, applicationState) {

        var notificationId = userInfo.notificationId;

        if (self.applicationStateOnPush === undefined) {
            self.applicationStateOnPush = applicationState;
        }

        donkyCore.donkyNetwork.getServerNotification(notificationId, function (notification) {

            if (notification) {

                if (!donkyCore.findNotificationInRecentCache(notificationId)) {
                    // need to handle the case when a push message has been received when the app was not active (and noty display it again)                                                                              
                    if (notification.type === "SimplePushMessage" && applicationState !== AppStates.active) {
                        donkyCore.addNotificationToRecentCache(notification.id);
                        // TODO: need to TEST this ...
                        // Not sure I ned to do this as it will be acknowledged anyway ...
                        donkyCore._queueAcknowledgement(notification, "Delivered");
                        // TODO: need to see if this was a OneButton (need to change messag sig as only got the id atm)
                        // can just call handle button action with  

                        if (userInfo.inttype === "OneButton") {
                            handleButtonAction(notificationId, userInfo.lbl1, new Date().toISOString(), false);
                            if (userInfo.act1 === "DeepLink") {
                                self.openDeepLink(function () { }, function () { }, userInfo.link1);
                            }
                        }

                    } else {
                        donkyCore._processServerNotifications([notification]);
                    }

                    if (notification.type === "SimplePushMessage" || notification.type === "RichMessage") {
                        syncBadgeCount();
                    }
                }
            }
        });
    }

    /**
     * 
     */
    function handleButtonAction(notificationId, buttonText, clicked, addToRecent) {
        // If SDK not initialised, we can't make rest calls (even if we have a token)            
        if (donkyCore.isInitialised()) {

            if (addToRecent) {
                donkyCore.addNotificationToRecentCache(notificationId);
            }


            donkyCore.donkyNetwork.getServerNotification(notificationId, function (notification) {
                if (notification) {

                    switch (notification.type) {
                        case "SimplePushMessage":
                            if (window.donkyPushLogic) {

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

        } else {
            pluginError("handleButtonAction() called when not initialised");
        }
    }


    /**
     * 
     */
    function subscribeToDonkyEvents() {


        document.addEventListener("pause", function () {
            pluginLog("pause");

            // queue an AppSession 
            queueAppSession();


        }, false);

        /**
        * Need to determine whether app was foregrounded / launched due to a push or just opened.
        * Foreground event comes in before push event (which contains app state) - hence the setTimeout() usage 
        */
        document.addEventListener("resume", function () {
            pluginLog("resume");

            self.launchTimeUtc = new Date().toISOString();

            queueAppLaunch();

        }, false);


        /**
         * Donky events that need a sync of the badge count 
         */
        donkyCore.subscribeToLocalEvent("NewSimplePushMessagesReceived", function (event) { syncBadgeCount(); });
        donkyCore.subscribeToLocalEvent("NewRichMessagesReceived", function (event) { syncBadgeCount(); });
        donkyCore.subscribeToLocalEvent("PushMessageDeleted", function (event) { syncBadgeCount(); });
        donkyCore.subscribeToLocalEvent("RichMessageRead", function (event) { syncBadgeCount(); });
        donkyCore.subscribeToLocalEvent("RichMessageDeleted", function (event) { syncBadgeCount(); });
        donkyCore.subscribeToLocalEvent("SyncRichMessagesRead", function (event) { syncBadgeCount(); });
        donkyCore.subscribeToLocalEvent("SyncRichMessagesDeleted", function (event) { syncBadgeCount(); });

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

        /**
         * 
         */
        donkyCore.subscribeToLocalEvent("RegistrationChanged", function (event) {
            pluginLog("RegistrationChanged", JSON.stringify(event.data, null, 4));

            // need to re-submit the push token (same token will be used)
            sendPushConfiguration();
        });


    }

    /**
     * 
     */
    function sendPushConfiguration(deviceToken) {

        var pushConfig;

        if (deviceToken) {
            pushConfig = {
                registrationId: deviceToken,
                // will be undefined on Android
                bundleId: self.bundleId
            }
        } else {
            pushConfig = donkyCore.donkyData.get("pushConfig");
            // The first registration generates a RegistrationChanged event and this data won't be there so just return (registration will be performed later)
            if (pushConfig === null) {
                return;
            }
        }

        if (window.donkyCore) {
            // always store this object - it is used internally by Donky SDK when DonkyAccount.enablePush is called 
            donkyCore.donkyData.set("pushConfig", pushConfig);

            // ONLY do this if enabled or null
            // integrator can control this with donkyCore.donkyAccount.enablePush()
            if (donkyCore.donkyAccount.isPushEnabled() !== false) {

                pluginLog("sending push Configuration: " + JSON.stringify(pushConfig, null, 4));

                donkyCore.donkyAccount.sendPushConfiguration(pushConfig, function (result) {
                    pluginLog("sendPushConfiguration result: " + JSON.stringify(result, null, 4));
                });
            }
        } else {
            pluginError("window.donkyCore not set in donkyPlugin::sendPushConfiguration");
        }
    }

    /**
     * 
     */
    function doPushRegistation() {

        var configuration = donkyCore.donkyData.get("configuration");

        // Assumption is that Donky is initialised now as we need the button sets
        cordova.exec(function (result) {
            pluginLog("registerForPush success callback: " + JSON.stringify(result));

            // success callback re-used for push notifications and returning device token                                                 
            if (result.deviceToken) {
                sendPushConfiguration(result.deviceToken);
                donkyCore.publishLocalEvent({ type: "registerForPush", data: { succeeded: true, token: result.deviceToken } });
            } else {

                switch (self.platform) {
                    case "iOS":
                        if (result.userInfo.notificationId !== undefined) {
                            processAPNSPushMessage(result.userInfo, result.applicationState);
                        }
                        break;

                    /**
                     * We have the entire payload on Android so no need to get the notification 
                     * Also if a button has been clicked, we have that info too. 
                     * We should have all we need to call setSimplePushResult() 
                     */
                    case "Android":
                        processGCMPushMessage(result);
                        break;
                }
            }

        }, function (error) {
            pluginLog("registerForPush failed" + JSON.stringify(error));
            donkyCore.publishLocalEvent({ type: "registerForPush", data: { succeeded: false, error: error } });
        },
            "donky", "registerForPush",
            self.platform === "iOS" ? [JSON.stringify(donkyCore.getiOSButtonCategories())] : [configuration.configurationItems.DefaultGCMSenderId]);

    }

    /**
     * These are button clicks that occurred when the app was inactive 
     * Process, the data, store it and add the notifications to the recent cache so we don't 
     * inadvertantly get them again.  
     */
    function processColdstartNotifications(notifications) {

        pluginLog("processColdstartNotifications: " + notifications);

        var existing = JSON.parse(localStorage.getItem("coldstartNotifications"));

        var additional = [];

        if (notifications && notifications !== "") {
            donkyCore._each(notifications.split("|").filter(function (el) { return el.length !== 0 }), function (index, val) {
                additional.push(JSON.parse(val));
            });

        }

        var coldStartActions = existing !== null ? existing.concat(additional) : additional;

        if (coldStartActions.length > 0) {

            pluginLog("coldStartActions: " + JSON.stringify(coldStartActions));

            // How do we know if this was an influences app open ? (i.e a recent notification not some old one
            // We can look at the notification.clicked timestamp and if < say 1 minute we can say this was what triggered the open
            // check the age in the each loop below...
            var now = new Date();

            if (window.donkyCore) {

                donkyCore._each(coldStartActions, function (index, notification) {
                    // This will prevent the notification getting reprocessed
                    // only do this for push messages
                    if (notification.notificationType === "SIMPLEPUSHMSG") {
                        pluginLog("adding Notification " + notification.notificationId + " To RecentCache");
                        donkyCore.addNotificationToRecentCache(notification.notificationId);
                    }

                    var dif = (now - new Date(notification.clicked)) / 1000;

                    if (dif < 10) {
                        self.applicationStateOnPush = AppStates.inactive;
                        pluginLog("notification.clicked caused an influenced open: " + dif);
                    } else {
                        pluginLog("notification.clicked didnt cause an influenced open: " + dif);
                    }

                });
            }

            // These need to be picked up when we see the donkyInitialised event 
            localStorage.setItem("coldstartNotifications", JSON.stringify(coldStartActions));
        }

    }

    /**
     * 
     */
    function queueColdstartAnalytics() {

        var notifications = JSON.parse(localStorage.getItem("coldstartNotifications"));

        if (notifications) {

            donkyCore._each(notifications, function (index, notification) {
                // there may be non-interactive push messages in here, in which case ignore
                if (notification.label !== undefined & notification.label !== null) {
                    handleButtonAction(notification.notificationId, notification.label, notification.clicked, false);
                }
            });

            localStorage.removeItem("coldstartNotifications");
        }
    }

    /**
     * Operations to perform when donky SDK initialised event occurs ...
     */
    function onDonkyInitialised() {

        queueColdstartAnalytics();

        syncBadgeCount();

        queueAppLaunch();

        doPushRegistation();
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
    DonkyPlugin.prototype.callback = function (eventName, eventData) {
        if (window.donkyCore) {
            donkyCore.publishLocalEvent({ type: eventName, data: eventData });
        } else {
            pluginError("callback(" + eventName + ") : window.donkyCore not set");
        }
    }

    /**
     * Method to initialise donky plugin
     * @param {Callback} successCallback - callback to call if method was succsful with the deviceId
     * @param {Callback} errorCallback - callback to call if method failed with the error messag
     * @param {String} options
     */
    DonkyPlugin.prototype.initialise = function (successCallback, errorCallback, options) {

        cordova.exec(
            function (info) {

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

                processColdstartNotifications(info.coldstartNotifications);

                // Set this so it can safely be picked up in donkyAccount on registration 
                // NOTE: this only gets looked at in donkyCore.donkyAccount._register
                window.donkyDeviceOverrides = {
                    operatingSystem: self.platform,
                    deviceId: self.deviceId
                };

                if (window.donkyCore) {

                    // version must be >= 2.2.3.0 
                    if (donkyCore._versionCompare(donkyCore.version(), "2.2.3.0") < 0) {
                        errorCallback({ message: "donkyCore varsion too old - require minimum version of 2.2.3.0" });
                    } else {

                        if (!donkyCore.isInitialised()) {

                            donkyCore.donkyAccount._setOperatingSystem(self.platform);
                            donkyCore.donkyAccount._setDeviceId(self.deviceId);

                            var module = {
                                name: "cordova-plugin-donky-jsmodular",
                                version: pluginVersion
                            };

                            donkyCore.registerModule(module);

                            subscribeToDonkyEvents();

                            if (window.DonkyInitialised === true) {
                                pluginLog("Missed the DonkyInitialised event ...");
                                onDonkyInitialised();
                            } else {
                                // This event is ALWAYS published on succesful initialisation - hook into it and run our analysis ...
                                donkyCore.subscribeToLocalEvent("DonkyInitialised", function (event) {
                                    pluginLog("DonkyInitialised event received in DonkyPlugin()");
                                    onDonkyInitialised();
                                });
                            }

                            successCallback(info);

                        } else {
                            errorCallback({ message: "donkyCore already initialised, initialise this plugin BEFORE Donky" });
                        }
                    }

                } else {
                    errorCallback({ message: "donkyCore not available" });
                }
            },
            function (e) {

                self.available = false;
                pluginError("[ERROR] Error initializing donkyPlugin: " + e);

                errorCallback(e);
            },
            "donky", "initialise", [options]);
    }


    /**
     * Method to allow integrator to request whether user has granted permission to access Notifications
     * @param {Callback} successCallback - callback to call if method was succsful with the result
     * @param {Callback} errorCallback - callback to call if method failed with the error messag
     */
    DonkyPlugin.prototype.hasPermission = function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'donky', 'hasPermission', []);
    };

    /**
     * Method to allow integrator to explicitly set the application badge count
     * @param {Callback} successCallback - callback to call if method was succsful
     * @param {Callback} errorCallback - callback to call if method failed with the error messag
     * @param {Number} count - the count to set to
     */
    DonkyPlugin.prototype.setBadgeCount = function (successCallback, errorCallback, count) {
        cordova.exec(successCallback, errorCallback, "donky", "setBadgeCount", [count]);
    }

    /**
     * Method to allow integrator to open a deep link
     * @param {Callback} successCallback - callback to call if method was succsful
     * @param {Callback} errorCallback - callback to call if method failed with the error messag
     * @param {String} link - the link to open
     */
    DonkyPlugin.prototype.openDeepLink = function (successCallback, errorCallback, link) {
        cordova.exec(successCallback, errorCallback, "donky", "openDeepLink", [link]);
    }

}


module.exports = new DonkyPlugin();
