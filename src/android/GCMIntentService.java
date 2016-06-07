package com.donky.plugin;

import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.gcm.GcmListenerService;
import com.lepojevic.pushtest.R;

import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Random;

import android.app.Notification;
import android.app.NotificationManager;

import android.content.Context;

import android.support.v4.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;


public class GCMIntentService extends GcmListenerService implements PushConstants {

    private static final String LOG_TAG = "DonkyPlugin";

    /**
     *
     * @param from
     * @param extras
     */
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

    private PendingIntent getPendingIntentForAction(int notificationId, Bundle extras, JSONObject buttonSetAction) {

        Intent intent = new Intent(this, PushIntentService.class);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.HONEYCOMB_MR1) {
            intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        }

        intent.putExtra(PUSH_BUNDLE, extras);
        intent.putExtra(NOTIFICATION_ID, notificationId);

        if(buttonSetAction != null){

            String actionType = buttonSetAction.optString("actionType");
            String label = buttonSetAction.optString("label");

            intent.putExtra("ButtonLabel", label);

            if(actionType.equals("DeepLink")){
                intent.setAction(PushIntentService.ACTION_OPEN_DEEP_LINK);
                String deepLinkData = buttonSetAction.optString("data");
                intent.putExtra("DeepLinkData", deepLinkData);
                Log.d(LOG_TAG, "DeepLinkData = " + deepLinkData);
            }else if(actionType.equals("Dismiss")){
                intent.setAction(PushIntentService.ACTION_CANCEL_NOTIFICATION);
            }else if(actionType.equals("Open")){
                intent.setAction(PushIntentService.ACTION_OPEN_APPLICATION);
            }

        }
        else
        {
            intent.setAction(PushIntentService.ACTION_OPEN_APPLICATION);
        }

        return PendingIntent.getService(this.getApplicationContext(), new Random().nextInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT );
    }


    /**
     *
     * @param context
     * @param extras
     */
    public void createNotification(Context context, Bundle extras) {

        SharedPreferences sharedPref = getApplicationContext().getSharedPreferences(COM_DONKY_PLUGIN, Context.MODE_PRIVATE);

        String environment = sharedPref.getString("environment", "");
        Boolean vibrate = sharedPref.getBoolean("vibrate", true);
        Integer iconId = sharedPref.getInt("iconId", 0);
        String iconColor = sharedPref.getString("iconColor", "");

        Log.d(LOG_TAG, "SharedPreferences::environment = " + environment);
        Log.d(LOG_TAG, "SharedPreferences::vibrate = " + vibrate);
        Log.d(LOG_TAG, "SharedPreferences::iconId = " + iconId);
        Log.d(LOG_TAG, "SharedPreferences::iconColor = " + iconColor);


        int notificationId = extras.get("notificationId").hashCode();

        Log.d(LOG_TAG, "notificationId = " + notificationId);

        String payload = (String) extras.get("payload");

        Log.d(LOG_TAG, "payload = " + payload);

        String body = "";
        String senderDisplayName = "";
        String avatarAssetId = "";
        String interactionType = "";

        JSONArray buttonSets = null;
        JSONArray buttonSetActions = null;

        try {
            JSONObject jsonObj = new JSONObject(payload);
            body = jsonObj.optString("body");
            senderDisplayName = jsonObj.optString("senderDisplayName");
            avatarAssetId = jsonObj.optString("avatarAssetId", null);

            buttonSets = jsonObj.optJSONArray("buttonSets");

            if(buttonSets != null){
                // need to search for JSONObject that has property platform: "Mobile"

                for(int i = 0 ; i < buttonSets.length(); i++){

                    JSONObject buttonSet = buttonSets.getJSONObject(i);

                    String platform = buttonSet.optString("platform");

                    if(platform.equals("Mobile")){

                        interactionType = buttonSet.optString("interactionType");

                        buttonSetActions = buttonSet.optJSONArray("buttonSetActions");

                    }
                }
            }

        } catch (JSONException e) {
            e.printStackTrace();
        }

        Log.d(LOG_TAG, "body = " + body);
        Log.d(LOG_TAG, "senderDisplayName = " + senderDisplayName);

        NotificationManager mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String appName = (String) context.getPackageManager().getApplicationLabel(context.getApplicationInfo());

        // one button

        JSONObject buttonSetActionForOneButton = null;

        if(interactionType.equals("OneButton")){

            try {
                buttonSetActionForOneButton = buttonSetActions.getJSONObject(0);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }

        PendingIntent contentIntent = getPendingIntentForAction( notificationId, extras, buttonSetActionForOneButton );


        NotificationCompat.Builder mBuilder =
                new NotificationCompat.Builder(context)
                        .setWhen(System.currentTimeMillis())
                        .setContentTitle(senderDisplayName)
                        .setTicker(senderDisplayName)
                        .setContentIntent(contentIntent);
                        //.setAutoCancel(true);

        mBuilder.setDefaults(Notification.DEFAULT_VIBRATE);

        int smallIconId = R.drawable.ic_stat_notification;

        mBuilder.setSmallIcon(smallIconId);

        mBuilder.setColor(0xff0000FF);

        mBuilder.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI);

        mBuilder.setContentText(body);

        mBuilder.setNumber(0);

        if(interactionType.equals("TwoButton")) {
            try {

                if(buttonSetActions!=null){
                    for(int j = 0 ; j < buttonSetActions.length() ; j++){

                        JSONObject buttonSetAction = buttonSetActions.getJSONObject(j);

                        String label = buttonSetAction.optString("label");

                        PendingIntent actionIntent = getPendingIntentForAction( notificationId, extras, buttonSetAction );

                        mBuilder.addAction(android.R.color.transparent, label, actionIntent);

                    }
                }

            } catch (JSONException e) {
                e.printStackTrace();
            }

        }


        // TODO: need to get this AssetDownloadUrlFormat from somewhere ...
        if(avatarAssetId != ""){
            mBuilder.setLargeIcon(getBitmapFromURL("https://dev-client-api.mobiledonky.com/asset/" + avatarAssetId));
        }

        mNotificationManager.notify(notificationId, mBuilder.build());
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


