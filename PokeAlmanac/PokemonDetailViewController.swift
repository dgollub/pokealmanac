//
//  PokemonDetailViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/20.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit

private enum Tab: Int {
    case Overview = 0, Sprites = 1, Moves = 2, Forms = 3
}


class PokemonDetailViewController: UIViewController {

    @IBOutlet weak var labelName: UILabel?
    @IBOutlet weak var thumbnail: UIImageView?
    @IBOutlet weak var textInfo: UITextView!
    @IBOutlet weak var segmentedControl: UISegmentedControl?
    @IBOutlet weak var spriteImages: UIImageView?
    @IBOutlet weak var labelSprites: UILabel?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    @IBOutlet weak var labelOther: UILabel?
    
    private var pokemon: Pokemon? = nil
    private var currentSpriteType: PokemonSpriteType = PokemonSpriteType.FrontDefault
    
    private let db = DB()
    private let transformer = Transformer()
    private let dl = Downloader()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Pokemon Details"
    }
    
    internal func setPokemonDataJson(pokemonJson: String, thumb: UIImage? = nil) {
        if let pokemon = Transformer().jsonToPokemonModel(pokemonJson) {
            setPokemonData(pokemon, thumb: thumb)
        } else {
            log("could not load or convert Pokemon for JSON")
        }
    }
    
    internal func setPokemonDataId(pokemonId: Int, thumb: UIImage? = nil) {
//        if let pokemon = Transformer().jsonToPokemonModel(DB().getPokemonJSON(pokemonId)) {
//            setPokemonData(pokemon, thumb: thumb)
//        } else {
//            log("could not load or convert Pokemon for ID \(pokemonId)")
//        }
        assert(false, "implement me again")
    }
    
    internal func setPokemonData(pokemon: Pokemon, thumb: UIImage? = nil) {
        
        self.currentSpriteType = PokemonSpriteType.FrontDefault
        self.pokemon = pokemon
        self.title = pokemon.name.capitalizedString
        
        labelName!.text = pokemon.name.capitalizedString
        
        if let image = thumb {
            thumbnail!.image = image
        } else if let image = Downloader().getPokemonSpriteFromCache(pokemon) {
            thumbnail!.image = image
        } else  {
            thumbnail!.image = UIImage(named: "IconUnknownPokemon")
            // TODO(dkg): Should we start downloading the sprite in the background???
            //            If we do this, we should also queue the downloads somehow!
        }

        let leftSwipe = UISwipeGestureRecognizer(target: self, action:  #selector(PokemonDetailViewController.spriteSwipe(_:)))
        let rightSwipe = UISwipeGestureRecognizer(target: self, action:  #selector(PokemonDetailViewController.spriteSwipe(_:)))
        
        leftSwipe.direction = .Left
        rightSwipe.direction = .Right
        
        self.spriteImages?.addGestureRecognizer(leftSwipe)
        self.spriteImages?.addGestureRecognizer(rightSwipe)
        self.spriteImages?.userInteractionEnabled = true
        
        self.showOverview()
    }

    @IBAction func segmentChanged(sender: AnyObject) {
        // TODO(dkg): hide and show textfield or sprite images depending on the currently selected "segment/tab"
        log("segmentChanged \(self.segmentedControl?.selectedSegmentIndex)")
        switch (Tab(rawValue: (self.segmentedControl?.selectedSegmentIndex)!)!) {
        case .Forms:
            showForms()
            break
        case .Moves:
            showMoves()
            break
        case .Overview:
            showOverview()
            break
        case .Sprites:
            showSprites()
            break
        }
    }
    
    func showOverview() {
        self.labelOther?.text = ""
        // TODO(dkg): show more/different info
        
        var games: [String] = []
        for gameIndex: VersionGameIndex in (self.pokemon?.game_indices)! {
            games.append(gameIndex.version.name.capitalizedString)
        }
        let gamesString: String = games.joinWithSeparator(", ")

        func getSpeciesText(json: String?) -> String {
            if let species = self.transformer.jsonToPokemonSpecies(json) {
                let baby = species.is_baby ? "a baby" : "grown up"
                var happiness: String = ""
                switch (species.base_happiness) {
                case 10...25:
                    happiness = "very sad"
                case 25...50:
                    happiness = "sad"
                case 50...75:
                    happiness = "mellow"
                case 75...100:
                    happiness = "feeling under the weather"
                case 125...150:
                    happiness = "feeling good"
                case 125...150:
                    happiness = "feeling pretty nice"
                case 125...150:
                    happiness = "feeling good"
                case 150...200:
                    happiness = "feeling radical"
                case 200...225:
                    happiness = "feeling simply amazing"
                case 225...256:
                    happiness = "feeling simply amazing - what a time to be alive"
                default:
                    happiness = "so very, very, very sad"
                }
                let formSwitcher = species.forms_switchable ? "It can change its form." : "Sadly, it can not change its form."
                
                var flavorText: String = ""
                let filteredFlavorTextEntries = species.flavor_text_entries.filter({ (entry) -> Bool in
                    return entry.language.name.lowercaseString == "en"
                })
                if filteredFlavorTextEntries.count > 0 {
                    // TODO(dkg): some parsing/encoding issues here, need to look into that!
                    let englishTextEntry = filteredFlavorTextEntries[0]
                    flavorText = "\n\n\(englishTextEntry.flavor_text)"
                }
                return "It is \(baby) and is \(happiness).\n\n\(formSwitcher)\(flavorText)"
            }
            return ""
        }
        
        // TODO(dkg): refactor this into common code somewhere so it is easier to re-use
        var speciesText: String = "\(self.pokemon!.species.name.capitalizedString)."
        let speciesUrl: String = self.pokemon!.species.url
        let speciesId: Int = self.dl.extractIdFromUrl(speciesUrl)
        if let speciesJson: String = self.db.getCachedResponse(.PokemonSpecies, requestId: speciesId) {
            speciesText += getSpeciesText(speciesJson)
        } else {
            assert(false, "implement me again")
            // TODO(dkg): better error handling
//            self.dl.startDownload(speciesUrl, completed: { (json, error) in
//                if let json = json {
//                    self.db.insertOrUpdateCachedResponse(.PokemonSpecies, json: json, id: speciesId)
//                    // TODO(dkg): figure out if we are shown or not
//                    if let _ = self.view.window {
//                        if Tab(rawValue: (self.segmentedControl?.selectedSegmentIndex)!)! == Tab.Overview {
//                            self.showOverview() // load again
//                        }
//                    }
//                }
//            })
        }
        
        self.textInfo?.text = "Height: \(self.pokemon!.height), Weight: \(self.pokemon!.weight)\n\n" +
                              "The species is \(speciesText)\n\n" +
                              "This Pokemon is part of the following games: \(gamesString)"
        
        // TODO(dkg): should we animated on .alpha property instead of .hidden?
        UIView.animateWithDuration(0.5, animations: {
            self.textInfo?.hidden = false
            self.spriteImages?.hidden = true
            self.labelSprites?.hidden = true
            self.activityIndicator?.hidden = true
        }) { (finished) in
            //
        }
    }
    
    func showSprites() {
        self.labelOther?.text = "Try swiping left or right on the the thumbnail below."
        // TODO(dkg): should we animated on .alpha property instead of .hidden?
        UIView.animateWithDuration(0.5, animations: {
            self.textInfo?.hidden = true
            self.spriteImages?.hidden = false
            self.labelSprites?.hidden = false
            self.activityIndicator?.hidden = true
        }) { (finished) in
            if self.spriteImages?.image == nil {
                self.loadOrDownloadSprite(false)
            }
        }
    }
    
    // TODO(dkg): showMoves and showForms are very similar -> refactor common code maybe?
    func showMoves() {
        self.labelOther?.text = ""
        self.textInfo?.text = ""
        
        func getMoveText(move: Move) -> String? {
            var text: String = ""
            
            let filteredName = move.names.filter { (name) -> Bool in
                return name.language.name.lowercaseString == "en"
            }
            if filteredName.count > 0 {
                text = filteredName[0].name
            } else {
                return nil
            }
            let power = move.power == nil ? 0 : move.power!
            let accuracy = move.accuracy == nil ? 0 : move.accuracy!
            text += " [Power \(power), Accuracy \(accuracy)]"
            
            let filteredEffect = move.effect_entries.filter { (effect) -> Bool in
                return effect.language.name.lowercaseString == "en"
            }
            
            if filteredEffect.count > 0 {
                let chance = move.effect_chance == nil ? 0 : move.effect_chance!
                let shortEffectDesc = filteredEffect[0].short_effect.stringByReplacingOccurrencesOfString("$effect_chance", withString: "\(chance)")
                let longEffectDesc = filteredEffect[0].effect.stringByReplacingOccurrencesOfString("$effect_chance", withString: "\(chance)")
                text += "\n\(shortEffectDesc)\n\(longEffectDesc)"
            }
            
            return text
        }
        
        let count = self.pokemon!.moves.count
        var counter = 0
        
        var moveStrings: [String] = []
        for moveTmp in self.pokemon!.moves {

            let move: NamedAPIResource = moveTmp.move
            let url = move.url
            let id = dl.extractIdFromUrl(url)
            
            if let json = self.db.getCachedResponse(.Move, requestId: id) {
                counter += 1
                if let move = self.transformer.jsonToMove(json) {
                    if let text = getMoveText(move) {
                        moveStrings.append(text)
                    }
                }
            } else {
                dl.startDownload(url, completed: { (json, error) in
                    counter += 1
                    if let json = json {
                        assert(false, "implement me again")
//                        self.db.insertOrUpdateCachedResponse(.Move, json: json, id: id)
                        // TODO(dkg): figure out if we are shown or not
                        // NOTE(dkg): do not do this within this loop
                        if let _ = self.view.window {
                            if count == counter && Tab(rawValue: (self.segmentedControl?.selectedSegmentIndex)!)! == Tab.Moves {
                                self.showMoves() // load again
                            }
                        }
                    }
                })
                moveStrings.append(move.name)
            }
        }
        
        let moveString = moveStrings.joinWithSeparator("\n\n######\n\n")
        if count == 1 {
            self.textInfo?.text = "This Pokemon has only this one move available to it.\n\n\(moveString)"
        } else {
            self.textInfo?.text = "This Pokemon has \(count) moves available to it.\n\n\(moveString)"
        }
        
        // TODO(dkg): should we animated on .alpha property instead of .hidden?
        UIView.animateWithDuration(0.5, animations: {
            self.textInfo?.hidden = false
            self.spriteImages?.hidden = true
            self.labelSprites?.hidden = true
            self.activityIndicator?.hidden = true
        }) { (finished) in
            //
        }
    }
    
    func showForms() {
        self.labelOther?.text = ""
        self.textInfo?.text = ""
        
        func getFormText(form: PokemonForm) -> String? {
            var text: String = ""
          
            if form.form_name.isEmpty {
                text = form.name.capitalizedString
            } else {
                text = "\(form.name.capitalizedString) (\(form.form_name.capitalizedString))"
            }
            
            if form.is_mega {
                text += "\nThis is the Mega form."
            }
            if form.is_default {
                text += "\nThis is the default form."
            }
            if form.is_battle_only {
                text += "\nThis form is only available during battle."
            }

            return text
        }
        
        let count = self.pokemon!.forms.count
        var counter = 0
        
        var formStrings: [String] = []
        for form in self.pokemon!.forms {
            
            let url = form.url
            let id = dl.extractIdFromUrl(url)
            
            if let json = self.db.getCachedResponse(.PokemonForm, requestId: id) {
                counter += 1
                if let form = self.transformer.jsonToPokemonForm(json) {
                    if let text = getFormText(form) {
                        formStrings.append(text)
                    }
                }
            } else {
                dl.startDownload(url, completed: { (json, error) in
                    counter += 1
                    if let json = json {
                        assert(false, "implement me again")
//                        self.db.insertOrUpdateCachedResponse(.PokemonForm, json: json, id: id)
                        // TODO(dkg): figure out if we are shown or not
                        if let _ = self.view.window {
                            if count == counter && Tab(rawValue: (self.segmentedControl?.selectedSegmentIndex)!)! == Tab.Forms {
                                self.showForms() // load again
                            }
                        }
                    }
                })
                formStrings.append(form.name)
            }
        }
        
        let formString = formStrings.joinWithSeparator("\n\n######\n\n")
        if count == 1 {
            self.textInfo?.text = "This Pokemon has only this one form available to it.\n\n\(formString)"
        } else {
            self.textInfo?.text = "This Pokemon has \(count) forms available to it.\n\n\(formString)"
        }
        
        // TODO(dkg): should we animated on .alpha property instead of .hidden?
        UIView.animateWithDuration(0.5, animations: {
            self.textInfo?.hidden = false
            self.spriteImages?.hidden = true
            self.labelSprites?.hidden = true
            self.activityIndicator?.hidden = true
        }) { (finished) in
            //
        }
    }
 
    func spriteSwipe(sender: UISwipeGestureRecognizer) {
        if sender.direction == .Right {
            self.loadOrDownloadSprite(true, direction: .Right)
        } else if sender.direction == .Left {
            self.loadOrDownloadSprite(true, direction: .Left)
        } else if sender.direction == .Up {
            self.loadOrDownloadSprite(true, direction: .Left)
        } else { // .Down
            self.loadOrDownloadSprite(true, direction: .Right)
        }
    }

    func loadOrDownloadSprite(advance: Bool = true, direction: UISwipeGestureRecognizerDirection = .Left) {
        
        if advance {
            switch(self.currentSpriteType, direction) {
            case (.FrontDefault, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .BackShinyFemale
                break
            case (.FrontDefault, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .FrontShiny
                break
            case (.FrontShiny, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .FrontDefault
                break
            case (.FrontShiny, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .FrontFemale
                break
            case (.FrontFemale, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .FrontShiny
                break
            case (.FrontFemale, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .FrontShinyFemale
                break
            case (.FrontShinyFemale, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .FrontShiny
                break
            case (.FrontShinyFemale, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .BackDefault
                break
            case (.BackDefault, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .FrontShinyFemale
                break
            case (.BackDefault, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .BackShiny
                break
            case (.BackShiny, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .BackDefault
                break
            case (.BackShiny, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .BackFemale
                break
            case (.BackFemale, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .BackShiny
                break
            case (.BackFemale, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .BackShinyFemale
                break
            case (.BackShinyFemale, UISwipeGestureRecognizerDirection.Left):
                self.currentSpriteType = .BackFemale
                break
            case (.BackShinyFemale, UISwipeGestureRecognizerDirection.Right):
                self.currentSpriteType = .FrontDefault
                break
            default:
                log("case not handled: \(self.currentSpriteType) - \(direction)")
                self.currentSpriteType = .FrontDefault
            }
        }
        
        self.labelSprites?.text = self.currentSpriteType.rawValue
        
        if let thumb = self.dl.getPokemonSpriteFromCache(self.pokemon!, type: self.currentSpriteType) {
            self.spriteImages?.image = thumb
        } else {
            self.spriteImages?.image = UIImage(named: "IconUnknownPokemon")
            self.activityIndicator?.hidden = false
            self.activityIndicator?.startAnimating()
            
            self.dl.downloadPokemonSprite(self.pokemon!, type: self.currentSpriteType, completed: { (sprite, type, error) in
                self.activityIndicator?.stopAnimating()
                self.activityIndicator?.hidden = true
                if error == APIError.NoError {
                    self.spriteImages?.image = sprite
                    
                    // set the thumbnail in the upper left corner, just in case it is still the "no sprite found" image
                    if type == PokemonSpriteType.FrontDefault {
                        self.thumbnail?.image = sprite
                    }

                } else if error == APIError.APINoSpriteForThisType {
                    self.labelSprites?.text = "No \(type.rawValue)"
                } else {
                    self.labelSprites?.text = "ERROR!"
                }
            })
        }
    }
    
}