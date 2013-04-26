//
//  AppDelegate.m
//  SavantPrototype
//
//  Created by Christopher Fuentes on 11/21/12.
//  Copyright (c) 2012 Christopher Fuentes. All rights reserved.
//

#import "AppDelegate.h"

//Below are some applescript lines that have been defined as constants for convenience

#define TEST_IF_ITUNES_RUNNING @"if appIsRunning(\"iTunes\") then \nreturn true \nelse \nreturn false \nend if \non appIsRunning(appName) \ntell application \"System Events\" to (name of processes) contains appName \nend appIsRunning"

#define TEST_IF_TRACK_IS_PLAYING @"tell application id \"com.apple.iTunes\" \nif player state is playing then\nreturn true \nelse \nreturn false\nend if \nend tell"

#define GET_TRACK_NAME @"tell application id \"com.apple.iTunes\" \nset currentTrackName to (get name of current track) as string \nreturn currentTrackName \nend tell"

#define GET_ARTIST_NAME @"tell application id \"com.apple.iTunes\" \nset currentTrackName to (get artist of current track) as string \nreturn currentTrackName \nend tell"

#define URL( x ) [NSString stringWithFormat:@"https://www.googleapis.com/books/v1/volumes?q=%@&key=AIzaSyCbOE0i2Ka9TUbclHgXEKn91E1b6RDMlfc", x]

//Gama is the "fine-tune" knob behind the recommendation scheme.
//The higher the knob, the tighter the recommendations will be, but
//you will bump up against the limits of your data much quicker.
//4 seems to work well.
#define GAMMA 4

//Similarity quotient is a ranking which determines at which point
//two strings are "similar" based on a method defined below.
//The lower the value, the more stringent the test. 
#define SIMILARITY_QUOTENT 1.4

@implementation AppDelegate

@synthesize imageOne;
@synthesize imageThree;
@synthesize imageTwo;
@synthesize mainLabel;
@synthesize openItunesButton;
@synthesize state;
@synthesize updateTimer;
@synthesize currentTrackName;
@synthesize view;
@synthesize spinny;
@synthesize spinnyBackground;
@synthesize currentSong;
@synthesize imageButton;
@synthesize purchaseLink;
@synthesize descriptionBox;
@synthesize coverButton;
@synthesize window;


//Starting point

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //We don't know what song is playing yet
    currentSong = nil;
    
    //set up ui features
    [self.openItunesButton setHidden:YES];
    [self.spinnyBackground setHidden:YES];
    [self.descriptionBox setHidden:YES];
    
    //initialize to default state
    self.state = SVStateDefault;
    
    //set a timer to check for state updates every second.
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                        target:self
                                                      selector:@selector(updateAppState)
                                                      userInfo:nil
                                                       repeats:YES];
    
    [self.coverButton setHidden:YES];
}

//When the user clicks the picture button, it will
//open the link in the default browser
- (IBAction)clickLink:(id)sender
{
    if (self.state != SViTunesOpenSongPlaying) return;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:self.purchaseLink]];
}

//this method is called every second.
//It tests for iTunes' conditions and updates
//accordingly
- (void)updateAppState
{
    if ([self testIfItunesIsOpen])
        if ([self testIfItunesIsPlaying])
            [self changeState:SViTunesOpenSongPlaying];
        else
            [self changeState:SViTunesOpenSongNotPlaying];
    else
        [self changeState:SViTunesNotOpen];
}

//If state change is necessary, it does so.
- (void)changeState:(SViTunesStates)s
{
    if (s == SViTunesOpenSongPlaying && ![self.currentSong isEqualToString:[self getTrackName]])
        self.state = s;
    
    //skip redundancies
    else if (self.state == s)
        return;
    
    switch (s) {
        case SViTunesNotOpen:
            [self displayiTunesNotOpen];
            break;
            
        case SViTunesOpenSongNotPlaying:
            [self displayiTunesNotPlaying];
            break;
            
        case SViTunesOpenSongPlaying:
            [self processQuery];
            break;
            
        default:
            NSLog(@"YOU SHOULD NOT BE HERE");
            break;
    }
    self.state = s;
}

