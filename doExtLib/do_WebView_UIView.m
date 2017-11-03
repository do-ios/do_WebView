//
//  do_WebView_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_WebView_UIView.h"
#import "doScriptEngineHelper.h"
#import "doSourceFile.h"
#import "doUIModuleHelper.h"
#import "doUIModule.h"
#import "doInvokeResult.h"
#import "doIPage.h"
#import "doIScriptEngine.h"
#import "doEventCenter.h"
#import "doServiceContainer.h"
#import "doIUIModuleFactory.h"
#import "doScriptEngineHelper.h"
#import "doTextHelper.h"
#import "doISourceFS.h"
#import "doUIContainer.h"
#import "doIScriptEngineFactory.h"
#import "doIOHelper.h"
#import "doJsonHelper.h"
#import "doEGORefreshTableHeaderView.h"
#import "doWebViewProgressView.h"

float InitialProgressValue = 0.6f;
const float InteractiveProgressValue = 0.5f;
const float FinalProgressValue = 0.9f;
const float _urltimeout = 60;

@interface do_WebView_UIView()<doEGORefreshTableDelegate,UIWebViewDelegate,UIScrollViewDelegate>
@property(nonatomic,strong)doInvokeResult *tempInvokeResult;
@property(nonatomic,strong)doEGORefreshTableHeaderView *doEGOHeaderView;
@end

@implementation do_WebView_UIView
{
    id<doIUIModuleView> _headView;
    BOOL _isRefreshing ;
    NSString* currentURL;
    BOOL _isHeaderVisible;
    BOOL _ifZoom;
    BOOL _firstLoad;//标示UIRefreshControl第一次添加
    doUIContainer *_headerContainer;
    
    BOOL _isShowLoadingProgress;
    
    //progress
    NSUInteger _loadingCount;
    NSUInteger _maxLoadCount;
    NSURL *_currentURL;
    
    float _progress;
    
    //progress view
    doWebViewProgressView *_progressView;
    
    BOOL _allowDeviceOne;
    
    NSString *_cacheType;
    
    BOOL _pullStatus;//下拉status = 1支触发一次
    
    NSURLRequest *_request;
    
    UIWebView *_webView;
    
    NSString *_progressColor;
    
    UIColor *_defaultColor;
    
    BOOL _isEncode;
    
    BOOL _isBounces;
}
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void)LoadView: (doUIModule *)_doUIModule
{
    model = (do_WebView_UIModel *)_doUIModule;
    CGFloat height = model.RealHeight;
    if (model.RealHeight <=0) {
        height = 0.5;
    }
    _webView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, model.RealWidth, height)];
    [self addSubview:_webView];
    _webView.delegate = self;
    _webView.scrollView.delegate = self;
    [self change_zoom:@"false"];
    _firstLoad = YES;
    _isHeaderVisible = NO;
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    _webView.backgroundColor = [UIColor clearColor];
    _maxLoadCount = _loadingCount = 0;
    
    _isShowLoadingProgress = NO;
    
    _allowDeviceOne = YES;
    
    _cacheType = @"no_cache";
    
    _pullStatus = NO;
    
    _webView.allowsInlineMediaPlayback = YES;
    
    _defaultColor = [UIColor colorWithRed:83.f / 255.f green:205.f / 255.f blue:105.f / 255.f alpha:1.0];
    
    _isEncode = YES;
    
    _isBounces = YES;
}
- (void)loadModuleJS
{
    if (_headerContainer) {
        NSString *header = [model GetPropertyValue:@"headerView"];
        [_headerContainer LoadDefalutScriptFile:header];
    }
}
- (doUIModule *) GetModel
{
    return model;
}

- (void)OnDispose
{
    if(html_scriptEngine!=nil){
        [html_scriptEngine Dispose];
        html_scriptEngine = nil;
    }
    if(_headView)
    {
        [(UIView *)_headView removeFromSuperview];
        [[_headView GetModel] Dispose];
        _headView = nil;
    }
    [_webView stopLoading];
    _webView.delegate = nil;
    _webView.scrollView.delegate = nil;
    model = nil;
    [_headerContainer Dispose];
    _headerContainer = nil;
    
    _currentURL = nil;
    [_progressView removeFromSuperview];
    _progressView = nil;
}

