//
//  JLFullScreenPageViewController.h
//  JLFullScreenPageViewController
//
//  Created by Jangsy7883 on 2015. 9. 4..
//  Copyright © 2015년 Dalkomm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JLPageViewController.h"
#import "JLSegmentedBar.h"

typedef NS_ENUM(NSInteger, JLFullScreenStyle)
{
    JLFullScreenStyleAutomatic = 0,
    JLFullScreenStyleScrolling,
};

@interface JLFullScreenPageViewController : UIViewController<KMPageViewDataSource,KMPageViewDelegate>

@property (nonatomic, strong, readonly) UINavigationBar *navigationBar;
@property (nonatomic, strong, readonly) JLPageViewController *pageViewController;
@property (nonatomic, strong) UIView *headerView;

@property (nonatomic, assign) JLFullScreenStyle fullScreenStyle;
@property (nonatomic, assign, getter = isNavigationBarHidden) BOOL navigationBarHidden;

@end

@interface UIViewController (JLFullScreenPageViewController)

@property (nonatomic, weak, readonly) JLFullScreenPageViewController *fullScreenPageViewController;

@end