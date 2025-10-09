//
//  UIBarButtonItem+Badge.h
//  therichest
//
//  Created by Mike on 2014-05-05.
//  Copyright (c) 2014 Valnet Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIButton (LS_Badge)

@property (strong, nonatomic) UILabel *ls_badge;

// Badge value to be displayed
@property (nonatomic) NSString *ls_badgeValue;
// Badge background color
@property (nonatomic) UIColor *ls_badgeBGColor;
// Badge text color
@property (nonatomic) UIColor *ls_badgeTextColor;
// Badge font
@property (nonatomic) UIFont *ls_badgeFont;
// Padding value for the badge
@property (nonatomic) CGFloat ls_badgePadding;
// Minimum size badge
@property (nonatomic) CGFloat ls_badgeMinSize;
// Offsets for positioning the badge
@property (nonatomic) CGFloat ls_badgeOriginX;
@property (nonatomic) CGFloat ls_badgeOriginY;
// Remove the badge when reaching zero (for numeric values)
@property (nonatomic) BOOL ls_shouldHideBadgeAtZero;
// Bounce animation when value changes
@property (nonatomic) BOOL ls_shouldAnimateBadge;

@end

NS_ASSUME_NONNULL_END
