//
//  ViewController.m
//  AVPlayerCacheDemo
//
//  Created by 奉强 on 16/6/16.
//  Copyright © 2016年 奉强. All rights reserved.
//

#define VideoUrl @"http://res.pmit.cn/F3Video/hls/a5814959235386e4e7126573030c4d79/list.m3u8"

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "M3U8Handler.h"
#import "GCDWebServer.h"
#import "GCDWebServerRequest.h"
#import "AFNetworking/AFNetworking.h"

@interface ViewController () <AVAssetResourceLoaderDelegate, M3U8HandlerDelegate>

@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, strong) GCDWebServer *webServer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setWebSever];
    
    [self buildPlayer];
}

- (void)setWebSever {
    self.webServer = [[GCDWebServer alloc] init];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    path = [NSString stringWithFormat:@"%@/video/", path];
    [self.webServer addGETHandlerForBasePath:@"/" directoryPath:path indexFilename:@"list.m3u8" cacheAge:3600 allowRangeRequests:YES];
    [self.webServer startWithPort:8080 bonjourName:nil];
}

- (void)buildPlayer {
//    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    path = [NSString stringWithFormat:@"%@/video/list.m3u8", path];
//    NSLog(@"%@", path);
    NSURL *url = [NSURL URLWithString:@"http://localhost:8080/list.m3u8"];
//    NSLog(@"%@", url);
    
    AVURLAsset *playerAsset = [AVURLAsset assetWithURL:url];
    [playerAsset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:playerAsset];
    
    AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    
    playerLayer.frame = CGRectMake(0, 64, 320, 160);
    
    [self.view.layer addSublayer:playerLayer];
    
    self.player = player;
    
    //监听播放状态变化
    [self.player addObserver:self forKeyPath:@"status"
                     options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                     context:nil];

}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.player play];
}

#pragma mark - AVAssetResourceLoaderDelegate
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
//    NSLog(@"%@", loadingRequest.request.URL);
    return NO;
}

-(void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
//    NSLog(@"%@", loadingRequest.request.URL);
}


#pragma mark - Event
- (IBAction)startHandleClick:(UIButton *)sender {
    
//    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    path = [NSString stringWithFormat:@"%@/video/list.m3u8", path];
    //    NSLog(@"%@", path);
//    NSURL *url = [NSURL fileURLWithPath:path];
    
    M3U8Handler *m3u8Handler = [M3U8Handler new];
    
    [m3u8Handler praseM3U8With:[NSURL URLWithString:VideoUrl] handlerDelegate:self];
}

#pragma mark - M3U8HandlerDelegate
- (void)praseM3U8InfoFinish:(M3U8Handler *)handler {
#ifdef DEBUG
    NSLog(@"解析完成");
#endif
    for (SegmentInfo *url in handler.segments) {
        [self downloadWithUrl:[NSURL URLWithString:url.tsURL]];
    }
    
}

- (void)M3U8Handler:(M3U8Handler *)handler praseError:(NSError *)error {
#ifdef DEBUG
    NSLog(@"解析错误-- %@", error);
#endif
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ([object isKindOfClass:[self.player class]]) {
        
        if ([keyPath isEqualToString:@"status"]) {
            //状态改变
            AVPlayerStatus oldStatus = [((NSNumber *)change[@"old"]) integerValue];
            AVPlayerStatus newStatus = [((NSNumber *)change[@"new"]) integerValue];
            NSLog(@"%ld--%ld", (long)oldStatus, (long)newStatus);
            
            if (newStatus == AVPlayerStatusReadyToPlay) {
//                [self.player play];
            }
//            [self playerStatusChangeFromOldStatus:oldStatus toNewStatus:newStatus];
        }
    }
}


#pragma mark - Download
- (void)downloadWithUrl:(NSURL *)url {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        path = [path stringByAppendingPathComponent:@"video"];
        NSLog(@"path = %@", path);
        NSURL *documentsDirectoryURL = [NSURL fileURLWithPath:path];
        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        NSLog(@"File downloaded to: %@", filePath);
    }];
    [downloadTask resume];
}

@end
