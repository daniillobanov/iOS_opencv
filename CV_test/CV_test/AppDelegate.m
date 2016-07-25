//
//  AppDelegate.m
//  CV_test
//
//  Created by Daniil Lobanov on 21.07.16.
//  Copyright © 2016 Daniil Lobanov. All rights reserved.
//

#import "AppDelegate.h"

#import "MLManager.h"

#define FIRST_START_KEY @"FIRST_START"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    if ([self isFirstStart])
    {
        [[MLManager sharedInstance] learn: [UIImage imageNamed: @"SS"]];
        [self setFirstStartFlag];
    }
    
    return YES;
}

#pragma mark - first start

- (BOOL) isFirstStart
{
#if DEBUG
    return YES;
#else
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey: FIRST_START_KEY] != nil;
#endif
}

- (void) setFirstStartFlag
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: @":)" forKey: FIRST_START_KEY];
    [defaults synchronize];
}

@end
