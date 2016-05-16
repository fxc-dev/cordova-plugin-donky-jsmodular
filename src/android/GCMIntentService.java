package com.donky.plugin;

import android.annotation.SuppressLint;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.gcm.GcmListenerService;

import java.util.Iterator;



@SuppressLint("NewApi")
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

            DonkyPlugin.sendExtras(extras);

        }
    }
}


