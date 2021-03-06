#include <sys/types.h>
#include <sys/sysctl.h>

#import "DonkyPlugin.h"
#import "DNKeychainHelper.h"
#import "PushHelper.h"
#import "NSDictionary+DNJsonDictionary.h"


static NSString *const DNDeviceID = @"DeviceID";

#define SYSTEM_VERSION_PLIST    @"/System/Library/CoreServices/SystemVersion.plist"

/* Return the string version of the decimal version */
#define CDV_VERSION [NSString stringWithFormat:@"%d.%d.%d", \
(CORDOVA_VERSION_MIN_REQUIRED / 10000),                 \
(CORDOVA_VERSION_MIN_REQUIRED % 10000) / 100,           \
(CORDOVA_VERSION_MIN_REQUIRED % 10000) % 100]


@implementation DonkyPlugin

@synthesize callbackId;
static UIWebView* webView;

@synthesize coldstart;
@synthesize launchNotification;

- (void) pluginInitialize;
{
    NSLog(@"Donky::pluginInitialize");
    
    if (self.webViewEngine != nil) {
        webView = (UIWebView *)self.webViewEngine.engineWebView;
    }
}

- (NSString*)modelVersion
{
    size_t size;
    
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char* machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString* platform = [NSString stringWithUTF8String:machine];
    free(machine);
    
    return platform;
}

+(NSString*) getCurrentTimestamp;
{
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    return [dateFormatter stringFromDate:[NSDate date]];
}


