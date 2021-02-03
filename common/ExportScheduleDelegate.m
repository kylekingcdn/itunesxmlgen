//
//  ExportScheduleDelegate.m
//  Music Library Exporter
//
//  Created by Kyle King on 2021-02-02.
//

#import "ExportScheduleDelegate.h"

#import <ServiceManagement/ServiceManagement.h>

#import "Defines.h"

@implementation ExportScheduleDelegate


#pragma mark - Initializers -

- (instancetype)init {

  self = [super init];

  [self loadPropertiesFromUserDefaults];
  [self updateSchedulerRegistrationIfRequired];

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

- (BOOL)isSchedulerRegisteredWithSystem {

  // source: http://blog.mcohen.me/2012/01/12/login-items-in-the-sandbox/
  // > As of WWDC 2017, Apple engineers have stated that [SMCopyAllJobDictionaries] is still the preferred API to use.
  //     ref: https://github.com/alexzielenski/StartAtLoginController/issues/12#issuecomment-307525807

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CFArrayRef cfJobDictsArr = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
#pragma pop
  NSArray* jobDictsArr = CFBridgingRelease(cfJobDictsArr);

  if (jobDictsArr && jobDictsArr.count > 0) {

    for (NSDictionary* jobDict in jobDictsArr) {

      if ([__MLE__HelperBundleIdentifier isEqualToString:[jobDict objectForKey:@"Label"]]) {
        return [[jobDict objectForKey:@"OnDemand"] boolValue];
      }
    }
  }

  return NO;
}

- (NSString*)errorForSchedulerRegistration:(BOOL)registerFlag {

  if (registerFlag) {
    return @"Couldn't add Music Library Exporter Helper to launch at login item list.";
  }
  else {
    return @"Couldn't remove Music Library Exporter Helper from launch at login item list.";
  }
}


#pragma mark - Mutators -

- (void)loadPropertiesFromUserDefaults {

  NSUserDefaults* groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:__MLE__AppGroupIdentifier];
  NSAssert(groupDefaults, @"failed to init NSUSerDefaults for app group");

  // register default values for properties
  [groupDefaults registerDefaults:[self defaultValues]];

  // read user defaults
  _scheduleEnabled = [groupDefaults boolForKey:@"ScheduleEnabled"];
  _scheduleInterval = [groupDefaults integerForKey:@"ScheduleInterval"];
}

- (void)setScheduleEnabled:(BOOL)flag {

  NSLog(@"[setScheduleEnabled:%@]", (flag ? @"YES" : @"NO"));

  _scheduleEnabled = flag;

  // FIXME: should defaults be a member var?
  NSUserDefaults* groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:__MLE__AppGroupIdentifier];
  NSAssert(groupDefaults, @"failed to init NSUSerDefaults for app group");

  [groupDefaults setBool:_scheduleEnabled forKey:@"ScheduleEnabled"];

  // update scheduler registration
  [self registerSchedulerWithSystem:_scheduleEnabled];
}

- (void)setScheduleInterval:(NSInteger)interval {

  NSLog(@"[setScheduleInterval:%ld]", (long)interval);

  _scheduleInterval = interval;

  // FIXME: should defaults be a member var?
  NSUserDefaults* groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:__MLE__AppGroupIdentifier];
  NSAssert(groupDefaults, @"failed to init NSUSerDefaults for app group");

  [groupDefaults setInteger:_scheduleInterval forKey:@"ScheduleInterval"];
}

- (BOOL)registerSchedulerWithSystem:(BOOL)flag {

  NSLog(@"[registerSchedulerWithSystem:%@]", (flag ? @"YES" : @"NO"));

  BOOL success = SMLoginItemSetEnabled ((__bridge CFStringRef)__MLE__HelperBundleIdentifier, flag);

  if (success) {
    NSLog(@"[registerSchedulerWithSystem] succesfully %@ scheduler", (flag ? @"registered" : @"unregistered"));
    _scheduleEnabled = YES;
  }
  else {
    NSLog(@"[registerSchedulerWithSystem] failed to %@ scheduler", (flag ? @"register" : @"unregister"));
    _scheduleEnabled = YES;
  }

  return success;
}

- (void)updateSchedulerRegistrationIfRequired {

  NSLog(@"[updateSchedulerRegistrationIfRequired]");

  BOOL shouldUpdate = (_scheduleEnabled != [self isSchedulerRegisteredWithSystem]);
  if (shouldUpdate) {
    NSLog(@"[updateSchedulerRegistrationIfRequired] updating registration to: %@", (_scheduleEnabled ? @"registered" : @"unregistered"));
    [self registerSchedulerWithSystem:_scheduleEnabled];
  }
}


@end