- (void) OnRedraw
{
    [doUIModuleHelper OnRedraw:model];
    if(_headView)
    {
        [_headView OnRedraw];
        [self drawheadView];
    }
    //为了确保dhtm引擎加载的时候，UIContainer的rootview不为空，在这里再执行一次
    [self initDHtmScript];
    
    //增加progressView
    CGFloat progressBarHeight = 2.f;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGRect barFrame = CGRectMake(0, 0, screenWidth, progressBarHeight);
    if (!_progressView && _isShowLoadingProgress) {
        _progressView = [[doWebViewProgressView alloc] initWithFrame:barFrame];
        _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_progressView];
        [self reset];
    }
    //支持-1
    BOOL isAutoHeight = [[model GetPropertyValue:@"height"] isEqualToString:@"-1"];
    if (isAutoHeight) {
        CGRect superRect = self.superview.frame;
        CGRect fixFrame = CGRectMake(model.RealX, model.RealY, superRect.size.width, superRect.size.height - model.RealY);
        self.frame = fixFrame;
    }
    if ([currentURL isEqualToString:@""] || !currentURL) {
        [self completeProgress];
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    _webView.frame = self.bounds;
}

- (void)OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    [doUIModuleHelper HandleViewProperChanged: self :model : _changedValues ];
}

-(BOOL)OnPropertiesChanging:(NSMutableDictionary *)_changedValues
{
    return YES;
}