- (void)initialise:(CDVInvokedUrlCommand*)command
{
    
    // Check command.arguments here.
    [self.commandDelegate runInBackground:^{
        
        NSLog(@"Donky::getPlatformInfo");
        NSString *deviceId = [DNKeychainHelper objectForKey:DNDeviceID];
        NSLog(@"DNKeychainHelper returned deviceId: %@", deviceId);
        
        if(deviceId == nil){
            deviceId = [PushHelper generateGUID];
            NSLog(@"Created a new GUID for the deviceId : %@", deviceId);
            [DNKeychainHelper saveObjectToKeychain:deviceId withKey:DNDeviceID];
        }
        
        UIDevice* device = [UIDevice currentDevice];
        NSMutableDictionary* devProps = [[NSMutableDictionary alloc] init];
        
        [devProps setObject:@"Apple" forKey:@"manufacturer"];
        [devProps setObject:[self modelVersion] forKey:@"model"];
        [devProps setObject:@"iOS" forKey:@"platform"];
        [devProps setObject:[device systemVersion] forKey:@"version"];
        [devProps setObject:CDV_VERSION forKey:@"cordova"];
        [devProps setObject:[[NSBundle mainBundle] bundleIdentifier] forKey:@"bundleId"];
        [devProps setObject:deviceId forKey:@"deviceId"];
        
        [devProps setObject:[NSNumber numberWithBool:[self coldstart]] forKey:@"coldstart"];
        if([self launchNotification] != nil){
            
            NSLog(@"DonkyPlugin::initialise launchNotification=%@", launchNotification);
            
            NSString *inttype = [launchNotification objectForKey:@"inttype"];
            
            NSLog(@"inttype: %@", inttype);
            
            NSString *notificationId = [launchNotification objectForKey:@"notificationId"];
            
            NSString *notificationType = [launchNotification objectForKey:@"notificationType"];
            
            if([notificationType isEqualToString:@"SIMPLEPUSHMSG"]){
                
                // need to determine whether this notification is interactive or not first ...
                if([inttype isEqualToString:@"OneButton"]){
                    NSLog(@"OneButton push ;-)");
                    NSString *label = [launchNotification objectForKey:@"lbl1"];
                    NSString *action = [launchNotification objectForKey:@"act1"];
                    NSString *link1 = [launchNotification objectForKey:@"link1"];
                    
                    [self addColdstartNotification: notificationId : notificationType:label :action];
                    
                    // if we have a 1 button push that is supposed to open a deep link, should I process it here of give it to the app to deal with ?
                    if([action isEqualToString:@"DeepLink"]){
                        
                        if(link1 != nil && ![link1 isKindOfClass:[NSNull class]])
                        {
                            NSURL *url = [NSURL URLWithString:link1];
                            [DonkyPlugin openDeepLink: url];
                        }
                    }
                    
                }else{
                    [self addColdstartNotification: notificationId :notificationType :nil :nil];
                }
                
                
            }else{
                [self addColdstartNotification: notificationId :notificationType :nil :nil];                
            }
            [devProps setObject:[self launchNotification] forKey:@"launchNotification"];
        }
        
        NSString * coldstartNotifications = [[NSUserDefaults standardUserDefaults] stringForKey:@"coldstartNotifications"];
        
        NSLog(@"Setting coldstartNotifications to %@", coldstartNotifications);
        
        [devProps setObject:coldstartNotifications != nil ? coldstartNotifications : @"" forKey:@"coldstartNotifications"];
        
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"coldstartNotifications"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        
        [devProps setObject:[DonkyPlugin getCurrentTimestamp] forKey:@"launchTimeUtc"];
        
        NSLog(@"DonkyPlugin::initialise devProps=%@", devProps);
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:devProps];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    
    
}

- (void)hasPermission:(CDVInvokedUrlCommand *)command
{
    BOOL enabled = NO;
    id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
    if ([appDelegate respondsToSelector:@selector(userHasRemoteNotificationsEnabled)]) {
        enabled = [appDelegate performSelector:@selector(userHasRemoteNotificationsEnabled)];
    }
    
    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
    [message setObject:[NSNumber numberWithBool:enabled] forKey:@"isEnabled"];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)registerForPush:(CDVInvokedUrlCommand*)command
{
    NSLog(@"Donky::registerForPush");
    
    self.callbackId = command.callbackId;
    
    // Check command.arguments here.
    [self.commandDelegate runInBackground:^{
        
        BOOL error = FALSE;
        NSString *errorMessage = nil;
        
        if ([PushHelper systemVersionAtLeast:8.0]) {
            
            NSLog(@"systemVersion >= 8.0");
            
            NSUInteger count = [[command arguments] count];
            
            if(count == 1){
                NSLog(@"Arg count == 1");
                
                NSString* buttonSetsJson = [[command arguments] objectAtIndex:0];
                
                NSData *jsonData = [buttonSetsJson dataUsingEncoding:NSUTF8StringEncoding];
                
                NSError *jsonError;
                
                id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options: NSJSONReadingMutableContainers error:&jsonError];
                
                if (!jsonError) {
                    if ([jsonObject isKindOfClass:[NSArray class]]) {
                        NSArray *shizz = (NSArray *)jsonObject;
                        
                        NSMutableSet *buttonSets = [PushHelper buttonsAsSets: shizz];
                        [PushHelper addCategoriesToRemoteNotifications:buttonSets];
                        
                    }else{
                        error = TRUE;
                        errorMessage = @"jsonData not an array";
                    }
                }else{
                    error = TRUE;
                    errorMessage = [NSString stringWithFormat:@"jsonError: %@", jsonError];
                }
                
            }else{
                error = TRUE;
                NSLog(@"Arg count != 1 : #FAIL");
                errorMessage = @"No button sets specified ;-(";
            }
            
        }
        else {
            NSLog(@"systemVersion < 8.0");
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge];
        }
        
        NSLog(@"error = %d", error);
        
        
    }];
}


