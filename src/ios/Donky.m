#import "Donky.h"
#import "DNKeychainHelper.h"
#import "PushHelper.h"


static NSString *const DNDeviceID = @"DeviceID"; 

@implementation Donky

static UIWebView* webView;

- (void) pluginInitialize;
{
    NSLog(@"DonkyPlugin:pluginInitialize");
    
    if (self.webViewEngine != nil) {
        webView = (UIWebView *)self.webViewEngine.engineWebView;
    }
}

- (void)greet:(CDVInvokedUrlCommand*)command
{

    NSString* name = [[command arguments] objectAtIndex:0];
    NSString* msg = [NSString stringWithFormat: @"Hello, %@", name];

    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK
                               messageAsString:msg];

    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)deviceId:(CDVInvokedUrlCommand*)command
{
    NSString *deviceId = [DNKeychainHelper objectForKey:DNDeviceID];
    
    NSLog(@"DNKeychainHelper returned deviceId: %@", deviceId);
    
    if(deviceId == nil){
        deviceId = [PushHelper generateGUID];
        NSLog(@"Created a new GUID for the deviceId : %@", deviceId);
        [DNKeychainHelper saveObjectToKeychain:deviceId withKey:DNDeviceID];
    }  

    NSLog(@"returning deviceId: %@", deviceId);

    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK
                               messageAsString:deviceId];

    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)registerForPush:(CDVInvokedUrlCommand*)command
{    
    NSLog(@"registerForPush");
    
    BOOL error = FALSE;
    NSString *errorMessage = nil;
    
    
    if ([PushHelper systemVersionAtLeast:8.0]) {
        
        NSLog(@"systemVersion >= 8.0");
        
        int count = [[command arguments] count];
        
        if(count == 1){
            NSLog(@"Arg count == 1");
            
            NSString* buttonSetsJson = [[command arguments] objectAtIndex:0];
            
            NSData *jsonData = [buttonSetsJson dataUsingEncoding:NSUTF8StringEncoding];
            
            NSError *jsonError;
            
            id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options: NSJSONReadingMutableContainers error:&jsonError];
            
            if (!jsonError) {
                if ([jsonObject isKindOfClass:[NSArray class]]) {
                    NSArray *shizz = (NSArray *)jsonObject;
                    //NSLog(@"You got your shit here: %@", shizz);
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

+ (void) notify:(NSString *)event withData:(NSString *)data
{
    
    if(webView){
        NSString* jsString = [NSString stringWithFormat:@"window.donky.callback(\'%@\',\'%@\');", event, data];
        
        NSLog(@"%@", jsString);
        
        
        if ([webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
            // Cordova-iOS pre-4
            [webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
        } else {
            // Cordova-iOS 4+
            [webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsString waitUntilDone:NO];
        }
    }
    
}


@end