//
//  IndexViewController.swift
//  BirthdayReminder
//
//  Created by Jacky Yu on 20/07/2017.
//  Copyright © 2017 CaptainYukinoshitaHachiman. All rights reserved.
//
//  swiftlint:disable line_length

import UIKit
import CoreData
import SnapKit
import ViewAnimator
import MobileCoreServices
import IGRPhotoTweaks
import NVActivityIndicatorView
import SafariServices
import CFNotify

class IndexViewController: ViewController, ManagedObjectContextUsing {

    weak var delegate: AppDelegate! {
        let app = UIApplication.shared
        let delegate = app.delegate as? AppDelegate
        return delegate
    }
    var frc: NSFetchedResultsController<PeopleToSave>!
    @IBOutlet weak var tableView: UITableView!

    private var data = [PeopleToSave]()
    private var timeShouldShowAsLocalizedDate = true

    private var isContributing = false {
        didSet {
            tableView.allowsMultipleSelection = isContributing
            if isContributing {
                onContribute()
            } else {
                navigationItem.setLeftBarButtonItems([], animated: true)
            }
        }
    }
    private var animePic: UIImage!
    private var picCopyright: String!
    private var animeName: String!
    private var contactInfo: String!

    private var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("emptyLabelText", comment: "emptyLabelText")
        label.font = .systemFont(ofSize: 25)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let activityIndicator = NVActivityIndicatorView(frame: CGRect(origin: .zero, size: CGSize(width: 150, height: 150)), type: .orbit, color: .tertiarySystemFill, padding: nil)
    private let indicatorBackground = UIView()
    private let uploadingLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupEmptyLabel()
        setupTableView()
        setupIndicator()
        tableView.animate(animations: [AnimationType.zoom(scale: 0.5)])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Decide to show tutorial or not
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "beenLaunched") {
            present(tutorialController, animated: true, completion: nil)
        }
    }

    private func setupEmptyLabel() {
        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.lessThanOrEqualToSuperview()
            make.width.lessThanOrEqualToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        emptyLabel.bringSubviewToFront(tableView)
    }

    @IBAction func onAddTapped(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController()
        alertController.popoverPresentationController?.barButtonItem = sender
        let newPersonAction = UIAlertAction(title: NSLocalizedString("new", comment: "New"), style: .default) { _ in
            let controller = PersonFormController(with: .new(nil))
            controller.title = NSLocalizedString("new", comment: "New")
            controller.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.pushViewController(controller, animated: true)
        }
        newPersonAction.setValue(UIImage(systemName: "square.and.pencil"), forKey: "image")
        let showRemoteAction = UIAlertAction(title: NSLocalizedString("remote", comment: "remote"), style: .default) { _ in
            self.performSegue(withIdentifier: "showAnimes", sender: nil)
        }
        showRemoteAction.setValue(UIImage(systemName: "globe"), forKey: "image")
        alertController.addAction(newPersonAction)
        alertController.addAction(showRemoteAction)
        present(alertController, animated: true, completion: nil)
    }

    private func setupTableView() {
        tableView.tableFooterView = UIView()
        let request = PeopleToSave.sortedFetchRequest
        frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: "index")
        frc.delegate = self
        do {
            try frc.performFetch()
            data = frc.fetchedObjects!
            data = BirthComputer.peopleOrderedByBirthday(peopleToReorder: data)
        } catch {
            fatalError(error.localizedDescription)
        }
        checkDataAndDisplayPlaceHolder()
    }

    private func setupIndicator() {
        indicatorBackground.backgroundColor = .gray
        indicatorBackground.alpha = 0.5
        indicatorBackground.isHidden = true
        view.addSubview(indicatorBackground)
        indicatorBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        uploadingLabel.isHidden = true
        uploadingLabel.text = NSLocalizedString("uploading", comment: "Uploading...")
        uploadingLabel.font = UIFont.systemFont(ofSize: 32)
        view.addSubview(uploadingLabel)
        uploadingLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(activityIndicator.snp.bottom).offset(5)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            switch identifier {
            case "birthdayCard":
                if let person = sender as? PeopleToSave {
                    (segue.destination as? BirthCardController)?.person = person
                }
            default:
                break
            }
        }
    }

    @IBAction func changeDateDisplayingType(_ sender: UIBarButtonItem) {
        timeShouldShowAsLocalizedDate = !timeShouldShowAsLocalizedDate
        let image = UIImage(systemName: timeShouldShowAsLocalizedDate ? "ellipsis" : "calendar" )
        sender.image = image
        tableView.reloadData()
    }

    private func checkDataAndDisplayPlaceHolder() {
        tableView.separatorStyle = .none
        if data.isEmpty {
            emptyLabel.isHidden = false
        } else {
            emptyLabel.isHidden = true
        }
    }

}

