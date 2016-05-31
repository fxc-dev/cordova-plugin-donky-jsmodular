package com.donky.plugin;

import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.gcm.GcmListenerService;

import java.util.Random;

import android.app.Notification;
import android.app.NotificationManager;

import android.content.Context;
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

            for (String key : extras.keySet()) {
                Log.d(LOG_TAG, "key = " + key);
                Object json = extras.get(key);
                Log.d(LOG_TAG, "value = " + json);
            }

            if(DonkyPlugin.isInForeground()){

                DonkyPlugin.sendExtras(extras);
                    
            }else{
                createNotification(getApplicationContext(), extras);
            }

        }
    }

    /**
     * Forces the main activity to re-launch if it's unloaded.
     *
    private void forceMainActivityReload() {
        PackageManager pm = getPackageManager();
        Intent launchIntent = pm.getLaunchIntentForPackage(getApplicationContext().getPackageName());

        startActivity(launchIntent);
    }*/

    public void createNotification(Context context, Bundle extras) {

        NotificationManager mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String appName = (String) context.getPackageManager().getApplicationLabel(context.getApplicationInfo());

        Random r = new Random();
        int notId = r.nextInt(100000);

        Intent notificationIntent = new Intent(this, PushHandlerActivity.class);
        notificationIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        notificationIntent.putExtra(PUSH_BUNDLE, extras);
        notificationIntent.putExtra(NOT_ID, notId);

        int requestCode = new Random().nextInt();
        PendingIntent contentIntent = PendingIntent.getActivity(this, requestCode, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        NotificationCompat.Builder mBuilder =
                new NotificationCompat.Builder(context)
                        .setWhen(System.currentTimeMillis())
                        .setContentTitle(extras.getString(TITLE))
                        .setTicker(extras.getString(TITLE))
                        .setContentIntent(contentIntent);
                        //.setAutoCancel(true);

        mBuilder.setDefaults(Notification.DEFAULT_VIBRATE);

        mBuilder.setSmallIcon(context.getApplicationInfo().icon);

        mBuilder.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI);

        mBuilder.setContentText("TODO: get content text ;-)");

        mBuilder.setNumber(0);
        
        mBuilder.addAction(android.R.color.transparent, "Yes", contentIntent);
        
        mBuilder.addAction(android.R.color.transparent, "No", contentIntent);

        mNotificationManager.notify(appName, notId, mBuilder.build());
    }

}


