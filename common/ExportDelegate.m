//
//  ExportDelegate.m
//  Music Library Exporter
//
//  Created by Kyle King on 2021-02-03.
//

#import "ExportDelegate.h"

#import <iTunesLibrary/ITLibrary.h>

#import "Logger.h"
#import "Defines.h"
#import "Utils.h"
#import "UserDefaultsExportConfiguration.h"
#import "LibraryFilter.h"
#import "LibrarySerializer.h"
#import "OrderedDictionary.h"


@implementation ExportDelegate {

  ITLibrary* _library;

  LibraryFilter* _libraryFilter;
  LibrarySerializer* _librarySerializer;
}


NSErrorDomain const __MLE_ErrorDomain_ExportDelegate = @"com.kylekingcdn.MusicLibraryExporter.ExportDelegateErrorDomain";


#pragma mark - Initializers

- (instancetype)initWithLibrary:(ITLibrary*)library {

  self = [super init];

  _state = ExportStopped;

  _library = library;

  _libraryFilter = [[LibraryFilter alloc] initWithLibrary:_library];
  _librarySerializer = [[LibrarySerializer alloc] initWithLibrary:_library];

  return self;
}


#pragma mark - Mutators

- (void)updateState:(ExportState)state {

  _state = state;

  if (_stateCallback) {
    _stateCallback(_state);
  }
}

- (BOOL)prepareForExportAndReturnError:(NSError**)error {

  MLE_Log_Info(@"ExportDelegate [prepareForExportAndReturnError]");

  // validate state
  switch (_state) {
    case ExportStopped:
    case ExportFinished:
    case ExportError: {
      break;
    }
    case ExportPreparing:
    case ExportGeneratingTracks:
    case ExportGeneratingPlaylists:
    case ExportWritingToDisk: {
      MLE_Log_Info(@"ExportDelegate [prepareForExportAndReturnError] currently busy - state: %@", [Utils descriptionForExportState:_state]);
      *error = [NSError errorWithDomain:__MLE_ErrorDomain_ExportDelegate code:ExportDelegateErrorBusyState userInfo:@{
        NSLocalizedDescriptionKey:@"Export handler is currently busy, please try again.",
      }];
      return NO;
    }
  }

  [self updateState:ExportPreparing];

  // set configuration
  if (!UserDefaultsExportConfiguration.sharedConfig.isOutputDirectoryValid) {
    MLE_Log_Info(@"ExportDelegate [prepareForExportAndReturnError] error - invalid output directory url");
    [self updateState:ExportError];
    return NO;
  }

  // init serializer
  [_librarySerializer initSerializeMembers];

  // get included items
  _includedTracks = [_libraryFilter getIncludedTracks];
  _includedPlaylists = [_libraryFilter getIncludedPlaylists];

  return YES;
}

- (BOOL)exportLibraryAndReturnError:(NSError**)error {

  MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError]");

  // validate state
  switch (_state) {
    case ExportPreparing: {
      break;
    }
    case ExportStopped:
    case ExportFinished:
    case ExportError: {
      MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError] error - prepareForExport must be called first - current state: %@", [Utils descriptionForExportState:_state]);
      return NO;
    }
    case ExportGeneratingTracks:
    case ExportGeneratingPlaylists:
    case ExportWritingToDisk: {
      MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError] delegate is currently busy - state: %@", [Utils descriptionForExportState:_state]);
      return NO;
    }
  }

  // serialize tracks
  MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError] serializing tracks");
  [self updateState:ExportGeneratingTracks];
  OrderedDictionary* tracksDict = [_librarySerializer serializeTracks:_includedTracks withProgressCallback:_trackProgressCallback];

  // serialize playlists
  MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError] serializing playlists");
  [self updateState:ExportGeneratingPlaylists];
  NSArray<OrderedDictionary*>* playlistsDicts = [_librarySerializer serializePlaylists:_includedPlaylists withProgressCallback:_playlistProgressCallback];

  // serialize library
  MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError] serializing library");
  OrderedDictionary* libraryDict = [_librarySerializer serializeLibraryforTracks:tracksDict andPlaylists:playlistsDicts];

  // write library
  MLE_Log_Info(@"ExportDelegate [exportLibraryAndReturnError] writing library");
  [self updateState:ExportWritingToDisk];

  BOOL writeSuccess = [self writeDictionary:libraryDict error:error];
  if (writeSuccess) {
    [self updateState:ExportFinished];
    return YES;
  }
  else {
    [self updateState:ExportError];
    return NO;
  }
}

- (BOOL)writeDictionary:(OrderedDictionary*)libraryDict error:(NSError**)error {

  MLE_Log_Info(@"ExportDelegate [writeDictionary]");

  NSURL* outputDirectoryUrl = UserDefaultsExportConfiguration.sharedConfig.resolveAndAutoRenewOutputDirectoryUrl;
  if (outputDirectoryUrl == nil) {
    MLE_Log_Info(@"ExportDelegate [writeDictionary] unable to retrieve output directory - a directory must be selected to obtain write permission");
    return NO;
  }

  NSString* outputFileName = UserDefaultsExportConfiguration.sharedConfig.outputFileName;
  if (!outputFileName || outputFileName.length == 0) {
    outputFileName = @"Library.xml"; // fallback to default filename
    MLE_Log_Info(@"ExportDelegate [writeDictionary] output filename unspecified - falling back to default: %@", outputFileName);
  }

  NSURL* outputFileUrl = [outputDirectoryUrl URLByAppendingPathComponent:outputFileName];

  // write library
  MLE_Log_Info(@"ExportDelegate [writeDictionary] saving to: %@", outputFileUrl);
  [outputDirectoryUrl startAccessingSecurityScopedResource];
  BOOL writeSuccess = [libraryDict writeToURL:outputFileUrl error:error];
  [outputDirectoryUrl stopAccessingSecurityScopedResource];

  if (!writeSuccess) {
    MLE_Log_Info(@"ExportDelegate [writeDictionary] error writing dictionary");
    return NO;
  }

  return YES;
}

@end

