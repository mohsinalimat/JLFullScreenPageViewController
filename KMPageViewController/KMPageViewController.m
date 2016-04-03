//
//  KMPagerController.m
//  KMPageController
//
//  Created by Jangsy7883 on 2015. 9. 4..
//  Copyright © 2015년 Dalkomm. All rights reserved.
//

#import "KMPageViewController.h"
#import "UIViewController+KMAdditions.h"

CG_INLINE CGRect
CGRectReplaceY(CGRect rect, CGFloat y)
{
    rect.origin.y = y;
    return rect;
}

#define kDefaultNavigationBarHeight 44

@interface UIView (KMAdditions)

@property (nonatomic, readonly) UIViewController *superViewController;

@end

@implementation UIView (KMAdditions)

- (UIViewController*)superViewController
{
    for (UIView* next = self; next; next = next.superview)
    {
        UIResponder* nextResponder = [next nextResponder];
        
        if ([nextResponder isKindOfClass:[UIViewController class]])
        {
            return (UIViewController*)nextResponder;
        }
    }
    return nil;
}

@end

@implementation UIViewController (KMPageViewController)

- (KMPageViewController*)pageViewController
{
    for (UIView* next = self.view; next; next = next.superview)
    {
        UIResponder* nextResponder = [next nextResponder];
        
        if ([nextResponder isKindOfClass:[KMPageViewController class]])
        {
            return (KMPageViewController*)nextResponder;
        }
    }
    return nil;
}

@end

static void * const KMPageViewControllerKVOContext = (void*)&KMPageViewControllerKVOContext;

@interface KMPageViewController ()

@property (nonatomic, strong) UIView *contentHeaderView;
@property (nonatomic, strong) KMPageView *pageView;
@property (nonatomic, strong) NSTimer *didScrollTimer;
@end

@implementation KMPageViewController

#pragma mark - memory

- (void)dealloc
{

    for (UIViewController *viewController in self.childViewControllers)
    {
        [self removeContentViewController:viewController];
    }

    //Observer
    @try {
        [self.contentHeaderView removeObserver:self
                                    forKeyPath:@"frame"
                                       context:KMPageViewControllerKVOContext];
    }
    @catch (NSException *exception) {}
}

#pragma mark - view lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.pageView = [[KMPageView alloc] init];
    self.pageView.frame = self.view.frame;
    [self.view addSubview:self.pageView];
    
    self.contentHeaderView = [[UIView alloc] init];
    [self.view addSubview:self.contentHeaderView];
    
    [self.contentHeaderView addObserver:self
                             forKeyPath:@"frame"
                                options:NSKeyValueObservingOptionNew
                                context:KMPageViewControllerKVOContext];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.pageView.frame = self.view.bounds;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    self.pageView.frame = self.view.bounds;
    
    [self layoutContentHeaderView];
    [self layoutNavigationBarItemsAlphaValue];
}

#pragma  mark -

- (void)layoutContentHeaderView
{
    CGRect bounds = self.view.bounds;
    
    CGRect rect = CGRectMake(0,
                             0,
                             CGRectGetWidth(bounds),
                             self.topLayoutGuide.length);
    
    rect.size.height += (self.navigationBar ? CGRectGetHeight(self.navigationController.navigationBar.frame) : 0);
    
    self.navigationBar.frame = rect;
    
    self.headerView.frame = CGRectMake(0,
                                       CGRectGetMaxY(rect),
                                       CGRectGetWidth(bounds),
                                       CGRectGetHeight(self.headerView.frame));
    
    self.contentHeaderView.frame = CGRectMake(0,
                                              CGRectGetMinY(self.contentHeaderView.frame),
                                              CGRectGetWidth(bounds),
                                              CGRectGetHeight(rect) + CGRectGetHeight(self.headerView.frame));}

