package com.donky.plugin;


import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import android.provider.Settings;
import org.json.JSONObject;
import android.content.Context;
import android.util.Log;
import android.os.Bundle;
import java.io.IOException;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Date;
import java.util.TimeZone;
import java.text.DateFormat;
import java.text.SimpleDateFormat;

import com.google.android.gms.iid.InstanceID;


public class DonkyPlugin extends CordovaPlugin implements PushConstants{

    public static final String LOG_TAG = "DonkyPlugin";
    private static CordovaWebView gWebView;
    private static boolean gForeground = false;
    private static CallbackContext pushContext;
    private static Bundle gCachedExtras = null;

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
     * @param args              JSONArry of arguments for the plugin.
     * @param callbackContext   The callback id used when calling back into JavaScript.
     * @return                  True if the action was valid, false if not.
     */    
    @Override
    public boolean execute(String action, final JSONArray data, final CallbackContext callbackContext) throws JSONException {

        Log.v(LOG_TAG, "execute: action=" + action);
        gWebView = this.webView;


        if (action.equals("getPlatformInfo")) {

            JSONObject platfornInfo = new JSONObject();

            platfornInfo.put("deviceId", getUuid());
            platfornInfo.put("platform", "Android");
            platfornInfo.put("manufacturer", android.os.Build.MANUFACTURER);
            platfornInfo.put("model", android.os.Build.MODEL);
            platfornInfo.put("version", android.os.Build.VERSION.RELEASE);


            TimeZone tz = TimeZone.getTimeZone("UTC");
            DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mmZ");
            df.setTimeZone(tz);
            String nowAsISO = df.format(new Date());

            platfornInfo.put("launchTimeUtc", nowAsISO);

            callbackContext.success(platfornInfo);
            return true;
        }
        else if(action.equals("registerForPush")){

            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    pushContext = callbackContext;
                    String senderID = null;

                    try {
                        senderID = data.getString(0);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }

                    Log.v(LOG_TAG, "senderId=" + senderID);
                    String token = null;

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
                }
            });

            return true;
        } else {
            return false;
        }
    }

    public static void sendEvent(JSONObject _json) {
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