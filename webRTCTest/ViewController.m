//
//  ViewController.m
//  webRTCTest
//
//  Created by 吳尚霖 on 7/22/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import "ViewController.h"
#import "SocketRTCManager.h"

#import <WebRTC/WebRTC.h>
#import <WebRTC/RTCIceServer.h>
#import <SocketIO-Swift.h>
#import <AVFoundation/AVFoundation.h>


#define STREAM     @"localStream"
#define AUDIOTRACK @"audioTest"

typedef enum : int{
    Caller = 0,
    Receiver = 1,
} Mode;

@interface ViewController ()<SocketRTCManagerDelegate,RTCPeerConnectionDelegate>
@property (strong, nonatomic) IBOutlet UILabel *socketStatus;
@property (strong, nonatomic) IBOutlet UIButton *joinRoomBtn;
@property (strong, nonatomic) IBOutlet UIButton *createRoomBtn;

@property (strong,nonatomic) SocketRTCManager *socketRTCManager;

@property (strong,nonatomic) RTCPeerConnectionFactory *rtcFactory;
@property (strong,nonatomic) RTCPeerConnection *peerConnection;
@property (strong,nonatomic) RTCMediaStream *localStream;

@property (strong, nonatomic) IBOutlet UILabel *offerStatus;
@property (strong, nonatomic) IBOutlet UILabel *answerStatus;

@property (strong,nonatomic) NSMutableDictionary *connectionDic;
@property (strong,nonatomic) NSMutableArray *remoteAudioTracks;
@property (strong,nonatomic) NSMutableArray *connectionIdArray;
@property (strong,nonatomic) NSMutableArray *ICEServers;

@property (strong,nonatomic) NSDictionary *startCallDic;

@property (strong,nonatomic) NSMutableArray *roomList;
@property (strong,nonatomic) NSString *socketRoom;
@property (strong,nonatomic) NSString *socketID;
@property (strong,nonatomic) NSString *targetID;
@property (strong,nonatomic) NSString *userID;
@property (strong,nonatomic) NSString *roomID;

@property (strong, nonatomic) IBOutlet UIButton *joinBtn1;

@property (assign,nonatomic) Mode *mode;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initData];
    
    [self getMediaTrackWithFactoryInit];
    
    [self socketRTCManagerInit];

}

#pragma mark - Initialize
//initData
- (void)initData{
    
    _connectionDic = @{}.mutableCopy;
    _connectionIdArray = @[].mutableCopy;
    _remoteAudioTracks = @[].mutableCopy;
    
    //keep the screen on
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
}

//getMediaTrackWithFactoryInit
- (void)getMediaTrackWithFactoryInit{
    if (!_rtcFactory)
        _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    
    if(!_localStream)
       [self createLocalStream];
    
}

//createLocalStream
- (void)createLocalStream{
    _localStream = [_rtcFactory mediaStreamWithStreamId:STREAM];
    
    [self checkMicroPhonePermission];
}

- (void)checkMicroPhonePermission{
    
    AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession
                                                      discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone]
                                                      mediaType:AVMediaTypeAudio position:0];
    
    AVCaptureDevice *device = [deviceSession.devices firstObject];
    
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
           if(!granted)
               NSLog(@"Microphone permission denied.");
           else{
               if (device) {
                   
                   [[AVAudioSession sharedInstance]setActive:false error:nil];
                   [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers error:nil];
                   
                   [_localStream addAudioTrack:[_rtcFactory audioTrackWithTrackId:AUDIOTRACK]];
                                      
                   NSLog(@"setLocalStream");
               }
           }
        }];
        
    }
    else{
        if (device) {
        
            [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];

            [_localStream addAudioTrack:[_rtcFactory audioTrackWithTrackId:AUDIOTRACK]];
                        
            NSLog(@"setLocalStream");
            
        }else
            NSLog(@"Microphone cannot open in this device.");
    }

    //Video
                   /*
                   RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:device.localizedName];
                   RTCVideoSource *videoSource = [_factory videoSourceWithCapturer:capturer constraints:[self localVideoConstraints]];
                    */
                   
    //               RTCAVFoundationVideoSource *videoSource = [[RTCAVFoundationVideoSource alloc] initWithFactory:_factory constraints:[self localVideoConstraints]];
    //               _localVideoSource = videoSource;
    //               RTCVideoTrack *videoTrack = [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
    //               [_localStream addVideoTrack:videoTrack];
                   
                   
    //               //显示本地流
    //               RTCEAGLVideoView *localVideoView = [[RTCEAGLVideoView alloc] init];
    //               localVideoView.frame = CGRectMake(0, 60, 375/2.0, 375/2.0*1.3);
    //               //标记摄像头
    //               localVideoView.tag = 100;
    //               //摄像头旋转
    //               localVideoView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    //               _localVideoTrack = [_localStream.videoTracks lastObject];
    //               [_localVideoTrack addRenderer:localVideoView];
    //               [self.view addSubview:localVideoView];
                   
    
    
}

