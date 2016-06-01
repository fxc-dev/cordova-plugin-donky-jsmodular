package com.donky.plugin;

import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.gcm.GcmListenerService;

import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Random;

import android.app.Notification;
import android.app.NotificationManager;

import android.content.Context;
import android.content.res.Resources;

import android.support.v4.app.NotificationCompat;

import org.json.JSONException;
import org.json.JSONObject;


public class GCMIntentService extends GcmListenerService implements PushConstants {

    private static final String LOG_TAG = "DonkyPlugin";

    @Override
    public void onMessageReceived(String from, Bundle extras) {
        Log.d(LOG_TAG, "onMessage - from: " + from);

        if (extras != null) {

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


        String payload = (String) extras.get("payload");

        Log.d(LOG_TAG, "payload = " + payload);

        String body = "";
        String senderDisplayName = "";
        String avatarAssetId = "";

        try {
            JSONObject jsonObj = new JSONObject(payload);
            body = jsonObj.optString("body");
            senderDisplayName = jsonObj.optString("senderDisplayName");
            avatarAssetId = jsonObj.optString("avatarAssetId", null);

        } catch (JSONException e) {
            e.printStackTrace();
        }

        Log.d(LOG_TAG, "body = " + body);
        Log.d(LOG_TAG, "senderDisplayName = " + senderDisplayName);


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
                        .setContentTitle(senderDisplayName)
                        .setTicker(senderDisplayName)
                        .setContentIntent(contentIntent);

        mBuilder.setDefaults(Notification.DEFAULT_VIBRATE);

        mBuilder.setSmallIcon(context.getApplicationInfo().icon);

        mBuilder.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI);

        mBuilder.setContentText(body);

        mBuilder.setNumber(0);
        
        // mBuilder.addAction(android.R.color.transparent, "Yes", contentIntent);
        
        // mBuilder.addAction(android.R.color.transparent, "No", contentIntent);

        // TODO: need to get this AssetDownloadUrlFormat from somewhere ...
        if(avatarAssetId != ""){
            mBuilder.setLargeIcon(getBitmapFromURL("https://dev-client-api.mobiledonky.com/asset/" + avatarAssetId));
        }

        mNotificationManager.notify(appName, notId, mBuilder.build());
    }

    /**
     *
     * @param strURL
     * @return
     */
    public Bitmap getBitmapFromURL(String strURL) {
        try {
            URL url = new URL(strURL);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setDoInput(true);
            connection.connect();
            InputStream input = connection.getInputStream();
            return BitmapFactory.decodeStream(input);
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
    }

}


