//
//  RootViewController.h
//  UUChatTableView
//
//  Created by shake on 15/1/4.
//  Copyright (c) 2015年 uyiuyao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LeanMessageManager.h"

@interface ChatViewController : UIViewController

- (instancetype)initWithConversation:(AVIMConversation*)conversation;

@end