//Configure UI for when iTunes isn't even open.
- (void)displayiTunesNotOpen
{
    [self.mainLabel setStringValue:@"iTunes is not open..."];
    [self.openItunesButton setHidden:NO];
    [self.spinny stopAnimation:nil];
    [self.spinnyBackground setHidden:YES];
    [self.imageOne setHidden:NO];
    [self.imageTwo setHidden:NO];
    [self.imageThree setHidden:NO];
    [self.coverButton setHidden:YES];
    [self.descriptionBox setHidden:YES];
}

//configure UI for when iTunes is open, but not playing anything.
- (void)displayiTunesNotPlaying
{
    [self.mainLabel setStringValue:@"Play a song on iTunes for a book recommendation."];
    [self.spinny stopAnimation:nil];
    [self.spinnyBackground setHidden:YES];
    [self.openItunesButton setHidden:YES];
    [self.imageOne setHidden:NO];
    [self.imageTwo setHidden:NO];
    [self.imageThree setHidden:NO];
    [self.coverButton setHidden:YES];
    [self.descriptionBox setHidden:YES];
}

#define MAX_TITLE_LENGTH 24


//Set's up the UI for the "loading screen", including a "spinny". 
- (void)displayProcessingUI
{
    NSString *titleLabel = [self getTrackName];
    if (titleLabel.length > MAX_TITLE_LENGTH)
    {
        titleLabel = [titleLabel substringToIndex:MAX_TITLE_LENGTH];
        titleLabel = [NSString stringWithFormat:@"%@...", titleLabel];
    }
    [self.mainLabel setStringValue:[NSString stringWithFormat:@"Looking for books based on \"%@\"", titleLabel]];
    
    [self.spinny startAnimation:nil];
    [self.spinnyBackground setHidden:NO];
}

//An error handling function. Simply displays
//the error message and hides the progress spinwheel.
- (void)error:(NSString *)errorMsg
{
    [self.mainLabel setStringValue:errorMsg];
    [self.spinnyBackground setHidden:YES];
    [self.spinny stopAnimation:nil];
}


//Create a barnes and noble URL based on a book title, author name, and isbn.
//I have no affiliation with B and N, but it is easy to make reliable URLs for their
//site.
- (NSString *)BarnesAndNobleURLFromBookName:(NSString *)bName authorName:(NSString *)aName isbn:(NSString *)isbn
{
    NSString *second = [aName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    NSString *first = [bName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    return [NSString stringWithFormat:@"http://www.barnesandnoble.com/w/%@-%@/0?ean=%@", first, second, isbn];
}


//Given an ISBN number, we query GoogleBooks API to get all relevant book info.
- (void)recommend:(NSString *)isbnNumber
{
    //Attempt to fetch JSON
    NSData *data = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:URL(isbnNumber)]];
    if (!data)
    {
        [self error:@"No recommendations were found!"];
        return;
    }
    NSError *error = nil;
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:
                              NSJSONReadingMutableContainers error:&error];
    if (error)
    {
        [self error:@"No recommendations were found!"];
        return;
    }
    
    //Main dictionary
    NSArray *lib = [response objectForKey:@"items"];
    if (!lib || lib.count == 0)
    {
        [self error:@"No recommendations were found!"];
        return;
    }
    
   //The first book in the response is what we need. 
    NSDictionary *firstBook = [lib objectAtIndex:0]; 

    //get the necessary info
    NSString *title = [[firstBook valueForKey:@"volumeInfo"] valueForKey:@"title"];
    NSString *descript = [[firstBook valueForKey:@"volumeInfo"] valueForKey:@"description"];
    NSArray *authors = [[firstBook valueForKey:@"volumeInfo"] valueForKey:@"authors"];
    NSString *author = nil;
    
    //authors come in an array, so we'll just grab the first one.
    if (authors.count >= 1)
        author = [authors objectAtIndex:0];
    
    //create a purchase link
    self.purchaseLink = [self BarnesAndNobleURLFromBookName:title authorName:author isbn:isbnNumber];
    
    //get the thumbnail URL
    NSDictionary *images = [[firstBook valueForKey:@"volumeInfo"] valueForKey:@"imageLinks"];
    if (!images || [images allKeys].count == 0)
    {
        [self error:@"No recommendations were found!"];
        return;
    }
    NSString *imgLink = [[[firstBook valueForKey:@"volumeInfo"] valueForKey:@"imageLinks"] valueForKey:@"thumbnail"];
    
    
    //Set up the UI to display the recommendation
    [self.mainLabel setStringValue:[NSString stringWithFormat:@"I recommend \"%@\". Click for details", title]];
    [self.imageOne setHidden:YES];
    [self.imageTwo setHidden:YES];
    [self.imageThree setHidden:YES];
    [self.descriptionBox setHidden:NO];
    [self.descriptionBox setStringValue:descript];
    [self.coverButton setHidden:NO];
    [self.spinny stopAnimation:nil];
    [self.spinnyBackground setHidden:YES];
    
    //Display the thumbnail url
    NSURL *url = [NSURL URLWithString:imgLink];
    NSImage *img = [[NSImage alloc] initWithContentsOfURL:url];
    if (img == nil)
    {
        //if no image is available, we use a default icon.png image.
        NSString *imgfile = [[NSBundle mainBundle] pathForResource:@"icon" ofType:@"png"];
        img = [[NSImage alloc] initWithContentsOfFile:imgfile];
    }
    [self.coverButton setImage:img];
}