extension IndexViewController: NSFetchedResultsControllerDelegate {

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let person = anObject as? PeopleToSave else { return }
        let index = data.firstIndex(of: person)
        switch type {
        case .insert:
            data.append(person)
            data.sort()
            tableView.reloadData()
            NotificationManager.onInsert(person: person)
        case .delete:
            data.remove(at: index!)
            tableView.deleteRows(at: [IndexPath(row: index!, section: 0)], with: .automatic)
            NotificationManager.onRemove(person: person)
        case .update:
            tableView.reloadRows(at: [IndexPath(row: index!, section: 0)], with: .automatic)
            NotificationManager.onModify(person: person)
        default:
            break
        }
        checkDataAndDisplayPlaceHolder()
        delegate.syncWithAppleWatch()
    }

}

extension IndexViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let index = indexPath.row
        let cellData = data[index]
        let cell = tableView.dequeueReusableCell(withIdentifier: "personalCell", for: indexPath)
        guard let personCell = cell as? PersonalCell else { fatalError() }
        personCell.nameLabel.text = cellData.name
        personCell.birthLabel.text = timeShouldShowAsLocalizedDate ? cellData.birth.toLocalizedDate() : cellData.birth.toLeftDays()
        DispatchQueue.global(qos: .userInteractive).async {
            let picImage: UIImage?
            if let imgData = cellData.picData {
                picImage = UIImage(data: imgData)
            } else {
                picImage = UIImage().scaled(to: 200)
            }
            DispatchQueue.main.async {
                personCell.picView.image = picImage
            }
        }
        cell.addInteraction(UIContextMenuInteraction(delegate: self))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.allowsMultipleSelection {
            let index = indexPath.row
            let person = data[index]
            let readyForContribution = person.picCopyright != nil && person.picCopyright != ""
            if !readyForContribution {
                tableView.reloadRows(at: [indexPath], with: .automatic)
                illegalContributionAlert()
            }
        } else {
            performSegue(withIdentifier: "birthdayCard", sender: data[indexPath.row])
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

}

extension IndexViewController: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = interaction.view as? PersonalCell,
            let indexPath = tableView.indexPath(for: cell),
            let controller = UIStoryboard.main.instantiateViewController(withIdentifier: "birthCard") as? BirthCardController
            else { return nil }
        let person = data[indexPath.row]
        controller.person = person
        func contextMenuMaker(_ menuElements: [UIMenuElement]) -> UIMenu? {
            let share = UIAction(title: NSLocalizedString("share", comment: "share"), image: UIImage(systemName: "square.and.arrow.up")) { [unowned self] _ in
                controller.share(on: self, from: cell.nameLabel)
            }
            let edit = UIAction(title: NSLocalizedString("edit", comment: "edit"), image: UIImage(systemName: "pencil")) { [unowned self] _ in
                let editController = PersonFormController(with: .persistent(person))
                self.show(editController, sender: nil)
            }
            let delete = UIAction(title: NSLocalizedString("delete", comment: "delete"), image: UIImage(systemName: "trash"), attributes: .destructive) { [unowned self] _ in
                do {
                    self.context.delete(person)
                    try self.context.save()
                } catch {
                    let cfView = CFNotifyView.cyberWith(title: NSLocalizedString("failedToSave", comment: "FailedToSave"), body: error.localizedDescription, theme: .fail(.light))
                    var config = CFNotify.Config()
                    config.initPosition = .top(.center)
                    config.appearPosition = .top
                    CFNotify.present(config: config, view: cfView)
                    self.tableView.reloadData()
                }
            }
            
            return UIMenu(title: "", children: [share, edit, delete])
        }
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: { controller }, actionProvider: contextMenuMaker)
        return configuration
    }
    
}

