//
//  CubeListPage.swift
//  TccSwift_Example
//
//  Created by hrk on 2020/11/06.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import TccSwift

class CubeListPage: UITableViewController, CubeManagerDelegate {
    
    private let cubeManager = CubeManager()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cubeManager.delegate = self
        cubeManager.startScan()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cubeManager.stopScan()
    }
    
    @IBAction func onRefleshButtonPushed(_ sender: Any) {
        cubeManager.stopScan()
        cubeManager.startScan()
        tableView.reloadData()
    }
    
    // MARK: CubeManagerDelegate
    
    func cubeManager(_ cubeManager: CubeManager, didCubeFound: Cube) {
        tableView.reloadData()
    }
    
    // MARK: UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cubeManager.foundCubeEntries.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CubeListCell", for: indexPath)
        let labels = cell.contentView.subviews.compactMap { $0 as? UILabel }
        if labels.count > 0 {
            if indexPath.row < cubeManager.foundCubeEntries.count {
                let cube = cubeManager.foundCubeEntries[indexPath.row]
                labels.first?.text = "\(cube.name ?? "(no name)")"
                labels.last?.text = "\(cube.identifierString)"
            }
        }
        return cell
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < cubeManager.foundCubeEntries.count {
            connectToCube(cubeManager.foundCubeEntries[indexPath.row])
        }
    }
    
    // MARK: Connect to cubes
    
    private func connectToCube(_ cube:Cube) {
        cube.connect() {
            switch $0 {
            case .success(let cube):
                self.performSegue(withIdentifier: "showCubeControllerPage", sender: cube)
                break
            case .failure(let error):
                let alertController = UIAlertController(title: "Connection Failed", message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let page = segue.destination as? CubeControllerPage, let cube = sender as? Cube {
            page.cube = cube
        }
    }
}
