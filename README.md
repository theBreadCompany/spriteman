# spriteman

A small script to extract/combine sprites from/to a grid. (-> full name: sprite manager)

## Dislaimer

This is a freetime project done in not that much time, please keep in mind that I won't work on issues as soon as
I can because it is no prioritized project. Also, please mind the LICENSE.

## Please note further

Currently, it can only extract single-tile sprites, a multitile-detection may follow if I'm motivated enough.
Same goes for combines sprites: I have not tested it with multi-tile sprites yet.

Also, the ´--make-alpha` option for `extract` has not been implemented.

## Building

```
git clone https://github.com/thebreadcompany/spriteman.git
cd spriteman
swift build
```

You may wish to use `swift build -c release` instead of `swift build`, 
depending on whether you can confirm for yourself that the tool is roughly doing what you want and debugging is not nescessary.

## Usage

The built tool is in `.build/[debug|release]/spriteman` or depending where you downloaded it of course. 
It is always advised to create a (hidden) directory, add that to your `PATH` and put your executables there.

### Extracting

Basically just `spriteman extract <file> --tilesize <tilesize in px>`, combined with `--output-direcotry <dir>` if required.

### Combining

Even simpler, `spriteman combine <directory>`. The output-file is named after the input directory.

## Output notes

- The output files are not yet completely optimized for space (neither for px area nor for disk space), so the following points may get improved
- all output files have a generic RGB colorspace (8 components, 4 bytes per pixel)
- all output files have an alpha channel, independently of the input file(s) having one or not

## Credits

Escpecially important to aknowledge how to obain pixel data and create `CGContext`s
- https://stackoverflow.com/questions/71169691/getting-a-cgcontext-from-a-cgimage and
- https://gist.github.com/figgleforth/b5b193c3379b3f048210 (including https://gist.github.com/figgleforth/b5b193c3379b3f048210?permalink_comment_id=4069753#gistcomment-4069753)

And of course
- [Apple](https://github.com/apple) for their amazing programming languages that makes this stuff fun to learn
- my brain to somehow get the idea to write this tool simply because I found icon (yes, not sprite) maps on [Nintendo developer](https://developer.nintendo.com) 
