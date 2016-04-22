//
//  BackpackTableCell.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/21.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit


private var dateFormatter: NSDateFormatter? = nil

public class BackpackTableCell : UITableViewCell {
    
    @IBOutlet weak var labelName: UILabel?
    @IBOutlet weak var thumbnail: UIImageView?
    @IBOutlet weak var labelInfo: UILabel?
    
    
    public func setPokemonData(annotation: PokemonAnnotation) {
        
        if dateFormatter == nil {
            dateFormatter = NSDateFormatter()
            dateFormatter!.dateFormat = "yyyy-M-Mdd HH:mm"
        }
        
        let pokemon = annotation.pokemon

        labelName!.text = pokemon.name.capitalizedString
        
        if let image = annotation.image {
            thumbnail!.image = image
        } else if let image = Downloader().getPokemonSpriteFromCache(pokemon) {
            thumbnail!.image = image
        } else  {
            thumbnail!.image = UIImage(named: "IconUnknownPokemon")
            // TODO(dkg): Should we start downloading the sprite in the background???
            //            If we do this, we should also queue the downloads somehow!
        }
        
        // TODO(dkg): show more/different info
        let (lat, lon) = (annotation.coordinate.latitude, annotation.coordinate.longitude)
        if let date = annotation.found {
            labelInfo!.text = "Found on \(dateFormatter!.stringFromDate(date))\n\(lat)°N\n\(lon)°E"
        } else {
            labelInfo!.text = "Found at Location\n\(lat)°N\n\(lon)°E"
        }
        
    }
    
    public func clearCell() {
        labelName!.text = ""
        thumbnail!.image = nil
        labelInfo!.text = ""
    }
}
