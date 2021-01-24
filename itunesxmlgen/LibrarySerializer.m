//
//  serializer.m
//  itunesxmlgen
//
//  Created by Kyle King on 2021-01-18.
//

#import "LibrarySerializer.h"

#import "Utils.h"

#import <iTunesLibrary/ITLibrary.h>
#import <iTunesLibrary/ITLibAlbum.h>
#import <iTunesLibrary/ITLibArtist.h>
#import <iTunesLibrary/ITLibMediaItem.h>
#import <iTunesLibrary/ITLibPlaylist.h>

@implementation LibrarySerializer

+ (NSString*) getHexadecimalPersistentId:(NSNumber*)decimalPersistentId {

  return [[NSString stringWithFormat:@"%016lx", decimalPersistentId.unsignedIntegerValue] uppercaseString];
}

+ (void) dumpPropertiesForEntity:(ITLibMediaEntity*) entity {

  return [LibrarySerializer dumpPropertiesForEntity:entity withoutProperties:nil];
}

+ (void) dumpPropertiesForEntity:(ITLibMediaEntity*) entity withoutProperties:(NSSet<NSString *> * _Nullable) excludedProperties {

  if (entity) {
    NSLog(@"\n");
    [entity enumerateValuesExceptForProperties:excludedProperties usingBlock:^(NSString * _Nonnull property, id  _Nonnull value, BOOL * _Nonnull stop) {
      NSLog(@"%@: %@", property, value);
    }];
  }
}

+ (void) dumpLibraryPlaylists:(ITLibrary*) library {

  for (ITLibPlaylist* item in library.allPlaylists) {

    ITLibMediaEntity* entity = item;
    [LibrarySerializer dumpPropertiesForEntity:entity withoutProperties:[NSSet setWithObject:ITLibPlaylistPropertyItems]];
  }
}

+ (void) dumpLibraryTracks:(ITLibrary*) library {

  for (ITLibMediaItem* item in library.allMediaItems) {

      ITLibMediaEntity* entity = item;
      [LibrarySerializer dumpPropertiesForEntity:entity];
  }
}

- (void) serializeLibrary:(ITLibrary*) library {

  NSLog(@"[LibrarySerializer serializeLibrary]");

  // clear generated library dictionary
  _libraryDict = [NSMutableDictionary dictionary];

  // reset internal entity IDs
  currentEntityId = 0;
  entityIdsDicts = [NSMutableDictionary dictionary];

  [_libraryDict setValue:[NSNumber numberWithUnsignedInteger:library.apiMajorVersion] forKey:@"Major Version"];
  [_libraryDict setValue:[NSNumber numberWithUnsignedInteger:library.apiMinorVersion] forKey:@"Minor Version"];
  [_libraryDict setValue:[NSDate date] forKey:@"Date"]; // TODO:finish me
  [_libraryDict setValue:library.applicationVersion forKey:@"Application Version"];
  [_libraryDict setValue:[NSNumber numberWithUnsignedInteger:library.features] forKey:@"Features"];
  [_libraryDict setValue:@(library.showContentRating) forKey:@"Show Content Ratings"];
//  [_libraryDict setValue:library.mediaFolderLocation.absoluteString forKey:@"Music Folder"]; - invalid
//  [dictionary setValue:library.persistentID forKey:@"Library Persistent ID"]; - unavailable

  // add tracks dictionary to library dictionary
  NSMutableDictionary* tracksDict = [self serializeTracks:library.allMediaItems];
  [_libraryDict setObject:tracksDict forKey:@"Tracks"];

  // add playlists array to library dictionary
  NSMutableArray<NSMutableDictionary*>* playlistsArray = [self serializePlaylists:library.allPlaylists];
  [_libraryDict setObject:playlistsArray forKey:@"Playlists"];
}

