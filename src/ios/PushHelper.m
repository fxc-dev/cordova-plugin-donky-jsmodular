#import "PushHelper.h"


static NSString *const DNButtonValues = @"buttonValues";


@implementation PushHelper


+ (BOOL)systemVersionAtLeast:(CGFloat)version {
    return [[[UIDevice currentDevice] systemVersion] floatValue] >= version;
}

+ (NSString *)generateGUID {

    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    NSString *guid = (NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, uuidRef));
    CFRelease(uuidRef);

    return guid;
}


+ (NSMutableSet *)buttonsAsSets: (NSArray *)buttons{

//    NSArray *buttons = [DNConfigurationController buttonSets][@"buttonSets"];
    NSMutableSet *buttonSets = [[NSMutableSet alloc] init];
    NSArray *buttonCombinations = @[@"|F|F", @"|F|B", @"|B|F", @"|B|B"];

    [buttonCombinations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *buttonCombination = obj;
        [buttons enumerateObjectsUsingBlock:^(id obj2, NSUInteger idx2, BOOL *stop2) {
            NSDictionary *buttonDict = obj2;
            NSArray *buttonValues = buttonDict[DNButtonValues];
            [buttonSets addObject:[PushHelper categoryWithFirstButtonTitle:[buttonValues firstObject]
                                                                    firstButtonIdentifier:[buttonValues firstObject]
                                                                    firstButtonIsForground:idx != 2 && idx != 3
                                                                        secondButtonTitle:[buttonValues lastObject]
                                                                    secondButtonIdentifier:[buttonValues lastObject]
                                                                secondButtonIsForeground:idx != 1 && idx != 3
                                                                    andCategoryIdentifier:[buttonDict[@"buttonSetId"] stringByAppendingString:buttonCombination]]];
        }];
    }];

    return buttonSets;

}


+ (UIMutableUserNotificationCategory *)categoryWithFirstButtonTitle:(NSString *)firstButtonTitle firstButtonIdentifier:(NSString *)firstButtonIdentifier firstButtonIsForground:(BOOL)firstButtonForeground secondButtonTitle:(NSString *)secondButtonTitle secondButtonIdentifier:(NSString *)secondButtonIdentifier secondButtonIsForeground:(BOOL)secondButtonForeground andCategoryIdentifier:(NSString *)categoryIdentifier {

    UIMutableUserNotificationAction *firstAction = [[UIMutableUserNotificationAction alloc] init];
    [firstAction setTitle:firstButtonTitle];
    [firstAction setIdentifier:firstButtonIdentifier];
    [firstAction setActivationMode:firstButtonForeground ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground];
    [firstAction setDestructive:NO];
    [firstAction setAuthenticationRequired:NO];

    UIMutableUserNotificationAction *secondAction = [[UIMutableUserNotificationAction alloc] init];
    [secondAction setTitle:secondButtonTitle];
    [secondAction setIdentifier:secondButtonIdentifier];
    [secondAction setActivationMode:secondButtonForeground ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground];
    [secondAction setDestructive:NO];
    [secondAction setAuthenticationRequired:NO];

    UIMutableUserNotificationCategory *notificationCategory = [[UIMutableUserNotificationCategory alloc] init];
    [notificationCategory setIdentifier:categoryIdentifier];
    [notificationCategory setActions:@[secondAction, firstAction] forContext:UIUserNotificationActionContextDefault];
    [notificationCategory setActions:@[secondAction, firstAction] forContext:UIUserNotificationActionContextMinimal];

    return notificationCategory;

}


+ (void)addCategoriesToRemoteNotifications:(NSMutableSet *)categories {
    
    if (![PushHelper systemVersionAtLeast:8.0]) {
        NSLog(@"Can only add categories in iOS 8.0 and above...");
        return;
    }
    
    NSSet *existingCategories = [[[UIApplication sharedApplication] currentUserNotificationSettings] categories];
    
    NSMutableSet *newCategories = [[NSMutableSet alloc] initWithSet:existingCategories];
    
    [categories enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        [existingCategories enumerateObjectsUsingBlock:^(id  _Nonnull obj2, BOOL * _Nonnull stop2) {
            UIMutableUserNotificationCategory *existingCategory = obj2;
            if ([[existingCategory identifier] isEqualToString:[obj identifier]]) {
                *stop2 = YES;
                [newCategories removeObject:obj];
            }
        }];
        [newCategories addObject:obj];
    }];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings
                                                                         settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge)
                                                                         categories:newCategories]];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
}


@end