- (void) unregisterForPush:(CDVInvokedUrlCommand*)command
{
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"unregistered"];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if (self.callbackId == nil) {
        NSLog(@"Unexpected call to didRegisterForRemoteNotificationsWithDeviceToken, ignoring: %@", deviceToken);
        return;
    }
    
    NSLog(@"Push Plugin register success: %@", deviceToken);
    
    NSMutableString *hexString = nil;
    if (deviceToken) {
        const unsigned char *dataBuffer = (const unsigned char *) [deviceToken bytes];
        
        NSUInteger dataLength = [deviceToken length];
        hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
        
        for (int i = 0; i < dataLength; ++i) {
            [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long) dataBuffer[i]]];
        }
    }
    
    NSDictionary *message = [[NSDictionary alloc] initWithObjectsAndKeys: hexString, @"deviceToken", nil];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}


- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    if (self.callbackId == nil) {
        NSLog(@"Unexpected call to didFailToRegisterForRemoteNotificationsWithError, ignoring: %@", error);
        return;
    }
    
    NSDictionary *message = [[NSDictionary alloc] initWithObjectsAndKeys: [error localizedDescription], @"message", nil];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    
}

- (void)didRegisterUserNotificationSettings:(nonnull UIUserNotificationSettings *)notificationSettings{
    
    if (notificationSettings.types) {
        NSLog(@"user allowed notifications");
    }else{
        NSLog(@"user did not allow notifications");
    }
}



- (void) setBadgeCount:(CDVInvokedUrlCommand*)command;
{
    NSLog(@"Donky::setBadgeCount");
    NSString* badgeCount = [[command arguments] objectAtIndex:0];
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[badgeCount intValue]];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    
}

- (void)openDeepLink:(CDVInvokedUrlCommand*)command;
{
    NSString* linkValue = [[command arguments] objectAtIndex:0];
    CDVPluginResult* pluginResult = nil;
    
    if(linkValue != nil && ![linkValue isKindOfClass:[NSNull class]])
    {
        NSURL *url = [NSURL URLWithString:linkValue];
        
        Boolean canOpen = [DonkyPlugin openDeepLink: url];
        
        pluginResult = canOpen ? [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] : [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

+ (Boolean)openDeepLink:(NSURL*)url;
{
    NSLog(@"handleDeepLink: Opening link: %@", url);
    
    Boolean canOpen = [[UIApplication sharedApplication] canOpenURL:url];
    
    if (canOpen) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:url];
        });
    }
    else {
        NSLog(@"Cannot open URL: %@", url);
    }
    
    return canOpen;
}

