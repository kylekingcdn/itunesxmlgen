//
//  ExportDelegate.m
//  Music Library Exporter
//
//  Created by Kyle King on 2021-02-03.
//

#import "ExportDelegate.h"

#import <iTunesLibrary/ITLibrary.h>

#import "Defines.h"
#import "UserDefaultsExportConfiguration.h"
#import "LibraryFilter.h"
#import "LibrarySerializer.h"
#import "OrderedDictionary.h"


@implementation ExportDelegate {

  ITLibrary* _itLibrary;

  LibraryFilter* _libraryFilter;
  LibrarySerializer* _librarySerializer;
}


#pragma mark - Initializers -

- (instancetype)init {

  self = [super init];

  _state = ExportStopped;

  NSError *error = nil;
  _itLibrary = [ITLibrary libraryWithAPIVersion:@"1.1" error:&error];
  if (!_itLibrary) {
    NSLog(@"error - failed to init ITLibrary. error: %@", error.localizedDescription);
    return self;
  }

  _libraryFilter = [[LibraryFilter alloc] init];
  _librarySerializer = [[LibrarySerializer alloc] init];

  return self;
}

+ (instancetype)exporter {

  return [[ExportDelegate alloc] init];
}



#pragma mark - Mutators -

- (void)updateState:(ExportState)state {

  _state = state;

  if (_stateCallback) {
    _stateCallback(_state);
  }
}

- (BOOL)prepareForExport {

  NSLog(@"ExportDelegate [prepareForExport]");

  [self updateState:ExportPreparing];

  // set configuration
  if (!UserDefaultsExportConfiguration.sharedConfig.isOutputDirectoryValid) {
    NSLog(@"ExportDelegate [prepareForExport] error - invalid output directory url");
    [self updateState:ExportError];
    return NO;
  }
  if (!UserDefaultsExportConfiguration.sharedConfig.isOutputFileNameValid) {
    NSLog(@"ExportDelegate [prepareForExport] error - invalid output filename");
    [self updateState:ExportError];
    return NO;
  }

  // init ITLibrary instance
  NSError *initLibraryError = nil;
  _itLibrary = [ITLibrary libraryWithAPIVersion:@"1.1" error:&initLibraryError];
  if (!_itLibrary) {
    NSLog(@"ExportDelegate [prepareForExport]  error - failed to init ITLibrary. error: %@", initLibraryError.localizedDescription);
    [self updateState:ExportError];
    return NO;
  }

  // init filter
  [_libraryFilter setLibrary:_itLibrary];

  // init serializer
  [_librarySerializer setLibrary:_itLibrary];
  [_librarySerializer initSerializeMembers];

  // get included items
  _includedTracks = [_libraryFilter getIncludedTracks];
  _includedPlaylists = [_libraryFilter getIncludedPlaylists];

  return YES;
}

- (void)exportLibrary {

  NSLog(@"ExportDelegate [exportLibrary]");

  // serialize tracks
  NSLog(@"ExportDelegate [exportLibrary] serializing tracks");
  [self updateState:ExportGeneratingTracks];
  OrderedDictionary* tracks = [_librarySerializer serializeTracks:_includedTracks withProgressCallback:_trackProgressCallback];

  // serialize playlists
  NSLog(@"ExportDelegate [exportLibrary] serializing playlists");
  [self updateState:ExportGeneratingPlaylists];
  NSArray<OrderedDictionary*>* playlists = [_librarySerializer serializePlaylists:_includedPlaylists];

  // serialize library
  NSLog(@"ExportDelegate [exportLibrary] serializing library");
  OrderedDictionary* library = [_librarySerializer serializeLibraryforTracks:tracks andPlaylists:playlists];

  // write library
  NSLog(@"ExportDelegate [exportLibrary] writing library");
  [self updateState:ExportWritingToDisk];
  BOOL writeSuccess = [self writeDictionary:library];

  if (writeSuccess) {
    [self updateState:ExportFinished];
  }
  else {
    [self updateState:ExportError];
  }
}

- (BOOL)writeDictionary:(OrderedDictionary*)libraryDict {

  NSLog(@"ExportDelegate [writeDictionary]");

  NSURL* outputDirectoryUrl = UserDefaultsExportConfiguration.sharedConfig.resolveAndAutoRenewOutputDirectoryUrl;
  if (!outputDirectoryUrl) {
    NSLog(@"ExportDelegate [writeDictionary] unable to retrieve output directory - a directory must be selected to obtain write permission");
    return NO;
  }

  // write library
  NSLog(@"ExportDelegate [writeDictionary] saving to: %@", UserDefaultsExportConfiguration.sharedConfig.outputFileUrl);
  [outputDirectoryUrl startAccessingSecurityScopedResource];
  BOOL writeSuccess = [libraryDict writeToURL:UserDefaultsExportConfiguration.sharedConfig.outputFileUrl atomically:YES];
  [outputDirectoryUrl stopAccessingSecurityScopedResource];

  if (!writeSuccess) {
    NSLog(@"ExportDelegate [writeDictionary] error writing dictionary");
    return NO;
  }

  return YES;
}

@end