- (void)layoutContentInsetForScrollView:(UIScrollView*)scrollView atContentOffsetY:(CGFloat)offsetY
{
    if ([scrollView isKindOfClass:[UIScrollView class]])
    {
        UIEdgeInsets inset = scrollView.contentInset;
        inset.top = offsetY;
        
        if (!UIEdgeInsetsEqualToEdgeInsets(scrollView.contentInset, inset))
        {
            scrollView.contentInset = inset;
            scrollView.scrollIndicatorInsets = inset;
        }
    }
}

- (void)layoutContentInsetAllChildScrollViews
{
    CGFloat pageY = CGRectGetMaxY(self.contentHeaderView.frame);
    
    for (UIViewController *viewController in self.childViewControllers)
    {
        [self layoutContentInsetForScrollView:viewController.contentScrollView
                             atContentOffsetY:pageY];
    }
}

- (void)layoutNavigationBarItemsAlphaValue
{
    CGFloat minimumLocation = self.topLayoutGuide.length - CGRectGetHeight(self.navigationBar.frame);
    CGFloat alpha = -(CGRectGetMinY(self.contentHeaderView.frame) - minimumLocation) / minimumLocation;
    
    for (UIView *view in self.navigationBar.subviews)
    {
        bool isBackgroundView = (view == self.navigationBar.subviews.firstObject);
        bool isViewHidden = view.hidden || view.alpha < FLT_EPSILON;
        
        if (!isBackgroundView && !isViewHidden)
        {
            view.alpha = MAX(alpha, FLT_EPSILON);
        }
    }
}

#pragma mark - timer

- (void)onDidScrollTimer:(NSTimer*)timer
{
    [self.didScrollTimer invalidate];
    self.didScrollTimer = nil;
    
    [self navigationBarIsVisible:CGRectGetMinY(self.contentHeaderView.frame) > -22
                        animated:YES];
}

- (void)didScrollTimerIsActive:(BOOL)isActive
{
    if (self.didScrollTimer)
    {
        [self.didScrollTimer invalidate];
        self.didScrollTimer = nil;
    }
    
    if (isActive)
    {
        self.didScrollTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                               target:self
                                                             selector:@selector(onDidScrollTimer:)
                                                             userInfo:nil
                                                              repeats:NO];
    }
}

#pragma  mark - content view controller

- (void)addContentViewController:(UIViewController *)viewController
{
    [self.pageView addSubview:viewController.view];
    [self addChildViewController:viewController];
    [viewController didMoveToParentViewController:self];

    //
    UIScrollView *scrollView = viewController.contentScrollView;
    
    if ([scrollView isKindOfClass:[UIScrollView class]])
    {
        //Observer
        @try {
            [scrollView addObserver:self
                         forKeyPath:@"contentOffset"
                            options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                            context:KMPageViewControllerKVOContext];
        }
        @catch (NSException *exception) {}
        @try {
            [scrollView addObserver:self
                         forKeyPath:@"contentInset"
                            options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                            context:KMPageViewControllerKVOContext];
        }
        @catch (NSException *exception) {}
        
        //
        [self layoutContentInsetForScrollView:scrollView
                             atContentOffsetY:CGRectGetMaxY(self.contentHeaderView.frame)];
        [scrollView setContentOffset:CGPointMake(0, -scrollView.contentInset.top) animated:NO];
    }
}

- (void)removeContentViewController:(UIViewController *)viewController
{
    UIScrollView *scrollView = viewController.contentScrollView;
    
    if ([scrollView isKindOfClass:[UIScrollView class]])
    {
        //Observer
        @try {
            [scrollView removeObserver:self
                            forKeyPath:@"contentOffset"
                               context:KMPageViewControllerKVOContext];
        }
        @catch (NSException *exception) {}
        @try {
            [scrollView removeObserver:self
                            forKeyPath:@"contentInset"
                               context:KMPageViewControllerKVOContext];
        }
        @catch (NSException *exception) {}
    }
    
    NSLog(@"BB %@",viewController);
        [viewController.view removeFromSuperview];
        [viewController willMoveToParentViewController:nil];
        [viewController removeFromParentViewController];

}

