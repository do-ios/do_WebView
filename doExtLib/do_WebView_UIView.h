//
//  do_WebView_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_WebView_IView.h"
#import "do_WebView_UIModel.h"
#import "doIUIModuleView.h"

@interface do_WebView_UIView : UIView<do_WebView_IView, doIUIModuleView>
//可根据具体实现替换UIView
{
	@private
		__weak do_WebView_UIModel *model;
        id<doIScriptEngine> html_scriptEngine;
}
- (void)loadModuleJS;
@end
