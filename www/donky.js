/*global cordova, module*/

module.exports = {
    /**
     * 
     */
    callback: function(eventName, eventData){
        console.log("donkyevent: " + eventName + eventData);
        
        var event = new CustomEvent(eventName, {
            detail: {
                data: eventData
            }
        });

        document.dispatchEvent(event);                
    },
    /**
     * 
     */
    greet: function (name, successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "donky", "greet", [name]);
    },
    /**
     * 
     */
    deviceId: function (successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "donky", "deviceId",[]);
    },
    /**
     * 
     */
    registerForPush: function (successCallback, errorCallback, buttonSets) {
        cordova.exec(successCallback, errorCallback, "donky", "registerForPush",[JSON.stringify(buttonSets)]);
    },
    
};
