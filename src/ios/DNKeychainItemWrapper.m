//
//  DNKeychainItemWrapper.m
//  NAAS Core SDK Container
//
//  Created by Donky Networks on 19/02/2015.
//  Copyright (c) 2015 Donky Networks Ltd. All rights reserved.
//

#if !__has_feature(objc_arc)
#error Donky SDK must be built with ARC.
// You can turn on ARC for only Donky Class files by adding -fobjc-arc to the build phase for each of its files.
#endif

#import "DNKeychainItemWrapper.h"

@interface DNKeychainItemWrapper ()

@end

@implementation DNKeychainItemWrapper

+ (NSMutableDictionary *)genericPasswordQueryWithKey:(NSString *)key {

    NSMutableDictionary *genericQuery = [[NSMutableDictionary alloc] init];
    genericQuery[(__bridge id) kSecClass] = (__bridge id) kSecClassGenericPassword;
    genericQuery[(__bridge id) kSecAttrService] = key;
    genericQuery[(__bridge id) kSecAttrAccount] = key;

    return genericQuery;
}

+ (id)keychainDataForKey:(NSString *)key {

    CFMutableDictionaryRef outDictionary = nil;
    OSStatus keychainErr = SecItemCopyMatching((__bridge CFDictionaryRef)[DNKeychainItemWrapper genericPasswordQueryWithKey:key],
                                      (CFTypeRef *)&outDictionary);
    
    if (keychainErr == noErr) {
        CFDataRef passwordData = NULL;
        
        NSMutableDictionary *query = [DNKeychainItemWrapper genericPasswordQueryWithKey:key];
        query[(__bridge id) kSecMatchLimit] = (__bridge id) kSecMatchLimitOne;
        query[(__bridge id) kSecReturnData] = (__bridge id) kCFBooleanTrue;
        
        OSStatus keychainError = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                            (CFTypeRef *)&passwordData);
        if (outDictionary) {
            CFRelease(outDictionary);
        }

        if (!keychainError) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData * _Nonnull)(passwordData)];
        }
        else {
            return nil;
        }
    } else if (keychainErr == errSecItemNotFound) {
        [DNKeychainItemWrapper resetKeychainItem:key];
    } else {
        NSLog(@"Serious keychain error %d", (int)keychainErr);
        if (outDictionary) {
           CFRelease(outDictionary);
        }
    }
    
    if (outDictionary) {
        CFRelease(outDictionary);
    }
    
    return nil;
}

+ (void)setObject:(id)inObject forKey:(id)key {
    if (inObject == nil) {
       return;
    }
   
    NSMutableDictionary *keychainData = [DNKeychainItemWrapper genericPasswordQueryWithKey:key];
    keychainData[(__bridge id) kSecAttrSynchronizable] = (__bridge id) kCFBooleanFalse;
    keychainData[(__bridge id) kSecAttrAccessible] = (__bridge id) kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    keychainData[(__bridge id) kSecValueData] = [NSKeyedArchiver archivedDataWithRootObject:inObject];
   
    [DNKeychainItemWrapper writeToKeychain:keychainData withKey:key];
}

+ (id)objectForKey:(id)key {
    return [DNKeychainItemWrapper keychainDataForKey:key];
}

+ (NSMutableDictionary *)resetKeychainItem:(NSString *)key {
    NSMutableDictionary *keychainData = [[NSMutableDictionary alloc] init];
  
    keychainData[(__bridge id) kSecAttrAccount] = key;
    keychainData[(__bridge id) kSecAttrService] = key;
    
    return [DNKeychainItemWrapper dictionaryToSecItemFormat:keychainData withKey:(__bridge id)kSecValueData];
}

+ (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert withKey:(NSString *)key {
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    
    returnDictionary[(__bridge id) kSecAttrGeneric] = key;
    returnDictionary[(__bridge id) kSecClass] = (__bridge id) kSecClassGenericPassword;
    
    NSString *passwordString = dictionaryToConvert[(__bridge id) kSecValueData];
    if (passwordString) {
        returnDictionary[(__bridge id) kSecValueData] = [NSKeyedArchiver archivedDataWithRootObject:passwordString];
    }
    
    return returnDictionary;
}

// could be in a class
+ (void)writeToKeychain:(NSMutableDictionary *)keyChainData withKey:(NSString *)key {
    
    CFDictionaryRef attributes = nil;
    NSMutableDictionary *updateItem = nil;
    
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keyChainData, (CFTypeRef *)&attributes) == noErr) {

        updateItem = [NSMutableDictionary dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attributes];
        updateItem[(__bridge id) kSecClass] = keyChainData[(__bridge id) kSecClass];
        NSMutableDictionary *tempCheck = [DNKeychainItemWrapper dictionaryToSecItemFormat:keyChainData withKey:key];
        [tempCheck removeObjectForKey:(__bridge id)kSecClass];

        SecItemDelete((CFDictionaryRef  _Nonnull)keyChainData);
        OSStatus errorcode = SecItemAdd((__bridge CFDictionaryRef)keyChainData, NULL);
        
        if (errorcode != noErr) {
            NSLog(@"keychain error: %d", (int)errorcode);
        }
    }
    else {
        OSStatus errorcode = SecItemAdd((__bridge CFDictionaryRef)keyChainData, NULL);
        if (errorcode != noErr) {
            NSLog(@"Couldn't add the Keychain Item.");
        }
        if (attributes) {
            CFRelease(attributes);
        }
    }
}

@end