- (NSMutableArray<NSMutableDictionary*>*) serializePlaylists:(NSArray<ITLibPlaylist*>*) playlists {

  hasPlaylistIdWhitelist = (_includedPlaylistPersistentIds.count >= 1);

  NSMutableArray<NSMutableDictionary*>* playlistsArray = [NSMutableArray array];

  for (ITLibPlaylist* playlistItem in playlists) {

    NSString* playlistPersistentIdHex = [LibrarySerializer getHexadecimalPersistentId:playlistItem.persistentID];

    // ignore internal playlists if specified
    if (_includeInternalPlaylists || (playlistItem.distinguishedKind == ITLibDistinguishedPlaylistKindNone && !playlistItem.master)) {

      // ignore playlists when whitelist is enabled and their id is not included
      if (!hasPlaylistIdWhitelist || [_includedPlaylistPersistentIds containsObject:playlistPersistentIdHex]) {

        // ignore folders when flattened if specified
        if (playlistItem.kind != ITLibPlaylistKindFolder || !_flattenPlaylistHierarchy || _includeFoldersWhenFlattened) {

          // generate playlist id
          NSUInteger playlistId = ++currentEntityId;

          // store playlist + id in playlistIds dict
          NSNumber* playlistIdNumber = [NSNumber numberWithUnsignedInteger:playlistId];
          [entityIdsDicts setValue:playlistIdNumber forKey:playlistPersistentIdHex];

          // serialize playlist
          NSMutableDictionary* playlistDict = [self serializePlaylist:playlistItem withId:playlistId];

          // add playlist dictionary object to playlistsArray
          [playlistsArray addObject:playlistDict];
        }
        else {
          NSLog(@"excluding folder due to folders disabled w/ flat hierarchy : %@ - %@", playlistItem.name, playlistItem.persistentID);
        }
      }
      else {
        NSLog(@"excluding playlist since it is not on the whitelist: %@ - %@", playlistItem.name, playlistItem.persistentID);
      }
    }
    else {
      NSLog(@"excluding internal playlist: %@ - %@", playlistItem.name, playlistItem.persistentID);
    }
  }

  return playlistsArray;
}

- (NSMutableDictionary*) serializePlaylist:(ITLibPlaylist*) playlistItem withId: (NSUInteger) playlistId {

  NSMutableDictionary* playlistDict = [NSMutableDictionary dictionary];

  [playlistDict setValue:playlistItem.name forKey:@"Name"];
//  [playlistDict setValue:playlistItem. forKey:@"Description"]; - unavailable
  if (playlistItem.master) {
    [playlistDict setValue:[NSNumber numberWithBool:YES] forKey:@"Master"];
  }
  [playlistDict setValue:[NSNumber numberWithInteger:playlistId] forKey:@"Playlist ID"];
  [playlistDict setValue:[LibrarySerializer getHexadecimalPersistentId:playlistItem.persistentID] forKey:@"Playlist Persistent ID"];

  if (playlistItem.parentID > 0 && !_flattenPlaylistHierarchy) {
    [playlistDict setValue:[LibrarySerializer getHexadecimalPersistentId:playlistItem.parentID] forKey:@"Parent Persistent ID"];
  }
  if (playlistItem.distinguishedKind > ITLibDistinguishedPlaylistKindNone) {
    [playlistDict setValue:[NSNumber numberWithUnsignedInteger:playlistItem.distinguishedKind] forKey:@"Distinguished Kind"];
  }
  if (playlistItem.distinguishedKind == ITLibDistinguishedPlaylistKindMusic) {
    [playlistDict setValue:[NSNumber numberWithBool:YES] forKey:@"Music"];
  }
  if (!playlistItem.visible) {
    [playlistDict setValue:[NSNumber numberWithBool:NO] forKey:@"Visible"];
  }
  [playlistDict setValue:[NSNumber numberWithBool:playlistItem.allItemsPlaylist] forKey:@"All Items"];
  if (playlistItem.kind == ITLibPlaylistKindFolder) {
    [playlistDict setValue:[NSNumber numberWithBool:YES] forKey:@"Folder"];
  }

  // add playlist items array to playlist dict
  NSMutableArray<NSMutableDictionary*>* playlistItemsArray = [self serializePlaylistItems:playlistItem.items];
  [playlistDict setObject:playlistItemsArray forKey:@"Playlist Items"];

  return playlistDict;
}

- (NSMutableArray<NSMutableDictionary*>*) serializePlaylistItems: (NSArray<ITLibMediaItem*>*) trackItems {

  NSMutableArray<NSMutableDictionary*>* playlistItemsArray = [NSMutableArray array];

  for (ITLibMediaItem* trackItem in trackItems) {

    if (trackItem.mediaKind == ITLibMediaItemMediaKindSong) {

      NSMutableDictionary* playlistItemDict = [NSMutableDictionary dictionary];

      // get track id
      NSString* trackPersistentId = [LibrarySerializer getHexadecimalPersistentId:trackItem.persistentID];
      NSAssert([[entityIdsDicts allKeys] containsObject:trackPersistentId], @"trackIds doesn't contain persistent ID for track '%@'", trackPersistentId);
      NSUInteger trackId = [[entityIdsDicts objectForKey:trackPersistentId] integerValue];
      NSAssert(trackId > 0, @"trackIds dict returned an invalid value: %lu", trackId);

      [playlistItemDict setValue:[NSNumber numberWithUnsignedInteger:trackId] forKey:@"Track ID"];

      // add item dict to playlist items array
      [playlistItemsArray addObject:playlistItemDict];
    }
  }

  return playlistItemsArray;
}