- (void)socketRTCManagerInit{
    _socketRTCManager = [SocketRTCManager getInstance];
    _socketRTCManager.delegate = self;
    [_socketRTCManager connect];
}

#pragma mark - IBAction
- (IBAction)muteBtnClick:(UIButton*)sender {
    //init status is selected
    //1.擴音:喇叭圖(unselect)  2.不擴音:斜線喇叭圖(selected)
    bool isLoud = !sender.isSelected;
    
    if (isLoud) {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        // Turn off the speaker
        sender.selected = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
//            [self.view makeToast:@"關閉擴音"];
        [sender setTitle:@"擴音" forState:UIControlStateNormal];
    }
    else {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        // Turn on the speaker
        BOOL isSuccess = [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
        if (isSuccess) {
            sender.selected = !isSuccess;
//            [self.view makeToast:@"開啟擴音"];
            [sender setTitle:@"手持" forState:UIControlStateNormal];
        }else{
            NSLog(@"%@",error.description);
        }
    }
}

- (IBAction)createRoom:(id)sender {

    _userID = [[NSUUID new]UUIDString];
    _roomID = @"530TestRoom";
    
    [_socketRTCManager newRoomToStreamWithSocketID:_socketID roomID:_roomID];
    
//    BOOL isJoinSuccessed = [_socketRTCManager startCallToStreamWithSocketID:_socketID targetID:_userID roomID:_roomID];
//
//    _socketStatus.text = (isJoinSuccessed)? @"正在建立房間" : @"Socket尚未連接，建立房間失敗";

}

- (IBAction)joinTestRoom:(UIButton *)sender {
    _socketRoom = [sender.titleLabel.text componentsSeparatedByString:@"+"].firstObject;
    
    BOOL isJoinSuccessed = [_socketRTCManager startCallToStreamWithSocketRoom:_socketRoom SocketID:_socketID];
    
    _socketStatus.text = (isJoinSuccessed)? @"正在建立房間" : @"Socket尚未連接，建立房間失敗";
    
}

- (IBAction)joinRoom:(id)sender {
    [self processLocalTask:_startCallDic];
    [self createOfferAndSetSDP];
}

#pragma mark - createPeerConnection
- (void)processLocalTask:(NSDictionary*)dic{

    //get all of connections
    NSString *socketID = dic[@"socketID"];
        
    BOOL isExist = false;
    //add all of connectionID to array
    for(NSString *str in _connectionIdArray)
        isExist = (str == socketID);
    
    if(!isExist)
        [_connectionIdArray addObject:socketID];
        
    // To initialize RTCPeerConnection object base on coonections(ConnectionID)
    [self createPeerConnection];
    
    //给每一个点对点连接，都加上本地流
    [self addStream];
    
}

- (void)createPeerConnection{
    if(!_rtcFactory)
        _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    
    _peerConnection = [_rtcFactory peerConnectionWithConfiguration:[self setStunServerToICEServer]
                                                       constraints:[self peerConnectionConstraints]
                                                          delegate:self];
    
//    //create p2p object base on connectionIDArray
//    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger index, BOOL * _Nonnull stop) {
//
//        //设置这个ID对应的 RTCPeerConnection对象
//        _connectionDic[connectionID] = connection;
//    }];
}

- (RTCConfiguration*)setStunServerToICEServer{
    if(!_ICEServers)
        _ICEServers = @[].mutableCopy;
    
    //@"stun:turn.quickblox.com",
    //@"turn:turn.quickblox.com:3478?transport=udp",
    //@"turn:turn.quickblox.com:3478?transport=tcp"
    //NSString *userName = [stunURL containsString:@"quickblox"] ? @"quickblox":@"";
    //NSString *password = [stunURL containsString:@"quickblox"] ? @"baccb97ba2d92d71e26eb9886da5f1e0":@"";
    
    NSArray *stunServers = @[
                            @"stun:stun.l.google.com:19302",
                            @"stun:stun1.l.google.com:19302",
                            @"stun:stun2.l.google.com:19302",
                            @"stun:stun3.l.google.com:19302",
                            @"stun:stun4.l.google.com:19302"
                           ];
    
    RTCConfiguration *rtcConfig = [[RTCConfiguration alloc]init];
    
    [rtcConfig setIceServers:@[[[RTCIceServer alloc]initWithURLStrings:stunServers]]];
    return rtcConfig;
}

- (RTCMediaConstraints *)peerConnectionConstraints {
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:@{@"DtlsSrtpKeyAgreement":@"true"}];
    
    return constraints;
}

