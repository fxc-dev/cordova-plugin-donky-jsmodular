package com.donky.plugin;

import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
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

            Boolean isInForeground = DonkyPlugin.isInForeground();
            Boolean isActive = DonkyPlugin.isActive(); 

            extras.putString("isInForeground", isInForeground ? "Yes" : "No");
            extras.putString("isActive", isActive ? "Yes" : "No");

            if(isInForeground){

                DonkyPlugin.sendExtras(extras);

            }else{
                createNotification(getApplicationContext(), extras);
            }

        }
    }

    private PendingIntent getPendingIntentForRichMessage(int notificationId, Bundle extras) {
        Intent intent = new Intent(this, PushIntentService.class);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.HONEYCOMB_MR1) {
            intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        }
        
        intent.putExtra(PUSH_BUNDLE, extras);
        intent.putExtra(NOTIFICATION_ID, notificationId);

        intent.putExtra("messageType", "Rich");

        intent.setAction(PushIntentService.ACTION_OPEN_RICH_MESSAGE);
        
        return PendingIntent.getService(this.getApplicationContext(), new Random().nextInt(), intent, PendingIntent.FLAG_UPDATE_CURRENT );
    }


    private PendingIntent getPendingIntentForSimplePushAction(int notificationId, Bundle extras, JSONObject buttonSetAction) {

        Intent intent = new Intent(this, PushIntentService.class);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.HONEYCOMB_MR1) {
            intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        }

        intent.putExtra(PUSH_BUNDLE, extras);
        intent.putExtra(NOTIFICATION_ID, notificationId);

        intent.putExtra("messageType", "SimplePush");

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
        Resources resources = context.getResources();
        String environment = sharedPref.getString("environment", "");
        Boolean vibrate = sharedPref.getBoolean("vibrate", true);
        String icon = sharedPref.getString("icon", "");
        String iconColor = sharedPref.getString("iconColor", "");

        Log.d(LOG_TAG, "SharedPreferences::environment = " + environment);
        Log.d(LOG_TAG, "SharedPreferences::vibrate = " + vibrate);
        Log.d(LOG_TAG, "SharedPreferences::icon = " + icon);
        Log.d(LOG_TAG, "SharedPreferences::iconColor = " + iconColor);

        int notificationId = extras.get("notificationId").hashCode();

        Log.d(LOG_TAG, "notificationId = " + notificationId);

        String payload = (String) extras.get("payload");

        Log.d(LOG_TAG, "payload = " + payload);

        String messageType = "";
        String body = "";
        String senderDisplayName = "";
        String avatarAssetId = "";
        String interactionType = "";
        Boolean canDisplay = false;

        JSONArray buttonSets = null;
        JSONArray buttonSetActions = null;

        try {
            JSONObject jsonObj = new JSONObject(payload);
            messageType =jsonObj.optString("messageType");

            senderDisplayName = jsonObj.optString("senderDisplayName");
            avatarAssetId = jsonObj.optString("avatarAssetId", null);

            if(messageType.equals("Rich")){
                body = jsonObj.optString("description");
                canDisplay = true;
            }
            else if(messageType.equals("SimplePush")){
                body = jsonObj.optString("body");

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

                canDisplay = true;
            }

        } catch (JSONException e) {
            e.printStackTrace();
        }

        Log.d(LOG_TAG, "body = " + body);
        Log.d(LOG_TAG, "senderDisplayName = " + senderDisplayName);

        if(canDisplay){

            NotificationManager mNotificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            String appName = (String) context.getPackageManager().getApplicationLabel(context.getApplicationInfo());

            NotificationCompat.Builder mBuilder =
                    new NotificationCompat.Builder(context)
                            .setWhen(System.currentTimeMillis())
                            .setContentTitle(senderDisplayName)
                            .setTicker(senderDisplayName);

            // generic stuff ...
            if(vibrate){
                mBuilder.setDefaults(Notification.DEFAULT_VIBRATE);
            }

            int iconId = 0;
            if (icon != null && !"".equals(icon)) {
                iconId = resources.getIdentifier(icon, DRAWABLE, context.getPackageName());
                Log.d(LOG_TAG, "using icon from plugin options");
            }
            if (iconId == 0) {
                Log.d(LOG_TAG, "no icon resource found - using application icon");
                iconId = context.getApplicationInfo().icon;
            }
            mBuilder.setSmallIcon(iconId);

            int _iconColor = 0;
            if (iconColor != null && !"".equals(iconColor)) {
                try {
                    _iconColor = Color.parseColor(iconColor);
                } catch (IllegalArgumentException e) {
                    Log.e(LOG_TAG, "couldn't parse color from android options");
                }
            }
            if (_iconColor != 0) {
                mBuilder.setColor(_iconColor);
            }

            mBuilder.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI);

            mBuilder.setContentText(body);

            mBuilder.setNumber(0);

            if(avatarAssetId != ""){
                mBuilder.setLargeIcon(getBitmapFromURL("https://" + environment + "client-api.mobiledonky.com/asset/" + avatarAssetId));
            }
            

            // message type specifics ...

            if(messageType.equals("SimplePush")){

                // one button ?

                JSONObject buttonSetActionForOneButton = null;

                if(interactionType.equals("OneButton")){

                    try {
                        buttonSetActionForOneButton = buttonSetActions.getJSONObject(0);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }

                PendingIntent contentIntent = getPendingIntentForSimplePushAction( notificationId, extras, buttonSetActionForOneButton );

                mBuilder.setContentIntent(contentIntent);

                if(interactionType.equals("TwoButton")) {
                    try {

                        if(buttonSetActions!=null){
                            for(int j = 0 ; j < buttonSetActions.length() ; j++){

                                JSONObject buttonSetAction = buttonSetActions.getJSONObject(j);

                                String label = buttonSetAction.optString("label");

                                PendingIntent actionIntent = getPendingIntentForSimplePushAction( notificationId, extras, buttonSetAction );

                                mBuilder.addAction(android.R.color.transparent, label, actionIntent);

                            }
                        }

                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }


            }else if(messageType.equals("Rich")){

                PendingIntent contentIntent = getPendingIntentForRichMessage( notificationId, extras );

                mBuilder.setContentIntent(contentIntent);

            }

            mNotificationManager.notify(notificationId, mBuilder.build());
        }

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


