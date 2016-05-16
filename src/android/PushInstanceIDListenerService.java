package com.donky.plugin;

import com.google.android.gms.iid.InstanceIDListenerService;

public class PushInstanceIDListenerService extends InstanceIDListenerService {
    
    /*
        Called when the system determines that the tokens need to be refreshed. The application should call getToken() and send the tokens to all application servers.
        This will not be called very frequently, it is needed for key rotation and to handle special cases.
        The system will throttle the refresh event across all devices to avoid overloading application servers with token updates.    
     */
    @Override
    public void onTokenRefresh() {
        // TODO: get anothere token and pass back to JS plugin ...
        //  - 
    }

}
