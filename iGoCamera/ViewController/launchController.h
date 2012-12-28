//
//  launchController.h
//  iGoCamera
//
//  Created by Zeng Li on 12/22/12.
//  Copyright (c) 2012 _iceNuts. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GCDAsyncSocket.h"
#import <Availability.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <AVFoundation/AVFoundation.h>

//Server IP:http://itp.59igou.com/

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]


@interface launchController : UIViewController{
	
	dispatch_queue_t socketQueue;
	
	GCDAsyncSocket *listenSocket;
	NSMutableArray *connectedSockets;
		
}

@property (strong, nonatomic) IBOutlet UIButton *startBtn;

@property (strong, nonatomic) IBOutlet UIView *videoPreviewView;
@property (assign, nonatomic) BOOL isRunning;

@property (strong, nonatomic) IBOutlet UIWebView *statusWatcher;
@property (strong, nonatomic) IBOutlet UILabel *ipInfo;
@property (retain, nonatomic) AVCaptureSession *session;
@property (retain, nonatomic) 	AVCaptureSession* mysession;


@end