//A string similarity function. Two strings are given a rating on similarity
//based on the number of consecutive matching characters. Each consecutive
//matching character is increasingly weighted so that words will get a high
//similarity ranking even if they only share roots. This ensures that
//for the most part etymologically similar words will have be identified
//as similar.
- (long long)string:(NSString *)first similarToString:(NSString *)second
{
    int score = 0;
    int points = 1;
    
    NSInteger l = first.length > second.length ? second.length : first.length;
    for (int i = 0; i < l; i++)
    {
        if ([first characterAtIndex:i] == [second characterAtIndex:i])
            score += (points *= 1.5);
    }
    
    return score;
}

//Lookup a recommendation based on TFIDF values
- (void)TFIDFLookup:(NSString *)searchString
{
    //alert user what we're doing
    [self.mainLabel setStringValue:@"Loading recommendation..."];
    
    NSString *bookLibraryPath = [[NSBundle mainBundle] pathForResource:@"bookCharacteristicStrings" ofType:@"plist"];
    NSDictionary *bookLibrary = [NSDictionary dictionaryWithContentsOfFile:bookLibraryPath];
    
    NSString *songLibraryPath = [[NSBundle mainBundle] pathForResource:@"songCharacteristicStrings" ofType:@"plist"];
    NSDictionary *songLibrary = [NSDictionary dictionaryWithContentsOfFile:songLibraryPath];
    
    NSString *tfidfQueryString = [songLibrary valueForKey:searchString];
    
    //if we find an exact match, recommend that
    if ([[bookLibrary allKeys] containsObject:tfidfQueryString])
    {
        [self recommend:[bookLibrary valueForKey:tfidfQueryString]];
    }
    //if not, we will find the most similar matches by checking the first GAMMA letters
    else
    {
        NSArray *sentence = [tfidfQueryString componentsSeparatedByCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        NSMutableArray *words = [NSMutableArray arrayWithArray:sentence];
        NSMutableArray *potentialMatches = [NSMutableArray array];
        
        for (NSString *key in [bookLibrary allKeys])
        {
            for (NSString *string in words)
            {
                if (!(string.length >= GAMMA && key.length >= GAMMA)) continue;
                BOOL shouldAdd = YES;
                for (int i = 0; i < GAMMA; i++)
                {
                    if ([string characterAtIndex:i] != [key characterAtIndex:i])
                            shouldAdd = NO;
                }
                if (shouldAdd)
                {
                    [potentialMatches addObject:key];
                    break;
                }
            }
        }
        
        if ( potentialMatches.count == 0 )
        {
            [self error:@"No matches found... sorry! Try another song."];
            return;
        }
        
        //default to the first object in case of categorical ties. 
        NSString *recommendation = [potentialMatches objectAtIndex:0];
        
        //iterate through all combinations of words in book key and song key
        //to get a total similarity score, then choose the book key with the
        //greatest similarity score.
        int mostSimilar = -1;
        for (NSString *key in potentialMatches)
        {
            int similarity = 0;
            NSArray *matchWords = [key componentsSeparatedByCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
            for (NSString *mWord in matchWords)
            {
                for (NSString *word in words)
                {
                    similarity += [self string:word similarToString:mWord];
                }
            }
            if (similarity >= mostSimilar)
            {
                recommendation = key;
                mostSimilar = similarity;
            }
        }
        //recommend most similar key
        [self performSelector:@selector(recommend:) withObject:[bookLibrary valueForKey:recommendation] afterDelay:1.5f];
    }
}

//If the song wasn't found in the database, which it probably wasn't,
//We'll try to extract as much info as we can out of the song title
//and guess from there. 
- (void)randomGuess:(NSString *)key
{
    [self.mainLabel  setStringValue:@"Song not found! Savant is taking a guess ..."];
    
    NSString *bookLibraryPath = [[NSBundle mainBundle] pathForResource:@"bookCharacteristicStrings" ofType:@"plist"];
    NSDictionary *bookLibrary = [NSDictionary dictionaryWithContentsOfFile:bookLibraryPath];
    
    //break song title into individual words, if need be.
    NSArray *words = [[self getTrackName] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    //find which book key has the most similar words to the song titles
    long long mostSimilar = 0;
    NSString *recommendation = nil;
    for (NSString *key in [bookLibrary allKeys])
    {
        int similarity = 0;
        NSArray *matchWords = [key componentsSeparatedByCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        for (NSString *mWord in matchWords)
        {
            for (NSString *word in words)
            {
                similarity += [self string:word similarToString:mWord];
            }
        }
        if (similarity >= mostSimilar)
        {
            recommendation = key;
            mostSimilar = similarity;
        }
    }
    //if we have a recommendation, we'll display it.
    if (recommendation != nil)
        [self performSelector:@selector(recommend:) withObject:[bookLibrary valueForKey:recommendation] afterDelay:1.5f];
    else
    {
        //if we don't have a recommendation, we'll just give up for now.
        [self error:@"Savant tried, it really did... but no matches were found"];
    }
}

//processQuery intercepts iTunes' current track via AppleScript and begins
//to query a plist database to find matches.
- (void)processQuery
{
    //set up UI
    [self displayProcessingUI];
    self.currentSong = [self getTrackName];
    
    NSString *songLibraryPath = [[NSBundle mainBundle] pathForResource:@"songCharacteristicStrings" ofType:@"plist"];
    NSDictionary *songLibrary = [NSDictionary dictionaryWithContentsOfFile:songLibraryPath];
    
    //search strings are in the form <Artist> - <SongTitle>, all lowercase. So we construct a search string. 
    NSString *searchString = [NSString stringWithFormat:@"%@ - %@", [[self getArtistName] lowercaseString], [self.currentSong lowercaseString]];

    //if the search string exists exactly as we find it, then we already have our reccomendation.
    if ([[songLibrary allKeys] containsObject:searchString])
        [self performSelector:@selector(TFIDFLookup:) withObject:searchString afterDelay:2.5f];
    else
    {
        //if not, we'll try to find similar search strings by assigning a
        //similarity cutoff value and taking the first key to pass this cutoff.
        long long cutoff = (searchString.length / SIMILARITY_QUOTENT);
        for (NSString *songKey in [songLibrary allKeys])
        {
            if ([songKey characterAtIndex:0] != [searchString characterAtIndex:0]) continue;
            
            if ([self string:searchString similarToString:songKey] > cutoff)
            {
                [self performSelector:@selector(TFIDFLookup:) withObject:songKey afterDelay:2.5f];
                return;
            }
        }
        //if we still don't have anything, we've gotta improvise
        [self performSelector:@selector(randomGuess:) withObject:searchString afterDelay:2.5f];
    }
}

//Upon pressing the "Open It" button, trigger some AppleScript to open iTunes.
- (IBAction)openItunes:(id)sender
{
    NSDictionary *errorDict;
    NSAppleEventDescriptor *descript;
    NSString *openITunes = @"tell application \"iTunes\" to activate";
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:openITunes];
    descript = [script executeAndReturnError: &errorDict];
    
    if ([descript descriptorType])
        NSLog(@"It's Open.");
    else
        NSLog(@"Script execution has failed. It sucks. Here's what went wrong: %@",
              [errorDict objectForKey: @"NSAppleScriptErrorMessage"]);
    
    //iTunes is never playing by default upon launch
    [self displayiTunesNotPlaying];
}


//Run an applesript line to see if iTunes is open. 
- (BOOL)testIfItunesIsOpen
{
    NSDictionary *errorDict;
    NSAppleEventDescriptor *descript;
    NSString *openITunes = TEST_IF_ITUNES_RUNNING;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:openITunes];
    descript = [script executeAndReturnError: &errorDict];
    
    if ([descript descriptorType])
    {
        if (kAENullEvent != [descript descriptorType])
            return descript.booleanValue == true ? YES : NO;
    }
    return NO;
}

//Run an applescript line to see if iTunes is playing any tracks
- (BOOL)testIfItunesIsPlaying
{
    NSDictionary *errorDict;
    NSAppleEventDescriptor *descript;
    NSString *openITunes = TEST_IF_TRACK_IS_PLAYING;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:openITunes];
    descript = [script executeAndReturnError: &errorDict];
    
    if ([descript descriptorType])
    {
        if (kAENullEvent != [descript descriptorType])
            return descript.booleanValue == true ? YES : NO;
    }
    return NO;
}

//Returns the current track name of the playing song.
//Note that there is no error checking: This must be called
//AFTER it has been verified that itunes is in fact playing something. 
- (NSString *)getTrackName
{
    NSDictionary            *errorDict;
    NSAppleEventDescriptor 	*returnDescriptor;
    NSString *script =  GET_TRACK_NAME;
    NSAppleScript           *scriptObject = [[NSAppleScript alloc] initWithSource: script];
    
    returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
    
    if ([returnDescriptor descriptorType]) {
        if (kAENullEvent != [returnDescriptor descriptorType])
            if (cAEList == [returnDescriptor descriptorType])
                exit(1);
            else
                return returnDescriptor.stringValue;
        else
            NSLog(@"AppleScript has no result.");
    }
    else
        NSLog(@"Your code, and microsoft: both are SUCKING right now: %@", [errorDict objectForKey: @"NSAppleScriptErrorMessage"]);
    return nil;
}

//As above, but for artist. 
- (NSString *)getArtistName
{
    NSDictionary            *errorDict;
    NSAppleEventDescriptor 	*returnDescriptor;
    NSString *script =      GET_ARTIST_NAME;
    NSAppleScript           *scriptObject = [[NSAppleScript alloc] initWithSource: script];
    
    returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
    
    if ([returnDescriptor descriptorType]) {
        if (kAENullEvent != [returnDescriptor descriptorType])
            if (cAEList == [returnDescriptor descriptorType])
                exit(1);
            else
                return returnDescriptor.stringValue;
            else
                NSLog(@"AppleScript has no result.");
    }
    else
        NSLog(@"Your code, and microsoft: both are SUCKING right now: %@", [errorDict objectForKey: @"NSAppleScriptErrorMessage"]);
    return nil;
}
@end
