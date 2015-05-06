//
//  RootViewController.m
//  UUChatTableView
//
//  Created by shake on 15/1/4.
//  Copyright (c) 2015年 uyiuyao. All rights reserved.
//

#import "ChatViewController.h"
#import "UUInputFunctionView.h"
#import "MJRefresh.h"
#import "UUMessageCell.h"
#import "ChatModel.h"
#import "UUMessageFrame.h"
#import "UUMessage.h"

@interface ChatViewController ()<UUInputFunctionViewDelegate,UUMessageCellDelegate,UITableViewDataSource,UITableViewDelegate>

@property (strong, nonatomic) MJRefreshHeaderView *head;
@property (strong, nonatomic) ChatModel *chatModel;

@property (weak, nonatomic) IBOutlet UITableView *chatTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@property (nonatomic,strong) AVIMConversation *conversation;

@end

@implementation ChatViewController{
    UUInputFunctionView *IFView;
}

- (instancetype)initWithConversation:(AVIMConversation*)conversation
{
    self = [super init];
    if (self) {
        _conversation=conversation;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initBar];
    [self addRefreshViews];
    IFView = [[UUInputFunctionView alloc]initWithSuperVC:self];
    IFView.delegate = self;
    [self.view addSubview:IFView];
    
    self.chatModel = [[ChatModel alloc] initWithConversation:_conversation];
    WEAKSELF
    [self.chatModel loadMessagesWhenInitWithBlock:^{
        [weakSelf.chatTableView reloadData];
        [weakSelf tableViewScrollToBottom];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //add notification
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardChange:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardChange:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(tableViewScrollToBottom) name:UIKeyboardDidShowNotification object:nil];
    WEAKSELF
    [self.chatModel listenForNewMessageWithBlock:^{
        [weakSelf finishSendMessage];
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [self.chatModel cancelListenForNewMessage];
}

- (void)initBar
{
    self.title=@"Chat";
    
    self.navigationController.navigationBar.tintColor = [UIColor grayColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:nil];
}

- (void)addRefreshViews
{
    WEAKSELF
    _head = [MJRefreshHeaderView header];
    _head.scrollView = self.chatTableView;
    _head.beginRefreshingBlock = ^(MJRefreshBaseView *refreshView) {
        [weakSelf.chatModel loadOldMessageItemsWithBlock:^(NSInteger count) {
            [weakSelf.head endRefreshing];
            if(count>0){
                [weakSelf.chatTableView reloadData];
                if(weakSelf.chatModel.dataSource.count>count){
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:count inSection:0];
                    [weakSelf.chatTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                }
            }
        }];
    };
}


-(void)keyboardChange:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardEndFrame;
    
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];
    
    //adjust ChatTableView's height
    if (notification.name == UIKeyboardWillShowNotification) {
        self.bottomConstraint.constant = keyboardEndFrame.size.height+40;
    }else{
        self.bottomConstraint.constant = 40;
    }
    
    [self.view layoutIfNeeded];
    
    //adjust UUInputFunctionView's originPoint
    CGRect newFrame = IFView.frame;
    newFrame.origin.y = keyboardEndFrame.origin.y - newFrame.size.height;
    IFView.frame = newFrame;
    
    [UIView commitAnimations];
    
}

//tableView Scroll to bottom
- (void)tableViewScrollToBottom
{
    if (self.chatModel.dataSource.count==0)
        return;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.chatModel.dataSource.count-1 inSection:0];
    [self.chatTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}


#pragma mark - InputFunctionViewDelegate

- (void)UUInputFunctionView:(UUInputFunctionView *)funcView sendMessage:(NSString *)message
{
    
    AVIMTextMessage *textMessage=[AVIMTextMessage messageWithText:message attributes:nil];
    WEAKSELF
    [self.chatModel sendMessage:textMessage block:^(BOOL succeeded, NSError *error) {
        if([weakSelf filterError:error]){
            funcView.TextViewInput.text = @"";
            [funcView changeSendBtnWithPhoto:YES];
            [weakSelf finishSendMessage];
        }
    }];
}

-(void)finishSendMessage{
    [self.chatTableView reloadData];
    [self tableViewScrollToBottom];
}

- (void)UUInputFunctionView:(UUInputFunctionView *)funcView sendPicture:(UIImage *)image
{
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"tmp.jpg"];
    NSData* photoData=UIImageJPEGRepresentation(image,0.6);
    [photoData writeToFile:filePath atomically:YES];
    AVIMImageMessage *imageMessage = [AVIMImageMessage messageWithText:nil attachedFilePath:filePath attributes:nil];
    WEAKSELF
    [self.chatModel sendMessage:imageMessage block:^(BOOL succeeded, NSError *error) {
        if([weakSelf filterError:error]){
            [weakSelf finishSendMessage];
        }
    }];
}

- (void)UUInputFunctionView:(UUInputFunctionView *)funcView sendVoice:(NSData *)voice time:(NSInteger)second
{
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"tmp.mp3"];
    [voice writeToFile:filePath atomically:YES];
    AVIMAudioMessage* sendAudioMessage=[AVIMAudioMessage messageWithText:nil attachedFilePath:filePath attributes:nil];
    WEAKSELF
    [self.chatModel sendMessage:sendAudioMessage block:^(BOOL succeeded, NSError *error) {
        if([weakSelf filterError:error]){
            [weakSelf finishSendMessage];
        }
    }];
}

#pragma mark - tableView delegate & datasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.chatModel.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UUMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellID"];
    if (cell == nil) {
        cell = [[UUMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CellID"];
        cell.delegate = self;
    }
    [cell setMessageFrame:self.chatModel.dataSource[indexPath.row]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return [self.chatModel.dataSource[indexPath.row] cellHeight];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.view endEditing:YES];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    [self.view endEditing:YES];
}

#pragma mark - cellDelegate
- (void)headImageDidClick:(UUMessageCell *)cell userId:(NSString *)userId{
    // headIamgeIcon is clicked
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:cell.messageFrame.message.strName message:@"headImage clicked" delegate:nil cancelButtonTitle:@"sure" otherButtonTitles:nil];
    [alert show];
}

#pragma mark - custom

-(BOOL)filterError:(NSError*)error{
    if(error){
        UIAlertView *alertView=[[UIAlertView alloc]
                                initWithTitle:nil message:error.description delegate:nil
                                cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alertView show];
        return NO;
    }
    return YES;
}

@end
