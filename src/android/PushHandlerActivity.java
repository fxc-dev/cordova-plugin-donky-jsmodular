package com.donky.plugin;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

public class PushHandlerActivity extends Activity implements PushConstants {
    private static String LOG_TAG = "PushPlugin";

    /*
     * this activity will be started if the user touches a notification that we own.
     * We send it's data off to the push plugin for processing.
     * If needed, we boot up the main activity to kickstart the application.
     * @see android.app.Activity#onCreate(android.os.Bundle)
     */
    @Override
    public void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        Log.v(LOG_TAG, "onCreate");

        boolean isPushPluginActive = DonkyPlugin.isActive();
        boolean launch = processPushBundle(isPushPluginActive);

        finish();

        if (!isPushPluginActive && launch) {
            forceMainActivityReload();
        }
    }

    /**
     * Takes the pushBundle extras from the intent,
     * and sends it through to the PushPlugin for processing.
     *
     */
    private boolean processPushBundle(boolean isPushPluginActive) {
        Bundle extras = getIntent().getExtras();
        boolean launch = true;

        if (extras != null)	{
            Bundle originalExtras = extras.getBundle(PUSH_BUNDLE);

            String actionType = extras.getString("actionType");
            String label = extras.getString("label");
            String data = extras.getString("data");

            Log.d(LOG_TAG, "actionType = " + actionType);
            Log.d(LOG_TAG, "label = " + label);
            Log.d(LOG_TAG, "data = " + data);

            if(actionType != null && actionType.equals("Dismiss")){
                launch = false;
            }

            originalExtras.putBoolean(FOREGROUND, false);
            originalExtras.putBoolean(COLDSTART, !isPushPluginActive);
            originalExtras.putString(CALLBACK, extras.getString("callback"));


            DonkyPlugin.sendExtras(originalExtras);
        }

        return launch;
    }

    /**
     * Forces the main activity to re-launch if it's unloaded.
     */
    private void forceMainActivityReload() {
        PackageManager pm = getPackageManager();
        Intent launchIntent = pm.getLaunchIntentForPackage(getApplicationContext().getPackageName());
        startActivity(launchIntent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        final NotificationManager notificationManager = (NotificationManager) this.getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancelAll();
    }
}