- (void)addStream{
    
    if(!_localStream)
        [self createLocalStream];
    
    [_peerConnection addStream:_localStream];
}

/** Generate an SDP offer to Set Local Description for each peerConnection */
- (void)createOfferAndSetSDP{
    
    _mode = 0;
    
    __weak typeof(self) weakSelf = self;
    
    [_peerConnection offerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        
        if(error){
            NSLog(@"%@",error);
            return;
        }
        
        [_peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
           if(error){
                NSLog(@"%@",error);
                return;
            }
                        
            NSDictionary *dic = @{@"sdp":sdp.sdp,
                                  @"type":@(sdp.type),
                                  @"roomName":weakSelf.roomID,
                                  @"socketID":weakSelf.socketID,
                                  @"socketRoom":weakSelf.socketRoom
                                };
            
            [weakSelf.socketRTCManager sendOfferToStreamWithDic:dic];
            NSLog(@"===========Send Offer : %@ \n%@\n===========",weakSelf.socketID,dic);

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.offerStatus.text = @"Offer emmitted";
                weakSelf.socketStatus.text = @"房間已建立";
            });
            
        }];
    }];

//    __weak typeof(self) weakSelf = self;

//    //讓每個peerConnection都建立offer
//    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
//        _mode = 0;
//        connection.delegate = weakSelf;
//
//        /** Generate an SDP offer. */
//        [connection offerForConstraints :[self offerOranswerConstraint]
//                       completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error){
//
//            /** Set Local Description */
//            [connection setLocalDescription:sdp completionHandler:nil];
//
//            /** Send SDP Offer */
//            [_socketRTCManager sendOfferToStreamWithDic:@{@"sdp":sdp}];
//        }];
//    }];
}

- (RTCMediaConstraints *)offerOranswerConstraint {
    
//    NSMutableArray *audioArr = @[].mutableCopy;
//    RTCPair *receiveAudio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
//    [audioArr addObject:receiveAudio];
    
//    NSString *video = @"true";
//    RTCPair *receiveVideo = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video];
//    [array addObject:receiveVideo];
    
    //回音消除
//    RTCPair *echoCancellation = [[RTCPair alloc] initWithKey:@"VoiceActivityDetection" value:@"false"];
//    [audioArr addObject:echoCancellation];
    
    NSDictionary *dic = @{@"VoiceActivityDetection":@"false"};
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":@"true",@"VoiceActivityDetection":@"false"} optionalConstraints:dic];
}

#pragma mark - SocketRTCManagerDelegate
- (void)socketConnected:(NSArray*)data{
    _socketStatus.text = @"Socket Connected : 連線成功";
    
//    //get data
//    NSDictionary *dataDic = dic[@"data"];
//    //get all of connections
//    NSArray *connections = dataDic[@"connections"];
//
//    //add all of connection to array
//    [_connectionIdArray addObjectsFromArray:connections];
//
//    //拿到给自己分配的ID
//    //    _userId = dataDic[@"you"];
//
//    //create p2p object base on connectionIDArray
//    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger index, BOOL * _Nonnull stop) {
//
//        //根据连接ID去初始化 RTCPeerConnection 连接对象
//        RTCPeerConnection *connection = [self createPeerConnection:connectionID];
//
//        //设置这个ID对应的 RTCPeerConnection对象
//        _connectionDic[connectionID] = connection;
//    }];
//
//    //给每一个点对点连接，都加上本地流
//    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
//        if (!_localStream)
//        {
//            [self createLocalStreaming];
//        }
//
//    }];
       
}

