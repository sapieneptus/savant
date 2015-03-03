# Savant

This project is the culmination of my CS50 course, taught at Harvard University. 

I decided to attempt something NLP related for the course and settled on attempting
to draw connections between books and songs based on textual content. 

This prototype (built over a 2 week period) waits for the user to play a song 
on their iTunes, then attempts to match that song to a book recommendation based
on the lyrical content. The concept is that features such as mood, tone, style of a 
song/book may form some correlation in terms of the 'shared artistry' of the two. 

## How it works
Building the xcode project will create a MacOS app which sits on the desktop and
waits for the user to play a song using iTunes. AppleScript is used to communicate with
iTunes to check for which song is playing. 

The app then consults a database of song lyrics and attempts to use feature-extraction
methods such as TF*IDF to determine a sort of artistic signature for the song. It then
attempts to match that signature to the signatures generated from books (using the entire
Google Books library, with many thanks to Google Inc. for allowing me to download it). 

## Where it's going...

This is a very rough prototype both on the front and back end. If I resume work on the project, 
I will likely start by refining the artistic signature extration piece to include multiple 
dimensions  (in order to capture music that doesn't have lyrics, for example). I would also
connect the app to a cloud to start tracking user intaractions to try to gauge how well the
algorithm works and implement some sort of learning algorithm to work as a dynamic corrective 
factor to the results (such as Neural Net or some sort of weighted clustering). 
