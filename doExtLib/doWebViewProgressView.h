//
//  doWebViewProgressView.h
//  doDebuger
//
//  Created by wl on 15/9/9.
//  Copyright (c) 2015年 deviceone. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface doWebViewProgressView : UIView
@property (nonatomic) float progress;

@property (nonatomic) UIView *progressBarView;
@property (nonatomic) NSTimeInterval barAnimationDuration; // default 0.1
@property (nonatomic) NSTimeInterval fadeAnimationDuration; // default 0.27
@property (nonatomic) NSTimeInterval fadeOutDelay; // default 0.1

- (void)setProgress:(float)progress animated:(BOOL)animated;

@end