- (NSMutableDictionary*) serializeTracks:(NSArray<ITLibMediaItem*>*) tracks {

  shouldRemapTrackLocations = (_remapRootDirectory && _originalRootDirectory.length > 0 && _mappedRootDirectory.length > 0);

  NSMutableDictionary* tracksDict = [NSMutableDictionary dictionary];

  for (ITLibMediaItem* trackItem in tracks) {

    if (trackItem.mediaKind == ITLibMediaItemMediaKindSong) {

      // generate track id
      NSUInteger trackId = ++currentEntityId;

      // store track + id in trackIds dict
      NSString* trackPersistentIdHex = [LibrarySerializer getHexadecimalPersistentId:trackItem.persistentID];
      NSString* trackIdString = [@(trackId) stringValue];
      [entityIdsDicts setValue:trackIdString forKey:trackPersistentIdHex];

      NSMutableDictionary* trackDict = [self serializeTrack:trackItem withId:trackId];

      // add track dictionary object to root tracks dictionary
      [tracksDict setObject:trackDict forKey:[@(trackId) stringValue]];
    }
  }

  return tracksDict;
}

- (NSMutableDictionary*) serializeTrack:(ITLibMediaItem*) trackItem withId: (NSUInteger) trackId {

  NSMutableDictionary* trackDict = [NSMutableDictionary dictionary];

  [trackDict setValue:[NSNumber numberWithInteger: trackId] forKey:@"Track ID"];
  [trackDict setValue:trackItem.title forKey:@"Name"];
  if (trackItem.artist.name) {
    [trackDict setValue:trackItem.artist.name forKey:@"Artist"];
  }
  if (trackItem.album.albumArtist) {
    [trackDict setValue:trackItem.album.albumArtist forKey:@"Album Artist"];
  }
  if (trackItem.composer.length > 0) {
    [trackDict setValue:trackItem.composer forKey:@"Composer"];
  }
  if (trackItem.album.title) {
    [trackDict setValue:trackItem.album.title forKey:@"Album"];
  }
  if (trackItem.grouping) {
    [trackDict setValue:trackItem.grouping forKey:@"Grouping"];
  }
  [trackDict setValue:trackItem.genre forKey:@"Genre"];
  if (trackItem.kind) {
    [trackDict setValue:trackItem.kind forKey:@"Kind"];
  }
  if (trackItem.comments) {
    [trackDict setValue:trackItem.comments forKey:@"Comments"];
  }
  [trackDict setValue:[NSNumber numberWithUnsignedLongLong:trackItem.fileSize] forKey:@"Size"];
  [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.totalTime] forKey:@"Total Time"];
  if (trackItem.startTime > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.startTime] forKey:@"Start Time"];
  }
  if (trackItem.stopTime > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.stopTime] forKey:@"Stop Time"];
  }
  if (trackItem.album.discNumber > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.album.discNumber] forKey:@"Disc Number"];
  }
  if (trackItem.album.discCount > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.album.discCount] forKey:@"Disc Count"];
  }
  if (trackItem.trackNumber > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.trackNumber] forKey:@"Track Number"];
  }
  if (trackItem.album.trackCount > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.album.trackCount] forKey:@"Track Count"];
  }
  [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.year] forKey:@"Year"];
  if (trackItem.beatsPerMinute > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.beatsPerMinute] forKey:@"BPM"];
  }
  if (trackItem.modifiedDate) {
    [trackDict setValue:trackItem.modifiedDate forKey:@"Date Modified"];
  }
  if (trackItem.addedDate) {
    [trackDict setValue:trackItem.addedDate forKey:@"Date Added"];
  }
  [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.bitrate] forKey:@"Bit Rate"];
  [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.sampleRate] forKey:@"Sample Rate"];
  if (trackItem.volumeAdjustment != 0) {
    [trackDict setValue:[NSNumber numberWithInteger:trackItem.volumeAdjustment] forKey:@"Volume Adjustment"];
  }
  if (trackItem.album.gapless) {
    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Part Of Gapless Album"];
  }
  if (trackItem.rating != 0) {
    [trackDict setValue:[NSNumber numberWithInteger:trackItem.rating] forKey:@"Rating"];
  }
  if (trackItem.ratingComputed) {
    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Rating Computed"];
  }
  if (trackItem.album.rating != 0) {
    [trackDict setValue:[NSNumber numberWithInteger:trackItem.album.rating] forKey:@"Album Rating"];
  }
  if (trackItem.album.ratingComputed) {
    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Album Rating Computed"];
  }
  if (trackItem.playCount > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.playCount] forKey:@"Play Count"];
  }
  if (trackItem.lastPlayedDate) {
//    [trackDict setValue:[NSNumber numberWithLongLong:trackItem.lastPlayedDate.timeIntervalSince1970+2082844800] forKey:@"Play Date"]; - invalid
    [trackDict setValue:trackItem.lastPlayedDate forKey:@"Play Date UTC"];
  }
  if (trackItem.skipCount > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.skipCount] forKey:@"Skip Count"];
  }
  if (trackItem.skipDate) {
    [trackDict setValue:trackItem.skipDate forKey:@"Skip Date"];
  }
  if (trackItem.releaseDate) {
    [trackDict setValue:trackItem.releaseDate forKey:@"Release Date"];
  }
  if (trackItem.volumeNormalizationEnergy > 0) {
    [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.volumeNormalizationEnergy] forKey:@"Normalization"];
  }
  if (trackItem.album.compilation) {
    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Compilation"];
  }