- (void)streamConnectedData:(NSArray *)data{
    
    _socketID = data.firstObject[@"socketID"];
    
    [_createRoomBtn setHidden:false];
    
}

- (void)streamReceiveStartCall:(NSArray *)data{
    
//    [_joinRoomBtn setHidden:false];
    _startCallDic = data.firstObject;
    [self processLocalTask:_startCallDic];
    [self createOfferAndSetSDP];
}

- (void)streamReceiveNewRoom:(NSArray *)data{
    NSArray<NSString*> *roomList = data.firstObject[@"roomList"];
    _roomID = [roomList.firstObject componentsSeparatedByString:@"+"].lastObject;
    if(roomList.count>0){
        NSString *roomName = roomList.firstObject;
        if([roomName containsString:@"530Test"]){
            [_joinBtn1 setTitle:roomName forState:UIControlStateNormal] ;
            _joinBtn1.hidden = false;

        }
    }
}

- (void)streamReceiveOffer:(NSArray *)data{

    
    NSDictionary *dic = data.firstObject;
    
    if([_socketID isEqualToString:dic[@"socketID"]]) return;
    
    NSLog(@"%s",__func__);
    
    _socketRoom = dic[@"socketRoom"];
    
    _offerStatus.text = [NSString stringWithFormat:@"Offer received\n\n%@",dic[@"socketID"]];
    
    
    __weak typeof(self) weakSelf = self;
    
    [self processLocalTask:dic];

    RTCSessionDescription *sdp = [[RTCSessionDescription alloc]initWithType:[dic[@"type"]integerValue] sdp:dic[@"sdp"]];
    
    NSLog(@"===========Receive Offer : %@\nsdpType : %ld\n%@\n===========",dic[@"socketID"],(long)[dic[@"type"]integerValue],dic[@"sdp"]);
    
    
    [_peerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
        if(error){
            NSLog(@"%@",error);
            return;
        }
        
        [weakSelf.peerConnection answerForConstraints:[weakSelf offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            if(error){
                NSLog(@"%@",error);
                return;
            }
            
            RTCSessionDescription *answerSDP = sdp;
            
            [weakSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                if(error){
                    NSLog(@"%@",error);
                    return;
                }
                
                NSDictionary *dic = @{@"sdp":answerSDP.sdp,
                                      @"type":@(answerSDP.type),
                                      @"socketID":weakSelf.socketID,
                                      @"socketRoom":weakSelf.socketRoom
                                     };
                
                [weakSelf.socketRTCManager answerToStreamWithDic:dic];
                NSLog(@"===========Send Answer : %@ \n%@\n===========",weakSelf.socketID,dic);

                
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.answerStatus.text = @"Answer emitted";
                    weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中",weakSelf.roomID];
                });
                
            }];
        }];
    }];
    
    
    
}

- (void)streamReceiveAnswer:(NSArray *)data{

    NSDictionary *dic = data.firstObject;
    
    if([_socketID isEqualToString:dic[@"socketID"]])return;
   
    NSLog(@"%s",__func__);
    
    NSLog(@"===========Receive Answer : %@\nsdpType : %ld\n%@\n===========",_socketID,(long)[dic[@"type"]integerValue],dic[@"sdp"]);
    
    _answerStatus.text = [NSString stringWithFormat:@"Answer received\n\n%@",dic[@"socketID"]];
    
    __weak typeof(self) weakSelf = self;
    
//    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
//    _mode = 0;
//    //添加代理
//    connection.delegate = weakSelf;
//    [connection offerForConstraints :[self offerOranswerConstraint] completionHandler:nil];
//    [connection answerForConstraints:[self offerOranswerConstraint] completionHandler:nil];
    
    RTCSessionDescription *sdp = [[RTCSessionDescription alloc]initWithType:[dic[@"type"]integerValue] sdp:dic[@"sdp"]];
    
    [weakSelf.peerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(error){
                NSLog(@"%@",error);
                weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中發生錯誤\n%@",weakSelf.roomID,error];
            }else
                weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中",weakSelf.roomID];

        });

        
    }];
}

