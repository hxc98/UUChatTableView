//
//  ChatModel.h
//  UUChatTableView
//
//  Created by shake on 15/1/6.
//  Copyright (c) 2015年 uyiuyao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVOSCloudIM/AVOSCloudIM.h>

@interface ChatModel : NSObject

@property (nonatomic, strong) NSMutableArray *dataSource;

- (instancetype)initWithConversation:(AVIMConversation*)conversation;

- (void)loadOldMessageItemsWithBlock:(void (^)(NSInteger count))block;

-(void)loadMessagesWhenInitWithBlock:(dispatch_block_t)block;

-(void)listenForNewMessageWithBlock:(dispatch_block_t)block;

-(void)sendMessage:(AVIMTypedMessage*)message block:(AVBooleanResultBlock)block;

-(void)cancelListenForNewMessage;

@end