-(BOOL)InvokeSyncMethod:(NSString *)_methodName :(NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine :(doInvokeResult *)_invokeResult
{
    return [doScriptEngineHelper InvokeSyncSelector:self :_methodName :_dicParas :_scriptEngine :_invokeResult];
}

-(BOOL)InvokeAsyncMethod:(NSString *)_methodName :(NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine :(NSString *)_callbackFuncName
{
    return [doScriptEngineHelper InvokeASyncSelector:self :_methodName :_dicParas :_scriptEngine :_callbackFuncName];
}

#pragma mark -
#pragma mark - progress
- (void)startProgress
{
    if (_progress < InitialProgressValue) {
        [self setProgress:InitialProgressValue];
    }
}

- (void)incrementProgress
{
    float progress = _progress;
    float maxProgress = FinalProgressValue;
    float remainPercent = (float)_loadingCount / (float)_maxLoadCount;
    float increment = (maxProgress - progress) * remainPercent;
    progress += increment;
    progress = fmin(progress, maxProgress);
    [self setProgress:progress];
}

- (void)completeProgress
{
    [self setProgress:1.0];
}

- (void)setProgress:(float)progress
{
    if (progress > _progress || progress == 0) {
        _progress = progress;
        [_progressView setProgress:progress animated:YES];
    }
}

- (void)reset
{
    _maxLoadCount = _loadingCount = 0;
    [self setProgress:0.0];
}

#pragma mark -
#pragma mark - change property
- (void)change_zoom: (NSString *)newValue
{
    _ifZoom = [newValue boolValue];
    _webView.scalesPageToFit = _ifZoom;
}

- (void)change_url: (NSString *)_url
{
    for (int i=0; i<6; i++) {
        InitialProgressValue = (1 + (arc4random() % 6))/10.0;
    }
    
    if (_url != nil && _url.length > 0)
    {
        _url = [_url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        currentURL = [self getFullWebUrl:_url];
        if (_isEncode) {
            currentURL = [currentURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        [self initDHtmScript];
        if (currentURL && currentURL.length>0) {
            [self navigate:currentURL];
        }
    }
}

- (void)change_headerView:(NSString *)herderView
{
    id<doIPage> pageModel = model.CurrentPage;
    doSourceFile *fileName = [pageModel.CurrentApp.SourceFS GetSourceByFileName:herderView];
    if(!fileName)
    {
        [NSException raise:@"webView" format:@"无效的headView路径:%@",herderView,nil];
        return;
    }
    _headerContainer = [[doUIContainer alloc] init:pageModel];
    [_headerContainer LoadFromFile:fileName:nil:nil];
    doUIModule *headViewModel = _headerContainer.RootView;
    if (headViewModel == nil)
    {
        [NSException raise:@"webView" format:@"创建headerViewModel失败",nil];
        return;
    }
    UIView *insertView = (UIView*)headViewModel.CurrentUIModuleView;
    _headView = headViewModel.CurrentUIModuleView;
    if (insertView == nil)
    {
        [NSException raise:@"webView" format:@"创建headerView失败"];
        return;
    }
    _firstLoad = NO;
    if (insertView && _isHeaderVisible) {
        [_webView.scrollView addSubview:insertView];
    }
    if (pageModel.ScriptEngine) {
        [_headerContainer LoadDefalutScriptFile:herderView];
    }
}
- (void)change_isHeaderVisible:(NSString *)newValue
{
    _isHeaderVisible = [[doTextHelper Instance] StrToBool:newValue :NO];
}
- (void)change_isShowLoadingProgress:(NSString *)newValue
{
    _isShowLoadingProgress = [newValue boolValue];
}
- (void)change_allowDeviceOne:(NSString *)newValue
{
    _allowDeviceOne = [newValue boolValue];
}
- (void)change_cacheType:(NSString *)newValue
{
    _cacheType = newValue;
    if ([newValue isEqualToString:@"no_cache"])
        _cacheType = @"0";
    else if ([newValue isEqualToString:@"normal"])
        _cacheType = @"1";
    else
        _cacheType = [@([newValue boolValue]) stringValue];
    [model SetPropertyValue:@"cacheType" :_cacheType];
}
- (void)change_bounces:(NSString *)newValue
{
    _isBounces = [newValue boolValue];
    _webView.scrollView.bounces = _isBounces;
}
- (void)change_allowVideoFullScreenPlayback:(NSString *)newValue
{
    _webView.allowsInlineMediaPlayback = ![newValue boolValue];
}
- (void)change_userAgent:(NSString *)newValue
{
//    NSString *userAgent = [[[UIWebView alloc] init] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
//    NSString *customUserAgent = [userAgent stringByAppendingFormat:@"%@",newValue];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent":newValue}];
}

#pragma mark -
#pragma mark 重写get方法
- (doInvokeResult *)tempInvokeResult
{
    if (!_tempInvokeResult) {
        _tempInvokeResult = [[doInvokeResult alloc]init:model.UniqueKey];
    }
    return _tempInvokeResult;
}

- (doEGORefreshTableHeaderView *)doEGOHeaderView
{
    if (!_doEGOHeaderView) {
        _doEGOHeaderView = [[doEGORefreshTableHeaderView alloc]initWithFrame:CGRectMake(0, 0 - _webView.scrollView.bounds.size.height, _webView.scrollView.bounds.size.width, _webView.scrollView.bounds.size.height)];
        _doEGOHeaderView.backgroundColor = [UIColor clearColor];
        _firstLoad = NO;
        _doEGOHeaderView.delegate = self;
        [_webView.scrollView addSubview:_doEGOHeaderView];
    }
    [_doEGOHeaderView refreshLastUpdatedDate];
    return _doEGOHeaderView;
}


#pragma mark -
#pragma mark - private
- (void) initDHtmScript
{
    if (!_allowDeviceOne) {
        return;
    }
    
    //只有扩展名是.dhtm才需要加载do_html.js
    doUIModule* rootview = ((doUIModule*)model).CurrentUIContainer.RootView;
    if(rootview!=nil){
        //创建webview对应的脚本，需要把当前model的地址传到脚本引擎
        html_scriptEngine = [[doServiceContainer Instance].ScriptEngineFactory CreateScriptEngine:model.CurrentPage.CurrentApp :model.CurrentPage:[@"dhtm:" stringByAppendingString:model.UniqueKey] :currentURL];
    }
}
- (void)drawheadView
{
    if (_headView) {
        UIView *headView = (UIView *)_headView;
        //如果header的模板不是和屏幕一样宽的bug
        CGFloat realW = headView.frame.size.width;
        CGFloat realH = headView.frame.size.height;
        headView.frame = CGRectMake(headView.frame.origin.x, -realH, realW, realH);
        return;
    }
    else
    {
        CGFloat realW = _webView.scrollView.contentSize.width;
        CGFloat realH = _doEGOHeaderView.frame.size.height;
        _doEGOHeaderView.frame = CGRectMake(0, -realH, realW, realH);
    }
}

- (NSString *)getFullWebUrl:(NSString *)_name
{
    if (_name == nil || _name.length <= 0) return @"";
    if ([_name hasPrefix:@"http:"]|| [_name hasPrefix:@"https:"] || [_name hasPrefix:@"file:"])
    {
        return _name;
    }
    
    NSString * _urlPath = [doIOHelper GetLocalFileFullPath:model.CurrentPage.CurrentApp :_name];
    return _urlPath;
}

- (void)navigate:(NSString *)_fullUrl
{
    NSURL *loadUrl = [NSURL fileURLWithPath:_fullUrl];
    if ([[NSFileManager defaultManager] fileExistsAtPath:_fullUrl]) {
    }else{
        NSString *urlStr = [NSString stringWithFormat:@"%@",_fullUrl];
        loadUrl = [NSURL URLWithString:urlStr];
    }
    NSURLRequestCachePolicy policy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    if(![_cacheType isEqualToString:@"no_cache"])
        policy = NSURLRequestUseProtocolCachePolicy;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:loadUrl cachePolicy:policy timeoutInterval:_urltimeout];
    request.HTTPShouldHandleCookies = true;
    NSArray<NSHTTPCookie *> *cookiesArray = [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies;
    for (NSHTTPCookie *cookie in cookiesArray) {
        NSString *cookieName = cookie.name;
        if ([cookieName isEqualToString:_fullUrl]) {
            [request setValue:cookie.value forHTTPHeaderField:@"Cookie"];
            break;
        }
    }
    
    [_webView loadRequest:request];
}
- (void)fireEvent:(int)state :(CGFloat)y
{
    if (!_isBounces) {
        return;
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@(state) forKey:@"state"];
    [dic setObject:@(fabs(y/model.YZoom)) forKey:@"offset"];
    [self.tempInvokeResult SetResultNode:dic];
    [model.EventCenter FireEvent:@"pull":self.tempInvokeResult];
}
#pragma mark -
#pragma mark - event
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (!_isShowLoadingProgress) {
        return YES;
    }
    
    BOOL ret = YES;
    
    BOOL isFragmentJump = NO;
    if (request.URL.fragment) {
        NSString *nonFragmentURL = [request.URL.absoluteString stringByReplacingOccurrencesOfString:[@"#" stringByAppendingString:request.URL.fragment] withString:@""];
        isFragmentJump = [nonFragmentURL isEqualToString:webView.request.URL.absoluteString]; // 请求的url中没有#
    }
    
    BOOL isTopLevelNavigation = [request.mainDocumentURL isEqual:request.URL];
    
    BOOL isHTTPOrLocalFile = [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"] || [request.URL.scheme isEqualToString:@"file"];
    if (ret && !isFragmentJump && isHTTPOrLocalFile && isTopLevelNavigation) {
        _currentURL = request.URL;
        if (_progress==1) {
            [self reset];
        }
    }
    return ret;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_isShowLoadingProgress) {
        _loadingCount--;
        [self incrementProgress];
        BOOL isNotRedirect = _currentURL && [_currentURL isEqual:webView.request.mainDocumentURL];
        if (isNotRedirect && !webView.isLoading) {
            [self completeProgress];
        }
    }
    
    if (html_scriptEngine) {
        [html_scriptEngine CallLoadScriptsAsModel];
    }
    if (!webView.isLoading) {
        _isRefreshing = NO;
        if(_isHeaderVisible && !_headView)
        {
            [self.doEGOHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:webView.scrollView];
        }
        doInvokeResult * _invokeResult = [[doInvokeResult alloc]init:model.UniqueKey];
        NSString *tempUrl = webView.request.URL.absoluteString;
        [_invokeResult SetResultText:tempUrl];
        [model.EventCenter FireEvent:@"loaded":_invokeResult];
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (_isShowLoadingProgress) {
        _loadingCount++;
        _maxLoadCount = fmax(_maxLoadCount, _loadingCount);
        [self startProgress];
    }
    
    _isRefreshing = YES;
    doInvokeResult * _invokeResult = [[doInvokeResult alloc]init:model.UniqueKey];
    [model.EventCenter FireEvent:@"start":_invokeResult];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (_isShowLoadingProgress) {
        _loadingCount--;
        [self incrementProgress];
        BOOL isNotRedirect = _currentURL && [_currentURL isEqual:webView.request.mainDocumentURL];
        if (isNotRedirect || error) {
            [self completeProgress];
        }
    }
    _isRefreshing = NO;
    if(_isHeaderVisible && !_headView)
    {
        [self.doEGOHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:webView.scrollView];
    }
    doInvokeResult * _invokeResult = [[doInvokeResult alloc]init:model.UniqueKey];
    [_invokeResult SetResultText:[error description]];
    [model.EventCenter FireEvent:@"failed":_invokeResult];
}
#pragma mark -
#pragma mark - scrollView代理

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (!_isHeaderVisible) {
        return;
    }
    if (_firstLoad) {
        [_webView.scrollView addSubview:self.doEGOHeaderView];
    }
    [self drawheadView];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_isHeaderVisible) {
        return;
    }
    
    //保证头和scrollView的宽度一样
    if (!_isRefreshing) {
        if (scrollView.contentOffset.y <= 0) {//下拉才触发
            if (!_headView) {
                [self.doEGOHeaderView egoRefreshScrollViewDidScroll:scrollView];
                if(scrollView.contentOffset.y >= 60*(-1))
                {
                    [self fireEvent:0 :scrollView.contentOffset.y];
                }
                else
                {
                    if (!_pullStatus) {
                        _pullStatus = YES;
                        [self fireEvent:1 :scrollView.contentOffset.y];
                    }
                    
                }
            }
            else
            {
                if(scrollView.contentOffset.y >= ((UIView *)_headView).frame.size.height*(-1))
                {
                    [self fireEvent:0 :scrollView.contentOffset.y];
                }
                else
                {
                    if (!_pullStatus) {
                        _pullStatus = YES;
                        [self fireEvent:1 :scrollView.contentOffset.y];
                    }
                }
            }
        }
        
    }
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!_isHeaderVisible) {
        return;
    }
    if (!_headView) {
        [self.doEGOHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
    }
    if (!_isRefreshing) {
        UIEdgeInsets edgeInsets;
        if (_headView) {
            edgeInsets = UIEdgeInsetsMake(((UIView *)_headView).frame.size.height, 0, 0, 0);
        }
        else
        {
            edgeInsets = UIEdgeInsetsMake(60, 0, 0, 0);
        }
        if(scrollView.contentOffset.y <= edgeInsets.top*(-1))
        {
            if (_headView) {
                [UIView animateWithDuration:0.2 animations:^{
                    _webView.scrollView.contentInset = edgeInsets;
                }];
            }
            [self fireEvent:2 :scrollView.contentOffset.y];
            _isRefreshing = YES;
        }
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _pullStatus = NO;
}
- (void)egoRefreshTableDidTriggerRefresh:(EGORefreshPos)aRefreshPos
{
    _isRefreshing = NO;
}
-(BOOL)egoRefreshTableDataSourceIsLoading:(UIView *)view
{
    return _isRefreshing;
}
-(NSDate *)egoRefreshTableDataSourceLastUpdated:(UIView *)view
{
    return [NSDate date];
}
#pragma mark -
#pragma mark Methods
- (void)loadString :(NSArray *)_parms
{
    NSDictionary *_dictParas = [_parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine =[_parms objectAtIndex:1];
    NSString *_callbackFuncName = [_parms objectAtIndex:2];
    doInvokeResult *_invokeResult = [[doInvokeResult alloc] init:model.UniqueKey];
    @try {
        NSString* _text =[doJsonHelper GetOneText: _dictParas : @"text" : @""];
        
        [_webView loadHTMLString:_text baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
    }
    @catch (NSException *exception) {
        [_invokeResult SetException:exception];
    }
    [_scriptEngine Callback:_callbackFuncName :_invokeResult];
}

- (void)setCookie:(NSArray *)_parms
{
//    [NSHTTPCookieStorage sharedHTTPCookieStorage].cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    NSDictionary *_dictParas = [_parms objectAtIndex:0];
    NSString *_urlStr = [doJsonHelper GetOneText:_dictParas :@"url" :@""];
    NSURL*cookieHost=[NSURL URLWithString:_urlStr];
    NSString *_value = [doJsonHelper GetOneText:_dictParas :@"value" :@""];
    // To successfully create a cookie, you must provide values for (at least) the path,name, and value keys, and either the originURL key or the domain key.See Constants for more information on the available cookie attribute constants and the constraints imposed on the values in the dictionary.
    
    NSString *path = @""; // 不能为空字符串
    if ([[cookieHost path] isEqualToString:@""]) {
        path = @"/";
    }else {
        path = [cookieHost path];
    }
    
    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    [cookieProperties setObject:path forKey:NSHTTPCookiePath];
    [cookieProperties setObject:_urlStr forKey:NSHTTPCookieName];
    [cookieProperties setObject:_value forKey:NSHTTPCookieValue];
    [cookieProperties setObject:_urlStr forKey:NSHTTPCookieOriginURL];
    [cookieProperties setObject:[cookieHost host] forKey:NSHTTPCookieDomain];
    NSHTTPCookie *cookieuser = [NSHTTPCookie cookieWithProperties:cookieProperties];
    
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookieuser];

}

- (void)back :(NSArray *)_parms
{
    [_webView goBack];
}

- (void)forward :(NSArray *)_parms
{
    [_webView goForward];
}

- (void)reload :(NSArray *)_parms
{
    [_webView reload];
}

- (void)stop :(NSArray *)_parms
{
    [_webView stopLoading];
}

- (void)canForward :(NSArray *)_parms
{
    doInvokeResult *_invokeResult = [_parms objectAtIndex:2];
    [_invokeResult SetResultBoolean:_webView.canGoForward];
}

- (void)canBack :(NSArray *)_parms
{
    doInvokeResult *_invokeResult = [_parms objectAtIndex:2];
    [_invokeResult SetResultBoolean:_webView.canGoBack];
}

- (void)getOffsetX :(NSArray *)_parms
{
    doInvokeResult *_invokeResult = [_parms objectAtIndex:2];
    NSString *offsetX = [NSString stringWithFormat:@"%f", _webView.scrollView.contentOffset.x];
    [_invokeResult SetResultText:offsetX];
}

- (void)getOffsetY :(NSArray *)_parms
{
    doInvokeResult *_invokeResult = [_parms objectAtIndex:2];
    NSString *offsetY = [NSString stringWithFormat:@"%f", _webView.scrollView.contentOffset.y];
    [_invokeResult SetResultText:offsetY];
}

- (void)rebound:(NSArray *)parms
{
    _isRefreshing = NO;
    _pullStatus = NO;
    if (!_headView && _isHeaderVisible) {
        [self.doEGOHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_webView.scrollView];
    }
    [UIView animateWithDuration:0.2 animations:^{
        _webView.scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    }];
    
}

- (void)setLoadingProgressColor:(NSArray *)parms
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    _progressColor = [doJsonHelper GetOneText:_dictParas :@"color" :@""];

    if (_progressColor.length>0) {
        _progressView.progressBarView.backgroundColor = [doUIModuleHelper GetColorFromString:_progressColor :_defaultColor];
    }
}

- (void)getContentSize:(NSArray *)parms
{
    doInvokeResult *_invokeResult = [parms objectAtIndex:2];
    
    CGSize size = [_webView.scrollView contentSize];
    CGFloat width = size.width/model.XZoom;
    CGFloat height = size.height/model.YZoom;
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:@(width) forKey:@"width"];
    [dict setObject:@(height) forKey:@"height"];
    
    [_invokeResult SetResultNode:dict];
}

- (void)setDefaultEncodingURL:(NSArray *)parms
{
    NSDictionary *_dict = [parms objectAtIndex:0];
    _isEncode = [doJsonHelper GetOneBoolean:_dict :@"isEncode" :YES];
}

- (void)eval:(NSArray *)parms
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    __block id<doIScriptEngine> _scriptEngine =[parms objectAtIndex:1];
    NSString *_callbackFuncName = [parms objectAtIndex:2];
    __block doInvokeResult *_invokeResult = [[doInvokeResult alloc] init:model.UniqueKey];

    NSString *code = [doJsonHelper GetOneText:_dictParas :@"code" :@""];
    if (code.length==0) {
        return;
    }
    __block NSString *result;
    dispatch_async(dispatch_get_main_queue(), ^{
        result = [[_webView stringByEvaluatingJavaScriptFromString:code] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [_invokeResult SetResultText:result];
        [_scriptEngine Callback:_callbackFuncName :_invokeResult];
    });
}

@end