//  if (trackItem.hasArtworkAvailable) {
//    [trackDict setValue:[NSNumber numberWithUnsignedInteger:1] forKey:@"Artwork Count"]; - unavailable
//  }
  if (trackItem.album.sortTitle) {
    [trackDict setValue:trackItem.album.sortTitle forKey:@"Sort Album"];
  }
  if (trackItem.album.sortAlbumArtist) {
    [trackDict setValue:trackItem.album.sortAlbumArtist forKey:@"Sort Album Artist"];
  }
  if (trackItem.artist.sortName) {
    [trackDict setValue:trackItem.artist.sortName forKey:@"Sort Artist"];
  }
  if (trackItem.sortComposer) {
    [trackDict setValue:trackItem.sortComposer forKey:@"Sort Composer"];
  }
  if (trackItem.sortTitle) {
    [trackDict setValue:trackItem.sortTitle forKey:@"Sort Name"];
  }
  if (trackItem.isUserDisabled) {
    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Disabled"];
  }

  [trackDict setValue:[LibrarySerializer getHexadecimalPersistentId:trackItem.persistentID] forKey:@"Persistent ID"];
//  [trackDict setValue:trackItem.title forKey:@"Track Type"]; - invalid

//  [trackDict setValue:[NSNumber numberWithUnsignedInteger:trackItem.fileType] forKey:@"File Type"]; - deprecated
//  if (trackItem.cloud) {
//    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Matched"]; - unavailable
//  }
//  if (trackItem.purchased) {
//    [trackDict setValue:[NSNumber numberWithBool:YES] forKey:@"Purchased"]; - invalid
//  }
  if (trackItem.location) {

    NSString* trackFilePath = trackItem.location.path;

    if (shouldRemapTrackLocations) {
      trackFilePath = [trackFilePath stringByReplacingOccurrencesOfString:_originalRootDirectory withString:_mappedRootDirectory];
    }

    NSString* encodedTrackPath = [@"file://" stringByAppendingString:trackFilePath];
    [trackDict setValue:encodedTrackPath forKey:@"Location"];
  }

  return trackDict;
}

- (NSString*) remapRootMusicDirForFilePath:(NSString*)filePath {

  return [filePath stringByReplacingOccurrencesOfString:_originalRootDirectory withString:_mappedRootDirectory];
}

- (void) writeDictionary {

  NSLog(@"[LibrarySerializer writeDictionary]");

  NSError* serializeError = nil;
  NSData* data = [NSPropertyListSerialization dataWithPropertyList:_libraryDict format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeError];
  if (serializeError) {
      NSLog(@"[LibrarySerializer writeDictionary] error serializing dictionary: %@", serializeError);
      return;
  }

  NSError* writeError = nil;
  BOOL writeSuccessful = [data writeToFile:_filePath
                                   options:NSDataWritingAtomic
                                     error:&writeError];
  if (!writeSuccessful) {
      NSLog (@"[LibrarySerializer writeDictionary] error writing dictionary: %@", writeError);
      return;
  }
}

@end
