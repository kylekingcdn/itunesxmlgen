//
//  ScheduleConfiguration.m
//  Music Library Exporter
//
//  Created by Kyle King on 2021-02-02.
//

#import "ScheduleConfiguration.h"

#import <ServiceManagement/ServiceManagement.h>

#import "Defines.h"


@implementation ScheduleConfiguration {

  NSUserDefaults* _userDefaults;

  BOOL _scheduleEnabled;
  NSInteger _scheduleInterval;

  NSDate* _lastExportedAt;
  NSDate* _nextExportAt;
}


#pragma mark - Initializers -

- (instancetype)init {

  self = [super init];

  _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:__MLE__AppGroupIdentifier];

  [self loadPropertiesFromUserDefaults];

  return self;
}


#pragma mark - Accessors -

- (NSDictionary*)defaultValues {

  return [NSDictionary dictionaryWithObjectsAndKeys:
    @NO,             @"ScheduleEnabled",
    @1,              @"ScheduleInterval",
    nil
  ];
}

- (BOOL)scheduleEnabled {

  return _scheduleEnabled;
}

- (NSInteger)scheduleInterval {

  return _scheduleInterval;
}

- (nullable NSDate*)lastExportedAt {

  return _lastExportedAt;
}

- (nullable NSDate*)nextExportAt {

  return _nextExportAt;
}

- (void)dumpProperties {

  NSLog(@"ScheduleConfiguration [dumpProperties]");

  NSLog(@"  ScheduleEnabled:                 '%@'", (_scheduleEnabled ? @"YES" : @"NO"));
  NSLog(@"  ScheduleInterval:                '%ld'", (long)_scheduleInterval);
  NSLog(@"  LastExportedAt:                  '%@'", _lastExportedAt.description);
  NSLog(@"  NextExportAt:                    '%@'", _nextExportAt.description);
}


#pragma mark - Mutators -

- (void)loadPropertiesFromUserDefaults {

  // register default values for properties
  [_userDefaults registerDefaults:[self defaultValues]];

  // read user defaults
  _scheduleEnabled = [_userDefaults boolForKey:@"ScheduleEnabled"];
  _scheduleInterval = [_userDefaults integerForKey:@"ScheduleInterval"];

  _lastExportedAt = [_userDefaults valueForKey:@"LastExportedAt"];
  _nextExportAt = [_userDefaults valueForKey:@"NextExportAt"];
}

- (void)setScheduleEnabled:(BOOL)flag {

  NSLog(@"ScheduleConfiguration [setScheduleEnabled:%@]", (flag ? @"YES" : @"NO"));

  _scheduleEnabled = flag;

  [_userDefaults setBool:_scheduleEnabled forKey:@"ScheduleEnabled"];
}

- (void)setScheduleInterval:(NSInteger)interval {

  NSLog(@"ScheduleConfiguration [setScheduleInterval:%ld]", (long)interval);

  _scheduleInterval = interval;

  [_userDefaults setInteger:_scheduleInterval forKey:@"ScheduleInterval"];
}

- (void)setLastExportedAt:(nullable NSDate*)timestamp {

  NSLog(@"ScheduleConfiguration [setLastExportedAt:%@]", timestamp.description);

  _lastExportedAt = timestamp;

  [_userDefaults setValue:_lastExportedAt forKey:@"LastExportedAt"];
}

- (void)setNextExportAt:(nullable NSDate*)timestamp {

  NSLog(@"ScheduleConfiguration [setNextExportAt:%@]", timestamp.description);

  _nextExportAt = timestamp;

  [_userDefaults setValue:_nextExportAt forKey:@"NextExportAt"];
}

@end
