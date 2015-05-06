//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "LoginTableViewController.h"
#import "LeanMessageManager.h"
#import "ChatViewController.h"

@implementation LoginTableViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"UUChat";
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    cell.textLabel.font=[UIFont systemFontOfSize:15];
    
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Michael 发起和 Betty 的聊天";
                break;
            case 1:
                cell.textLabel.text = @"Betty 发起和 Michael 的聊天";
                break;
        }
    }
    else if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Michael 发起和 Betty、Linda 的聊天";
                break;
            case 1:
                cell.textLabel.text = @"Betty 发起和 Michael、Linda 的聊天";
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"单聊";
        case 1:
            return @"群聊";
        default:
            return nil;
    }
}

#pragma mark - Table view delegate

- (void)openSessionByClientId:(NSString*)clientId navigationToIMWithTargetClientIDs:(NSArray *)clientIDs {
    WEAKSELF
    [[LeanMessageManager manager] openSessionWithClientID:clientId completion:^(BOOL succeeded, NSError *error) {
        if(!error){
            ConversationType type;
            if(clientIDs.count>1){
                type=ConversationTypeGroup;
            }else{
                type=ConversationTypeOneToOne;
            }
            [[LeanMessageManager manager] createConversationsWithClientIDs:clientIDs conversationType:type completion:^(AVIMConversation *conversation, NSError *error) {
                if(error){
                    NSLog(@"error=%@",error);
                }else{
                    ChatViewController *vc=[[ChatViewController alloc] initWithConversation:conversation];
                    [weakSelf.navigationController pushViewController:vc animated:YES];
                }
            }];
        }else{
            NSLog(@"error=%@",error);
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                [self openSessionByClientId:kMichaelClientID navigationToIMWithTargetClientIDs:@[kBettyClientID]];
                break;
            case 1:
                [self openSessionByClientId:kBettyClientID navigationToIMWithTargetClientIDs:@[kMichaelClientID]];
                break;
        }
    }
    else if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0:
                [self openSessionByClientId:kMichaelClientID  navigationToIMWithTargetClientIDs:@[kBettyClientID,kLindaClientID]];
                break;
            case 1:
                [self openSessionByClientId:kBettyClientID navigationToIMWithTargetClientIDs:@[kLindaClientID,kMichaelClientID]];
                break;
        }
    }
}



@end
