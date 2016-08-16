# Introduction
The Cordova plugin is designed to work in conjunction with the existing Javascript SDK. It allows your Cordova or PhoneGap app to easily receive native Push Notifications and use all the functionality of the Donky JavaScript SDK. 

Read through the sections below to discover how to deploy and use the Donky Cordova Plugin to Donky enable your apps:
>**Compatability**
>
> This plugin supports iOS (7 and above) and Android (4.0 - API level 14 and above). It works with Cordova and PhoneGap frameworks.

# Installation

To install the plugin into your app, simply execute the following command in your applications development folder. 
If you are using PhoneGap or Ionic then substitute in the relevant CLI command name.

The android senderId is specified as a variable (*SENDER_ID*) when the plugin is added. More information about GCM [here](https://developers.google.com/cloud-messaging/gcm). 

If your app is iOS only, or you wish to use to use the Donky default GCM configuration, you don't need to specify the *SENDER_ID* variable.

If you want to change the *SENDER_ID*, you can remove the plugin and then re-add it specifying the different *SENDER_ID*.

## From Github
```shell
    $ cordova plugin add https://github.com/Donky-Network/cordova-plugin-donky-jsmodular
```
or if you want to specify a senderId
```shell
    $ cordova plugin add https://github.com/Donky-Network/cordova-plugin-donky-jsmodular --variable SENDER_ID=\"XXXXXXXXXX\"
```


## Via NPM

```shell
    $ cordova plugin add cordova-plugin-donky-jsmodular
```
or if you want to specify a senderId
```shell
    $ cordova plugin add cordova-plugin-donky-jsmodular --variable SENDER_ID=\"XXXXXXXXXX\"
```


# Dependencies

## donkyLogicBundle.js

This plugin is intended to be used with the Donky Javascript SDK. 
This can be found on our CDN. We recommend that you take a copy of donkyLogicBundle.js from the CDN and place in your application folder. 
This will then need to be included in your index.html 

This bundle contains all of the Donky logic modules apart from the donkyCoreAnalytics module which is incompatible. 
(If you want to cherry pick the bare minimum modules, then you can do that too)

The Logic Bundle can be downloaded from here:

https://cdn.dnky.co/sdk/2.2.3.1/modules/donkyLogicBundle.js

https://cdn.dnky.co/sdk/2.2.3.1/modules/donkyLogicBundle.min.js

or for the latest verion ...

https://cdn.dnky.co/sdk/latest-modular/modules/donkyLogicBundle.js

https://cdn.dnky.co/sdk/latest-modular/modules/donkyLogicBundle.min.js


Note: 2.2.3.0 is the MINIMUM version of the SDK that supports this plugin



Here is a sample ...
```html
<script src="js/jquery-1.11.2.min.js"></script>
<script src="js/jquery.signalR-2.2.0.min.js"></script>
<script type="text/javascript" src="js/donkyLogicBundle.js"></script>
```

>**jQuery and signalR Dependencies**
>
>As can be seen in the above snippet, the Donky SDK has dependencies on jQuery and signalR

# Push configuration
To use push in your app you will need to setup [APNS](http://docs.mobiledonky.com/docs/remote-notification-certificates) 
and [GCM](http://docs.mobiledonky.com/docs/gcm-configuration)
*(The above links are links to the respective Donky native SDK push configuration sections)* 

>**Setting GCM Sender ID**
>
>Setting GCM Sender ID in your application resources in res/values/strings.xml is NOT necessary as we will specify it when we install the plugin

# Initialisation

Here is a minimal code fragment showing how to initialise everything. 
You need to do the following in sequence:
1) Wait for device ready event
2) Initialise the Donky plugin
3) Initialise the Donky SDK

