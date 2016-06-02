package com.donky.plugin;

import android.app.IntentService;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

public class PushIntentService extends IntentService implements PushConstants{

    private static String LOG_TAG = "PushPlugin";

    /**
     * Action name of intent. Notification described in intent should be canceled.
     */
    static final String ACTION_CANCEL_NOTIFICATION = "com.donky.plugin.push.CANCEL_NOTIFICATION";

    /**
     * Action name of intent. Notification described in intent should be canceled. Main application Activity will be opened.
     */
    static final String ACTION_OPEN_APPLICATION = "com.donky.plugin.push.OPEN";

    /**
     * Action name of intent. Notification described in intent should be canceled. System will try to open activity responding to deep link.
     */
    static final String ACTION_OPEN_DEEP_LINK = "com.donky.plugin.push.DEEP_LINK";


    public PushIntentService() {
        super("PushIntentService");
    }

    @Override
    protected void onHandleIntent(final Intent intent) {

        Bundle extras = intent.getExtras();


        if (extras != null) {
            Bundle originalExtras = extras.getBundle(PUSH_BUNDLE);

            String actionType = extras.getString("actionType");
            String label = extras.getString("label");
            String data = extras.getString("data");

            Log.d(LOG_TAG, "actionType = " + actionType);
            Log.d(LOG_TAG, "label = " + label);
            Log.d(LOG_TAG, "data = " + data);

/*
        if (ACTION_CANCEL_NOTIFICATION.equals(intent.getAction())){

            Log.v(LOG_TAG, ACTION_CANCEL_NOTIFICATION);

        }
        else if(ACTION_OPEN_APPLICATION.equals(intent.getAction())){

            Log.v(LOG_TAG, ACTION_OPEN_APPLICATION);

        }
        else if(ACTION_OPEN_DEEP_LINK.equals(intent.getAction())){

            Log.v(LOG_TAG, ACTION_OPEN_DEEP_LINK);

        }*/
        }
    
    }
}