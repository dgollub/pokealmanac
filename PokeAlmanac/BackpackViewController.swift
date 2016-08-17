//
//  BackpackViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit

private let CELL_IDENTIFIER_BACKPACK = "cellIdentfierBackpackCell"
private let CELL_IDENTIFIER_EMPTY_PACK = "cellIdentfierBackpackEmptyCell"


class BackpackViewController: UITableViewController {
    
    let db = DB()
    let transformer = Transformer()
    
    var data: [PokemonAnnotation]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log("BackpackViewController")
        
        self.title = "Backpack"
    }
    
    func loadData() {
        log("loadData")
//        data = db.loadPokemonsFromBackpackAsPokemonAnnotations()
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
            let cell: BackpackEmptyTableCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER_EMPTY_PACK) as! BackpackEmptyTableCell
            
            return cell
        } else {
            
            // TODO(dkg): move cell in IB in separate XIB file so we can reuse it accross several ViewControllers!
            let cell: BackpackTableCell = self.tableView.dequeueReusableCellWithIdentifier(CELL_IDENTIFIER_BACKPACK, forIndexPath: indexPath) as! BackpackTableCell
            
            if indexPath.row < count {
                if let pokemonData = data {
                    let annotation = pokemonData[indexPath.row]
                    cell.setPokemonData(annotation)
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
            let annotation = pokemonData[indexPath.row]
            let vc: PokemonDetailViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PokemonDetailViewController") as! PokemonDetailViewController
            self.navigationController?.pushViewController(vc, animated: true, completion: { () in
                vc.setPokemonData(annotation.pokemon, thumb: annotation.image)
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
            
            let removeFromBackpack = UITableViewRowAction(style: .Destructive, title: "Let it go?") { action, indexPath in
                if let pokemonData = self.data {
                    let annotation = pokemonData[indexPath.row]
                    // TODO(dkg): ask user if we really should do this!
                    assert(false, "implement me again")
//                    self.db.removePokemonFromBackpack(annotation.pokemon, caughtOnDate: annotation.found!)
                    
                    self.tableView.setEditing(false, animated: true)
                    
                    self.loadData()
                }
            }
            removeFromBackpack.backgroundColor = UIColor.redColor()
            
            return [removeFromBackpack]
        } else {
            return []
        }
    }
    
    
}

