//
//  UIBarButtonItem+Badge.m
//  therichest
//
//  Created by Mike on 2014-05-05.
//  Copyright (c) 2014 Valnet Inc. All rights reserved.
//
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "UIBarButtonItem+Badge.h"

#pragma mark - Associated Keys

static NSString const *UIBarButtonItem_ls_badgeKey                   = @"UIBarButtonItem_ls_badgeKey";
static NSString const *UIBarButtonItem_ls_badgeBGColorKey            = @"UIBarButtonItem_ls_badgeBGColorKey";
static NSString const *UIBarButtonItem_ls_badgeTextColorKey          = @"UIBarButtonItem_ls_badgeTextColorKey";
static NSString const *UIBarButtonItem_ls_badgeFontKey               = @"UIBarButtonItem_ls_badgeFontKey";
static NSString const *UIBarButtonItem_ls_badgePaddingKey            = @"UIBarButtonItem_ls_badgePaddingKey";
static NSString const *UIBarButtonItem_ls_badgeMinSizeKey            = @"UIBarButtonItem_ls_badgeMinSizeKey";
static NSString const *UIBarButtonItem_ls_badgeOriginXKey            = @"UIBarButtonItem_ls_badgeOriginXKey";
static NSString const *UIBarButtonItem_ls_badgeOriginYKey            = @"UIBarButtonItem_ls_badgeOriginYKey";
static NSString const *UIBarButtonItem_ls_shouldHideBadgeAtZeroKey   = @"UIBarButtonItem_ls_shouldHideBadgeAtZeroKey";
static NSString const *UIBarButtonItem_ls_shouldAnimateBadgeKey      = @"UIBarButtonItem_ls_shouldAnimateBadgeKey";
static NSString const *UIBarButtonItem_ls_badgeValueKey              = @"UIBarButtonItem_ls_badgeValueKey";
static NSString const *UIBarButtonItem_ls_hostingNavBarKey           = @"UIBarButtonItem_ls_hostingNavBarKey";

#pragma mark - Helpers

static inline BOOL LS_NavItemContainsBarButtonItem(UINavigationItem *navItem, UIBarButtonItem *item) {
    if (!navItem || !item) return NO;
    if (navItem.backBarButtonItem == item) return YES;
    if (navItem.leftBarButtonItem == item) return YES;
    if (navItem.rightBarButtonItem == item) return YES;
    if ([navItem.leftBarButtonItems containsObject:item]) return YES;
    if ([navItem.rightBarButtonItems containsObject:item]) return YES;
    return NO;
}

static UINavigationBar *LS_FindHostingNavigationBarForItem(UIBarButtonItem *item) {
    // 1) If the item already has a view in the hierarchy, climb up to a bar.
    UIView *candidateView = nil;
    if (item.customView) {
        candidateView = item.customView;
    } else if ([item respondsToSelector:@selector(view)]) {
        candidateView = [item valueForKey:@"view"];
    }
    for (UIView *s = candidateView; s; s = s.superview) {
        if ([s isKindOfClass:UINavigationBar.class]) {
            return (UINavigationBar *)s;
        }
    }
    
    // 2) Scan visible windows for nav bars that own this item.
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isHidden || w.alpha < 0.01) continue;
                NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:w];
                while (queue.count) {
                    UIView *u = queue.firstObject; [queue removeObjectAtIndex:0];
                    if ([u isKindOfClass:UINavigationBar.class]) {
                        UINavigationBar *bar = (UINavigationBar *)u;
                        for (UINavigationItem *ni in (bar.items ?: @[])) {
                            if (LS_NavItemContainsBarButtonItem(ni, item)) return bar;
                        }
                    }
                    [queue addObjectsFromArray:u.subviews];
                }
            }
        }
    } else {
        UIWindow *w = UIApplication.sharedApplication.keyWindow;
        if (w) {
            NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:w];
            while (queue.count) {
                UIView *u = queue.firstObject; [queue removeObjectAtIndex:0];
                if ([u isKindOfClass:UINavigationBar.class]) {
                    UINavigationBar *bar = (UINavigationBar *)u;
                    for (UINavigationItem *ni in (bar.items ?: @[])) {
                        if (LS_NavItemContainsBarButtonItem(ni, item)) return bar;
                    }
                }
                [queue addObjectsFromArray:u.subviews];
            }
        }
    }
    return nil;
}

