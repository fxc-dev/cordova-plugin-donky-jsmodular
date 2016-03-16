/*global cordova, module*/

module.exports = {
    greet: function (name, successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "donky", "greet", [name]);
    },
    deviceId: function (successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "donky", "deviceId",[]);
    },
    registerForPush: function (successCallback, errorCallback, buttonSets) {
        cordova.exec(successCallback, errorCallback, "donky", "registerForPush",[JSON.stringify(buttonSets)]);
    },
    
};