As can be seen, a [**pushOptions**](doc:cordova-plugin#section-push-options)  object is passed into the initialise method which allows the customisation of the native push message.

```javascript

// Wait for device ready ...
document.addEventListener('deviceready', function(){

	// Initialise plugin  ....
  
    var pushOptions = {
        ios: {},
        android:{
            vibrate: true,
            icon: "newMessage",
            iconColor: "green"                     
        }
    }; 
  
    window.cordova.plugins.donkyPlugin.initialise(function(){

    		// Initialise Donky
        donkyCore.initialise({
            apiKey: ">>>YOUR API KEY<<<",
            resultHandler: function(result) {

                if(result.succeeded) {
                  
                  // Your cool app code ...
                  
                }else{
                    console.error(result);
                }
            }
        });
    
    }, function(e){
        console.error("initialise failed", JSON.stringify(e));
    }, pushOptions );       

}, false);
```

## Push Options

Here is a summary of the available push options; note that currently only Android has options.


| Attribute        | Type          | Default  | Description |
| ---------------- |---------------| ---------|  ---------- |
| android.vibrate  | boolean       | true     | Optional. If true the device vibrates on receipt of notification. |
| android.icon     | string        |          | Optional. The name of a drawable resource to use as the small-icon. The name should not include the extension. |
| android.iconColor| string        |          | Optional. Sets the background color of the small icon on Android 5.0 and greater. [Supported Formats](https://developer.android.com/reference/android/graphics/Color.html#parseColor(java.lang.String)) |



# Push Registration
Native Push registration is internally managed by the plugin. The plugin subscribes to the [local event](doc:local-events) **DonkyInitialised** and performs the push registration off the back of this. The APNS device token / GCM registrationId is queried from the device and then it is sent to Donky.

You can register to listen for a local event (*registerForPush*), which is published after the native push registration has been performed which will indicate success or failure.

```javascript
// Listen for Donky's push registration result
donkyCore.subscribeToLocalEvent("registerForPush", function (event) {

  var result = event.data;
  
  if(result.succeded){
  	console.log("registerForPush succeeded", result.token);
  }else{
  	console.error("registerForPush succeeded", result.error);
  }

});           
```
# Enabling / Disabling push notifications

If you would like to enable / disable push notifications in your app, you can do this using the following method:


## Enable Push

```javascript
// Enable
donkyCore.donkyAccount.enablePush(true, function(result){     
	// callback function fires when cached push token sent to donky
  if(result.succeeded){
    console.log("enablePush(true) succeeded");
  }else{
    console.error("enablePush(true) failed");
  }                    
});   
```

## Disable Push

```javascript
// Disable
donkyCore.donkyAccount.enablePush(false, function(result){                    
	// callback function fires when push token deleted from Donky network
  if(result.succeeded){
    console.log("enablePush(false) succeeded");
  }else{
    console.error("enablePush(false) failed");
  }                    

});  
```

# Deep links
You can send a deep link as part of an interactive push message using Donky. 
These will be correctly handled by the Cordova plugin but you will need to use another plugin to correctly handle the links in your application (for routing purposes). 
The following two 3rd party plugins are recommended (*The ionic sample app uses ionic-plugin-deeplinks*)

  * [cordova-universal-links-plugin](https://github.com/nordnet/cordova-universal-links-plugin)
  * [ionic-plugin-deeplinks](https://github.com/driftyco/ionic-plugin-deeplinks)

To correctly handle deep links in your app you will need to tweak the native project files:

## iOS 

You will need to add <a href="https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html#//apple_ref/doc/uid/TP40009250-SW14" target="_new">LSApplicationQueriesSchemes</a> key to your info.plist file to allow opening of deep links.

## Android

You will need to modify AndroidManifest.xml 

- **android:launchMode** needs to be set to **singleTask** 

```xml
<activity android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale" 
    android:label="@string/activity_name" 
    **android:launchMode="singleTask" 
    **android:name="MainActivity" 
    android:theme="@android:style/Theme.DeviceDefault.NoActionBar" 
    android:windowSoftInputMode="adjustResize">
```
- add an intent filter for the scheme
```xml
<intent-filter>
  <data android:scheme=">>>YOUR SCHEME NAME<<<"/>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
</intent-filter>
```

# Location Services
Donky provides [core location](http://docs.mobiledonky.com/v1.5/docs/core-location-js) module that works with the HTML5 geolocation API.

If you import the [cordova-plugin-geolocation](https://github.com/apache/cordova-plugin-geolocation) plugin, 
it will use this API with a native location tracking sensors therefore you get the benefits of native accuracy and the ability to interact with Donky.

```shell
$ cordova plugin add cordova-plugin-geolocation
```
# Sample Apps

Various sample projects can be found on Github, including popular frameworks such as <a href="http://ionicframework.com/" target="_new">Ionic</a> and <a href="https://angularjs.org/" target="_new">Angular</a> here:

<a href="https://github.com/Donky-Network/Donky-Cordova-JSModular-Samples" target="_new">https://github.com/Donky-Network/Donky-Cordova-JSModular-Samples</a>

The **Readme.md** in the root of the repo details how to get these projects running