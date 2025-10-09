//
//  UIBarButtonItem+Badge.m
//  therichest
//
//  Created by Mike on 2014-05-05.
//  Copyright (c) 2014 Valnet Inc. All rights reserved.
//
#import <objc/runtime.h>
#import "UIButton+Badge.h"

static NSString const *UIButton_ls_badgeKey                 = @"UIButton_ls_badgeKey";
static NSString const *UIButton_ls_badgeBGColorKey          = @"UIButton_ls_badgeBGColorKey";
static NSString const *UIButton_ls_badgeTextColorKey        = @"UIButton_ls_badgeTextColorKey";
static NSString const *UIButton_ls_badgeFontKey             = @"UIButton_ls_badgeFontKey";
static NSString const *UIButton_ls_badgePaddingKey          = @"UIButton_ls_badgePaddingKey";
static NSString const *UIButton_ls_badgeMinSizeKey          = @"UIButton_ls_badgeMinSizeKey";
static NSString const *UIButton_ls_badgeOriginXKey          = @"UIButton_ls_badgeOriginXKey";
static NSString const *UIButton_ls_badgeOriginYKey          = @"UIButton_ls_badgeOriginYKey";
static NSString const *UIButton_ls_shouldHideBadgeAtZeroKey = @"UIButton_ls_shouldHideBadgeAtZeroKey";
static NSString const *UIButton_ls_shouldAnimateBadgeKey    = @"UIButton_ls_shouldAnimateBadgeKey";
static NSString const *UIButton_ls_badgeValueKey            = @"UIButton_ls_badgeValueKey";

@implementation UIButton (LS_Badge)

@dynamic ls_badgeValue, ls_badgeBGColor, ls_badgeTextColor, ls_badgeFont;
@dynamic ls_badgePadding, ls_badgeMinSize, ls_badgeOriginX, ls_badgeOriginY;
@dynamic ls_shouldHideBadgeAtZero, ls_shouldAnimateBadge;

#pragma mark - Setup

- (void)ls_badgeInit
{
    self.ls_badgeBGColor   = [UIColor redColor];
    self.ls_badgeTextColor = [UIColor whiteColor];
    self.ls_badgeFont      = [UIFont systemFontOfSize:12.0];
    self.ls_badgePadding   = 6.0;
    self.ls_badgeMinSize   = 8.0;
    self.ls_badgeOriginX   = self.frame.size.width - self.ls_badge.frame.size.width / 2.0;
    self.ls_badgeOriginY   = -4.0;
    self.ls_shouldHideBadgeAtZero = YES;
    self.ls_shouldAnimateBadge    = YES;
    self.clipsToBounds = NO; // avoid clipping during scale animation
}

#pragma mark - Utilities

- (void)ls_refreshBadge
{
    self.ls_badge.textColor       = self.ls_badgeTextColor;
    self.ls_badge.backgroundColor = self.ls_badgeBGColor;
    self.ls_badge.font            = self.ls_badgeFont;
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

    self.ls_badge.frame = CGRectMake(self.ls_badgeOriginX, self.ls_badgeOriginY, minWidth + padding, minHeight + padding);
    self.ls_badge.layer.cornerRadius = (minHeight + padding) / 2.0;
    self.ls_badge.layer.masksToBounds = YES;
}

- (void)ls_updateBadgeValueAnimated:(BOOL)animated
{
    if (animated && self.ls_shouldAnimateBadge && ![self.ls_badge.text isEqualToString:self.ls_badgeValue]) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        animation.fromValue = @(1.5);
        animation.toValue   = @(1.0);
        animation.duration  = 0.2;
        animation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:.4f :1.3f :1.f :1.f];
        [self.ls_badge.layer addAnimation:animation forKey:@"ls_badgeBounceAnimation"];
    }

    self.ls_badge.text = self.ls_badgeValue;

    NSTimeInterval duration = (animated && self.ls_shouldAnimateBadge) ? 0.2 : 0.0;
    [UIView animateWithDuration:duration animations:^{
        [self ls_updateBadgeFrame];
    }];
}

