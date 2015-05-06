//
//  ChatModel.m
//  UUChatTableView
//
//  Created by shake on 15/1/6.
//  Copyright (c) 2015年 uyiuyao. All rights reserved.
//

#import "ChatModel.h"
#import "LeanMessageManager.h"

#import "UUMessage.h"
#import "UUMessageFrame.h"

@interface ChatModel ()

@property (nonatomic,strong) AVIMConversation *conversation;

@property (nonatomic,strong) NSMutableArray *typedMessages;

@end

@implementation ChatModel

- (instancetype)initWithConversation:(AVIMConversation*)conversation
{
    self = [super init];
    if (self) {
        _conversation=conversation;
        _dataSource=[NSMutableArray array];
        _typedMessages=[NSMutableArray array];
    }
    return self;
}

- (void)loadOldMessageItemsWithBlock:(void (^)(NSInteger count))block{
    if(self.dataSource.count==0){
        block(0);
    }else{
        AVIMTypedMessage *typedMessage=self.typedMessages[0];
        WEAKSELF
        [self.conversation queryMessagesBeforeId:nil timestamp:typedMessage.sendTimestamp limit:20 callback:^(NSArray *typedMessages, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSMutableArray *oldMessageFrames=[NSMutableArray array];
                for(AVIMTypedMessage* typedMessage in typedMessages){
                    [oldMessageFrames addObject:[weakSelf messageFrameByTypedMessage:typedMessage]];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSMutableArray *messages=[NSMutableArray arrayWithArray:typedMessages];
                    [messages addObjectsFromArray:weakSelf.typedMessages];
                    weakSelf.typedMessages=messages;
                    
                    NSMutableArray *messageFrames = [NSMutableArray arrayWithArray:oldMessageFrames];
                    [messageFrames addObjectsFromArray:weakSelf.dataSource];
                    weakSelf.dataSource=messageFrames;
                    [weakSelf setShowTimeFlag];
                    block(oldMessageFrames.count);
                });
            });
        }];
    }
}

-(void)setShowTimeFlag{
    if(self.dataSource.count!=self.typedMessages.count){
        [NSException raise:@"Error" format:@"count not equal"];
    }
    for(int i=0;i<self.typedMessages.count;i++){
        UUMessageFrame *messageFrame=self.dataSource[i];
        UUMessage *message=messageFrame.message;
        BOOL changed=NO;
        if(i==0){
            if(messageFrame.showTime!=YES){
                changed=YES;
                message.showDateLabel=YES;
                messageFrame.showTime=YES;
            }
        }else{
            AVIMTypedMessage *lastMessage=self.typedMessages[i-1];
            AVIMTypedMessage *theMessage=self.typedMessages[i];
            if((theMessage.sendTimestamp-lastMessage.sendTimestamp)/1000>5*60){
                if(messageFrame.showTime!=YES){
                    changed=YES;
                    messageFrame.showTime=YES;
                    message.showDateLabel=YES;
                }
            }else{
                if(messageFrame.showTime!=NO){
                    changed=YES;
                    message.showDateLabel=NO;
                    messageFrame.showTime=NO;
                }
            }
        }
        if(changed){
            messageFrame.message=message;
        }
    }
}

-(UUMessageFrame*)messageFrameByDictionary:(NSDictionary*)dictionary{
    UUMessageFrame *messageFrame=[[UUMessageFrame alloc] init];
    UUMessage *message=[[UUMessage alloc] init];
    [message setWithDict:dictionary];
    messageFrame.message=message;
    return messageFrame;
}

-(UUMessageFrame*)messageFrameByTypedMessage:(AVIMTypedMessage*)typedMessage{
    return [self messageFrameByDictionary:[self messageDictionaryByAVIMTypedMessage:typedMessage]];
}

-(void)loadMessagesWhenInitWithBlock:(dispatch_block_t)block{
    WEAKSELF
    [self.conversation queryMessagesBeforeId:nil timestamp:0 limit:10 callback:^(NSArray *typedMessages, NSError *error) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *filterMessages=[NSMutableArray array];
            for(AVIMMessage *typedMessage in typedMessages){
                if([typedMessage isKindOfClass:[AVIMTypedMessage class]]){
                    [filterMessages addObject:typedMessage];
                }
            }
            NSMutableArray* messageFrames=[NSMutableArray array];
            for(AVIMTypedMessage* typedMessage in filterMessages){
                [messageFrames addObject:[weakSelf messageFrameByTypedMessage:typedMessage]];
            }
            weakSelf.typedMessages=filterMessages;
            [weakSelf.dataSource addObjectsFromArray:messageFrames];
            [weakSelf setShowTimeFlag];
            dispatch_async(dispatch_get_main_queue(), ^{
                block();
            });
        });
    }];
}