static UIView *LS_BarButtonSourceView(UIBarButtonItem *item) {
    if (item.customView) return item.customView;
    if ([item respondsToSelector:@selector(view)]) {
        return [item valueForKey:@"view"];
    }
    return nil;
}

static inline UINavigationBar *LS_GetHostingNavBar(UIBarButtonItem *item) {
    return objc_getAssociatedObject(item, &UIBarButtonItem_ls_hostingNavBarKey);
}

static inline void LS_SetHostingNavBar(UIBarButtonItem *item, UINavigationBar *bar) {
    objc_setAssociatedObject(item, &UIBarButtonItem_ls_hostingNavBarKey, bar, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - Implementation

@implementation UIBarButtonItem (LS_Badge)

@dynamic ls_badgeValue, ls_badgeBGColor, ls_badgeTextColor, ls_badgeFont;
@dynamic ls_badgePadding, ls_badgeMinSize, ls_badgeOriginX, ls_badgeOriginY;
@dynamic ls_shouldHideBadgeAtZero, ls_shouldAnimateBadge;

#pragma mark - Setup

- (void)ls_badgeInit
{
    UILabel *badgeLabel = self.ls_badge;
    
    // Default appearance
    self.ls_badgeBGColor   = [UIColor redColor];
    self.ls_badgeTextColor = [UIColor whiteColor];
    self.ls_badgeFont      = [UIFont systemFontOfSize:12.0];
    self.ls_badgePadding   = 6.0;
    self.ls_badgeMinSize   = 8.0;
    
    // Offsets relative to the item view’s top-right corner
    self.ls_badgeOriginX   = 0.0;
    self.ls_badgeOriginY   = -4.0;
    
    self.ls_shouldHideBadgeAtZero = YES;
    self.ls_shouldAnimateBadge    = YES;
    
    // Attach badge to the hosting UINavigationBar if available; otherwise temporary fallback
    UINavigationBar *bar = LS_FindHostingNavigationBarForItem(self);
    if (bar) {
        LS_SetHostingNavBar(self, bar);
        if (badgeLabel.superview != bar) {
            [badgeLabel removeFromSuperview];
            [bar addSubview:badgeLabel];
        }
        [bar bringSubviewToFront:badgeLabel];
    } else {
        // Fallback until the bar is available (e.g., before the item is displayed)
        UIView *superview = LS_BarButtonSourceView(self);
        if (superview) {
            superview.clipsToBounds = NO;
            if (badgeLabel.superview != superview) {
                [badgeLabel removeFromSuperview];
                [superview addSubview:badgeLabel];
            }
        }
    }
    
    // Avoid wrong-side flash; wait for proper anchor, then place
    self.ls_badge.alpha = 0.0;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self ls_updateBadgeFrame];
    });
    
    [self ls_refreshBadge];
}

#pragma mark - Utility

- (BOOL)ls_shouldHideBadge {
    BOOL shouldHide = (!self.ls_badgeValue ||
                       [self.ls_badgeValue isEqualToString:@""] ||
                       ([self.ls_badgeValue isEqualToString:@"0"] && self.ls_shouldHideBadgeAtZero));
    return shouldHide;
}

- (void)ls_refreshBadge
{
    // Apply attributes
    self.ls_badge.textColor       = self.ls_badgeTextColor;
    self.ls_badge.backgroundColor = self.ls_badgeBGColor;
    self.ls_badge.font            = self.ls_badgeFont;
    
    const BOOL shouldHide = self.ls_shouldHideBadge;
    
    self.ls_badge.hidden = shouldHide;
    if (!shouldHide) {
        [self ls_updateBadgeValueAnimated:YES];
    }
    else {
        [self ls_removeBadgeAnimated:YES];
    }
}

- (CGSize)ls_badgeExpectedSize
{
    UILabel *frameLabel = [self ls_duplicateLabel:self.ls_badge];
    [frameLabel sizeToFit];
    return frameLabel.frame.size;
}

