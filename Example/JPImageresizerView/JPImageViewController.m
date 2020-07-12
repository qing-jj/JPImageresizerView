//
//  JPImageViewController.m
//  JPImageresizerView_Example
//
//  Created by 周健平 on 2018/1/2.
//  Copyright © 2018年 ZhouJianPing. All rights reserved.
//

#import "JPImageViewController.h"
#import "JPPhotoTool.h"
#import "JPImageresizerSlider.h"

@interface JPImageViewController ()
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (nonatomic, weak) UIImageView *imageView;
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, weak) AVPlayerLayer *playerLayer;
@property (nonatomic, weak) JPImageresizerSlider *slider;
@property (nonatomic, strong) id timeObserver;
@end

@implementation JPImageViewController
{
    BOOL _isDidAppear;
}

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Finish";
    [self __setupNavigationBar];
    [self __changBgColor];
    if (self.videoURL) {
        [self __setupPlayerLayer];
        [self __setupSlider];
    } else {
        [self __setupImageView];
    }
    
    JPObserveNotification(self, @selector(__didChangeStatusBarOrientation), UIApplicationDidChangeStatusBarOrientationNotification, nil);
    [self __didChangeStatusBarOrientation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    if (_isDidAppear) return;
    _isDidAppear = YES;
    
    [self.player play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.player pause];
}

- (void)dealloc {
    NSLog(@"imageViewController is dead");
    if (self.videoURL) {
        JPRemoveNotification(self);
        [self.playerLayer removeFromSuperlayer];
        if (self.timeObserver) {
            [self.player removeTimeObserver:self.timeObserver];
            self.timeObserver = nil;
        }
        NSLog(@"删除视频文件");
        [[NSFileManager defaultManager] removeItemAtURL:self.videoURL error:nil];
    }
}

#pragma mark - 初始布局

- (void)__setupNavigationBar {
    UIButton *camceraBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    camceraBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [camceraBtn setTitle:@"保存相册" forState:UIControlStateNormal];
    [camceraBtn addTarget:self action:@selector(__savePhotoToAppAlbum) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:camceraBtn];
}

- (void)__setupPlayerLayer {
    AVURLAsset *asset = [AVURLAsset assetWithURL:self.videoURL];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:item];
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:playerLayer];
    self.playerLayer = playerLayer;
    self.player = player;
    
    @jp_weakify(self);
    self.timeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        @jp_strongify(self);
        if (!self) return;
        self.slider.second = CMTimeGetSeconds(time);
    }];
    
    JPObserveNotification(self, @selector(__playDidEnd), AVPlayerItemDidPlayToEndTimeNotification, item);
}

- (void)__setupSlider {
    @jp_weakify(self);
    JPImageresizerSlider *slider = [JPImageresizerSlider imageresizerSlider:CMTimeGetSeconds(self.player.currentItem.asset.duration) second:0];
    slider.sliderBeginBlock = ^(float second) {
        @jp_strongify(self);
        if (!self) return;
        [self.player pause];
    };
    slider.sliderDragingBlock = ^(float second) {
        @jp_strongify(self);
        if (!self) return;
        [self.player seekToTime:CMTimeMakeWithSeconds(second, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    };
    slider.sliderEndBlock = ^(float second) {
        @jp_strongify(self);
        if (!self) return;
        [self.player play];
    };
    [self.view addSubview:slider];
    self.slider = slider;
}

- (void)__setupImageView {
    self.toolbar.hidden = YES;
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:imageView];
    self.imageView = imageView;
}

#pragma mark - 通知方法

- (void)__didChangeStatusBarOrientation {
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(JPNavBarH + JPMargin, JPMargin, JPDiffTabBarH + JPMargin, JPMargin);
    BOOL isLandscape = JPScreenWidth > JPScreenHeight;
    if (isLandscape) {
        if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft) {
            contentInsets.left += JPStatusBarH;
            contentInsets.right += JPDiffTabBarH;
        } else {
            contentInsets.left += JPDiffTabBarH;
            contentInsets.right += JPStatusBarH;
        }
    } else {
        contentInsets.top += JPStatusBarH;
    }
    CGFloat x = contentInsets.left;
    CGFloat y = contentInsets.top;
    CGFloat w = JPScreenWidth - contentInsets.left - contentInsets.right;
    CGFloat h = JPScreenHeight - contentInsets.top - contentInsets.bottom;
    if (self.videoURL) {
        if (!isLandscape) h -= JPNavBarH;
        [self.slider setImageresizerFrame:CGRectMake(x, y, w, h) isRoundResize:NO];
        h -= [JPImageresizerSlider viewHeight];
        self.playerLayer.frame = CGRectMake(x, y, w, h);
    } else {
        self.imageView.frame = CGRectMake(x, y, w, h);
    }
}

- (void)__playDidEnd {
    [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self.player pause];
}

#pragma mark - 私有方法

- (void)__changBgColor {
    @jp_weakify(self);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.view jp_addPOPBasicAnimationWithPropertyNamed:kPOPViewBackgroundColor toValue:JPRandomColor duration:2.0 completionBlock:^(POPAnimation *anim, BOOL finished) {
            @jp_strongify(self);
            if (!self) return;
            [self __changBgColor];
        }];
    });
}

#pragma mark - 事件触发方法

- (void)__savePhotoToAppAlbum {
    [JPProgressHUD show];
    if (self.videoURL) {
        [JPPhotoToolSI saveVideoWithFileURL:self.videoURL successHandle:^(NSString *assetID) {
            [JPProgressHUD showSuccessWithStatus:@"保存成功" userInteractionEnabled:YES];
        } failHandle:^{
            [JPProgressHUD showSuccessWithStatus:@"保存失败" userInteractionEnabled:YES];
        }];
        return;
    }
    [JPPhotoToolSI savePhotoToAppAlbumWithImage:self.image successHandle:^(NSString *assetID) {
        [JPProgressHUD showSuccessWithStatus:@"保存成功" userInteractionEnabled:YES];
    } failHandle:^(NSString *assetID, BOOL isGetAlbumFail, BOOL isSaveFail) {
        [JPProgressHUD showSuccessWithStatus:@"保存失败" userInteractionEnabled:YES];
    }];
}


- (IBAction)play:(id)sender {
    [self.player play];
}

- (IBAction)pause:(id)sender {
    [self.player pause];
}

@end
