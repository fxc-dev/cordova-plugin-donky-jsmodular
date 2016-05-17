package com.donky.plugin;

import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.gcm.GcmListenerService;

import java.util.Iterator;

import android.app.Notification;
import android.app.NotificationManager;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Resources;

import android.support.v4.app.NotificationCompat;


public class GCMIntentService extends GcmListenerService implements PushConstants {

    private static final String LOG_TAG = "DonkyPlugin";

/*
    05-16 09:57:42.841 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: key = type
    05-16 09:57:56.429 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: value = NOTIFICATIONPENDING
    05-16 09:59:45.810 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: key = notificationId
    05-16 09:59:45.810 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: value = f49441f4-87d8-4135-b94c-abd9c9f7f456
    05-16 09:59:45.811 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: key = notificationType
    05-16 09:59:45.811 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: value = SIMPLEPUSHMSG
    05-16 09:59:45.811 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: key = collapse_key
    05-16 09:59:45.811 4056-5446/com.lepojevic.pushtest D/DonkyPlugin: value = do_not_collapse
*/
    @Override
    public void onMessageReceived(String from, Bundle extras) {
        Log.d(LOG_TAG, "onMessage - from: " + from);

        if (extras != null) {

            Iterator<String> it = extras.keySet().iterator();

            while (it.hasNext()) {
                String key = it.next();
                Log.d(LOG_TAG, "key = " + key);
                Object json = extras.get(key);
                Log.d(LOG_TAG, "value = " + json);
            }

            if(DonkyPlugin.isInForeground())
            {
                DonkyPlugin.sendExtras(extras);
            }
            else
            {
                createNotification(getApplicationContext(), extras);
            }
        }
    }


    public void createNotification(Context context, Bundle extras) {
        NotificationManager mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String appName = getAppName(this);
        String packageName = context.getPackageName();
        Resources resources = context.getResources();

    //    int notId = parseInt(NOT_ID, extras);
    //    Intent notificationIntent = new Intent(this, PushHandlerActivity.class);
    //    notificationIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
    //    notificationIntent.putExtra(PUSH_BUNDLE, extras);
    //    notificationIntent.putExtra(NOT_ID, notId);

    //    int requestCode = new Random().nextInt();
    //    PendingIntent contentIntent = PendingIntent.getActivity(this, requestCode, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        NotificationCompat.Builder mBuilder =
                new NotificationCompat.Builder(context)
                        .setWhen(System.currentTimeMillis())
                        .setContentTitle(extras.getString(TITLE))
                        .setTicker(extras.getString(TITLE))
        //              .setContentIntent(contentIntent)
                        .setAutoCancel(true);

        SharedPreferences prefs = context.getSharedPreferences(DonkyPlugin.COM_ADOBE_PHONEGAP_PUSH, Context.MODE_PRIVATE);

        String localIcon = prefs.getString(ICON, null);
        String localIconColor = prefs.getString(ICON_COLOR, null);
        boolean soundOption = prefs.getBoolean(SOUND, true);
        boolean vibrateOption = prefs.getBoolean(VIBRATE, true);
        Log.d(LOG_TAG, "stored icon=" + localIcon);
        Log.d(LOG_TAG, "stored iconColor=" + localIconColor);
        Log.d(LOG_TAG, "stored sound=" + soundOption);
        Log.d(LOG_TAG, "stored vibrate=" + vibrateOption);

        /*
         * Notification Vibration
         */

        setNotificationVibration(extras, vibrateOption, mBuilder);

        /*
         * Notification Icon Color
         *
         * Sets the small-icon background color of the notification.
         * To use, add the `iconColor` key to plugin android options
         *
         */
        // setNotificationIconColor(extras.getString("color"), mBuilder, localIconColor);

        /*
         * Notification Icon
         *
         * Sets the small-icon of the notification.
         *
         * - checks the plugin options for `icon` key
         * - if none, uses the application icon
         *
         * The icon value must be a string that maps to a drawable resource.
         * If no resource is found, falls
         *
         */
        setNotificationSmallIcon(context, extras, packageName, resources, mBuilder, localIcon);

        /*
         * Notification Large-Icon
         *
         * Sets the large-icon of the notification
         *
         * - checks the gcm data for the `image` key
         * - checks to see if remote image, loads it.
         * - checks to see if assets image, Loads It.
         * - checks to see if resource image, LOADS IT!
         * - if none, we don't set the large icon
         *
         */
        // setNotificationLargeIcon(extras, packageName, resources, mBuilder);

        /*
         * Notification Sound
         */
        if (soundOption) {
            setNotificationSound(context, extras, mBuilder);
        }

        /*
         *  LED Notification
         */
        // setNotificationLedColor(extras, mBuilder);

        /*
         *  Priority Notification
         */
        // setNotificationPriority(extras, mBuilder);

        /*
         * Notification message
         */
        setNotificationMessage(extras, mBuilder);

        /*
         * Notification count
         */
        setNotificationCount(extras, mBuilder);

        /*
         * Notification add actions
         */

        // TODO: interactive buttons!!!
        // createActions(extras, mBuilder, resources, packageName);

        int notId = 0;

        mNotificationManager.notify(appName, notId, mBuilder.build());
    }

    private void setNotificationVibration(Bundle extras, Boolean vibrateOption, NotificationCompat.Builder mBuilder) {
        mBuilder.setDefaults(Notification.DEFAULT_VIBRATE);
    }

    private void setNotificationMessage(Bundle extras, NotificationCompat.Builder mBuilder) {
        mBuilder.setContentText("TODO: get content text ;-)");
    }

    private void setNotificationCount(Bundle extras, NotificationCompat.Builder mBuilder) {
        mBuilder.setNumber(0);
    }

    private void setNotificationSound(Context context, Bundle extras, NotificationCompat.Builder mBuilder) {
        mBuilder.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI);
    }



    private void setNotificationSmallIcon(Context context, Bundle extras, String packageName, Resources resources, NotificationCompat.Builder mBuilder, String localIcon) {
        int iconId = 0;
        String icon = extras.getString(ICON);
        if (icon != null) {
            iconId = resources.getIdentifier(icon, DRAWABLE, packageName);
            Log.d(LOG_TAG, "using icon from plugin options");
        }
        else if (localIcon != null) {
            iconId = resources.getIdentifier(localIcon, DRAWABLE, packageName);
            Log.d(LOG_TAG, "using icon from plugin options");
        }
        if (iconId == 0) {
            Log.d(LOG_TAG, "no icon resource found - using application icon");
            iconId = context.getApplicationInfo().icon;
        }
        mBuilder.setSmallIcon(iconId);
    }



    private static String getAppName(Context context) {
        CharSequence appName =  context.getPackageManager().getApplicationLabel(context.getApplicationInfo());
        return (String)appName;
    }


}


