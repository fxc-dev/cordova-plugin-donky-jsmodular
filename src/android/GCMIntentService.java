package com.donky.plugin;

import android.annotation.SuppressLint;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.gcm.GcmListenerService;



@SuppressLint("NewApi")
public class GCMIntentService extends GcmListenerService implements PushConstants {

    private static final String LOG_TAG = "DonkyPlugin";


    /**
     * Constructor.
     */
    public GCMIntentService(){

    }


    @Override
    public void onMessageReceived(String from, Bundle extras) {
        Log.d(LOG_TAG, "onMessage - from: " + from);

        if (extras != null) {


        }
    }
}