- (void)ls_updateBadgeFrame
{
    UILabel *badge = self.ls_badge;
    if (!badge) return;
    
    // Size
    CGSize expected = [self ls_badgeExpectedSize];
    CGFloat minH = MAX(expected.height, self.ls_badgeMinSize);
    CGFloat minW = MAX(expected.width,  minH);
    CGFloat pad  = self.ls_badgePadding;
    
    CGSize badgeSize = CGSizeMake(minW + pad, minH + pad);
    badge.layer.masksToBounds = YES;
    badge.layer.cornerRadius  = (minH + pad) * 0.5;
    if (@available(iOS 13.0, *)) {
        badge.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    // Ensure badge is attached to a UINavigationBar
    UINavigationBar *bar = LS_GetHostingNavBar(self);
    if (!bar) {
        bar = LS_FindHostingNavigationBarForItem(self);
        if (bar) {
            LS_SetHostingNavBar(self, bar);
            [badge removeFromSuperview];
            [bar addSubview:badge];
        }
    }
    
    UIView *sourceView = LS_BarButtonSourceView(self);
    
    // Don't place until the bar button's view exists (prevents wrong initial side) ---
    if (bar && (!sourceView || !sourceView.window)) {
        [bar setNeedsLayout];
        [bar layoutIfNeeded];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self ls_updateBadgeFrame];
        });
        return; // keep alpha 0 until we have a correct anchor
    }
    
    if (bar && sourceView && sourceView.window) {
        // Convert the item view’s frame into the nav bar’s coordinate space
        CGRect srcInBar = [sourceView.superview convertRect:sourceView.frame toView:bar];
        
        // Anchor near the top-right corner of the bar button item’s view.
        // Tweak the 0.35 factor to visually align with the icon shape if needed.
        CGFloat x = CGRectGetMaxX(srcInBar) - badgeSize.width * 0.35 + self.ls_badgeOriginX;
        CGFloat y = CGRectGetMinY(srcInBar) - badgeSize.height * 0.35 + self.ls_badgeOriginY;
        
        badge.frame = (CGRect){ .origin = CGPointMake(x, y), .size = badgeSize };
        [bar bringSubviewToFront:badge];
        
        // Now that it's correctly anchored, reveal without jump
        badge.alpha = 1.0;
        return;
    }
    
    // Fallback: position relative to current superview (pre-attachment)
    UIView *fallback = badge.superview ?: sourceView;
    if (fallback) {
        CGFloat defaultX = fallback.bounds.size.width - badgeSize.width * 0.5;
        badge.frame = CGRectMake(defaultX + self.ls_badgeOriginX,
                                 self.ls_badgeOriginY,
                                 badgeSize.width,
                                 badgeSize.height);
        // Keep hidden in fallback to avoid visible jump
        badge.alpha = 0.0; // <-- FIX: don't show until anchored to real bar/item view
    } else {
        badge.frame = (CGRect){ .origin = CGPointMake(self.ls_badgeOriginX, self.ls_badgeOriginY),
            .size = badgeSize };
        badge.alpha = 0.0; // still waiting for a host
    }
}

- (void)ls_updateBadgeValueAnimated:(BOOL)animated
{
    BOOL valueChanged = ![self.ls_badge.text isEqualToString:self.ls_badgeValue];
    
    if (animated && self.ls_shouldAnimateBadge && valueChanged) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        animation.fromValue = @(1.5);
        animation.toValue   = @(1.0);
        animation.duration  = 0.2;
        animation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:.4f :1.3f :1.f :1.f];
        [self.ls_badge.layer addAnimation:animation forKey:@"ls_badgeBounceAnimation"];
    }
    
    // Update text
    self.ls_badge.text = self.ls_badgeValue;
    
    if (animated && self.ls_shouldAnimateBadge) {
        [UIView animateWithDuration:0.2 animations:^{
            [self ls_updateBadgeFrame];
        }];
    } else {
        [self ls_updateBadgeFrame];
    }
}

- (UILabel *)ls_duplicateLabel:(UILabel *)labelToCopy
{
    UILabel *dup = [[UILabel alloc] initWithFrame:labelToCopy.frame];
    dup.textAlignment = labelToCopy.textAlignment;
    dup.text = labelToCopy.text;
    dup.font = labelToCopy.font;
    return dup;
}

