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

#if _SWIZZLED_INIT_
@synthesize coldstart;
#endif

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


- (void)getPlatformInfo:(CDVInvokedUrlCommand*)command
{
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
    
#if _SWIZZLED_INIT_
    [devProps setObject:[NSNumber numberWithBool:[self coldstart]] forKey:@"coldstart"];
#endif
    
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    [devProps setObject:[dateFormatter stringFromDate:[NSDate date]] forKey:@"launchTimeUtc"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:devProps];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registerForPush:(CDVInvokedUrlCommand*)command
{    
    NSLog(@"Donky::registerForPush");
    
    self.callbackId = command.callbackId;
    
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
    
    // CDVPluginResult* result = [CDVPluginResult resultWithStatus: !error ? CDVCommandStatus_OK : CDVCommandStatus_ERROR messageAsString:errorMessage];
    // [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) unregisterForPush:(CDVInvokedUrlCommand*)command
{
    self.callbackId = command.callbackId;

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
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
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
        NSLog(@"handleDeepLink: Opening link: %@", linkValue);
        
        pluginResult = [[UIApplication sharedApplication] openURL:url] ? [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] : [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setPushOptions:(CDVInvokedUrlCommand*)command;
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];    
}

- (void)notificationReceived:(NSDictionary *)notificationMessage;
{
    NSLog(@"Notification received: %@", notificationMessage);
    
    // send notification message
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:notificationMessage];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
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


#if _HANDLE_USER_ACTIVITY_
- (BOOL)handleUserActivity:(NSUserActivity *)userActivity {
    
    NSURL *launchURL = userActivity.webpageURL;

    NSLog(@"%@", launchURL);
    
    return NO;
}
#endif

@end