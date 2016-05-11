package com.donky.plugin;


import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import android.provider.Settings;
import org.json.JSONObject;

public class DonkyPlugin extends CordovaPlugin {


    /**
     * Constructor.
     */
    public DonkyPlugin() {
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
    }


    /**
     * Executes the request and returns PluginResult.
     *
     * @param action            The action to execute.
     * @param args              JSONArry of arguments for the plugin.
     * @param callbackContext   The callback id used when calling back into JavaScript.
     * @return                  True if the action was valid, false if not.
     */    
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {

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