#pragma  mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KMPageViewControllerKVOContext)
    {
        if ([keyPath isEqualToString:@"contentOffset"] && [object isKindOfClass:[UIScrollView class]])
        {
            UIScrollView *scrollView = object;
            CGPoint new = [change[NSKeyValueChangeNewKey] CGPointValue];
            CGPoint old = [change[NSKeyValueChangeOldKey] CGPointValue];

            if (scrollView.superViewController.view.frame.origin.x == self.pageView.contentOffset.x
                && new.y != old.y
                && scrollView.contentOffset.y+scrollView.frame.size.height < scrollView.contentSize.height)
            {
                CGRect rect = self.contentHeaderView.frame;
                
                if (scrollView.contentOffset.y > -CGRectGetHeight(self.contentHeaderView.frame))
                {
                    CGFloat minY = CGRectGetHeight(self.navigationBar.frame)-(self.navigationBar? self.topLayoutGuide.length : 0);
                    CGFloat y = CGRectGetMinY(self.contentHeaderView.frame) - (new.y - old.y);
                    
                    rect = CGRectReplaceY(self.contentHeaderView.frame, ceil(MAX(-minY, MIN(0,y))));
                }
                else
                {
                    rect = CGRectReplaceY(self.contentHeaderView.frame, 0);
                }                
                
                if (CGRectEqualToRect(rect, self.contentHeaderView.frame) == NO)
                {
                    self.contentHeaderView.frame = rect;
                }
                
                [self didScrollTimerIsActive:YES];
            }
        }
        else if ([keyPath isEqualToString:@"contentInset"] && [object isKindOfClass:[UIScrollView class]])
        {
            UIScrollView *scrollView = object;
            
            UIEdgeInsets new = [change[NSKeyValueChangeNewKey] UIEdgeInsetsValue];
            UIEdgeInsets old = [change[NSKeyValueChangeOldKey] UIEdgeInsetsValue];
            
            if (-old.top == scrollView.contentOffset.y)
            {
                [scrollView setContentOffset:CGPointMake(0, -new.top) animated:NO];
            }
        }
        else if([keyPath isEqualToString:@"frame"] && [object isKindOfClass:[self.contentHeaderView class]])
        {
            [self layoutContentInsetAllChildScrollViews];
            [self layoutNavigationBarItemsAlphaValue];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - navigation bar

- (void)navigationBarIsVisible:(BOOL)isVisible animated:(BOOL)animated
{
    CGRect rect = CGRectZero;
    
    if (isVisible)
    {
        rect = CGRectMake(0,
                          0,
                          CGRectGetWidth(self.view.bounds),
                          CGRectGetHeight(self.contentHeaderView.frame));
    }
    else
    {
        rect = CGRectMake(0,
                          -(self.navigationBar.frame.size.height - self.topLayoutGuide.length),
                          CGRectGetWidth(self.view.bounds),
                          CGRectGetHeight(self.contentHeaderView.frame));
    }
    
    if (CGRectEqualToRect(self.contentHeaderView.frame, rect) == NO)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.15
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                                 self.contentHeaderView.frame = rect;
                             }
                             completion:^(BOOL finished) {
                             }];
        }
        else
        {
            self.contentHeaderView.frame = rect;
        }
    }
}

#pragma mark - SETTERS

- (void)setHeaderView:(UIView *)headerView
{
    if (_headerView != headerView)
    {
        [_headerView removeFromSuperview];
        
        _headerView = nil;
        _headerView = headerView;
        
        [self.contentHeaderView addSubview:_headerView];
        
        [self layoutContentHeaderView];
    }
}

- (void)setNavigationBar:(UINavigationBar *)navigationBar
{
    if (_navigationBar != navigationBar)
    {
        [_navigationBar removeFromSuperview];
        
        _navigationBar = nil;
        _navigationBar = navigationBar;
        
        [self.contentHeaderView addSubview:_navigationBar];
        
        [self layoutContentHeaderView];
    }
}

@end