- (UILabel *)ls_duplicateLabel:(UILabel *)labelToCopy
{
    UILabel *duplicateLabel = [[UILabel alloc] initWithFrame:labelToCopy.frame];
    duplicateLabel.textAlignment = labelToCopy.textAlignment;
    duplicateLabel.text = labelToCopy.text;
    duplicateLabel.font = labelToCopy.font;
    return duplicateLabel;
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

#pragma mark - Associated Object Backing

- (UILabel *)ls_badge
{
    return objc_getAssociatedObject(self, &UIButton_ls_badgeKey);
}
- (void)setLs_badge:(UILabel *)badgeLabel
{
    objc_setAssociatedObject(self, &UIButton_ls_badgeKey, badgeLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Value
- (NSString *)ls_badgeValue
{
    return objc_getAssociatedObject(self, &UIButton_ls_badgeValueKey);
}
- (void)setLs_badgeValue:(NSString *)badgeValue
{
    objc_setAssociatedObject(self, &UIButton_ls_badgeValueKey, badgeValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (!badgeValue || [badgeValue isEqualToString:@""] ||
        ([badgeValue isEqualToString:@"0"] && self.ls_shouldHideBadgeAtZero)) {
        [self ls_removeBadge];
    } else if (!self.ls_badge) {
        self.ls_badge = [[UILabel alloc] initWithFrame:CGRectMake(self.ls_badgeOriginX, self.ls_badgeOriginY, 20, 20)];
        self.ls_badge.textColor       = self.ls_badgeTextColor;
        self.ls_badge.backgroundColor = self.ls_badgeBGColor;
        self.ls_badge.font            = self.ls_badgeFont;
        self.ls_badge.textAlignment   = NSTextAlignmentCenter;
        [self ls_badgeInit];
        [self addSubview:self.ls_badge];
        [self ls_updateBadgeValueAnimated:NO];
    } else {
        [self ls_updateBadgeValueAnimated:YES];
    }
}

// Colors & font
- (UIColor *)ls_badgeBGColor
{
    return objc_getAssociatedObject(self, &UIButton_ls_badgeBGColorKey);
}
- (void)setLs_badgeBGColor:(UIColor *)badgeBGColor
{
    objc_setAssociatedObject(self, &UIButton_ls_badgeBGColorKey, badgeBGColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

- (UIColor *)ls_badgeTextColor
{
    return objc_getAssociatedObject(self, &UIButton_ls_badgeTextColorKey);
}
- (void)setLs_badgeTextColor:(UIColor *)badgeTextColor
{
    objc_setAssociatedObject(self, &UIButton_ls_badgeTextColorKey, badgeTextColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

- (UIFont *)ls_badgeFont
{
    return objc_getAssociatedObject(self, &UIButton_ls_badgeFontKey);
}
- (void)setLs_badgeFont:(UIFont *)badgeFont
{
    objc_setAssociatedObject(self, &UIButton_ls_badgeFontKey, badgeFont, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_refreshBadge]; }
}

// Layout metrics
- (CGFloat)ls_badgePadding
{
    NSNumber *n = objc_getAssociatedObject(self, &UIButton_ls_badgePaddingKey);
    return n.floatValue;
}
- (void)setLs_badgePadding:(CGFloat)badgePadding
{
    NSNumber *n = @(badgePadding);
    objc_setAssociatedObject(self, &UIButton_ls_badgePaddingKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (CGFloat)ls_badgeMinSize
{
    NSNumber *n = objc_getAssociatedObject(self, &UIButton_ls_badgeMinSizeKey);
    return n.floatValue;
}
- (void)setLs_badgeMinSize:(CGFloat)badgeMinSize
{
    NSNumber *n = @(badgeMinSize);
    objc_setAssociatedObject(self, &UIButton_ls_badgeMinSizeKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (CGFloat)ls_badgeOriginX
{
    NSNumber *n = objc_getAssociatedObject(self, &UIButton_ls_badgeOriginXKey);
    return n.floatValue;
}
- (void)setLs_badgeOriginX:(CGFloat)badgeOriginX
{
    NSNumber *n = @(badgeOriginX);
    objc_setAssociatedObject(self, &UIButton_ls_badgeOriginXKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

- (CGFloat)ls_badgeOriginY
{
    NSNumber *n = objc_getAssociatedObject(self, &UIButton_ls_badgeOriginYKey);
    return n.floatValue;
}
- (void)setLs_badgeOriginY:(CGFloat)badgeOriginY
{
    NSNumber *n = @(badgeOriginY);
    objc_setAssociatedObject(self, &UIButton_ls_badgeOriginYKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.ls_badge) { [self ls_updateBadgeFrame]; }
}

// Behavior flags
- (BOOL)ls_shouldHideBadgeAtZero
{
    NSNumber *n = objc_getAssociatedObject(self, &UIButton_ls_shouldHideBadgeAtZeroKey);
    return n.boolValue;
}
- (void)setLs_shouldHideBadgeAtZero:(BOOL)shouldHideBadgeAtZero
{
    NSNumber *n = @(shouldHideBadgeAtZero);
    objc_setAssociatedObject(self, &UIButton_ls_shouldHideBadgeAtZeroKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)ls_shouldAnimateBadge
{
    NSNumber *n = objc_getAssociatedObject(self, &UIButton_ls_shouldAnimateBadgeKey);
    return n.boolValue;
}
- (void)setLs_shouldAnimateBadge:(BOOL)shouldAnimateBadge
{
    NSNumber *n = @(shouldAnimateBadge);
    objc_setAssociatedObject(self, &UIButton_ls_shouldAnimateBadgeKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