- (void)streamReceiveCandidates:(NSArray *)data{

    NSDictionary *dic = data.firstObject;
    
    if([_socketID isEqualToString:dic[@"socketID"]])return;
    
    NSLog(@"%s",__func__);

    RTCIceCandidate *candidate = [[RTCIceCandidate alloc]initWithSdp:dic[@"candidateSdp"] sdpMLineIndex:[dic[@"sdpMLineIndex"]intValue] sdpMid:dic[@"sdpMid"]];
    [_peerConnection addIceCandidate:candidate];
}

- (void)socketDisConnected{
    
}

- (void)socketError{
    _socketStatus.text = @"Socket Error : 連線失敗";
    [self closePeerConnection];

}

- (void)streamCancel{
    [self closePeerConnection];
}

#pragma mark - RTCPeerConnectionDelegate
/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream{
    NSLog(@"%s",__func__);
//    NSString *uid = [self getKeyFromConnectionDic:peerConnection];
    dispatch_async(dispatch_get_main_queue(), ^{
        //缓存起来
        [_remoteAudioTracks addObject:[stream.audioTracks lastObject]];
        
        [_localStream addAudioTrack:[stream.audioTracks firstObject]];
                
        //speaker default is closed
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    });
    
    NSLog(@"addRemoteStream");
}

/** New ice candidate has been found. */
//创建peerConnection之后，从server得到响应后调用，得到ICE 候选地址
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate{
    NSLog(@"%s",__func__);
    
//    NSString *currentId = [self getKeyFromConnectionDic : peerConnection];
    
    NSLog(@"%d",candidate.sdpMLineIndex);
    
    
    [_socketRTCManager sendCandidatesToStreamWithDic:@{@"data": @{@"sdpMid":candidate.sdpMid,
                                                                  @"sdpMLineIndex": @(candidate.sdpMLineIndex),
                                                                  @"candidateSdp": candidate.sdp,
                                                                  @"socketID": _socketID,
                                                                  @"socketRoom": _socketRoom
                                                                 }
                                                      }];
}

/** Called when the SignalingState changed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged{
    NSLog(@"%s",__func__);
    NSLog(@"stateChanged = %ld", (long)stateChanged);
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream{
    NSLog(@"%s",__func__);
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    NSLog(@"%s",__func__);
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState{
    NSLog(@"%s : %ld",__func__,(long)newState);
    if(newState == RTCIceConnectionStateCompleted){
        
    }
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState{
    NSLog(@"%s : %ld",__func__,(long)newState);
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates{
    NSLog(@"%s : %@",__func__,candidates);
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel{
    NSLog(@"%s",__func__);
}

#pragma mark - Function
//- (NSString *)getKeyFromConnectionDic:(RTCPeerConnection *)peerConnection{
//    //find socketID by peerConnection
//    static NSString *socketId;
//
//    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
//        if ([obj isEqual:peerConnection])
//        {
//            NSLog(@"%@",key);
//            socketId = key;
//        }
//    }];
//    return socketId;
//}

- (void)closePeerConnection{
    _localStream = nil;
    [_peerConnection close];
//    RTCPeerConnection *peerConnection = _connectionDic[connectionID];
//
//    if (peerConnection)
//        [peerConnection close];
//
//    [_connectionIdArray removeObject:connectionID];
//    [_connectionDic removeObjectForKey:connectionID];
    dispatch_async(dispatch_get_main_queue(), ^{
        //移除語音追踪
        _remoteAudioTracks = nil;
//        [_remoteAudioTracks removeObjectForKey:connectionID];
    });
}

- (void)exitRoom{
    [self closePeerConnection];
}

- (void)closeVC{
    [self exitRoom];
    
    [self dismissViewControllerAnimated:true completion:^{
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }];
}


@end
