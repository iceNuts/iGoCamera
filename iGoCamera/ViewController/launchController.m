//
//  launchController.m
//  iGoCamera
//
//  Created by Zeng Li on 12/22/12.
//  Copyright (c) 2012 _iceNuts. All rights reserved.
//

#import "launchController.h"

#define WELCOME_MSG  0
#define ECHO_MSG     1
#define WARNING_MSG  2

#define READ_TIMEOUT 15.0
#define READ_TIMEOUT_EXTENSION 10.0


@interface launchController (){
		
	NSMutableString *log;
}
@end

@implementation launchController

@synthesize startBtn;
@synthesize statusWatcher;
@synthesize isRunning;
@synthesize ipInfo;
@synthesize session;
@synthesize videoPreviewView;
@synthesize mysession;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
		log = [[NSMutableString alloc] init];
    }
    return self;
}

- (void)previewSetUp{
	mysession = [[AVCaptureSession alloc] init];
	mysession.sessionPreset = AVCaptureSessionPresetHigh;
	
	AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:mysession];
	
	captureVideoPreviewLayer.frame = self.videoPreviewView.bounds;
	[self.videoPreviewView.layer addSublayer:captureVideoPreviewLayer];
	
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	
	NSError *error = nil;
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	if (!input) {
		// Handle the error appropriately.
		NSLog(@"ERROR: trying to open camera: %@", error);
	}
	[mysession addInput:input];
	
	[mysession startRunning];
}

- (void)viewDidAppear:(BOOL)animated{
	
	//Add Live Preview
	
	[self previewSetUp];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	
	// Do any additional setup after loading the view.
	
	statusWatcher.dataDetectorTypes = UIDataDetectorTypeNone;
	
	[startBtn addTarget:self action:@selector(startBtnTouched) forControlEvents:UIControlEventTouchUpInside];
	isRunning = NO;
	
	socketQueue = dispatch_queue_create("socketQueue", NULL);
	
	listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
	
	// Setup an array to store all accepted client connections
	connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
	exit(0);
}

- (void)startBtnTouched{
	if(isRunning){
		// Stop accepting connections
		[listenSocket disconnect];
		
		// Stop any client connections
		@synchronized(connectedSockets)
		{
			NSUInteger i;
			for (i = 0; i < [connectedSockets count]; i++)
			{
				// Call disconnect on the socket,
				// which will invoke the socketDidDisconnect: method,
				// which will remove the socket from the list.
				[[connectedSockets objectAtIndex:i] disconnect];
			}
		}
		
		[self logInfo:@"服务器关闭"];
		isRunning = false;
		[startBtn setTitle:@"Start" forState:UIControlStateNormal];

	}else{
		//start socket server
		int port = 9875;
		
		NSError *error = nil;
		if(![listenSocket acceptOnPort:port error:&error])
		{
			[self logError:FORMAT(@"启动服务器失败，请重启应用: %@", error)];
			return;
		}
		
		[self logInfo: @"Socket服务启动"];
		
		[ipInfo setText:[[self getIPAddress] stringByAppendingString:@":9875"]];
		
		isRunning = YES;
		
		[startBtn setTitle:@"Stop" forState:UIControlStateNormal];
		
	}
}

//Delegate for Socket

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	// This method is executed on the socketQueue (not the main thread)
	
	@synchronized(connectedSockets)
	{
		[connectedSockets addObject:newSocket];
	}
	
	NSString *host = [newSocket connectedHost];
	UInt16 port = [newSocket connectedPort];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			
			[self logInfo:FORMAT(@"客户端与服务器成功建立连接 %@:%hu", host, port)];
			
		}
	});

	[newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	// This method is executed on the socketQueue (not the main thread)
	
	if (tag == ECHO_MSG)
	{
		[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
	}
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	// This method is executed on the socketQueue (not the main thread)
	
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
			
			NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
			NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
			if (msg)
			{
				//take picture
				[self autoCapture: msg];
			}
			else
			{
				[self logError:@"请传输UTF－8数据"];
			}
			
		}
	});
	
	// Echo message back to client
	[sock writeData:[@"OK" dataUsingEncoding: NSUTF8StringEncoding] withTimeout:-1 tag:ECHO_MSG];
}


/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
 **/
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length
{
	if (elapsed <= READ_TIMEOUT)
	{
		return READ_TIMEOUT_EXTENSION;
	}
	
	return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	if (sock != listenSocket)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			@autoreleasepool {
				
				[self logInfo:FORMAT(@"客户端已断开连接；服务器工作正常,不需要重启")];				
			}
		});
		
		@synchronized(connectedSockets)
		{
			[connectedSockets removeObject:sock];
		}
	}
}


//Error & Log

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	NSLog(@"Oooops, web view failed!");
}

