#import "Donky.h"
#import "DNKeychainHelper.h"
#import "PushHelper.h"


static NSString *const DNDeviceID = @"DeviceID"; 

@implementation Donky

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
    
    if ([PushHelper systemVersionAtLeast:8.0]) {
        NSMutableSet *buttonSets = [PushHelper buttonsAsSets: nil];
        [PushHelper addCategoriesToRemoteNotifications:buttonSets];
    }
    else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge];
    }
    

    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK ];

    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

@end