- (void)ls_removeBadgeAnimated:(BOOL)animated
{
    dispatch_block_t completion = ^{
        [self.ls_badge removeFromSuperview];
        self.ls_badge = nil;
        LS_SetHostingNavBar(self, nil);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            self.ls_badge.transform = CGAffineTransformMakeScale(0, 0);
        } completion:^(BOOL finished) {
            completion();
        }];
    }
    else {
        completion();
    }
}

#pragma mark - Getters / Setters (Associated Objects)

- (UILabel *)ls_badge
{
    return objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeKey);
}

- (void)setLs_badge:(UILabel *)badgeLabel
{
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeKey, badgeLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)ls_badgeValue
{
    return objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeValueKey);
}

- (void)setLs_badgeValue:(NSString *)badgeValue
{
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeValueKey, badgeValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (self.ls_shouldHideBadge) {
        [self ls_removeBadgeAnimated:NO];
    }
    else {
        //lazy load badge label
        UILabel *lbl = [self ls_badge];
        if (lbl == nil) {
            lbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 20.0, 20.0)];
            [self setLs_badge:lbl];
            lbl.userInteractionEnabled = NO;
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.backgroundColor = self.ls_badgeBGColor;
            lbl.textColor = self.ls_badgeTextColor;
            lbl.font = self.ls_badgeFont;
            
            // Do NOT attach here; ls_badgeInit decides proper superview (nav bar vs fallback)
            [self ls_badgeInit];
        }
        
        [self ls_updateBadgeValueAnimated:YES];
        [self ls_refreshBadge];
    }
}

- (UIColor *)ls_badgeBGColor
{
    return objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeBGColorKey);
}

- (void)setLs_badgeBGColor:(UIColor *)badgeBGColor
{
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeBGColorKey, badgeBGColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

- (UIColor *)ls_badgeTextColor
{
    return objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeTextColorKey);
}

- (void)setLs_badgeTextColor:(UIColor *)badgeTextColor
{
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeTextColorKey, badgeTextColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

- (UIFont *)ls_badgeFont
{
    return objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeFontKey);
}

- (void)setLs_badgeFont:(UIFont *)badgeFont
{
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeFontKey, badgeFont, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

- (CGFloat)ls_badgePadding
{
    NSNumber *n = objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgePaddingKey);
    return n.floatValue;
}

- (void)setLs_badgePadding:(CGFloat)badgePadding
{
    NSNumber *n = @(badgePadding);
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgePaddingKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (CGFloat)ls_badgeMinSize
{
    NSNumber *n = objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeMinSizeKey);
    return n.floatValue;
}

- (void)setLs_badgeMinSize:(CGFloat)badgeMinSize
{
    NSNumber *n = @(badgeMinSize);
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeMinSizeKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (CGFloat)ls_badgeOriginX
{
    NSNumber *n = objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeOriginXKey);
    return n.floatValue;
}

- (void)setLs_badgeOriginX:(CGFloat)badgeOriginX
{
    NSNumber *n = @(badgeOriginX);
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeOriginXKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (CGFloat)ls_badgeOriginY
{
    NSNumber *n = objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeOriginYKey);
    return n.floatValue;
}

- (void)setLs_badgeOriginY:(CGFloat)badgeOriginY
{
    NSNumber *n = @(badgeOriginY);
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_badgeOriginYKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (BOOL)ls_shouldHideBadgeAtZero
{
    NSNumber *n = objc_getAssociatedObject(self, &UIBarButtonItem_ls_shouldHideBadgeAtZeroKey);
    return n.boolValue;
}

- (void)setLs_shouldHideBadgeAtZero:(BOOL)shouldHideBadgeAtZero
{
    NSNumber *n = @(shouldHideBadgeAtZero);
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_shouldHideBadgeAtZeroKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

- (BOOL)ls_shouldAnimateBadge
{
    NSNumber *n = objc_getAssociatedObject(self, &UIBarButtonItem_ls_shouldAnimateBadgeKey);
    return n.boolValue;
}

- (void)setLs_shouldAnimateBadge:(BOOL)shouldAnimateBadge
{
    NSNumber *n = @(shouldAnimateBadge);
    objc_setAssociatedObject(self, &UIBarButtonItem_ls_shouldAnimateBadgeKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

@end