// MARK: - Contributing
extension IndexViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, IGRPhotoTweakViewControllerDelegate {

    public func startContributingIfNotAlready() {
        if isContributing != true {
            isContributing = true
        }
    }

    private func onContribute() {
        showContributeInstructions()
        let buttonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(sender:)))
        navigationItem.setLeftBarButtonItems([buttonItem], animated: true)
    }

    private func showContributeInstructions() {
        let alertController = UIAlertController(title: NSLocalizedString("you're entering contributing mode", comment: "You're entering contributing mode"), message: NSLocalizedString("for more details, checkout the contributing guide", comment: "For more details, checkout the contributing guide"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("show the guide", comment: "Show the guide"), style: .default) { _ in
            let sfController = SFSafariViewController(url: "https://github.com/CaptainYukinoshitaHachiman/BirthReminder/blob/master/ContributingGuide.md")
            self.present(sfController, animated: true)
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .default) { _ in self.isContributing = false })
        present(alertController, animated: true)
    }

    private func illegalContributionAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("no pic copyright provided", comment: "No pic copyright provided"), message: NSLocalizedString("Pic copyright is required to contribute, please edit the character before contributing", comment: "pic copyright is required to contribute, please edit the character before contributing"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("got it", comment: "Got it"), style: .default))
        present(alertController, animated: true)
    }

    @objc private func done(sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: NSLocalizedString("end choosing", comment: "End choosing"), message: NSLocalizedString("are you sure to contribute these selected characters?", comment: "Are you sure to contribute these selected characters?"), preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: String.localizedStringWithFormat(
            NSLocalizedString("contribute the selected %d character(s)", comment: "Contribute the selected %d character(s)"),
            tableView.indexPathsForSelectedRows?.count ?? 0), style: .default) { _ in
                self.getAnimeName()
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("make a few more changes", comment: "Make a few more changes"), style: .cancel))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("exit contributing mode", comment: "Exit contributing mode"), style: .destructive) { _ in
            self.isContributing = false
        })
        alertController.popoverPresentationController?.barButtonItem = sender
        present(alertController, animated: true, completion: nil)
    }

    private func getAnimeName() {
        let alertController = UIAlertController(title: NSLocalizedString("what's the name of the character set?", comment: "What's the name of the character set?"), message: NSLocalizedString("e.g. Anime names, Galgame names, Lightnovel names...", comment: "e.g. Anime names, Galgame names, Lightnovel names..."), preferredStyle: .alert)
        alertController.addTextField { field in
            field.placeholder = NSLocalizedString("the name of the set of characters", comment: "The name of the set of characters")
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("next", comment: "Next"), style: .default) { _ in
            self.animeName = alertController.textFields!.first!.text!
            self.askForAnimePic()
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel) { _ in self.isContributing = false })
        present(alertController, animated: true)
    }

    private func askForAnimePic() {
        let alertController = UIAlertController(title: NSLocalizedString("choose the pic for the set", comment: "Choose the pic for the set"), message: NSLocalizedString("its copyright info is also required", comment: "Its copyright info is also required"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("choose from album", comment: "Choose from album"), style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            let picker = UIImagePickerController()
            picker.allowsEditing = false
            picker.delegate = self
            picker.mediaTypes =  [kUTTypeImage as String]
            picker.sourceType = .savedPhotosAlbum
            self.present(picker, animated: true, completion: nil)
        })
        present(alertController, animated: true)
    }

    func photoTweaksController(_ controller: IGRPhotoTweakViewController, didFinishWithCroppedImage croppedImage: UIImage) {
        animePic = croppedImage
    }

    func photoTweaksControllerDidCancel(_ controller: IGRPhotoTweakViewController) {
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        animePic = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) {
            // cropping
            let controller = SquareImageCroppingViewController()
            controller.image = self.animePic
            controller.delegate = self
            controller.previousController = self
            controller.misc = self.askForCopyrightInfo
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        isContributing = false
    }

    private func askForCopyrightInfo() {
        let alertController = UIAlertController(title: NSLocalizedString("copyright Info", comment: "Copyright Info"), message: NSLocalizedString("enter the copyright info for the pic you've just selected", comment: "Enter the copyright info for the pic you've just selected"), preferredStyle: .alert)
        alertController.addTextField { field in
            field.placeholder = NSLocalizedString("copyright Info", comment: "Copyright Info")
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("next", comment: "Next"), style: .default) { _ in
            self.picCopyright = alertController.textFields?.first?.text
            self.askForContactInfo()
        })
        present(alertController, animated: true, completion: nil)
    }

    private func askForContactInfo() {
        let alertController = UIAlertController(title: NSLocalizedString("almost done", comment: "Almost done"), message: NSLocalizedString("finally, leave your contact info here.\n It's not forced, but we can then express our strong thankfulness through the info if you do so.", comment: "Finally, leave your contact info here.\n It's not forced, but we can then express our strong thankfulness through the info if you do so."), preferredStyle: .alert)
        alertController.addTextField { field in
            field.placeholder = NSLocalizedString("nickname and contact info (optional)", comment: "Nickname and contact info (optional)")
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("submit", comment: "Submit"), style: .default) { _ in
            self.contactInfo = alertController.textFields?.first?.text
            self.submit()
        })
        present(alertController, animated: true, completion: nil)
    }

    private func submit() {
        let animePicPack = PicPack(image: animePic, copyrightInfo: picCopyright)!
        let people: [People] = (tableView.indexPathsForSelectedRows ?? []).map { indexPath in
            let index = indexPath.row
            let person =  data[index]
            let name = person.name
            let birth = person.birth
            let picData = person.picData!
            let copyright = person.picCopyright!
            let personForContribution = People(withName: name, birth: birth, picData: picData, id: nil)
            personForContribution.picPack?.copyright = copyright
            return personForContribution
        }
        activityIndicator.startAnimating()
        indicatorBackground.isHidden = false
        uploadingLabel.isHidden = false
        NetworkController.networkQueue.async {
            NetworkController.provider.request(TCWQService.contribution(animeName: self.animeName, animePicPack: animePicPack, people: people, contributorInfo: self.contactInfo)) { result in
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.indicatorBackground.isHidden = true
                    self.uploadingLabel.isHidden = true
                    switch result {
                    case .success(let response):
                        if response.statusCode == 200 {
                            self.isContributing = false
                            let controller = UIAlertController(title: NSLocalizedString("done", comment: "Done"), message: NSLocalizedString("contributionThanks", comment: "contributionThanks"), preferredStyle: .alert)
                            controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "ok"), style: .default))
                            self.present(controller, animated: true, completion: nil)
                        } else {
                            let controller = UIAlertController(title: NSLocalizedString("failedToUpload", comment: "Failed To Upload"), message: "Status code: \(response.statusCode)\nError message: \(String(data: response.data, encoding: .utf8) ?? "Empty")", preferredStyle: .alert)
                            controller.addAction(UIAlertAction(title: NSLocalizedString("retry", comment: "Retry"), style: .default) { _ in
                                self.submit()
                            })
                            controller.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .default) { _ in
                                self.isContributing = false
                            })
                            self.present(controller, animated: true, completion: nil)
                        }
                    case .failure(let error):
                        let controller = UIAlertController(title: NSLocalizedString("failedToUpload", comment: "Failed To Upload"), message: error.localizedDescription, preferredStyle: .alert)
                        controller.addAction(UIAlertAction(title: NSLocalizedString("retry", comment: "Retry"), style: .default) { _ in
                            self.submit()
                        })
                        controller.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .default) { _ in
                            self.isContributing = false
                        })
                        self.present(controller, animated: true, completion: nil)
                    }
                }
            }
        }
    }

}
