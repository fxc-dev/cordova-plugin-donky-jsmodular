package com.donky.plugin;


import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import android.provider.Settings;
import org.json.JSONObject;
import android.content.Context;
import android.util.Log;

public class DonkyPlugin extends CordovaPlugin {

    public static final String LOG_TAG = "DonkyPlugin";
    private static CordovaWebView gWebView;
    private static boolean gForeground = false;

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
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {

        Log.v(LOG_TAG, "execute: action=" + action);
        gWebView = this.webView;


        if (action.equals("getPlatformInfo")) {
            
            JSONObject platfornInfo = new JSONObject();
            
            platfornInfo.put("deviceId", getUuid());
            platfornInfo.put("platform", "Android");
            platfornInfo.put("manufacturer", android.os.Build.MANUFACTURER);
            platfornInfo.put("model", android.os.Build.MODEL);
            platfornInfo.put("version", android.os.Build.VERSION.RELEASE);

            callbackContext.success(platfornInfo);
            return true;            
        } else {            
            return false;
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
