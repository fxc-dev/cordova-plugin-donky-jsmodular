package com.donky.plugin;

import android.app.IntentService;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
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


    public PushIntentService() {
        super("PushIntentService");
    }

    @Override
    protected void onHandleIntent(final Intent intent) {

        Bundle extras = intent.getExtras();

        if (extras != null) {
            Bundle originalExtras = extras.getBundle(PUSH_BUNDLE);

            if (ACTION_CANCEL_NOTIFICATION.equals(intent.getAction())){

                Log.v(LOG_TAG, ACTION_CANCEL_NOTIFICATION);

                // TODO: what to return to donky ?
                //  - need to ensure we don't get this message again
                // need to report the button click ...
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