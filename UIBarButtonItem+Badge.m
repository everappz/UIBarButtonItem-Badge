//
//  UIBarButtonItem+Badge.m
//  therichest
//
//  Created by Mike on 2014-05-05.
//  Copyright (c) 2014 Valnet Inc. All rights reserved.
//
#import <objc/runtime.h>
#import "UIBarButtonItem+Badge.h"

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

@implementation UIBarButtonItem (LS_Badge)

@dynamic ls_badgeValue, ls_badgeBGColor, ls_badgeTextColor, ls_badgeFont;
@dynamic ls_badgePadding, ls_badgeMinSize, ls_badgeOriginX, ls_badgeOriginY;
@dynamic ls_shouldHideBadgeAtZero, ls_shouldAnimateBadge;

#pragma mark - Setup

- (void)ls_badgeInit
{
    UIView *superview = nil;
    CGFloat defaultOriginX = 0.0;

    if (self.customView) {
        superview = self.customView;
        defaultOriginX = superview.frame.size.width - self.ls_badge.frame.size.width / 2.0;
        // Avoid clipping during animations
        superview.clipsToBounds = NO;
    } else if ([self respondsToSelector:@selector(view)] && [(id)self view]) {
        superview = [(id)self view];
        defaultOriginX = superview.frame.size.width - self.ls_badge.frame.size.width;
    }

    [superview addSubview:self.ls_badge];

    // Default appearance
    self.ls_badgeBGColor   = [UIColor redColor];
    self.ls_badgeTextColor = [UIColor whiteColor];
    self.ls_badgeFont      = [UIFont systemFontOfSize:12.0];
    self.ls_badgePadding   = 6.0;
    self.ls_badgeMinSize   = 8.0;
    self.ls_badgeOriginX   = defaultOriginX;
    self.ls_badgeOriginY   = -4.0;
    self.ls_shouldHideBadgeAtZero = YES;
    self.ls_shouldAnimateBadge    = YES;
}

#pragma mark - Utility

- (void)ls_refreshBadge
{
    // Apply attributes
    self.ls_badge.textColor       = self.ls_badgeTextColor;
    self.ls_badge.backgroundColor = self.ls_badgeBGColor;
    self.ls_badge.font            = self.ls_badgeFont;

    BOOL shouldHide = (!self.ls_badgeValue ||
                       [self.ls_badgeValue isEqualToString:@""] ||
                       ([self.ls_badgeValue isEqualToString:@"0"] && self.ls_shouldHideBadgeAtZero));

    self.ls_badge.hidden = shouldHide;
    if (!shouldHide) {
        [self ls_updateBadgeValueAnimated:YES];
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
    CGSize expected = [self ls_badgeExpectedSize];

    CGFloat minHeight = MAX(expected.height, self.ls_badgeMinSize);
    CGFloat minWidth  = MAX(expected.width,  minHeight);
    CGFloat padding   = self.ls_badgePadding;

    self.ls_badge.layer.masksToBounds = YES;
    self.ls_badge.frame = CGRectMake(self.ls_badgeOriginX,
                                     self.ls_badgeOriginY,
                                     minWidth + padding,
                                     minHeight + padding);
    self.ls_badge.layer.cornerRadius = (minHeight + padding) / 2.0;
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

- (void)ls_removeBadge
{
    [UIView animateWithDuration:0.2 animations:^{
        self.ls_badge.transform = CGAffineTransformMakeScale(0, 0);
    } completion:^(BOOL finished) {
        [self.ls_badge removeFromSuperview];
        self.ls_badge = nil;
    }];
}

#pragma mark - Getters / Setters (Associated Objects)

- (UILabel *)ls_badge
{
    UILabel *lbl = objc_getAssociatedObject(self, &UIBarButtonItem_ls_badgeKey);
    if (lbl == nil) {
        lbl = [[UILabel alloc] initWithFrame:CGRectMake(self.ls_badgeOriginX, self.ls_badgeOriginY, 20, 20)];
        lbl.textAlignment = NSTextAlignmentCenter;
        [self setLs_badge:lbl];
        [self ls_badgeInit];
        if (self.customView) {
            [self.customView addSubview:lbl];
        } else if ([self respondsToSelector:@selector(view)] && [(id)self view]) {
            [[(id)self view] addSubview:lbl];
        }
    }
    return lbl;
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
    [self ls_updateBadgeValueAnimated:YES];
    [self ls_refreshBadge];
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
