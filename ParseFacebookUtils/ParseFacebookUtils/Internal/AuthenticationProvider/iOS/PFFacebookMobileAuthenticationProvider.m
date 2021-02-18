/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookMobileAuthenticationProvider.h"
#import "PFFacebookMobileAuthenticationProvider_Private.h"

#import <Bolts/BFTask.h>
#import <Bolts/BFTaskCompletionSource.h>

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

#import <Parse/PFConstants.h>

#import "PFFacebookPrivateUtilities.h"

@implementation PFFacebookMobileAuthenticationProvider

///--------------------------------------
#pragma mark - Init
///--------------------------------------

- (instancetype)initWithApplication:(UIApplication *)application
                      launchOptions:(nullable NSDictionary *)launchOptions {
    self = [super initWithApplication:application launchOptions:launchOptions];
    if (!self) return self;

    _loginManager = [[FBSDKLoginManager alloc] init];

    return self;
}

///--------------------------------------
#pragma mark - Authenticate
///--------------------------------------

- (BFTask<NSDictionary<NSString *, NSString *>*> *)authenticateAsyncWithReadPermissions:(nullable NSArray<NSString *> *)readPermissions
                                                                     publishPermissions:(nullable NSArray<NSString *> *)publishPermissions
                                                                     fromViewComtroller:(UIViewController *)viewController {
    // This is enough for combyne's use-case. Extended permissions (including publish permissions)
    // are ignored, but we won't pass them in the first place.
    NSString *nonce = [[NSUUID UUID] UUIDString];
    FBSDKLoginConfiguration *configuration = [[FBSDKLoginConfiguration alloc] initWithPermissions:readPermissions
                                                                                         tracking:FBSDKLoginTrackingLimited
                                                                                            nonce:nonce];

    BFTaskCompletionSource *taskCompletionSource = [BFTaskCompletionSource taskCompletionSource];
    FBSDKLoginManagerLoginResultBlock completion = ^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (result.isCancelled) {
            [taskCompletionSource cancel];
        } else if (error) {
            taskCompletionSource.error = error;
        } else {
            FBSDKAuthenticationToken *token = FBSDKAuthenticationToken.currentAuthenticationToken;

            if (![nonce isEqualToString:token.nonce]) {
                taskCompletionSource.error = [NSError errorWithDomain:PFParseErrorDomain
                                                                 code:kPFErrorFacebookInvalidNonce
                                                             userInfo:nil];
            } else {
                taskCompletionSource.result = [PFFacebookPrivateUtilities userAuthenticationDataFromAuthenticationToken:token];
            }
        }
    };
    
    [self.loginManager logInFromViewController:viewController configuration:configuration completion:completion];
    
    return taskCompletionSource.task;
}

///--------------------------------------
#pragma mark - PFUserAuthenticationDelegate
///--------------------------------------

- (BOOL)restoreAuthenticationWithAuthData:(nullable NSDictionary<NSString *, NSString *> *)authData {
    if (!authData) {
        [self.loginManager logOut];
    }

    // With limited login, there's no access token to restore since Graph API queries are impossible.
    return YES;
}

@end
