package com.donky.plugin;


import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.provider.Settings;
import org.json.JSONObject;
import android.content.Context;
import android.util.Log;
import android.os.Bundle;
import java.io.IOException;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Date;
import java.util.Map;
import java.util.TimeZone;
import java.text.DateFormat;
import java.text.SimpleDateFormat;

import com.google.android.gms.iid.InstanceID;

import java.util.List;


public class DonkyPlugin extends CordovaPlugin implements PushConstants{

    public static final String LOG_TAG = "DonkyPlugin";
    private static CordovaWebView gWebView;
    private static boolean gForeground = false;
    private static CallbackContext pushContext;
    // these are used if the push comes in and the webview isnt initialised
    private static Bundle gCachedExtras = null;


    private static Map <String, Bundle> gCachedExtrasMap = new HashMap<String,Bundle>();


    /**
     * Constructor.
     */
    public DonkyPlugin() {
    }

    /**
     * Gets the application context from cordova's main activity.
     * @return the application context
     */
    private Context getApplicationContext() {
        return this.cordova.getActivity().getApplicationContext();
    }


    /**
     * Sets the context of the Command. This can then be used to do things like
     * get file paths associated with the Activity.
     *
     * @param cordova The context of the main Activity.
     * @param webView The CordovaWebView Cordova is running in.
     */
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        gForeground = true;
    }

    @Override
    public void onPause(boolean multitasking) {
        super.onPause(multitasking);
        gForeground = false;
    }

    @Override
    public void onResume(boolean multitasking) {
        super.onResume(multitasking);
        gForeground = true;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        gForeground = false;
        gWebView = null;
    }

    public static boolean isInForeground() {
      return gForeground;
    }

    public static boolean isActive() {
        return gWebView != null;
    }



    /**
     * Executes the request and returns PluginResult.
     *
     * @param action            The action to execute.
     * @param data              JSONArry of arguments for the plugin.
     * @param callbackContext   The callback id used when calling back into JavaScript.
     * @return                  True if the action was valid, false if not.
     */
    @Override
    public boolean execute(String action, final JSONArray data, final CallbackContext callbackContext) throws JSONException {

        Log.v(LOG_TAG, "execute: action=" + action);
        gWebView = this.webView;

        if (action.equals("initialise")) {

            JSONObject platformInfo = new JSONObject();

            platformInfo.put("deviceId", getUuid());
            platformInfo.put("platform", "Android");
            platformInfo.put("manufacturer", android.os.Build.MANUFACTURER);
            platformInfo.put("model", android.os.Build.MODEL);
            platformInfo.put("version", android.os.Build.VERSION.RELEASE);
            
            SharedPreferences sharedPref = getApplicationContext().getSharedPreferences(COM_DONKY_PLUGIN, Context.MODE_PRIVATE);
            String dismissedNotifications = sharedPref.getString("dismissedNotifications", "");

            platformInfo.put("dismissedNotifications", dismissedNotifications );

            SharedPreferences.Editor editor = sharedPref.edit();

            editor.putString("dismissedNotifications", "");

            TimeZone tz = TimeZone.getTimeZone("UTC");
            DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mmZ");
            df.setTimeZone(tz);
            String nowAsISO = df.format(new Date());

            platformInfo.put("launchTimeUtc", nowAsISO);

            String jsonOptions = data.getString(0);
            Log.v(LOG_TAG, "setPushOptions: " + jsonOptions);

            JSONObject options = new JSONObject(jsonOptions);

            JSONObject androidOptions = options.getJSONObject("android");

            String environment = androidOptions.optString("environment","");
            Boolean vibrate = androidOptions.optBoolean("vibrate", true);
            String icon = androidOptions.optString("icon");
            String iconColor = androidOptions.optString("iconColor");

            Log.v(LOG_TAG, "environment: " + environment);
            Log.v(LOG_TAG, "vibrate: " + vibrate);
            Log.v(LOG_TAG, "icon: " + icon);
            Log.v(LOG_TAG, "iconColor: " + iconColor);

            editor.putString("environment", environment);
            editor.putBoolean("vibrate", vibrate);
            editor.putString("icon", icon);
            editor.putString("iconColor", iconColor);

            editor.commit();

            callbackContext.success(platformInfo);
            return true;
        }
        else if(action.equals("openDeepLink")){
            String deepLink = data.getString(0);

            Intent currentIntent = this.cordova.getActivity().getIntent();
            Bundle extras = currentIntent.getExtras();

            if( openDeepLink(getApplicationContext(), extras, deepLink) ){
                callbackContext.success();
            }else{
                callbackContext.error("Could not find an intent that matched the link " + deepLink);
            }

            return true;
        }
        else if(action.equals("registerForPush")){

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    pushContext = callbackContext;

                    String senderID = "";

                    Integer identifier = getApplicationContext().getResources().getIdentifier("sender_id", "string", getApplicationContext().getPackageName());

                    if(identifier!=0){
                        senderID = getApplicationContext().getResources().getString(identifier);
                        Log.v(LOG_TAG, "senderID: " + senderID);
                    }

                    if(!"".equals(senderID)){

                        String token;

                        try {

                            token = InstanceID.getInstance(getApplicationContext()).getToken(senderID, GCM);

                            if (!"".equals(token)) {
                                JSONObject json = new JSONObject().put(DEVICE_TOKEN, token);

                                Log.v(LOG_TAG, "onRegistered: " + json.toString());

                                DonkyPlugin.sendEvent( json );
                            } else {
                                callbackContext.error("Empty device Tokem received from GCM");
                                return;
                            }

                        } catch (JSONException e) {
                            Log.e(LOG_TAG, "execute: Got JSON Exception " + e.getMessage());
                            callbackContext.error(e.getMessage());
                        } catch (IOException e) {
                            Log.e(LOG_TAG, "execute: Got JSON Exception " + e.getMessage());
                            callbackContext.error(e.getMessage());
                        }

                        if (gCachedExtras != null) {
                            Log.v(LOG_TAG, "sending cached extras");
                            sendExtras(gCachedExtras);
                            gCachedExtras = null;
                        }
                    }else{
                        callbackContext.error("Missing senderId");
                    }

                }
            });

            return true;
        } else {
            return false;
        }
    }



    /**
     * Check if there is Activity responding to an Intent.
     *
     * @param context Context
     * @param intent Intent to check if any Activity responds to.
     * @return True if Activity responds to an Intent.
     */
    public static boolean isActivityAvailable(Context context, Intent intent) {

        final PackageManager mgr = context.getPackageManager();

        List<ResolveInfo> list =
                mgr.queryIntentActivities(intent,
                        PackageManager.MATCH_DEFAULT_ONLY);

        return list.size() > 0;

    }

    public static boolean openDeepLink(Context context, Bundle extras, String deepLink) {

        Intent intent = new Intent();

        if(extras!=null){
            intent.putExtras(extras);
        }

        intent.setData(Uri.parse(deepLink));

        intent.setAction(Intent.ACTION_VIEW);
        intent.addCategory(Intent.CATEGORY_DEFAULT);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

        if (isActivityAvailable(context, intent)) {
            context.startActivity(intent);
            return true;

        }else{
            Log.v(LOG_TAG, "Could not find an intent that matched the link " + deepLink);
            return false;
        }
    }


    public static void sendEvent(JSONObject _json) {

        Log.v(LOG_TAG, "sendEvent(" + _json.toString() + ")");

        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, _json);
        pluginResult.setKeepCallback(true);
        if (pushContext != null) {
            pushContext.sendPluginResult(pluginResult);
        }
    }

    /*
 * serializes a bundle to JSON.
 */
    private static JSONObject convertBundleToJson(Bundle extras) {
        Log.d(LOG_TAG, "convert extras to json");
        try {
            JSONObject json = new JSONObject();
            JSONObject additionalData = new JSONObject();

            // Add any keys that need to be in top level json to this set
            HashSet<String> jsonKeySet = new HashSet();
            Collections.addAll(jsonKeySet, TITLE,MESSAGE,COUNT,SOUND,IMAGE);

            Iterator<String> it = extras.keySet().iterator();
            while (it.hasNext()) {
                String key = it.next();
                Object value = extras.get(key);

                Log.d(LOG_TAG, "key = " + key);

                if (jsonKeySet.contains(key)) {
                    json.put(key, value);
                }
                else if (key.equals(COLDSTART)) {
                    additionalData.put(key, extras.getBoolean(COLDSTART));
                }
                else if (key.equals(FOREGROUND)) {
                    additionalData.put(key, extras.getBoolean(FOREGROUND));
                }
                else if ( value instanceof String ) {
                    String strValue = (String)value;
                    try {
                        // Try to figure out if the value is another JSON object
                        if (strValue.startsWith("{")) {
                            additionalData.put(key, new JSONObject(strValue));
                        }
                        // Try to figure out if the value is another JSON array
                        else if (strValue.startsWith("[")) {
                            additionalData.put(key, new JSONArray(strValue));
                        }
                        else {
                            additionalData.put(key, value);
                        }
                    } catch (Exception e) {
                        additionalData.put(key, value);
                    }
                }
            } // while

            json.put(ADDITIONAL_DATA, additionalData);
            Log.v(LOG_TAG, "extrasToJSON: " + json.toString());

            return json;
        }
        catch( JSONException e) {
            Log.e(LOG_TAG, "extrasToJSON: JSON exception");
        }
        return null;
    }

    /*
     * Sends the pushbundle extras to the client application.
     * If the client application isn't currently active, it is cached for later processing.
     */
    public static void sendExtras(Bundle extras) {
        if (extras != null) {
            if (gWebView != null) {

                String notificationId = extras.getString("notificationId");
                gCachedExtrasMap.put(notificationId, extras);

                sendEvent(convertBundleToJson(extras));
            } else {
                Log.v(LOG_TAG, "sendExtras: caching extras to send at a later time.");
                gCachedExtras = extras;
            }
        }
    }


    /**
     * Get the device's Universally Unique Identifier (UUID).
     *
     * @return
     */
    private String getUuid() {
        String uuid = Settings.Secure.getString(this.cordova.getActivity().getContentResolver(), android.provider.Settings.Secure.ANDROID_ID);
        return uuid;
    }

}
