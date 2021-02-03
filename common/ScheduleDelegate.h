//
//  ScheduleDelegate.h
//  Music Library Exporter
//
//  Created by Kyle King on 2021-02-02.
//

#import <Foundation/Foundation.h>

@class ExportDelegate;
@class ScheduleConfiguration;


NS_ASSUME_NONNULL_BEGIN

@interface ScheduleDelegate : NSObject


#pragma mark - Properties -

@property ScheduleConfiguration* configuration;
@property ExportDelegate* exportDelegate;


#pragma mark - Initializers -

- (instancetype)initWithConfiguration:(ScheduleConfiguration*)config andExportDelegate:(ExportDelegate*)exportDelegate;


#pragma mark - Accessors -

#pragma mark - Mutators -

- (void)activateScheduler;
- (void)deactivateScheduler;


@end

NS_ASSUME_NONNULL_END