-(NSString*)fetchDataOfMessageFile:(AVFile*)file fileName:(NSString*)fileName error:(NSError**)error{
    NSString* path=[[NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:fileName];
    NSData* data=[file getData:error];
    if(*error==nil){
        [data writeToFile:path atomically:YES];
    }
    return path;
}

-(NSDictionary*)messageDictionaryByAVIMTypedMessage:(AVIMTypedMessage*)typedMessage{
    AVIMMessageMediaType msgType = typedMessage.mediaType;
    NSDate* timestamp=[NSDate dateWithTimeIntervalSince1970:typedMessage.sendTimestamp/1000];
    NSMutableDictionary *dict=[NSMutableDictionary dictionary];
    if([[LeanMessageManager manager].selfClientID isEqualToString:typedMessage.clientId]){
        [dict setObject:@(UUMessageFromMe) forKey:@"from"];
    }else{
        [dict setObject:@(UUMessageFromOther) forKey:@"from"];
    }
    [dict setObject:[timestamp description] forKey:@"strTime"];
    [dict setObject:[self displayNameByClientId:typedMessage.clientId] forKey:@"strName"];
    [dict setObject:[self avatarUrlByClientId:typedMessage.clientId] forKey:@"strIcon"];
    switch (msgType) {
        case kAVIMMessageMediaTypeText: {
            AVIMTextMessage *receiveTextMessage = (AVIMTextMessage *)typedMessage;
            [dict setObject:@(UUMessageTypeText) forKey:@"type"];
            [dict setObject:receiveTextMessage.text forKey:@"strContent"];
            break;
        }
        case kAVIMMessageMediaTypeImage: {
            AVIMImageMessage *imageMessage = (AVIMImageMessage *)typedMessage;
            [dict setObject:@(UUMessageTypePicture) forKey:@"type"];
            NSError *error;
            NSData *data=[imageMessage.file getData:&error];
            if(!error){
                UIImage *image=[UIImage imageWithData:data];
                [dict setObject:image forKey:@"picture"];
            }
            break;
        }
        case kAVIMMessageMediaTypeAudio:{
            AVIMAudioMessage *audioMessage=(AVIMAudioMessage*)typedMessage;
            NSError *error;
            NSData *data=[audioMessage.file getData:&error];
            [dict setObject:@(UUMessageTypeVoice) forKey:@"type"];
            if(!error){
                [dict setObject:data forKey:@"voice"];
            }
            [dict setObject:[NSString stringWithFormat:@"%.1f",audioMessage.duration] forKey:@"strVoiceTime"];
        }
        case kAVIMMessageMediaTypeVideo:
            break;
        case kAVIMMessageMediaTypeLocation:
            break;
        default:
            break;
    }
    return dict;
}

-(void)sendMessage:(AVIMTypedMessage*)message block:(AVBooleanResultBlock)block{
    WEAKSELF
    [self.conversation sendMessage:message callback:^(BOOL succeeded, NSError *error) {
        if(error){
            block(NO,error);
        }else{
            [weakSelf addMessageToLast:message completion:^{
                block(YES,nil);
            }];
        }
    }];
}

-(void)addMessageToLast:(AVIMTypedMessage*)message completion:(dispatch_block_t)completion{
    WEAKSELF
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UUMessageFrame *messageFrame=[weakSelf messageFrameByTypedMessage:message];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.typedMessages addObject:message];
            [weakSelf.dataSource addObject:messageFrame];
            [weakSelf setShowTimeFlag];
            completion();
        });
    });
}

-(void)listenForNewMessageWithBlock:(dispatch_block_t)block{
    WEAKSELF
    [[LeanMessageManager manager] setupDidReceiveTypedMessageCompletion:^(AVIMConversation *conversation, AVIMTypedMessage *message) {
        if([conversation.conversationId isEqualToString:weakSelf.conversation.conversationId]){
            [weakSelf addMessageToLast:message completion:^{
                block();
            }];
        }
    }];
}

-(void)cancelListenForNewMessage{
    [[LeanMessageManager manager] setupDidReceiveTypedMessageCompletion:nil];
}

#pragma mark - user info
/**
 * 配置头像
 */
- (NSString*)avatarUrlByClientId:(NSString*)clientId{
    NSDictionary *urls=@{kMichaelClientID:@"http://www.120ask.com/static/upload/clinic/article/org/201311/201311061651418413.jpg",kBettyClientID:@"http://p1.qqyou.com/touxiang/uploadpic/2011-3/20113212244659712.jpg",kLindaClientID:@"http://www.qqzhi.com/uploadpic/2014-09-14/004638238.jpg"};
    return urls[clientId];
}

/**
 * 配置用户名
 */
- (NSString*)displayNameByClientId:(NSString*)clientId{
    return clientId;
}

@end
