#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PushHelper : NSObject

/*!
 Helper method to determine if the version of iOS currently being used is greater than x
 
 @param version the minimum iOS version.
 
 @return BOOL indicating if the current iOS version is at least the specified version.
 
 @since 2.0.0.0
 */
+ (BOOL)systemVersionAtLeast:(CGFloat) version;

/*!
 Helper method to get a new GUID.
 
 @return a new GUID as a string.
 
 @since 2.0.0.0
 */
+ (NSString *)generateGUID;


+ (NSMutableSet *)buttonsAsSets: (NSArray *)buttons;


+ (UIMutableUserNotificationCategory *)categoryWithFirstButtonTitle:(NSString *)firstButtonTitle firstButtonIdentifier:(NSString *)firstButtonIdentifier firstButtonIsForground:(BOOL)firstButtonForeground secondButtonTitle:(NSString *)secondButtonTitle secondButtonIdentifier:(NSString *)secondButtonIdentifier secondButtonIsForeground:(BOOL)secondButtonForeground andCategoryIdentifier:(NSString *)categoryIdentifier;


/*!
 Helper method to add custom cateogries to the remote notificaiton sets used by the SDK.
 
 @param categories the cateogries that you wish to add to the registered set.
 
 @since 2.6.5.4
 */
+ (void)addCategoriesToRemoteNotifications:(NSMutableSet *)categories;


@end