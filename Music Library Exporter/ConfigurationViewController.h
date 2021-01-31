//
//  ConfigurationViewController.h
//  Music Library Exporter
//
//  Created by Kyle King on 2021-01-29.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ExportConfiguration;

@interface ConfigurationViewController : NSViewController {

  BOOL _scheduleEnabled;
  
  ExportConfiguration* _exportConfiguration;
}

- (instancetype)init;

- (BOOL)isScheduleRegisteredWithSystem;
- (BOOL)registerSchedulerWithSystem:(BOOL)flag;

- (IBAction)setScheduleEnabled:(id)sender;

- (NSString*)errorForSchedulerRegistration:(BOOL)registerFlag;

- (void)updateFromConfiguration;

@end

NS_ASSUME_NONNULL_END