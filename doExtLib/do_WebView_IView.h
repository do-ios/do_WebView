//
//  do_WebView_UI.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol do_WebView_IView <NSObject>

@required
//属性方法
- (void)change_allowDeviceOne:(NSString *)newValue;
//- (void)change_allowVideoFullScreenPlayback:(NSString *)newValue;
- (void)change_bounces:(NSString *)newValue;
- (void)change_cacheType:(NSString *)newValue;
- (void)change_headerView:(NSString *)newValue;
- (void)change_isHeaderVisible:(NSString *)newValue;
- (void)change_isShowLoadingProgress:(NSString *)newValue;
- (void)change_url:(NSString *)newValue;
- (void)change_userAgent:(NSString *)newValue;
- (void)change_zoom:(NSString *)newValue;
- (void)change_scrollEnable:(NSString *)newValue;

//同步或异步方法
- (void)back:(NSArray *)parms;
- (void)canBack:(NSArray *)parms;
- (void)canForward:(NSArray *)parms;
- (void)forward:(NSArray *)parms;
- (void)loadString:(NSArray *)parms;
- (void)rebound:(NSArray *)parms;
- (void)reload:(NSArray *)parms;
- (void)setCookie:(NSArray *)parms;
- (void)stop:(NSArray *)parms;
- (void)setLoadingProgressColor:(NSArray *)parms;
- (void)getContentSize:(NSArray *)parms;
- (void)setDefaultEncodingURL:(NSArray *)parms;
- (void)eval:(NSArray *)parms;
@end