- (void)notificationReceived:(NSDictionary *)notificationMessage;
{
    if (self.callbackId == nil) {
        NSLog(@"Unexpected call to notificationReceived, ignoring: %@", notificationMessage);
        return;
    }
    
    NSLog(@"Notification received: %@", notificationMessage);
    
    // send notification message
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:notificationMessage];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    UIApplicationState state =[[UIApplication sharedApplication] applicationState];
    
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: identifier, @"identifier", userInfo, @"userInfo", @(state), @"applicationState", [DonkyPlugin getCurrentTimestamp], @"clicked", nil];
    
    /**
     * Need 3 different behaviours here
     */
    
    switch([[UIApplication sharedApplication] applicationState]){
        case UIApplicationStateActive:
            break;
            
        case UIApplicationStateInactive:
            // dismissedNotifications can be passed back when init is called
            break;
            
        case UIApplicationStateBackground:
            // dismissedNotifications can be passed when app resumes ?
            // not sure I need to do anything here as the JS handleButtonAction code simply sends the analytics result (doesn't display anything)
            break;
    }
    
    if([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive){
        
        NSString* action;
        NSString* link;
        NSString* label;
        
        NSString *inttype = [userInfo objectForKey:@"inttype"];
        
        NSString *notificationId = [userInfo objectForKey:@"notificationId"];
        NSString *notificationType = [userInfo objectForKey:@"notificationType"];
        
        
        if([inttype isEqualToString:@"TwoButton"])
        {
            NSString *act1 = [userInfo objectForKey:@"act1"];
            NSString *act2 = [userInfo objectForKey:@"act2"];
            
            NSString *lbl1 =[userInfo objectForKey:@"lbl1"];
            NSString *lbl2 = [userInfo objectForKey:@"lbl2"];
            
            NSString *link1 =[userInfo objectForKey:@"link1"];
            NSString *link2 = [userInfo objectForKey:@"link2"];
            
            
            if([identifier isEqualToString:lbl1]){
                // button 1 clicked
                NSLog(@"%@ => %@", lbl1, act1);
                action = act1;
                link = link1;
                label = lbl1;
                
            }else{
                // button 2 clicked
                NSLog(@"%@ => %@", lbl2, act2);
                action = act2;
                link = link2;
                label = lbl2;
            }
        }
        
        [self addColdstartNotification: notificationId :notificationType :label :action];
        
        
        if([action isEqualToString:@"DeepLink"]){
            
            // dismissedNotifications needs to be renamed to processedNotifications as we want the same behaviour for
            
            if(link != nil && ![link isKindOfClass:[NSNull class]])
            {
                NSURL *url = [NSURL URLWithString:link];
                
                [DonkyPlugin openDeepLink: url];
            }
            
        }
    }
    
    // NOTE: if I call this when the app is in state UIApplicationStateBackground, it fires when resumed ...
    
    if([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground){
        [DonkyPlugin notify: @"handleButtonAction" withData: dict];
    }
    
    
}


// {"notificationId": "", "label": "dismiss", "action": "D"}|
- (void) addColdstartNotification :(NSString *)notificationId :(NSString *) notificationType :(NSString *) label :(NSString *) action{
    
    NSString *savedColdstartNotifications = [[NSUserDefaults standardUserDefaults] stringForKey:@"coldstartNotifications"];
    
    NSString *json;
    
    if(label!=nil){
        json = [NSString stringWithFormat:@"{\"notificationId\":\"%@\",\"notificationType\":\"%@\",\"label\":\"%@\",\"action\":\"%@\", \"clicked\":\"%@\"}", notificationId, notificationType, label, action, [DonkyPlugin getCurrentTimestamp]];
    }else{
        json = [NSString stringWithFormat:@"{\"notificationId\":\"%@\",\"notificationType\":\"%@\", \"clicked\":\"%@\"}", notificationId, notificationType, [DonkyPlugin getCurrentTimestamp]];
    }
    
    NSLog(@"addColdstartNotification: %@", json);
    
    NSString *valueToSave;
    
    if(savedColdstartNotifications != nil && ![savedColdstartNotifications isEqualToString:@""]){
        valueToSave = [NSString stringWithFormat:@"%@%@|", savedColdstartNotifications, json];
    }else{
        valueToSave = [NSString stringWithFormat:@"%@|", json];
    }
    
    NSLog(@"coldstartNotifications: %@", valueToSave);
    
    [[NSUserDefaults standardUserDefaults] setObject:valueToSave forKey:@"coldstartNotifications"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
}


+ (void) executeJavascript:(NSString *)jsString{
    
    if ([webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        // Cordova-iOS pre-4
        [webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
    } else {
        // Cordova-iOS 4+
        [webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsString waitUntilDone:NO];
    }
    
}


+ (void) notify:(NSString *)event withData:(NSDictionary *)data
{
    NSLog(@"Donky::notify");
    
    if(webView){
        
        NSString *jsonString = [data jsonString];
        
        if(jsonString){
            NSString* jsString = [NSString stringWithFormat:@"window.cordova.plugins.donkyPlugin.callback(\'%@\',%@);", event, jsonString];
            
            NSLog(@"%@", jsString);
            
            [DonkyPlugin executeJavascript: jsString];
            
        }else{
            NSString* jsString = [NSString stringWithFormat:@"window.cordova.plugins.donkyPlugin.callback(\'%@\');", event];
            
            NSLog(@"%@", jsString);
            
            [DonkyPlugin executeJavascript: jsString];
            
        }
    }
    
}


@end