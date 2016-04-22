//
//  TableCell.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit

public class PokemonTableCell : UITableViewCell {
    
    @IBOutlet weak var labelName: UILabel?
    @IBOutlet weak var thumbnail: UIImageView?
    @IBOutlet weak var labelInfo: UILabel?

    public func setPokemonDataJson(pokemonJson: String, thumb: UIImage? = nil) {
        if let pokemon = Transformer().jsonToPokemonModel(pokemonJson) {
            setPokemonData(pokemon, thumb: thumb)
        } else {
            log("could not load or convert Pokemon for JSON")
        }
    }

    public func setPokemonDataId(pokemonId: Int, thumb: UIImage? = nil) {
        if let pokemon = Transformer().jsonToPokemonModel(DB().getPokemonJSON(pokemonId)) {
            setPokemonData(pokemon, thumb: thumb)
        } else {
            log("could not load or convert Pokemon for ID \(pokemonId)")
        }
    }
    
    public func setPokemonData(pokemon: Pokemon, thumb: UIImage? = nil) {
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
        
        // TODO(dkg): show more/different info
        labelInfo!.text = "Height: \(pokemon.height)\nWeight: \(pokemon.weight)"
    }
    
    public func clearCell() {
        labelName!.text = ""
        thumbnail!.image = nil
        labelInfo!.text = ""
    }
}