- (void)webViewDidFinishLoad:(UIWebView *)sender
{
	NSString *scrollToBottom = @"window.scrollTo(document.body.scrollWidth, document.body.scrollHeight);";
	
    [sender stringByEvaluatingJavaScriptFromString:scrollToBottom];
}

- (void)logError:(NSString *)msg
{
	NSString *prefix = @"<font color=\"#B40404\">";
	NSString *suffix = @"</font><br/>";
	
	[log appendFormat:@"%@%@%@\n", prefix, msg, suffix];
	
	NSString *html = [NSString stringWithFormat:@"<html><body>\n%@\n</body></html>", log];
	[statusWatcher loadHTMLString:html baseURL:nil];
}

- (void)logInfo:(NSString *)msg
{
	NSString *prefix = @"<font color=\"#6A0888\">";
	NSString *suffix = @"</font><br/>";
	
	[log appendFormat:@"%@%@%@\n", prefix, msg, suffix];
	
	NSString *html = [NSString stringWithFormat:@"<html><body>\n%@\n</body></html>", log];
		
	[statusWatcher loadHTMLString:html baseURL:nil];
}

- (void)logMessage:(NSString *)msg
{
	NSString *prefix = @"<font color=\"#000000\">";
	NSString *suffix = @"</font><br/>";
	
	[log appendFormat:@"%@%@%@\n", prefix, msg, suffix];
	
	NSString *html = [NSString stringWithFormat:@"<html><body>%@</body></html>", log];
	[statusWatcher loadHTMLString:html baseURL:nil];
}

//take picture
- (void)autoCapture: (NSString*)msg{
	AVCaptureDevice *backCamera;
	
	
	NSArray *allCameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for ( int i = 0; i < allCameras.count; i++ ) {
		AVCaptureDevice *camera = [allCameras objectAtIndex:i];
		
		if ( camera.position == AVCaptureDevicePositionBack) {
			backCamera = camera;
		}
	}
	
	if(backCamera){
		// Set torch and flash mode to auto
		if ([backCamera hasFlash]) {
			if ([backCamera lockForConfiguration:nil]) {
				if ([backCamera isFlashModeSupported:AVCaptureFlashModeAuto]) {
					[backCamera setFlashMode:AVCaptureFlashModeAuto];
				}
				[backCamera unlockForConfiguration];
			}
		}
		if ([backCamera hasTorch]) {
			if ([backCamera lockForConfiguration:nil]) {
				if ([backCamera isTorchModeSupported:AVCaptureTorchModeAuto]) {
					[backCamera setTorchMode:AVCaptureTorchModeAuto];
				}
				[backCamera unlockForConfiguration];
			}
		}

		session = [[AVCaptureSession alloc] init];
		
		// Start the process of getting a picture.
		session.sessionPreset = AVCaptureSessionPresetHigh;
		
		// Setup instance of input with back camera and add to session.
		NSError *error;
		AVCaptureDeviceInput *input =
		[AVCaptureDeviceInput deviceInputWithDevice: backCamera error:&error];
		
		if (!error && [session canAddInput:input]){
			
			[session addInput:input];
			
			// We need to capture still image.
			AVCaptureStillImageOutput *output = [[AVCaptureStillImageOutput alloc] init];
			
			// Captured image. settings.
			[output setOutputSettings:
			 [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil]];
						
			if ([session canAddOutput:output]){
				[session addOutput:output];
				[session startRunning];

				AVCaptureConnection *videoConnection = nil;
				for (AVCaptureConnection *connection in output.connections) {
					for (AVCaptureInputPort *port in [connection inputPorts]){
						if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
							videoConnection = connection;
							break;
						}
					}
					if (videoConnection) { break; }
				}
				
				// Finally take the picture
				if (videoConnection){
					//set orientation
					
					[videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
					
					[NSThread sleepForTimeInterval:0.3f];
					[output captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
																		
						if (imageDataSampleBuffer != NULL){
							NSData *imageData = [AVCaptureStillImageOutput
												 jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
							//UIImage *photo = [[UIImage alloc] initWithData:imageData];
							
							//Create filename
							NSString* filename = [msg stringByAppendingString:[self picNameComponent]];
							
							//Write into a folder as waiting list
							[imageData writeToFile:[self storagePath: filename] atomically:YES];
						}
					}];
				}
				
			}
			//End of Capture
		}
	}
	
	[self previewSetUp];
}


// Get IP Address

- (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
	
}

- (NSString*) storagePath:(NSString*) filename{
	
	NSArray *StoreFilePath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *DoucumentsDirectiory = [StoreFilePath objectAtIndex:0];
    NSString *filePath = [DoucumentsDirectiory stringByAppendingPathComponent:filename];
	return filePath;
}

- (NSString*) picNameComponent{
	int max, min;
	max = 999999;
	min = 100000;
	int randNum = arc4random() % (max - min) + min;
	NSString *num = [NSString stringWithFormat:@"%d.jpg", randNum];
	return num;
}

@end
