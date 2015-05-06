//
//  AppDelegate.m
//  UUChatTableView
//
//  Created by shake on 15/1/6.
//  Copyright (c) 2015年 uyiuyao. All rights reserved.
//

#import "AppDelegate.h"
#import "ChatViewController.h"
#import "LeanMessageManager.h"
#import "LoginTableViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [LeanMessageManager setupApplication];

    self.window = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
    
    LoginTableViewController *login=[[LoginTableViewController alloc]  initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:login];
    self.window.rootViewController=nav;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
