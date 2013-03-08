//
//  AFHTTPRequestOperationLogger+VolumeControl.m
//  Copyright (c) 2013 Oliver Letterer
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "AFHTTPRequestOperationLogger+VolumeControl.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#ifdef DEBUG

char *const AFHTTPRequestOperationLoggerVolumeLevelKey;

static NSString *NSStringFromAFHTTPRequestLoggerLevel(AFHTTPRequestLoggerLevel logLevel)
{
    switch (logLevel) {
        case AFLoggerLevelDebug:
            return @"AFLoggerLevelDebug";
            break;
        case AFLoggerLevelInfo:
            return @"AFLoggerLevelInfo";
            break;
        case AFLoggerLevelOff:
            return @"AFLoggerLevelOff";
            break;
        default:
            break;
    }
    
    return @"Unkown";
}

static void class_swizzleSelector(Class class, SEL originalSelector, SEL newSelector)
{
    Method origMethod = class_getInstanceMethod(class, originalSelector);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    if(class_addMethod(class, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(class, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}



@implementation AFHTTPRequestOperationLogger (VolumeControl)

#pragma mark - setters and getters

- (CGFloat)volumeLevel
{
    return [objc_getAssociatedObject(self, &AFHTTPRequestOperationLoggerVolumeLevelKey) floatValue];
}

- (void)setVolumeLevel:(CGFloat)volumeLevel
{
    CGFloat previousVolumeLevel = self.volumeLevel;
    
    if (volumeLevel != previousVolumeLevel) {
        objc_setAssociatedObject(self, &AFHTTPRequestOperationLoggerVolumeLevelKey,
                                 @(volumeLevel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if (volumeLevel > previousVolumeLevel) {
            [self _volumeLevelDidIncrease];
        } else {
            [self _volumeLevelDidDecrease];
        }
    } else if (volumeLevel == 0.0f) {
        [self _volumeLevelDidDecrease];
    } else if (volumeLevel == 1.0f) {
        [self _volumeLevelDidIncrease];
    }
}

#pragma mark - Initialization

+ (NSArray *)logLevels
{
    static NSArray *logLevels = nil;
    
    if (!logLevels) {
        logLevels = @[
                      @(AFLoggerLevelOff),
                      @(AFLoggerLevelInfo),
                      @(AFLoggerLevelDebug)
                      ];
    }
    
    return logLevels;
}

+ (void)load
{
    class_swizzleSelector(self, @selector(init), @selector(__hookedInit));
}

- (id)__hookedInit __attribute__((objc_method_family(init)))
{
    if ((self = [self __hookedInit])) {
        CGFloat volumeLevel = [MPMusicPlayerController applicationMusicPlayer].volume;
        objc_setAssociatedObject(self, &AFHTTPRequestOperationLoggerVolumeLevelKey,
                                 @(volumeLevel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100.0f, 0.0f, 10.0f, 0.0f)];
        [volumeView sizeToFit];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication].keyWindow.rootViewController.view addSubview:volumeView];
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_volumeLevelDidChangeCallback:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    }
    
    return self;
}

#pragma mark - private implementation

- (void)_volumeLevelDidChangeCallback:(NSNotification *)notification
{
    self.volumeLevel = [notification.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
}

- (void)_volumeLevelDidIncrease
{
    NSArray *logLevels = [self.class logLevels];
    NSInteger currentIndex = [logLevels indexOfObject:@(self.level)];
    if (currentIndex == NSNotFound) {
        return;
    }
    
    currentIndex++;
    if (currentIndex >= logLevels.count) {
        return;
    }
    
    AFHTTPRequestLoggerLevel logLevel = [[logLevels objectAtIndex:currentIndex] integerValue];
    
    NSLog(@"changing log level to %@", NSStringFromAFHTTPRequestLoggerLevel(logLevel));
    self.level = logLevel;
}

- (void)_volumeLevelDidDecrease
{
    NSArray *logLevels = [self.class logLevels];
    NSInteger currentIndex = [logLevels indexOfObject:@(self.level)];
    if (currentIndex == NSNotFound) {
        return;
    }
    
    currentIndex--;
    if (currentIndex < 0) {
        return;
    }
    
    AFHTTPRequestLoggerLevel logLevel = [[logLevels objectAtIndex:currentIndex] integerValue];
    
    NSLog(@"changing log level to %@", NSStringFromAFHTTPRequestLoggerLevel(logLevel));
    self.level = logLevel;
}

@end

#endif
