//
//  AZSoundManager.m
//
//  Created by Aleksey Zunov on 06.08.15.
//  Copyright (c) 2015 aleksey.zunov@gmail.com. All rights reserved.
//

#import "AZSoundManager.h"

@interface AZSoundManager () <AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioPlayer *player;

@property (nonatomic) AZSoundStatus status;
@property (nonatomic, strong) AZSoundItem *currentItem;

@property (nonatomic, strong) NSTimer *infoTimer;
@property (nonatomic, copy) progressBlock progressBlock;
@property (nonatomic, copy) completionBlock completionBlock;

@end

@implementation AZSoundManager

#pragma mark - Init

+ (instancetype)sharedManager
{
    static AZSoundManager *sharedManager = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{ sharedManager = [[AZSoundManager alloc] init];});
    return sharedManager;
}

- (id)init
{
    if (self = [super init])
    {
        self.volume = 1.0f;
        self.pan = 0.0f;
        self.status = AZSoundStatusNotStarted;
        
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
    return self;
}

#pragma mark - Properties

- (void)setVolume:(float)volume
{
    if (_volume != volume)
    {
        _volume = volume;
        self.player.volume = volume;
    }
}

- (void)setPan:(float)pan
{
    if (_pan != pan)
    {
        _pan = pan;
        self.player.pan = pan;
    }
}

#pragma mark - Private Functions

- (void)startTimer
{
    if (!self.infoTimer)
    {
        NSTimeInterval interval = (self.player.rate > 0) ? (1.0f / self.player.rate) : 1.0f;
        self.infoTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self
                                               selector:@selector(timerFired:)
                                               userInfo:nil repeats:YES];
    }
}

- (void)stopTimer
{
    [self.infoTimer invalidate];
    self.infoTimer = nil;
}

- (void)timerFired:(NSTimer*)timer
{
    [self.currentItem updateCurrentTime:self.player.currentTime];
    
    if (self.progressBlock)
    {
        self.progressBlock(self.currentItem);
    }
}

#pragma mark - Public Functions

- (void)preloadSoundItem:(AZSoundItem*)item
{
    self.currentItem = item;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:item.URL error:nil];
    self.player.delegate = self;
    [self.player prepareToPlay];
}

- (void)playSoundItem:(AZSoundItem*)item
{
    [self preloadSoundItem:item];
    [self play];
}

- (void)play
{
    if (!self.player) return;
    
    [self.player play];
    self.status = AZSoundStatusPlaying;
    
    [self startTimer];
}

- (void)pause
{
    if (!self.player) return;
    
    [self.player pause];
    self.status = AZSoundStatusPaused;
    
    [self stopTimer];
}

- (void)stop
{
    if (!self.player) return;
    
    [self.player stop];
    self.player = nil;
    self.currentItem = nil;
    self.status = AZSoundStatusNotStarted;
    
    [self stopTimer];
}

- (void)restart
{
    [self playAtSecond:0];
}

- (void)playAtSecond:(NSInteger)second
{
    [self rewindToSecond:second];
    [self play];
}

- (void)rewindToSecond:(NSInteger)second
{
    if (!self.player) return;
    self.player.currentTime = second;
}

- (void)getItemInfoWithProgressBlock:(progressBlock)progressBlock
                     completionBlock:(completionBlock)completionBlock
{
    self.progressBlock = progressBlock;
    self.completionBlock = completionBlock;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    self.status = AZSoundStatusFinished;
    
    [self stopTimer];

    if (self.completionBlock && flag)
    {
        self.completionBlock();
    }
}

@end
