//
//  AppDelegate.h
//  SavantPrototype
//
//  Created by Christopher Fuentes on 11/21/12.
//  Copyright (c) 2012 Christopher Fuentes. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//Savant works in states depending on what's going on.
//These are represented as follows:
typedef enum {
    SViTunesOpenSongNotPlaying,
    SViTunesOpenSongPlaying,
    SViTunesNotOpen,
    SVStateDefault,
    SVStatesProcessing
} SViTunesStates;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) IBOutlet NSView *view;

//UI elements
@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSTextField *mainLabel;
@property (strong) IBOutlet NSImageView *imageOne;
@property (strong) IBOutlet NSImageView *imageTwo;
@property (strong) IBOutlet NSImageView *imageThree;
@property (strong) IBOutlet NSButton *openItunesButton;
@property (atomic) SViTunesStates state;
@property (nonatomic, retain) NSTimer *updateTimer;
@property (nonatomic, retain) NSString *currentTrackName;
@property (strong) IBOutlet NSProgressIndicator *spinny;
@property (strong) IBOutlet NSColorWell *spinnyBackground;
@property (nonatomic, retain) NSString *currentSong;
@property (strong) IBOutlet NSButton *imageButton;
@property (strong) NSString *purchaseLink;
@property (strong) IBOutlet NSTextField *descriptionBox;
@property (strong) IBOutlet NSButton *coverButton;



//UI Button Actions
- (IBAction)openItunes:(id)sender;
- (IBAction)clickLink:(id)sender;


//Internals
- (void)updateAppState;
- (BOOL)testIfItunesIsPlaying;
- (BOOL)testIfItunesIsOpen;
- (NSString *)getTrackName;
- (NSString *)getArtistName;
- (void)changeState:(SViTunesStates)s;
- (void)randomGuess:(NSString *)key;
- (void)TFIDFLookup;
- (void)displayiTunesNotOpen;
- (void)displayiTunesNotPlaying;
- (void)displayProcessingUI;
- (void)processQuery;

@end
