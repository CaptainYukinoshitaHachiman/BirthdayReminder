//
//  AnimeGettingFromServerViewController.swift
//  BirthdayReminder
//
//  Created by Jacky Yu on 17/07/2017.
//  Copyright © 2017 CaptainYukinoshitaHachiman. All rights reserved.
//

import UIKit
import SnapKit

class AnimeGettingFromServerViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    var animes = [Anime]()

    let networkController = ReminderDataNetworkController()
    let loadingView = LoadingView(frame: CGRect(x: 0, y: 0, width: 150, height: 150))
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.separatorStyle = .none
        
        //Loading Progress Viewer
        view.addSubview(loadingView)
        loadingView.center = view.center
        
        tableView.backgroundView?.backgroundColor = UIColor.clear
        tableView.backgroundColor = UIColor.clear
        networkController.networkQueue.async {
            OperationQueue.main.addOperation {
                self.loadingView.start()
            }
            self.animes = self.networkController.getListOfAnimes()
            OperationQueue.main.addOperation {
                self.loadingView.stop()
                self.tableView.separatorStyle = .singleLine
                self.tableView.reloadData()
            }
            self.animes.forEach { anime in
                let pic = self.networkController.get(PicFromStringedUrl: anime.picLink)
                anime.pic = pic
                OperationQueue.main.addOperation {
                    self.tableView.reloadData()
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAnimeDetail" {
            let viewController = segue.destination as! GetPersonalDataFromServerViewController
            viewController.anime = sender as? Anime
            viewController.navigationItem.title = (sender as! Anime).name
        }else if segue.identifier == "customize" {
            let controller = segue.destination as! DetailedPersonalInfoFromServerViewController
            controller.personalData = sender as! BirthPeople
            controller.personalData.status = true
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        performSegue(withIdentifier: "showAnimeDetail", sender: animes[row])
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return animes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "animeCell")
        let row = indexPath.row
        let data = animes[row]
        let image = data.pic
        cell.textLabel?.text = data.name
        let imageView = cell.imageView
        imageView?.image = image
        let layer = imageView?.layer
        layer?.masksToBounds = true
        layer?.cornerRadius = 5
        cell.backgroundView?.backgroundColor = UIColor.clear
        cell.backgroundColor = UIColor.clear
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    @IBAction func other(_ sender: Any) {
        performSegue(withIdentifier: "customize", sender: BirthPeopleManager().creatBirthPeople(name: "", stringedBirth: "01-01", picData: Data()))
    }
    
}

class RoundedSquareCanvas: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let pathRect = bounds.insetBy(dx: 1, dy: 1)
        let path = UIBezierPath(roundedRect: pathRect, cornerRadius: 10)
        path.lineWidth = 3
        UIColor.darkGray.setFill()
        UIColor.lightGray.setStroke()
        path.fill()
        path.stroke()
    }
    
}

class LoadingView:UIView {
    let progressView = UIActivityIndicatorView()
    var square:RoundedSquareCanvas?
    let loadingLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        square = RoundedSquareCanvas(frame: frame)
        self.addSubview(progressView)
        self.addSubview(square!)
        self.addSubview(loadingLabel)
        self.bringSubview(toFront: square!)
        self.bringSubview(toFront: progressView)
        self.bringSubview(toFront: loadingLabel)
        progressView.color = UIColor.white
        progressView.backgroundColor = UIColor.gray
        progressView.center = self.center
        loadingLabel.text = "Loading"
        loadingLabel.textAlignment = .center
        loadingLabel.textColor = UIColor.white
        loadingLabel.font = UIFont(name: "Pingfang SC", size: 20)
        loadingLabel.snp.makeConstraints { constraint in
            constraint.bottom.equalTo(square!).offset(-10)
            constraint.centerX.equalTo(square!)
            constraint.height.equalTo(50)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func start() {
        progressView.startAnimating()
        loadingLabel.isHidden = false
        square?.isHidden = false
    }
    
    func stop() {
        progressView.stopAnimating()
        loadingLabel.isHidden = true
        square?.isHidden = true
    }
    
}