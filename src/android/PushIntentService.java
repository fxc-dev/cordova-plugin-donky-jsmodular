package com.donky.plugin;

import android.app.IntentService;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

public class PushIntentService extends IntentService implements PushConstants{

    private static String LOG_TAG = "DonkyPlugin";

    /**
     * Action name of intent. Notification described in intent should be canceled.
     */
    static final String ACTION_CANCEL_NOTIFICATION = "com.donky.plugin.CANCEL_NOTIFICATION";

    /**
     * Action name of intent. Notification described in intent should be canceled. Main application Activity will be opened.
     */
    static final String ACTION_OPEN_APPLICATION = "com.donky.plugin.OPEN";

    /**
     * Action name of intent. Notification described in intent should be canceled. System will try to open activity responding to deep link.
     */
    static final String ACTION_OPEN_DEEP_LINK = "com.donky.plugin.DEEP_LINK";

    /**
     * Action name of intent. Notification described in intent should be open rich message.
     */
    static final String ACTION_OPEN_RICH_MESSAGE = "com.donky.plugin.RICH_MESSAGE";


    public PushIntentService() {
        super("PushIntentService");
    }

    @Override
    protected void onHandleIntent(final Intent intent) {

        Bundle extras = intent.getExtras();

        if (extras != null) {
            Bundle originalExtras = extras.getBundle(PUSH_BUNDLE);
            
            String messageType = (String) originalExtras.get("messageType");

            if( messageType.equals("SimplePush") ){
                originalExtras.putString("ButtonClicked", extras.getString("ButtonLabel"));
            }

            if (ACTION_CANCEL_NOTIFICATION.equals(intent.getAction())){

                Log.v(LOG_TAG, ACTION_CANCEL_NOTIFICATION);

                SharedPreferences sharedPref = getApplicationContext().getSharedPreferences(COM_DONKY_PLUGIN, Context.MODE_PRIVATE);

                String dismissedNotifications = sharedPref.getString("dismissedNotifications", "");

                String notificationId = (String) originalExtras.get("notificationId");

                dismissedNotifications += notificationId + ",";

                SharedPreferences.Editor editor = sharedPref.edit();

                editor.putString("dismissedNotifications", dismissedNotifications);

                editor.commit();
            }
            else if(ACTION_OPEN_APPLICATION.equals(intent.getAction())){

                Log.v(LOG_TAG, ACTION_OPEN_APPLICATION);

                // TODO: what to return to donky ?
                //  - need to ensure we don't get this message again
                // need to report the button click ...


                PackageManager pm = getPackageManager();
                Intent launchIntent = pm.getLaunchIntentForPackage(getApplicationContext().getPackageName());
                startActivity(launchIntent);
            }
            else if(ACTION_OPEN_DEEP_LINK.equals(intent.getAction())){

                Log.v(LOG_TAG, ACTION_OPEN_DEEP_LINK);
                String deepLinkData = extras.getString("DeepLinkData");
                Log.d(LOG_TAG, "DeepLinkData = " + deepLinkData);

            }
            else if(ACTION_OPEN_RICH_MESSAGE.equals(intent.getAction())){
                Log.v(LOG_TAG, ACTION_OPEN_RICH_MESSAGE);

                // TODO: what to return to donky ?


                PackageManager pm = getPackageManager();
                Intent launchIntent = pm.getLaunchIntentForPackage(getApplicationContext().getPackageName());
                startActivity(launchIntent);
            }


            DonkyPlugin.sendExtras(originalExtras);
        }


        cancelNotification(intent);
    
    }

    /**
     * Cancel notification described in intent.
     *
     * @param intent Intent from notification button click.
     */
    private void cancelNotification(Intent intent) {

        if (intent.getExtras().containsKey(NOTIFICATION_ID)) {

            int notificationId = intent.getIntExtra(NOTIFICATION_ID, 0);

            Log.v(LOG_TAG, "cancelNotification: notificationId = " + notificationId);


            NotificationManager manager = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);

            if (manager != null && notificationId != 0) {
                manager.cancel(notificationId);
            }

        } else {
            Log.v(LOG_TAG, "Missing notification id for dismiss action.");
        }
    }


}