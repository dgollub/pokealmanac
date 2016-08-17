//
//  RateViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit

private let CELL_IDENTIFIER = "cellIdentfierFavs"
private let CELL_IDENTIFIER_NO_FAVS = "cellIdentifierNoFavs"

// TODO(dkg): lots of duplicated code between this and the ListViewController - think about 
//            better BaseListViewController class implementation for common code
class FavoritesViewController: UITableViewController {
    
    let db = DB()
    let transformer = Transformer()

    var data: [Pokemon]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log("FavoritesViewController")
        
        self.title = "Favorites"
    }
    
    func loadData() {
        log("loadData")
//        data = db.loadFavoritePokemons()
        assert(false, "implement me again")
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        log("viewWillAppear")
        loadData()
    }
    
    // tableView callbacks
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if data?.count == 0 {
            return 1 // display special cell
        }
        return (data?.count)!
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let count = data?.count
        
        if count == 0 {
            // "no favorites yet" cell
            let cell: PokemonTableLoadMoreCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER_NO_FAVS) as! PokemonTableLoadMoreCell
            
            return cell
        } else {
            
            // TODO(dkg): move cell in IB in separate XIB file so we can reuse it accross several ViewControllers!
            let cell: PokemonTableCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER, forIndexPath: indexPath) as! PokemonTableCell
            
            if indexPath.row < count {
                if let pokemonData = data {
                    let pokemon = pokemonData[indexPath.row]
                    cell.setPokemonData(pokemon)
                } else {
                    cell.clearCell()
                }
            } else {
                log("this should not happen")
            }
            
            return cell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        log("Tapped on cell at \(indexPath)")
        
        if let pokemonData = data {
            let pokemon = pokemonData[indexPath.row]
            let vc: PokemonDetailViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PokemonDetailViewController") as! PokemonDetailViewController
            self.navigationController?.pushViewController(vc, animated: true, completion: { () in
                vc.setPokemonData(pokemon)
            })
        }
    }

    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        log("editActionsForRowAtIndexPath \(indexPath)")
        // NOTE(dkg): Maybe use a 3rd party library for this instead, that allows swipes in all directions and has different
        //            animation options for the swipe, e.g. https://github.com/MortimerGoro/MGSwipeTableCell
        
        // TODO(dkg): implement the following
        //              - "catch" -> try to catch that pokemon (you can catch as many of the same as you want)
        
        if data?.count > 0 {

            let favorite = UITableViewRowAction(style: .Normal, title: "Remove") { action, indexPath in
                if let pokemonData = self.data {
                    let pokemon = pokemonData[indexPath.row]
                    
                    assert(false, "implement me again")
//                    self.db.updatePokemonFavoriteStatus(pokemon.id, isFavorite: false)
                    
                    self.tableView.setEditing(false, animated: true)
                    
                    self.loadData()
                }
            }
            favorite.backgroundColor = UIColor.orangeColor()
            
            return [favorite]
        } else {
            return []
        }
    }

    
}

