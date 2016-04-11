#include <sys/types.h>
#include <sys/sysctl.h>

#import "Donky.h"
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


@implementation Donky

static UIWebView* webView;

@synthesize coldstart;

- (void) pluginInitialize;
{
    NSLog(@"Donky::pluginInitialize");
    
    if (self.webViewEngine != nil) {
        webView = (UIWebView *)self.webViewEngine.engineWebView;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPause) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResume) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    /**
     * TODO: is there a stored push notification that needs to be either
     *  [Donky notify: @"pushNotification" withData: dict];
     * or
     *  [Donky notify: @"handleButtonAction" withData: dict]; 
     */
}

- (void) onPause {
    NSLog(@"UIApplicationDidEnterBackgroundNotification");
    [Donky notify: @"AppBackgrounded" withData: nil];
}

- (void) onResume {
    NSLog(@"UIApplicationDidBecomeActiveNotification");
    [Donky notify: @"AppForegrounded" withData: nil];
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
    [devProps setObject:[NSNumber numberWithBool:[self coldstart]] forKey:@"coldstart"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:devProps];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)registerForPush:(CDVInvokedUrlCommand*)command
{    
    NSLog(@"Donky::registerForPush");
    
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
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: !error ? CDVCommandStatus_OK : CDVCommandStatus_ERROR messageAsString:errorMessage];

    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) setBadgeCount:(CDVInvokedUrlCommand*)command; 
{
    NSLog(@"Donky::setBadgeCount");
    NSString* badgeCount = [[command arguments] objectAtIndex:0];
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[badgeCount intValue]];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
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
            NSString* jsString = [NSString stringWithFormat:@"window.cordova.plugins.donky.callback(\'%@\',%@);", event, jsonString];
            
            NSLog(@"%@", jsString);
            
            [Donky executeJavascript: jsString];
            
        }else{
            NSString* jsString = [NSString stringWithFormat:@"window.cordova.plugins.donky.callback(\'%@\');", event];
            
            NSLog(@"%@", jsString);
            
            [Donky executeJavascript: jsString];

        }
    }
    
}



@end