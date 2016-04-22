# PokeAlmanac

A simple iPhone application that uses the version 2 of The RESTful Pokémon Data API at http://pokeapi.co/ (open source).


# Information

The iOS application is written in Swift 2.2 using Xcode 7.3.
An iPhone 6 with iOS 9.3.1 was used for testing.

The app was written over the course of 10 days.

Only a selected subset of the API is used.

Most of the UI elements are defined through InterfaceBuilder. Please have a look at the `Main.storyboard` file in IB.


# Repository

You can find the code on my GitHub account: [https://github.com/dgollub/pokealmanac](https://github.com/dgollub/pokealmanac)

# Preview
![App Preview 01](https://raw.githubusercontent.com/dgollub/pokealmanac/master/preview/pokealmanac-preview-01.gif)

Showing the basic list and details page.


![App Preview 02](https://raw.githubusercontent.com/dgollub/pokealmanac/master/preview/pokealmanac-preview-02.gif)

Showing the map interaction.


# Caching

The app caches the PokeAPI RESTful responses in a local SQLite database, however [modified/created timestamps are not available in version 2 of the API](https://github.com/phalt/pokeapi/issues/140) so there is no cache invalidation for now.


# Known issues
- The `PokemonDetailViewController` looks wonky/distorted on iPhone 5 and 4.
- The LauchScreen.storyboard has a UITabBar, but the custom tab bar items don't show their assigend images on the real device, only on the simulator
- The PokeAPI.co site has quite a few documentation errors.
  Example: /api/v2/pokemon/ has a "moves" property that is supposed to be a list of NamedAPIResource (with type Move entries), however the API returns something slightly different.
  Same for PokemonType that has a "type" property that is supposed to be "string", but it is clearly a NamedAPIResource.


# How to compile

Make sure you have the following libraries and tools installed:

- [XCode Version 7.3 (7D175)](https://developer.apple.com/xcode/) _(or better)_
- [CocoaPods](https://cocoapods.org/)
- [Python 2.7](https://www.python.org/) _(only needed if you want to re-create the generated Swift files from the API again)_

Open up the `*.xcworkspace` file with Xcode and hit that compile button. Enjoy.
(You may have to adjust the team and code signing options before it works.)


# Copyright information

Copyright (c) 2016 by Daniel Kurashige-Gollub <daniel@kurashige-gollub.de>


# Attribution

Pokemon Icon by Chris Banks
License: CC Attribution-Noncommercial-No Derivate 4.0
http://www.iconarchive.com/show/cold-fusion-hd-icons-by-chrisbanks2/pokemon-icon.html

Most other icons are from https://icons8.com

Fonts: Roboto, Noto by Google Material Design
https://www.google.com/design/spec/style/typography.html


# License

Licensed under MIT license. See LICENSE file.
